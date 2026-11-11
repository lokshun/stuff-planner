"""CONTRAT
Fusionne les exports des joueurs (/splan export, StuffPlanner/Data/Export.lua) en couche Overlay.
  decode(text), ExportError : réexportés de tools/export_codec.py
  read_exports(paths) -> chaînes SP1, une par ligne non vide, sans doublon, dans l'ordre des fichiers
  merge(exports) -> Merged(overlay, conflicts, rejected, loot, timings) ; exports = liste de listes
    d'enregistrements décodés. Par export, la dernière valeur non nulle de chaque champ (level, mapID,
    rewards, choices) d'une quête l'emporte ; entre exports, vote à la majorité, égalité = champ omis.
    overlay = {"quests": {questID: {champ: valeur}}, "items": {itemID: {"stats": {clé: valeur}}}} ;
    "items" absent sans objet ; kind "log" (lu dans le journal) : choices et rewards seulement ; stats lues en jeu (kind "item", ItemProbe) : dernière par export, vote
    entre exports comme un champ. Butins et médianes (kind "timing") comptés, pas fusionnés.
  report_lines(merged, exports, illegible) -> lignes du rapport : bilan, puis un conflit par ligne
  load_overlay(path) / save_overlay(path, overlay) : overlay.json (clés en texte dans le fichier)
Usage : python tools/merge_exports.py [fichiers...] [--json tools/overlay.json] [--out StuffPlanner_Data]
  sans fichier : tools/exports/*.txt ; écrit overlay.json et <out>/Overlay.lua si <out> existe ;
  code 1 si un export est illisible (les autres sont fusionnés quand même).
"""

import argparse
import json
import sys
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

import emit_lua
from export_codec import ExportError, decode  # noqa: F401 (réexportés)

ROOT = Path(__file__).resolve().parents[1]
QUEST_KINDS = frozenset({"detail", "complete", "log"})
ITEM_KIND = "item"
FIELDS = ("level", "mapID", "rewards", "choices")
LISTS = frozenset({"rewards", "choices"})


@dataclass
class Conflict:
    questID: int
    field: str
    votes: list
    chosen: object
    table: str = "quests"


@dataclass
class Merged:
    overlay: dict
    conflicts: list = field(default_factory=list)
    rejected: int = 0
    loot: int = 0
    timings: int = 0


def read_exports(paths):
    seen = []
    for path in paths:
        for line in Path(path).read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and line not in seen:
                seen.append(line)
    return seen


def _is_id(value):
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _is_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _clean_stats(record):
    """Stats d'objet figées (tuple trié de paires), ou None si l'enregistrement est rejeté."""
    stats = record.get("stats")
    if stats == []:
        stats = {}
    if not _is_id(record.get("itemID")) or not isinstance(stats, dict):
        return None
    if not all(isinstance(key, str) and _is_number(value) for key, value in stats.items()):
        return None
    return tuple(sorted(stats.items()))


def _clean(record):
    """Champs de quête valides, "loot", ou None si l'enregistrement est rejeté."""
    if not isinstance(record, dict) or record.get("kind") not in QUEST_KINDS | {"loot"}:
        return None
    if record["kind"] == "loot":
        return "loot"
    if not _is_id(record.get("questID")):
        return None
    kept = {}
    for name in FIELDS:
        value = record.get(name)
        if value is None:
            continue
        if name in LISTS:
            if isinstance(value, dict) and not value:
                value = []
            if not isinstance(value, list) or not all(_is_id(item) for item in value):
                return None
            value = tuple(value)
        elif not _is_id(value):
            return None
        kept[name] = value
    return kept


def _latest(records, merged):
    quests, items = {}, {}
    if not isinstance(records, list):
        merged.rejected += 1
        return quests, items
    for record in records:
        if isinstance(record, dict) and record.get("kind") == "timing":
            merged.timings += 1
            continue
        if isinstance(record, dict) and record.get("kind") == ITEM_KIND:
            stats = _clean_stats(record)
            if stats is None:
                merged.rejected += 1
            else:
                items[record["itemID"]] = stats
            continue
        kept = _clean(record)
        if kept is None:
            merged.rejected += 1
        elif kept == "loot":
            merged.loot += 1
        else:
            quests.setdefault(record["questID"], {}).update(kept)
    return quests, items


def _plain(value):
    return list(value) if isinstance(value, tuple) else value


