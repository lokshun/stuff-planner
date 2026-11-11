"""CONTRAT
Importe butins et stats observées sur Forever depuis WoW-Spyglass (MIT), dossier .contribute/data.
  COMMIT -> révision épinglée ; la changer est le seul moyen de rafraîchir les données
  fetch(cache_dir, opener=None) -> dossier cache_dir/COMMIT complété ; RuntimeError si réseau en échec
  load_drops(source_dir) -> (drops, instances), sans réseau
    drops = [{"item", "instance", "raid", "chance", "npc"}, ...] ; chance en %, npc nil hors boss
    instances = {mapID d'instance: {"id", "minLevel", "maxLevel", "reqLevel", "mapID", "raid", "bosses"}} ;
    bosses = [npcID...] dans l'ordre des rencontres (`encounters`), absent si aucune n'a de PNJ
  load_scan(source_dir) -> {itemID: {"quality", "ilvl", "reqLevel", "stats"}}
  convert_stats(raw) -> stats en clés internes ; clés inconnues ignorées
Butin saisi à la main ou observé en jeu par les auteurs : couverture partielle, surtout sans taux.
"""

import json
from pathlib import Path

from sources import cache
from sources.wago import RATING_PER_PERCENT, percent

COMMIT = "20292cfa88cac1fac3e56a1b1131deaa0d2024d8"
TREE_URL = "https://api.github.com/repos/Karl-HeinzSchneider/WoW-Spyglass/git/trees/{commit}?recursive=1"
RAW_URL = "https://raw.githubusercontent.com/Karl-HeinzSchneider/WoW-Spyglass/{commit}/{path}"
DATA_ROOT = ".contribute/data/"
SECTIONS = ("dungeons", "raids", "items")
TREE_FILE = "tree.json"

STAT_KEYS = {
    "STRENGTH": "STR",
    "AGILITY": "AGI",
    "STAMINA": "STA",
    "INTELLECT": "INT",
    "SPIRIT": "SPI",
    "ATTACK_POWER": "AP",
    "RANGED_ATTACK_POWER": "RAP",
    "SPELL_POWER": "SPELL_POWER",
    "SPELL_HEALING_DONE": "HEALING",
    "SPELL_DAMAGE_DONE": "SPELL_DMG",
    "HOLY_DAMAGE_DONE": "HOLY_DMG",
    "FIRE_DAMAGE_DONE": "FIRE_DMG",
    "NATURE_DAMAGE_DONE": "NATURE_DMG",
    "FROST_DAMAGE_DONE": "FROST_DMG",
    "SHADOW_DAMAGE_DONE": "SHADOW_DMG",
    "ARCANE_DAMAGE_DONE": "ARCANE_DMG",
    "HIT_RATING": "HIT",
    "CRIT_RATING": "CRIT",
    "HASTE_RATING": "HASTE",
    "DODGE_RATING": "DODGE",
    "PARRY_RATING": "PARRY",
    "BLOCK_RATING": "BLOCK",
    "DEFENSE_SKILL_RATING": "DEF",
    "BLOCK_VALUE": "BLOCK_VALUE",
    "MANA_REGENERATION": "MP5",
    "HEALTH_REGEN": "HP5",
    "SPELL_PENETRATION": "SPELL_PEN",
    "DAMAGE_PER_SECOND": "DPS",
    "RESISTANCE0_NAME": "ARMOR",
    "HOLY_RESISTANCE": "RES_HOLY",
    "RESISTANCE1_NAME": "RES_HOLY",
    "FIRE_RESISTANCE": "RES_FIRE",
    "RESISTANCE2_NAME": "RES_FIRE",
    "NATURE_RESISTANCE": "RES_NATURE",
    "RESISTANCE3_NAME": "RES_NATURE",
    "FROST_RESISTANCE": "RES_FROST",
    "RESISTANCE4_NAME": "RES_FROST",
    "SHADOW_RESISTANCE": "RES_SHADOW",
    "RESISTANCE5_NAME": "RES_SHADOW",
    "ARCANE_RESISTANCE": "RES_ARCANE",
    "RESISTANCE6_NAME": "RES_ARCANE",
}


def fetch(cache_dir, opener=None):
    target = Path(cache_dir) / COMMIT
    cache.complete(target, {TREE_FILE: TREE_URL.format(commit=COMMIT)}, opener)
    tree = json.loads((target / TREE_FILE).read_text(encoding="utf-8"))
    urls = {}
    for entry in tree["tree"]:
        path = entry["path"]
        if entry["type"] != "blob" or not path.startswith(DATA_ROOT) or not path.endswith(".json"):
            continue
        parts = path[len(DATA_ROOT) :].split("/")
        if len(parts) == 2 and parts[0] in SECTIONS:
            urls[f"{parts[0]}__{parts[1]}"] = RAW_URL.format(commit=COMMIT, path=path)
    return cache.complete(target, urls, opener)


def _documents(source_dir, section):
    for path in sorted(Path(source_dir).glob(f"{section}__*.json")):
        yield json.loads(path.read_text(encoding="utf-8"))


def _rows(document):
    for encounter in document.get("encounters") or []:
        for row in encounter.get("loot") or []:
            yield row, encounter.get("npc")
    for row in document.get("trash") or []:
        yield row, None


def _instance(document, raid):
    record = {
        "id": document["map"],
        "minLevel": document.get("minLevel"),
        "maxLevel": document.get("maxLevel"),
        "reqLevel": document.get("requiredLevel"),
        "mapID": document.get("zone"),
        "raid": raid,
    }
    bosses = []
    for encounter in document.get("encounters") or ():
        npc = encounter.get("npc")
        if isinstance(npc, int) and npc not in bosses:
            bosses.append(npc)
    if bosses:
        record["bosses"] = bosses
    return {field: value for field, value in record.items() if value is not None}


def load_drops(source_dir):
    drops = []
    instances = {}
    for section, raid in (("dungeons", False), ("raids", True)):
        for document in _documents(source_dir, section):
            instance_id = document["map"]
            instances.setdefault(instance_id, _instance(document, raid))
            for row, npc in _rows(document):
                if not isinstance(row.get("item"), int):
                    continue
                chance = row.get("chance")
                drops.append(
                    {
                        "item": row["item"],
                        "instance": instance_id,
                        "raid": raid,
                        "chance": None if chance is None else round(chance * 100, 2),
                        "npc": npc,
                    }
                )
    return drops, instances


def convert_stats(raw):
    stats = {}
    for name, value in raw.items():
        key = STAT_KEYS.get(name)
        if key is not None:
            rate = RATING_PER_PERCENT.get(key)
            stats[key] = percent(value, rate) if rate else value
    return stats


def load_scan(source_dir):
    scan = {}
    for document in _documents(source_dir, "items"):
        for item_id, row in document.items():
            scan[int(item_id)] = {
                "quality": row["quality"],
                "ilvl": row["itemLevel"],
                "reqLevel": max(row["reqLevel"], 1),
                "stats": convert_stats(row.get("stats") or {}),
            }
    return scan
