"""CONTRAT
Construit StuffPlanner_Data : lecture des sources, puis écriture par emit_lua.
  build(source_dir, out_dir, interfaces, quests=None, items=None, recipes=None, crafts=None, drops=(), instances=(),
        npcs=(), npc_names=None, report=None, overlay=None, era_items=(), quest_names=None, item_names=None)
    -> {"quests": n, "items": n, "origins": n, "instances": n, "npcNames": n, "questNames": n, "itemNames": n, "eraItems": n,
        "instanceQuests": n, "memory": octets,
        "eraMemory": octets} ;
    npc_names ({langue: {npcID: nom}}) réduit aux donneurs et aux boss, un fichier par langue ; quest_names,
    item_names (même forme) réduits aux quêtes et objets émis : repli des noms du client ; `quests` et `items`
    remplacent les fichiers de source_dir ; overlay ({"quests": {id: champs}}, tools/overlay.json
    de merge_exports.py) devient Overlay.lua ; `origins` est précalculé ; seuls les objets ayant une
    origine sont émis ; era_items (precompute.era_differences) réduit aux objets émis sans `forever`, écrit
    dans EraItems.lua ; `memory` : estimation en jeu (lua_memory) hors EraItems, `eraMemory` : EraItems seul ; report(ligne) reçoit le rapport
    de validation ; ValueError sans rien écrire si une erreur bloquante est trouvée
  read_interfaces(addon_dir) -> {"Camelot": 16001, ...}, lu dans les TOC de l'addon principal
Sources (cache dans tools/cache) : QuestieDB, wago.tools (Forever et Classic Era), NorgannonDB, Spyglass.
Quêtes absentes de la base Classic de QuestieDB et objets absents d'ItemSparse Classic Era : forever = 1.
Usage : python tools/build_db.py ; affiche les comptes en une ligne.
"""

import json
import re
import sys
from pathlib import Path

import emit_lua
import lua_memory
import merge_exports
import precompute
import schema
import validate_db
from sources import norgannon, questie, spyglass, wago, wago_era

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCES = ROOT / "tools" / "tests" / "fixtures"
CACHE_DIR = ROOT / "tools" / "cache"
ADDON_DIR = ROOT / "StuffPlanner"
OUT_DIR = ROOT / "StuffPlanner_Data"
OVERLAY = ROOT / "tools" / "overlay.json"
TABLES = ("quests", "items")


def read_interfaces(addon_dir):
    interfaces = {}
    for toc in sorted(Path(addon_dir).glob("StuffPlanner_*.toc")):
        match = re.search(r"^## Interface:\s*(\d+)", toc.read_text(encoding="utf-8"), re.MULTILINE)
        if not match:
            raise ValueError(f"{toc.name} : ## Interface introuvable")
        interfaces[toc.stem.removeprefix("StuffPlanner_")] = int(match.group(1))
    return interfaces


def _bosses(origins):
    raid_kinds = (schema.ORIGIN_KINDS["dungeon"], schema.ORIGIN_KINDS["raid"])
    return {
        entry[3] for origin in origins for entry in origin["entries"]
        if entry[0] in raid_kinds and len(entry) > 3 and entry[3]
    }


# Une langue ne charge que son fichier : l'anglais comble ses trous, plutôt que le repli « Quest #id ».
def _wanted_names(by_locale, wanted):
    english = {key: name for key, name in (by_locale or {}).get("enUS", {}).items() if key in wanted}
    names = {}
    for locale, table in (by_locale or {}).items():
        kept = {key: name for key, name in table.items() if key in wanted}
        if kept:
            names[locale] = {**english, **kept}
    return names