def _elect(counter):
    """(valeur gagnante | None si égalité, votes triés)."""
    ranked = sorted(counter.items(), key=lambda pair: (-pair[1], pair[0]))
    tie = len(ranked) > 1 and ranked[0][1] == ranked[1][1]
    return (None if tie else ranked[0][0]), ranked


def _merge_items(merged, votes):
    items = {}
    for item_id in sorted(votes):
        chosen, ranked = _elect(votes[item_id])
        if len(ranked) > 1:
            plain = [(dict(value), count) for value, count in ranked]
            merged.conflicts.append(
                Conflict(item_id, "stats", plain, None if chosen is None else dict(chosen), "items"))
        if chosen is not None:
            items[item_id] = {"stats": dict(chosen)}
    if items:
        merged.overlay["items"] = items


def merge(exports):
    merged = Merged(overlay={"quests": {}})
    votes, item_votes = {}, {}
    for records in exports:
        quests, items = _latest(records, merged)
        for quest_id, fields in quests.items():
            for name, value in fields.items():
                votes.setdefault(quest_id, {}).setdefault(name, Counter())[value] += 1
        for item_id, stats in items.items():
            item_votes.setdefault(item_id, Counter())[stats] += 1
    for quest_id in sorted(votes):
        fields = {}
        for name in FIELDS:
            counter = votes[quest_id].get(name)
            if not counter:
                continue
            chosen, ranked = _elect(counter)
            if len(ranked) > 1:
                plain = [(_plain(value), count) for value, count in ranked]
                merged.conflicts.append(Conflict(quest_id, name, plain, _plain(chosen)))
            if chosen is not None:
                fields[name] = _plain(chosen)
        if fields:
            merged.overlay["quests"][quest_id] = fields
    _merge_items(merged, item_votes)
    return merged


def _count(number, singular, plural):
    return f"{number} {singular if number <= 1 else plural}"


def report_lines(merged, exports, illegible):
    lines = [
        f"{_count(exports, 'export lu', 'exports lus')}, {_count(illegible, 'illisible', 'illisibles')} ; "
        f"{_count(len(merged.overlay['quests']), 'quête corrigée', 'quêtes corrigées')} ; "
        f"{_count(len(merged.overlay.get('items', {})), 'objet lu', 'objets lus')} ; "
        f"{_count(merged.loot, 'butin ignoré', 'butins ignorés')} ; "
        f"{_count(merged.rejected, 'rejeté', 'rejetés')}"
    ]
    for conflict in merged.conflicts:
        votes = " contre ".join(f"{value} ({count})" for value, count in conflict.votes)
        outcome = "égalité, champ omis" if conflict.chosen is None else str(conflict.chosen)
        label = "Objet" if conflict.table == "items" else "Quête"
        lines.append(f"{label} {conflict.questID}, {conflict.field} : {votes} → {outcome}")
    return lines


def load_overlay(path):
    raw = json.loads(Path(path).read_text(encoding="utf-8"))
    return {table: {int(key): fields for key, fields in rows.items()} for table, rows in raw.items()}


def save_overlay(path, overlay):
    text = json.dumps(overlay, ensure_ascii=False, indent=1, sort_keys=True) + "\n"
    Path(path).write_bytes(text.encode("utf-8"))


def main(argv=None):
    parser = argparse.ArgumentParser(description="Fusionne les exports SP1 en Overlay.")
    parser.add_argument("files", nargs="*")
    parser.add_argument("--json", default=str(ROOT / "tools" / "overlay.json"))
    parser.add_argument("--out", default=str(ROOT / "StuffPlanner_Data"))
    args = parser.parse_args(argv)
    sys.stdout.reconfigure(encoding="utf-8")
    files = args.files or sorted((ROOT / "tools" / "exports").glob("*.txt"))
    decoded, illegible = [], []
    for index, text in enumerate(read_exports(files), start=1):
        try:
            decoded.append(decode(text))
        except ExportError as error:
            illegible.append(f"Export {index} illisible : {error.code}")
    merged = merge(decoded)
    for line in report_lines(merged, len(decoded) + len(illegible), len(illegible)) + illegible:
        print(line)
    save_overlay(args.json, merged.overlay)
    out = Path(args.out)
    if out.is_dir():
        overlay = load_overlay(args.json)
        (out / "Overlay.lua").write_bytes(emit_lua.emit_overlay(overlay).encode("utf-8"))
    return 1 if illegible else 0


if __name__ == "__main__":
    sys.exit(main())
