"""CONTRAT
Importe le butin des boss des instances Classic depuis NorgannonDB (GPL-3.0), sans exécuter son Lua.
  COMMIT -> révision épinglée ; la changer est le seul moyen de rafraîchir les données
  fetch(cache_dir, opener=None) -> dossier cache_dir/COMMIT complété ; RuntimeError si réseau en échec
  load(source_dir, npc_zones=None) -> (drops, instances), sans réseau ; npc_zones = {npcID: zone}
    drops = [{"item", "instance", "raid", "chance", "npc"}, ...], triés ; chance en %
    npc nil : butin hors boss de l'instance, une ligne au meilleur taux par monstre
    instances = {mapID d'instance: {"id", "minLevel", "maxLevel", "mapID", "size", "raid", "bosses"}} ;
    bosses = [npcID...] dans l'ordre de la liste `bosses` de la source, ailes à la suite (ordre des clés)
  area_instances(source_dir) -> {areaID: instanceID} des instances gardées par load (zone d'instance)
Seules sont gardées les lignes à taux réel, sur un identifiant d'objet Classic, hors instance
Forever : le contenu issu de DungeonJournal n'est autorisé qu'à l'auteur de NorgannonDB, et les
taux viennent de pfQuest (MIT). Ces taux sont ceux de Vanilla. Les ailes d'une instance fusionnent.
Si plusieurs identifiants d'instance partagent une zone, le plus petit est retenu, comme Spyglass.
"""

import re
from pathlib import Path

from sources import cache, lua_table

COMMIT = "73f59a53f1423149d548725e1786a18168d670e9"
RAW_URL = "https://raw.githubusercontent.com/zmarotrix/NorgannonDB/{commit}/data/{name}"
FILES = ("items.lua", "world.lua")
FOREVER_ITEM_IDS = 200000
RECORD = re.compile(r'^R\((\d+),"(?:[^"\\]|\\.)*",\[\[(.*)\]\]\)$', re.MULTILINE)


def fetch(cache_dir, opener=None):
    urls = {name: RAW_URL.format(commit=COMMIT, name=name) for name in FILES}
    return cache.complete(Path(cache_dir) / COMMIT, urls, opener)


def _global_table(text, name):
    marker = f"NorgannonDB.{name} ="
    return lua_table.parse(text, None, text.index(marker) + len(marker))


def _item_drops(source_dir):
    text = (Path(source_dir) / "items.lua").read_text(encoding="utf-8")
    drops = {}
    for match in RECORD.finditer(text):
        record = lua_table.parse("{" + match.group(2) + "}")
        sources = record.get("drops")
        if isinstance(sources, dict) and isinstance(sources.get("npcs"), dict):
            drops[int(match.group(1))] = sources["npcs"]
    return drops


def _instance_ids(maps):
    ids = {}
    for instance_id in sorted(maps["instanceToArea"], reverse=True):
        ids[maps["instanceToArea"][instance_id]] = instance_id
    return ids


def _merge_wing(instances, instance_id, data, maps):
    levels = data.get("levels") or {}
    entrance = data.get("entrance") or {}
    current = instances.setdefault(
        instance_id,
        {
            "id": instance_id,
            "minLevel": levels.get("min"),
            "maxLevel": levels.get("max"),
            "mapID": maps["areaToUiMap"].get(entrance.get("area")),
            "size": data.get("size"),
            "raid": bool(data.get("raid")),
        },
    )
    if "min" in levels:
        current["minLevel"] = min(current["minLevel"], levels["min"])
        current["maxLevel"] = max(current["maxLevel"], levels["max"])
    bosses = current.setdefault("bosses", [])
    listed = data.get("bosses") or {}
    for boss in (listed[key] for key in sorted(listed)) if isinstance(listed, dict) else listed:
        npc = boss.get("id") if isinstance(boss, dict) else None
        if isinstance(npc, int) and npc not in bosses:
            bosses.append(npc)


def _boss_drops(data, instance_id, npc_drops):
    for boss in (data.get("bosses") or {}).values():
        if not isinstance(boss, dict):
            continue
        npc = boss.get("id")
        for item in (boss.get("loot") or {}).values():
            chance = npc_drops.get(item, {}).get(npc, 0)
            if item < FOREVER_ITEM_IDS and chance > 0:
                yield {
                    "item": item,
                    "instance": instance_id,
                    "raid": bool(data.get("raid")),
                    "chance": chance,
                    "npc": npc,
                }


def _trash_drops(npc_drops, boss_rows, npc_zones, areas, raids):
    best = {}
    for item, sources in npc_drops.items():
        if item >= FOREVER_ITEM_IDS:
            continue
        for npc, chance in sources.items():
            instance_id = areas.get(npc_zones.get(npc))
            if instance_id is None or chance <= 0 or (item, instance_id) in boss_rows:
                continue
            best[(item, instance_id)] = max(best.get((item, instance_id), 0), chance)
    return [
        {"item": item, "instance": instance_id, "raid": raids[instance_id], "chance": chance, "npc": None}
        for (item, instance_id), chance in best.items()
    ]


def _kept(world):
    known = _instance_ids(_global_table(world, "maps"))
    table = _global_table(world, "instances")
    for key in sorted(table):
        data = table[key]
        instance_id = known.get(data.get("area"))
        if not data.get("forever") and instance_id is not None:
            yield instance_id, data


def area_instances(source_dir):
    world = (Path(source_dir) / "world.lua").read_text(encoding="utf-8")
    return {data["area"]: instance_id for instance_id, data in _kept(world)}


def load(source_dir, npc_zones=None):
    world = (Path(source_dir) / "world.lua").read_text(encoding="utf-8")
    maps = _global_table(world, "maps")
    npc_drops = _item_drops(source_dir)
    instances = {}
    drops = []
    areas = {}
    for instance_id, data in _kept(world):
        _merge_wing(instances, instance_id, data, maps)
        areas[data["area"]] = instance_id
        drops.extend(_boss_drops(data, instance_id, npc_drops))
    boss_rows = {(drop["item"], drop["instance"]) for drop in drops}
    raids = {instance_id: record["raid"] for instance_id, record in instances.items()}
    drops.extend(_trash_drops(npc_drops, boss_rows, npc_zones or {}, areas, raids))
    drops.sort(key=lambda drop: (drop["item"], drop["instance"], drop["npc"] or 0))
    return drops, instances
