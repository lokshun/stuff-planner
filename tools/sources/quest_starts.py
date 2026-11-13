"""CONTRAT
Départ d'une quête (T17.6) : où la prendre quand le donneur placé (`starter`) manque, tiré de QuestieDB.
  add_starts(quests, source_dir, area_instances, instances, fixes=None) -> copies avec `startKind`
    (schema.START_KINDS), `startID`, `startMap`, `startX`, `startY` (nil si inconnus) ; `starter` peut devenir
    le porteur de l'objet de départ. area_instances = norgannon.area_instances, instances = {instanceID:
    enregistrement émis} ; fixes = tools/starter_fixes.json ({"questID": champs}, startKind en nom),
    prioritaire ; ValueError si un type est inconnu. Sans réseau (dossier rempli par questie.fetch).
  unknown(quests) -> [questID...] triés sans aucun lieu (ni starter ni startMap)
  counts(quests) -> {nom du type: n} des quêtes données (absent : type nil)
  object_ids(quests) -> {objectID} des départs par objet du monde (noms à émettre)
Règles, dans l'ordre :
  npc : `starter` déjà placé (questie._starter) ; startID et position nil (table npcs).
  instance : PNJ donneur dont la zone est un donjon connu ; startID = instanceID, startMap = carte de l'entrée.
  object : objet du monde déclencheur, le premier placé d'ID croissant (sinon le premier, sans position) ;
    startID = objectID.
  item : objet de sac ; startID = itemID ; `starter` = premier PNJ placé qui le laisse tomber, sinon position
    du premier objet du monde placé qui le contient.
  zone : rien d'autre ; startMap = mapID de la quête.
  Sans position propre : startMap = mapID de la quête (repère au centre de la zone).
"""

import schema
from sources import questie

CREATURES, OBJECTS, ITEMS = 1, 2, 3
POSITION = ("startMap", "startX", "startY")
FIELDS = ("startKind", "startID") + POSITION
NAMES = {code: name for name, code in schema.START_KINDS.items()}


def _place(position):
    return dict(zip(POSITION, position)) if position else {}


def _first_placed(ids, rows, areas):
    for entity in ids:
        position = questie._position(rows.get(entity), areas)
        if position:
            return entity, position
    return None, None


def _instance(creatures, npcs, area_instances, instances):
    for npc in creatures:
        instance = area_instances.get(npcs.get(npc, {}).get("zoneID"))
        if instance in instances:
            return {"startKind": schema.START_KINDS["instance"], "startID": instance,
                    "startMap": instances[instance].get("mapID")}
    return None


def _object(objects, rows, areas):
    found, position = _first_placed(objects, rows, areas)
    return {"startKind": schema.START_KINDS["object"], "startID": found or objects[0], **_place(position)}


def _item(item_id, items, npcs, objects, areas):
    item = items.get(item_id, {})
    start = {"startKind": schema.START_KINDS["item"], "startID": item_id}
    dropper, _ = _first_placed(questie._ints(item.get("npcDrops")), npcs, areas)
    if dropper:
        return {**start, "starter": dropper}
    _, position = _first_placed(questie._ints(item.get("objectDrops")), objects, areas)
    return {**start, **_place(position)}


def _start(quest, row, rows, area_instances, instances):
    npcs, objects, items, areas = rows
    if quest.get("starter"):
        return {"startKind": schema.START_KINDS["npc"]}
    started = row.get("startedBy") if isinstance(row.get("startedBy"), dict) else {}
    creatures = questie._ints(started.get(CREATURES))
    start = _instance(creatures, npcs, area_instances, instances)
    if start:
        return start
    if questie._ints(started.get(OBJECTS)):
        return _object(questie._ints(started.get(OBJECTS)), objects, areas)
    if questie._ints(started.get(ITEMS)):
        return _item(questie._ints(started.get(ITEMS))[0], items, npcs, objects, areas)
    return {"startKind": schema.START_KINDS["zone"]}


def _fix(fix):
    fix = dict(fix)
    kind = fix.get("startKind")
    if kind is not None:
        if kind not in schema.START_KINDS:
            raise ValueError(f"starter_fixes.json : type de départ inconnu « {kind} »")
        fix["startKind"] = schema.START_KINDS[kind]
    return fix


def add_starts(quests, source_dir, area_instances, instances, fixes=None):
    fixes = {int(quest_id): _fix(fix) for quest_id, fix in (fixes or {}).items()}
    resolve = questie._resolver(source_dir)
    quest_rows = questie._entities(source_dir, questie.QUEST_DB, questie.QUEST_LAYERS, ("startedBy",), resolve)
    rows = (
        questie._entities(source_dir, questie.NPC_DB, questie.NPC_LAYERS, ("zoneID", "spawns"), resolve),
        questie._entities(source_dir, questie.OBJECT_DB, questie.OBJECT_LAYERS, ("spawns",), resolve),
        questie._entities(source_dir, questie.ITEM_DB, questie.ITEM_LAYERS, ("npcDrops", "objectDrops"), resolve),
        questie._area_map(source_dir),
    )
    records = []
    for quest in quests:
        start = _start(quest, quest_rows.get(quest["id"], {}), rows, area_instances, instances)
        record = {**quest, **dict.fromkeys(FIELDS), **start}
        if not record.get("startMap") and not record.get("starter"):
            record["startMap"] = quest.get("mapID")
        records.append({**record, **fixes.get(quest["id"], {})})
    return records


def unknown(quests):
    return sorted(quest["id"] for quest in quests if not quest.get("starter") and not quest.get("startMap"))


def counts(quests):
    result = {}
    for quest in quests:
        name = NAMES.get(quest.get("startKind"))
        if name:
            result[name] = result.get(name, 0) + 1
    return result


def object_ids(quests):
    return {quest["startID"] for quest in quests if quest.get("startKind") == schema.START_KINDS["object"]}
