"""Audit en lecture seule des stats « Équipé » : comment les sources codent chaque bonus.

Usage : .venv/Scripts/python tools/audit_equip_stats.py [dossier_wago]
Sorties (texte) :
  1. codes de StatModifier d'ItemSparse absents de wago.STAT_KEYS (nombre d'objets, exemple) ;
  2. clés brutes du scan Spyglass absentes de spyglass.STAT_KEYS ;
  3. combinaisons de clés à sorts : client seul, scan seul, client + scan ;
  4. objets où enrich_items ajoute SPELL_POWER du scan à des clés à sorts du client (double comptage) ;
  5. clés du scan ignorées par enrich_items (seules DPS et SPELL_POWER sont reprises).
Ne modifie rien ; lit tools/cache.
"""

import collections
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from precompute import SCAN_ONLY_STATS  # noqa: E402
from sources import spyglass, wago  # noqa: E402

CACHE = ROOT / "cache"
SPELL_KEYS = (
    "SPELL_POWER", "SPELL_DMG", "HEALING",
    "HOLY_DMG", "FIRE_DMG", "NATURE_DMG", "FROST_DMG", "SHADOW_DMG", "ARCANE_DMG",
)


def wago_dir():
    if len(sys.argv) > 1:
        return Path(sys.argv[1])
    wanted = CACHE / "wago" / wago.BUILD
    if wanted.exists():
        return wanted
    return sorted((CACHE / "wago").glob("1.*"))[-1]


def unknown_codes(source_dir):
    sparse = wago.read_table(source_dir, "ItemSparse", wago.COLUMNS["ItemSparse"])
    counts, examples = collections.Counter(), {}
    for item_id, row in sparse.items():
        for slot in range(wago.STAT_SLOTS):
            code = int(row[f"StatModifier_bonusStat_{slot}"])
            if code >= 0 and code not in wago.STAT_KEYS and int(row[f"StatPercentEditor_{slot}"]):
                counts[code] += 1
                examples.setdefault(code, item_id)
    return counts, examples


def raw_scan(source_dir):
    raw = {}
    for path in sorted(Path(source_dir).glob("items__*.json")):
        for item_id, row in json.loads(path.read_text(encoding="utf-8")).items():
            raw[int(item_id)] = row.get("stats") or {}
    return raw


def spell_combo(stats):
    return tuple(key for key in SPELL_KEYS if key in stats)


def main():
    source = wago_dir()
    spy_dir = CACHE / "spyglass" / spyglass.COMMIT
    print(f"wago : {source.name} ; spyglass : {spyglass.COMMIT[:8]}")

    counts, examples = unknown_codes(source)
    print("\n1. Codes ItemSparse non lus (code : objets, exemple)")
    for code, count in counts.most_common():
        print(f"   {code} : {count}, ex. {examples[code]}")

    raw = raw_scan(spy_dir)
    names = collections.Counter(name for stats in raw.values() for name in stats if name not in spyglass.STAT_KEYS)
    print("\n2. Clés du scan non reprises (clé : objets)")
    for name, count in names.most_common():
        print(f"   {name} : {count}")

    items = {item["id"]: item for item in wago.load_items(source)}
    scan = {item_id: spyglass.convert_stats(stats) for item_id, stats in raw.items()}
    combos = collections.Counter()
    sample = {}
    doubled, ignored = [], collections.Counter()
    for item_id in sorted(set(items) | set(scan)):
        client = items.get(item_id, {}).get("stats", {})
        scanned = scan.get(item_id, {})
        label = ("client " + "+".join(spell_combo(client)) if spell_combo(client) else "") + (
            " | scan " + "+".join(spell_combo(scanned)) if spell_combo(scanned) else ""
        )
        if label:
            combos[label.strip()] += 1
            sample.setdefault(label.strip(), (item_id, {k: client[k] for k in spell_combo(client)},
                                              {k: scanned[k] for k in spell_combo(scanned)}))
        if item_id in items:
            if "SPELL_POWER" in scanned and "SPELL_POWER" not in client and spell_combo(client):
                doubled.append((item_id, dict(client), dict(scanned)))
            for key in scanned:
                if key not in SCAN_ONLY_STATS and key not in client:
                    ignored[key] += 1

    print("\n3. Combinaisons de clés à sorts (objets, exemple : id, client, scan)")
    for label, count in combos.most_common():
        print(f"   {count:5d}  {label}  ex. {sample[label]}")

    print(f"\n4. SPELL_POWER du scan ajouté à des clés à sorts du client : {len(doubled)} objets")
    for item_id, client, scanned in doubled[:15]:
        print(f"   {item_id} client={ {k: client[k] for k in spell_combo(client)} } scan={ {k: scanned[k] for k in spell_combo(scanned)} }")

    print("\n5. Clés du scan absentes du client et ignorées par enrich_items (clé : objets)")
    for key, count in ignored.most_common():
        print(f"   {key} : {count}")


if __name__ == "__main__":
    main()
