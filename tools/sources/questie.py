"""CONTRAT
Importe les quêtes Forever de QuestieDB (github.com/Questie/QuestieDB), sans exécuter leur Lua.
  COMMIT -> révision épinglée ; la changer est le seul moyen de rafraîchir les données
  FILES -> chemins amont nécessaires
  fetch(cache_dir, opener=None) -> dossier cache_dir/COMMIT complété ; RuntimeError si réseau en échec
  load_quests(source_dir) -> enregistrements `quests` triés par id, sans réseau
  npc_zones(source_dir) -> {npcID: zone}, sans réseau
  load_npcs(source_dir, ids) -> enregistrements `npcs` {id, mapID, x, y} des PNJ demandés ayant une
    position, triés par id, sans réseau
  load_quest_areas(source_dir) -> {questID: zoneOrSort} des zones positives (donjons compris ; négatif =
    catégorie, ignoré), sans réseau ; lu par precompute.mark_instances
  load_classic_quest_ids(source_dir) -> {questID} de Classic Era (base Classic + classicQuestFixes), sans réseau
  load_names(source_dir, kind) -> {"enUS": {id: nom}, langue: {...}}, kind "npc" | "quest" | "item" :
    anglais de la base (couches comprises), traductions l10n/Forever/lookup<Npcs|Quests|Items> puis traces
    (prioritaires) ; langue sans fichier absente. load_npc_names(source_dir) = load_names(source_dir, "npc")
Couches, dans l'ordre amont (docs/forever.md) : brut, legacy, delta, traces, corrections d'auteur.
Les corrections de faction et par personnage sont ignorées.
Écarts avec la source :
  rewards/choices : QuestieDB ne sait que « cette quête donne cet objet ». Un seul objet -> rewards,
    plusieurs -> tous en choices (un seul compté, donc prudent), confidence 2.
  mapID : zone de la quête, sinon zone du PNJ donneur d'ID le plus bas qui en a une, sinon nil.
  prereq : tous requis ; un élément liste signifie « l'un de ceux-ci ». Identifiant négatif de
    preQuestGroup : la quête reste requise, Questie saute seulement son contrôle d'exclusivité.
    Une quête citée dans ses propres prérequis en est retirée.
  starter : PNJ donneur (créature) d'ID le plus bas qui a une position, sinon nil ; objets et
    objets-déclencheurs ignorés.
  Position d'un PNJ : premier point valide (0–100) de sa zone, sinon de la plus petite zone connue
    de areaIdToUiMapId ; convertie en fraction 0–1 à 4 décimales. Points négatifs (instances) ignorés.
  classMask, raceMask : nil si aucune restriction ; constantes reprises de enum/expansions.lua.
  confidence : 3 sûr, 2 répartition devinée, 1 niveau absent de la source.
"""

import re
from pathlib import Path

from sources import cache, lua_table

COMMIT = "21be34023b72cf2ec3027cb9a61a8b72a1910857"
RAW_URL = "https://raw.githubusercontent.com/Questie/QuestieDB/{commit}/{path}"

QUEST_DB = "data/Forever/foreverQuestDB.lua"
ITEM_DB = "data/Forever/foreverItemDB.lua"
NPC_DB = "data/Forever/foreverNpcDB.lua"
CLASSIC_QUEST_DB = "data/Classic/classicQuestDB.lua"
CORRECTIONS = "src/corrections/Forever"
QUEST_LAYERS = (
    f"{CORRECTIONS}/legacy/classicQuestFixes.lua",
    f"{CORRECTIONS}/generated/foreverBaseQuest.lua",
    f"{CORRECTIONS}/traces/foreverQuestTraces.lua",
    f"{CORRECTIONS}/foreverQuestFixes.lua",
)
ITEM_LAYERS = (
    f"{CORRECTIONS}/legacy/classicItemFixes.lua",
    f"{CORRECTIONS}/generated/foreverBaseItem.lua",
    f"{CORRECTIONS}/traces/foreverItemTraces.lua",
    f"{CORRECTIONS}/foreverItemFixes.lua",
)
NPC_LAYERS = (
    f"{CORRECTIONS}/legacy/classicNPCFixes.lua",
    f"{CORRECTIONS}/generated/foreverBaseNpc.lua",
    f"{CORRECTIONS}/traces/foreverNpcTraces.lua",
    f"{CORRECTIONS}/foreverNPCFixes.lua",
)
AREA_MAP = "support/Forever/Zones/areaIdToUiMapId.lua"
ZONE_ENUM = "src/corrections/enum/zones.lua"
SORT_ENUM = "src/corrections/enum/quests.lua"
FILES = (
    (QUEST_DB, ITEM_DB, NPC_DB, CLASSIC_QUEST_DB)
    + QUEST_LAYERS
    + ITEM_LAYERS
    + NPC_LAYERS
    + (AREA_MAP, ZONE_ENUM, SORT_ENUM)
)

