"""CONTRAT
Étapes d'une quête pour le suivi (T7.2) : PNJ de rendu et un lieu d'objectif, tirés de QuestieDB.
  add_steps(quests, source_dir) -> mêmes enregistrements (copiés) avec `ender`, `objMap`, `objX`, `objY`
    (nil si inconnus), sans réseau (dossier rempli par questie.fetch)
  npc_ids(quests) -> {npcID} des donneurs et des PNJ de rendu, à passer à questie.load_npcs
Règles :
  ender : PNJ créature de `finishedBy` d'ID le plus bas qui a une position (comme `starter`) ; un rendu
    à un objet seul -> nil.
  Lieu d'objectif : zone de déclenchement (`triggerEnd`) si elle a des points ; sinon tous les spawns
    des créatures (objectif et crédit de mise à mort), des objets du monde, et des porteurs (PNJ et
    objets du monde) des objets demandés. Carte retenue : celle qui a le plus de points, à égalité la
    carte de la quête, puis le plus petit uiMapID ; point retenu : le spawn le plus proche du
    barycentre de cette carte (jamais un point vide). Coordonnées 0–100 -> fraction 0–1, 3 décimales (1 à 3 m selon la zone).
"""

from sources import questie

CREATURE_ENDERS = 1
CREATURE_OBJECTIVES, OBJECT_OBJECTIVES, ITEM_OBJECTIVES, KILL_CREDITS = 1, 2, 3, 5
TRIGGER_POINTS = 2
STEP_FIELDS = ("finishedBy", "objectives", "triggerEnd")


def _list(table):
    if not isinstance(table, dict):
        return []
    return [table[key] for key in sorted(k for k in table if isinstance(k, int))]


def _ids(entries, position=1):
    ids = []
    for entry in _list(entries):
        value = entry.get(position) if isinstance(entry, dict) else None
        if questie._int(value):
            ids.append(value)
        elif isinstance(value, dict):
            ids.extend(questie._ints(value))
    return ids


def _ender(row, npcs, areas):
    finished = row.get("finishedBy")
    creatures = questie._ints(finished.get(CREATURE_ENDERS) if isinstance(finished, dict) else None)
    for npc in creatures:
        if questie._position(npcs.get(npc), areas):
            return npc
    return None


def _add_points(points, spawns, areas):
    for zone, coords in (spawns.items() if isinstance(spawns, dict) else ()):
        map_id = areas.get(zone) if questie._int(zone) else None
        if not map_id:
            continue
        for coord in _list(coords):
            if isinstance(coord, dict) and questie._coordinate(coord.get(1)) and questie._coordinate(coord.get(2)):
                points.setdefault(map_id, []).append((coord[1], coord[2]))


def _sources(row, items):
    objectives = row.get("objectives") if isinstance(row.get("objectives"), dict) else {}
    creatures = _ids(objectives.get(CREATURE_OBJECTIVES)) + _ids(objectives.get(KILL_CREDITS))
    objects = _ids(objectives.get(OBJECT_OBJECTIVES))
    for item_id in _ids(objectives.get(ITEM_OBJECTIVES)):
        item = items.get(item_id, {})
        creatures += questie._ints(item.get("npcDrops"))
        objects += questie._ints(item.get("objectDrops"))
    return creatures, objects


def _choose(points, home):
    if not points:
        return None
    map_id = min(points, key=lambda m: (-len(points[m]), m != home, m))
    coords = points[map_id]
    cx = sum(x for x, _ in coords) / len(coords)
    cy = sum(y for _, y in coords) / len(coords)
    x, y = min(coords, key=lambda c: ((c[0] - cx) ** 2 + (c[1] - cy) ** 2, c))
    return map_id, round(x / 100, 3), round(y / 100, 3)


def _objective(row, quest, npcs, objects, items, areas):
    points = {}
    trigger = row.get("triggerEnd")
    if isinstance(trigger, dict):
        _add_points(points, trigger.get(TRIGGER_POINTS), areas)
    if not points:
        creatures, things = _sources(row, items)
        for npc in creatures:
            _add_points(points, npcs.get(npc, {}).get("spawns"), areas)
        for thing in things:
            _add_points(points, objects.get(thing, {}).get("spawns"), areas)
    return _choose(points, quest.get("mapID"))


def add_steps(quests, source_dir):
    resolve = questie._resolver(source_dir)
    rows = questie._entities(source_dir, questie.QUEST_DB, questie.QUEST_LAYERS, STEP_FIELDS, resolve)
    npcs = questie._entities(source_dir, questie.NPC_DB, questie.NPC_LAYERS, ("zoneID", "spawns"), resolve)
    objects = questie._entities(source_dir, questie.OBJECT_DB, questie.OBJECT_LAYERS, ("spawns",), resolve)
    items = questie._entities(source_dir, questie.ITEM_DB, questie.ITEM_LAYERS, ("npcDrops", "objectDrops"), resolve)
    areas = questie._area_map(source_dir)
    records = []
    for quest in quests:
        row = rows.get(quest["id"], {})
        point = _objective(row, quest, npcs, objects, items, areas)
        objective = dict(zip(("objMap", "objX", "objY"), point or (None, None, None)))
        records.append({**quest, "ender": _ender(row, npcs, areas), **objective})
    return records


def npc_ids(quests):
    ids = set()
    for quest in quests:
        ids |= {quest.get("starter"), quest.get("ender")}
    return ids - {None}