def build(
    source_dir,
    out_dir,
    interfaces,
    quests=None,
    items=None,
    recipes=None,
    crafts=None,
    drops=(),
    instances=(),
    npcs=(),
    npc_names=None,
    report=None,
    overlay=None,
    era_items=(),
    quest_names=None,
    item_names=None,
):
    tables = {}
    for table in TABLES:
        path = Path(source_dir) / f"{table}.json"
        tables[table] = json.loads(path.read_text(encoding="utf-8"))
    if quests is not None:
        tables["quests"] = quests
    if items is not None:
        tables["items"] = items
    tables["origins"] = precompute.origin_records(
        tables["quests"], tables["items"], recipes or {}, drops, crafts
    )
    with_origin = {origin["id"] for origin in tables["origins"]}
    tables["items"] = [item for item in tables["items"] if item["id"] in with_origin]
    tables["instances"] = list(instances)
    starters = {quest.get("starter") for quest in tables["quests"]} - {None}
    tables["npcs"] = [npc for npc in npcs if npc["id"] in starters]
    findings = validate_db.validate(tables)
    lines = validate_db.report_lines(findings)
    if report:
        for line in lines:
            report(line)
    if any(finding.blocking for finding in findings):
        errors = [line for line, finding in zip(lines, findings) if finding.blocking]
        raise ValueError("Base refusée : " + " ; ".join(errors))
    common = {item["id"] for item in tables["items"] if not item.get("forever")}
    era = [record for record in era_items if record["id"] in common]
    names = _wanted_names(npc_names, starters | _bosses(tables["origins"]))
    quest_names = _wanted_names(quest_names, {quest["id"] for quest in tables["quests"]})
    item_names = _wanted_names(item_names, {item["id"] for item in tables["items"]})
    emit_lua.write_addon(out_dir, {**tables, "eraItems": era}, interfaces, names, overlay, quest_names, item_names)
    counts = {table: len(records) for table, records in tables.items()}
    counts["eraItems"] = len(era)
    counts["instanceQuests"] = sum(1 for quest in tables["quests"] if quest.get("instance"))
    counts["eraMemory"] = lua_memory.estimate({"eraItems": era})
    counts["npcNames"] = len(names.get("enUS", {}))
    counts["questNames"] = len(quest_names.get("enUS", {}))
    counts["itemNames"] = len(item_names.get("enUS", {}))
    counts["memory"] = lua_memory.estimate(tables)
    return counts


def load_sources():
    questie_dir = questie.fetch(CACHE_DIR / "questie")
    quests = questie.load_quests(questie_dir)
    npcs = questie.load_npcs(questie_dir, {quest["starter"] for quest in quests} - {None})
    wago_dir = wago.fetch(CACHE_DIR / "wago")
    era_dir = wago_era.fetch(CACHE_DIR / "wago_era")
    spy_dir = spyglass.fetch(CACHE_DIR / "spyglass")
    norgannon_dir = norgannon.fetch(CACHE_DIR / "norgannon")
    norgannon_drops, norgannon_instances = norgannon.load(norgannon_dir, questie.npc_zones(questie_dir))
    spy_drops, spy_instances = spyglass.load_drops(spy_dir)
    drops = precompute.merge_drops(norgannon_drops, spy_drops)
    instances = {record["id"]: record for record in precompute.merge_instances(norgannon_instances, spy_instances)}
    scan = spyglass.load_scan(spy_dir)
    forever_items = wago.load_items(wago_dir)
    items = precompute.enrich_items(forever_items, scan)
    known = {item["id"] for item in items}
    wanted = {item for quest in quests for item in quest["rewards"] + quest["choices"]}
    wanted |= {drop["item"] for drop in drops}
    era_items = wago_era.load_items(era_dir)
    hidden = precompute.hidden_items(
        wanted - known, wago.load_bases(wago_dir), scan, era_items
    )
    return {
        "quests": precompute.mark_instances(
            precompute.mark_forever(quests, questie.load_classic_quest_ids(questie_dir)),
            questie.load_quest_areas(questie_dir),
            norgannon.area_instances(norgannon_dir),
            instances,
        ),
        "items": precompute.mark_forever(items + hidden, set(era_items)),
        "recipes": wago.load_recipes(wago_dir),
        "crafts": wago.load_crafts(wago_dir),
        "drops": drops,
        "instances": list(instances.values()),
        "npcs": npcs,
        "npc_names": questie.load_npc_names(questie_dir),
        "quest_names": questie.load_names(questie_dir, "quest"),
        "item_names": questie.load_names(questie_dir, "item"),
        "era_items": precompute.era_differences(forever_items, era_items, scan),
    }


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    try:
        sources = load_sources()
        if OVERLAY.exists():
            sources["overlay"] = merge_exports.load_overlay(OVERLAY)
        counts = build(DEFAULT_SOURCES, OUT_DIR, read_interfaces(ADDON_DIR), report=print, **sources)
    except (RuntimeError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1
    print(
        f"Base : {counts['quests']} quêtes, {counts['items']} objets, "
        f"{counts['origins']} objets avec origine, {counts['instances']} instances, "
        f"{counts['npcs']} donneurs placés, {counts['eraItems']} objets différents sur Classic Era, "
        f"{counts['instanceQuests']} quêtes de donjon ou de raid, "
        f"noms de base : {counts['questNames']} quêtes, {counts['itemNames']} objets"
    )
    print(f"Mémoire estimée en jeu : {counts['memory'] // 1024} Ko (Lua 5.1, 64 bits), EraItems {counts['eraMemory'] // 1024} Ko")
    return 0


if __name__ == "__main__":
    sys.exit(main())