QUEST_FIELDS = (
    "name",
    "startedBy",
    "requiredLevel",
    "questLevel",
    "preQuestGroup",
    "preQuestSingle",
    "zoneOrSort",
    "requiredRaces",
    "requiredClasses",
)
ALLIANCE_RACES = 1 + 4 + 8 + 64 + 2**32
HORDE_RACES = 2 + 16 + 32 + 128 + 2**33
RACE_KEYS = {
    "NONE": 0,
    "HUMAN": 1,
    "ORC": 2,
    "DWARF": 4,
    "NIGHT_ELF": 8,
    "UNDEAD": 16,
    "TAUREN": 32,
    "GNOME": 64,
    "TROLL": 128,
    "SKYBORNE_ALLIANCE": 2**32,
    "SKYBORNE_HORDE": 2**33,
    "ALL_ALLIANCE": ALLIANCE_RACES,
    "ALL_HORDE": HORDE_RACES,
}
CLASS_KEYS = {
    "NONE": 0,
    "WARRIOR": 1,
    "PALADIN": 2,
    "HUNTER": 4,
    "ROGUE": 8,
    "PRIEST": 16,
    "SHAMAN": 64,
    "MAGE": 128,
    "WARLOCK": 256,
    "DRUID": 1024,
}
LOCALES = ("deDE", "esES", "esMX", "frFR", "koKR", "ptBR", "ruRU", "zhCN", "zhTW")
NAME_SOURCES = {
    "npc": ("lookupNpcs", NPC_DB, NPC_LAYERS),
    "quest": ("lookupQuests", QUEST_DB, QUEST_LAYERS),
    "item": ("lookupItems", ITEM_DB, ITEM_LAYERS),
}
L10N_FILES = {
    name: path
    for kind, (folder, _, _) in NAME_SOURCES.items()
    for locale in LOCALES
    for name, path in (
        (f"{kind}Names_{locale}.lua", f"l10n/Forever/{folder}/{locale}.lua"),
        (f"{kind}NamesTraces_{locale}.lua", f"l10n/Forever/traces/{folder}/{locale}.lua"),
    )
    if locale != "zhCN" or "Traces" not in name
}
L10N_BODY = re.compile(r"\[\[(.*?)\]\]", re.DOTALL)
KEY_LINE = re.compile(r"^\s*\['(\w+)'\]\s*=\s*(\d+)", re.MULTILINE)
KEY_TABLES = ("questKeys", "itemKeys", "npcKeys")
CREATURE_STARTERS = 1


def fetch(cache_dir, opener=None):
    urls = {Path(path).name: RAW_URL.format(commit=COMMIT, path=path) for path in FILES}
    urls.update({name: RAW_URL.format(commit=COMMIT, path=path) for name, path in L10N_FILES.items()})
    return cache.complete(Path(cache_dir) / COMMIT, urls, opener)


def _read(source_dir, path):
    return (Path(source_dir) / Path(path).name).read_text(encoding="utf-8")


def _enum(text, name):
    marker = f"constants.{name} ="
    return lua_table.parse(text, None, text.index(marker) + len(marker))


def _resolver(source_dir):
    tables = {
        "zoneIDs": _enum(_read(source_dir, ZONE_ENUM), "zoneIDs"),
        "sortKeys": _enum(_read(source_dir, SORT_ENUM), "sortKeys"),
        "raceIDs": RACE_KEYS,
        "classIDs": CLASS_KEYS,
    }

    def resolve(path):
        head, _, tail = path.partition(".")
        if head in KEY_TABLES:
            return tail
        return tables.get(head, {}).get(tail, lua_table.UNRESOLVED)

    return resolve


def _edit(current, change, remove):
    current = current if isinstance(current, dict) else {}
    if not isinstance(change, dict):
        return current
    if change and all(isinstance(part, dict) for part in change.values()):
        result = dict(current)
        for position, part in change.items():
            result[position] = _edit(result.get(position), part, remove)
        return result
    values = list(current.values())
    if remove:
        values = [value for value in values if value not in change.values()]
    else:
        values += [value for value in change.values() if value not in values]
    return dict(enumerate(values, 1))


def _apply_fix(row, fix, fields):
    for key, value in fix.items():
        if not isinstance(key, str):
            continue
        if key in fields:
            row[key] = value
        elif key.endswith("_add") and key[:-4] in fields:
            row[key[:-4]] = _edit(row.get(key[:-4]), value, remove=False)
        elif key.endswith("_remove") and key[:-7] in fields:
            row[key[:-7]] = _edit(row.get(key[:-7]), value, remove=True)


def _entities(source_dir, raw_path, layers, fields, resolve):
    text = _read(source_dir, raw_path)
    indices = {name: int(index) for name, index in KEY_LINE.findall(text)}
    body = lua_table.long_strings(text)[0].removeprefix("return ")
    entities = {
        entity_id: {field: raw.get(indices[field]) for field in fields}
        for entity_id, raw in lua_table.parse(body).items()
    }
    for path in layers:
        text = _read(source_dir, path)
        start = lua_table.load_body(text)
        if start is None:
            raise ValueError(f"{path} : fonction Load introuvable")
        for entity_id, fix in lua_table.parse(text, resolve, start).items():
            if isinstance(entity_id, int) and isinstance(fix, dict):
                _apply_fix(entities.setdefault(entity_id, {}), fix, fields)
    return entities


def _area_map(source_dir):
    tables = [
        lua_table.parse(block.removeprefix("return "))
        for block in lua_table.long_strings(_read(source_dir, AREA_MAP))
    ]
    areas = {}
    for table in reversed(tables):
        areas.update(table)
    return areas


def _ints(table):
    if not isinstance(table, dict):
        return []
    return sorted(value for value in table.values() if isinstance(value, int))


def _int(value):
    return value if isinstance(value, int) and not isinstance(value, bool) else None


def _creatures(row):
    starters = row.get("startedBy")
    return _ints(starters.get(CREATURE_STARTERS) if isinstance(starters, dict) else None)


def _coordinate(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and 0 <= value <= 100


def _point(points):
    for point in points.values() if isinstance(points, dict) else ():
        if isinstance(point, dict) and _coordinate(point.get(1)) and _coordinate(point.get(2)):
            return round(point[1] / 100, 4), round(point[2] / 100, 4)
    return None


def _position(row, areas):
    spawns = row.get("spawns") if isinstance(row, dict) else None
    if not isinstance(spawns, dict):
        return None
    zones = sorted(zone for zone in spawns if _int(zone))
    home = _int(row.get("zoneID"))
    if home in zones:
        zones.remove(home)
        zones.insert(0, home)
    for zone in zones:
        map_id = areas.get(zone)
        point = _point(spawns[zone]) if map_id else None
        if point:
            return map_id, point[0], point[1]
    return None


def _starter(row, npcs, areas):
    for npc in _creatures(row):
        if _position(npcs.get(npc), areas):
            return npc
    return None


def _map_id(row, npcs, areas):
    creatures = _creatures(row)
    zones = [row.get("zoneOrSort")]
    zones += [npcs.get(npc, {}).get("zoneID") for npc in creatures]
    for zone in zones:
        map_id = areas.get(zone) if _int(zone) else None
        if map_id:
            return map_id
    return None


def _prereq(quest_id, row):
    prereq = sorted({abs(value) for value in _ints(row.get("preQuestGroup"))} - {quest_id})
    alternatives = [value for value in _ints(row.get("preQuestSingle")) if value != quest_id]
    if len(alternatives) == 1:
        prereq.append(alternatives[0])
    elif alternatives:
        prereq.append(alternatives)
    return prereq


def _rewards_by_quest(source_dir, resolve):
    items = _entities(source_dir, ITEM_DB, ITEM_LAYERS, ("questRewards",), resolve)
    rewards = {}
    for item_id in sorted(items):
        for quest_id in _ints(items[item_id].get("questRewards")):
            rewards.setdefault(quest_id, []).append(item_id)
    return rewards


def _mask(value):
    mask = _int(value)
    return mask if mask else None


def _record(quest_id, row, items, npcs, areas):
    required = _int(row.get("requiredLevel"))
    required = required if required and required > 0 else 1
    level = _int(row.get("questLevel"))
    known_level = level is not None and level > 0
    single = len(items) <= 1
    return {
        "id": quest_id,
        "level": level if known_level else required,
        "reqLevel": required,
        "mapID": _map_id(row, npcs, areas),
        "rewards": items if single else [],
        "choices": [] if single else items,
        "prereq": _prereq(quest_id, row),
        "source": "questie",
        "confidence": 1 if not known_level else 3 if single else 2,
        "classMask": _mask(row.get("requiredClasses")),
        "raceMask": _mask(row.get("requiredRaces")),
        "starter": _starter(row, npcs, areas),
    }


def npc_zones(source_dir):
    npcs = _entities(source_dir, NPC_DB, NPC_LAYERS, ("zoneID",), _resolver(source_dir))
    return {npc: row["zoneID"] for npc, row in npcs.items() if _int(row.get("zoneID"))}


def load_npcs(source_dir, ids):
    npcs = _entities(source_dir, NPC_DB, NPC_LAYERS, ("zoneID", "spawns"), _resolver(source_dir))
    areas = _area_map(source_dir)
    records = []
    for npc_id in sorted(set(ids) & set(npcs)):
        position = _position(npcs[npc_id], areas)
        if position:
            records.append({"id": npc_id, "mapID": position[0], "x": position[1], "y": position[2]})
    return records


def load_quests(source_dir):
    resolve = _resolver(source_dir)
    quests = _entities(source_dir, QUEST_DB, QUEST_LAYERS, QUEST_FIELDS, resolve)
    npcs = _entities(source_dir, NPC_DB, NPC_LAYERS, ("zoneID", "spawns"), resolve)
    rewards = _rewards_by_quest(source_dir, resolve)
    areas = _area_map(source_dir)
    return [
        _record(quest_id, quests[quest_id], rewards.get(quest_id, []), npcs, areas)
        for quest_id in sorted(quests)
        if quests[quest_id].get("name") is not None
    ]


def load_quest_areas(source_dir):
    quests = _entities(source_dir, QUEST_DB, QUEST_LAYERS, ("zoneOrSort",), _resolver(source_dir))
    return {
        quest_id: zone for quest_id, row in quests.items()
        if (zone := _int(row.get("zoneOrSort"))) is not None and zone > 0
    }


def load_classic_quest_ids(source_dir):
    layers = (QUEST_LAYERS[0],)
    quests = _entities(source_dir, CLASSIC_QUEST_DB, layers, ("name",), _resolver(source_dir))
    return {quest_id for quest_id, row in quests.items() if row.get("name") is not None}


def _l10n_names(path):
    match = L10N_BODY.search(path.read_text(encoding="utf-8"))
    if not match:
        raise ValueError(f"{path.name} : table de noms introuvable")
    rows = lua_table.parse(match.group(1).removeprefix("return "))
    names = {}
    for entity_id, row in rows.items():
        name = row.get(1) if isinstance(row, dict) else row
        if isinstance(name, str):
            names[entity_id] = name
    return names


def load_names(source_dir, kind):
    _, raw_path, layers = NAME_SOURCES[kind]
    entities = _entities(source_dir, raw_path, layers, ("name",), _resolver(source_dir))
    names = {"enUS": {key: row["name"] for key, row in entities.items() if isinstance(row.get("name"), str)}}
    for locale in LOCALES:
        merged = {}
        for prefix in (f"{kind}Names_", f"{kind}NamesTraces_"):
            path = Path(source_dir) / f"{prefix}{locale}.lua"
            if path.exists():
                merged.update(_l10n_names(path))
        if merged:
            names[locale] = merged
    return names


def load_npc_names(source_dir):
    return load_names(source_dir, "npc")
