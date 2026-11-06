"""CONTRAT
Précalculs à partir des enregistrements importés.
  origin_records(quests, items, recipes, drops=(), crafts=None) -> enregistrements `origins` triés par id d'objet :
    {"id": itemID, "entries": [[kind, id, chance, detail], ...]}, seulement pour les objets de `items`
    recipes = {itemID: [(spellID, skillLine), ...]}
    Quête : [kind, questID]. Donjon, raid : [kind, instance, chance, npc]. Artisanat : [kind, spellID, nil, skillLine],
    suivi de jaune, gris, [itemID, quantité, ...] si crafts = wago.load_crafts connaît le sort.
  merge_drops(primary, secondary) -> butins triés ; pour un même objet dans une même instance,
    `primary` l'emporte (il a les taux)
  merge_instances(primary, secondary) -> enregistrements `instances` triés ; secondary prime pour
    `mapID`, les niveaux couvrent les deux
  enrich_items(items, scan) -> copie ; ajoute DPS et SPELL_POWER des scans, absents des tables client
  hidden_items(ids, bases, scan, era) -> enregistrements `items` des objets masqués du client :
    scan d'abord (source spyglass, confidence 2), sinon Classic Era (source classic_era, confidence 1)
  era_differences(items, era, scan=None) -> enregistrements `eraItems` (id, quality, ilvl, reqLevel, stats) des
    objets de `items` (ItemSparse Forever, avant enrich_items) dont `era` (wago_era.load_items) diffère ;
    stats d'Era complétées du seul DPS du scan (la puissance des sorts du scan Forever, effet « Équipé »,
    n'existe pas toujours sur Era : ItemProbe la relit en jeu)
  mark_instances(quests, areas, area_instances, instances=None) -> copies ; "instance" = instanceID de la zone
    areas[questID] si area_instances la connaît (et si instances, {instanceID: enregistrement} émis, la contient) ;
    "mapID" = zone de l'entrée (instances[id]["mapID"]) si connue : la carte du donjon n'existe pas sur Classic Era
  mark_forever(records, classic_ids) -> copie ; "forever": 1 sur les enregistrements absents de classic_ids
  split_rewards(quests, split) -> copies ; split = cmangos.load_quest_rewards ; quête confidence 2 (répartition
    devinée) dont choices + rewards est exactement l'ensemble de split[id] : sa répartition, confidence 3 ;
    sinon inchangée (objet ajouté par Forever, quête absente de CMaNGOS)
"""

import schema

SCAN_ONLY_STATS = ("DPS", "SPELL_POWER")
SCAN_CONFIDENCE = 2
ERA_CONFIDENCE = 1


def _drop_kind(drop):
    return schema.ORIGIN_KINDS["raid" if drop["raid"] else "dungeon"]


def _sort_key(entry):
    detail = entry[3] if len(entry) > 3 else None
    return (entry[0], entry[1], -1 if detail is None else detail)


def _craft_entry(spell, skill, crafts):
    entry = [schema.ORIGIN_KINDS["craft"], spell, None, skill]
    detail = (crafts or {}).get(spell)
    if detail:
        low, high, pairs = detail
        entry += [low, high, [value for pair in pairs for value in pair]]
    return entry


def origin_records(quests, items, recipes, drops=(), crafts=None):
    known = {item["id"] for item in items}
    origins = {}
    for quest in quests:
        for item_id in set(quest["rewards"]) | set(quest["choices"]):
            if item_id in known:
                origins.setdefault(item_id, []).append([schema.ORIGIN_KINDS["quest"], quest["id"]])
    for item_id, recipe_list in recipes.items():
        if item_id in known:
            for spell, skill in recipe_list:
                origins.setdefault(item_id, []).append(_craft_entry(spell, skill, crafts))
    for drop in drops:
        if drop["item"] in known:
            origins.setdefault(drop["item"], []).append(
                [_drop_kind(drop), drop["instance"], drop["chance"], drop["npc"]]
            )
    return [
        {"id": item_id, "entries": sorted(origins[item_id], key=_sort_key)}
        for item_id in sorted(origins)
    ]


def _drop_key(drop):
    return (drop["item"], drop["instance"], -1 if drop["npc"] is None else drop["npc"])


def merge_drops(primary, secondary):
    covered = {(drop["item"], drop["instance"]) for drop in primary}
    merged = {_drop_key(drop): drop for drop in primary}
    for drop in secondary:
        if (drop["item"], drop["instance"]) not in covered:
            merged.setdefault(_drop_key(drop), drop)
    return [merged[key] for key in sorted(merged)]


def _merge_levels(merged, first, second):
    for field, choose in (("minLevel", min), ("maxLevel", max)):
        values = [record[field] for record in (first, second) if record.get(field) is not None]
        if values:
            merged[field] = choose(values)


def merge_instances(primary, secondary):
    records = []
    for instance_id in sorted(set(primary) | set(secondary)):
        first = primary.get(instance_id, {})
        second = secondary.get(instance_id, {})
        merged = {**first, **second}
        _merge_levels(merged, first, second)
        records.append(merged)
    return records


def enrich_items(items, scan):
    enriched = []
    for item in items:
        stats = scan.get(item["id"], {}).get("stats", {})
        additions = {
            key: stats[key] for key in SCAN_ONLY_STATS if key in stats and key not in item["stats"]
        }
        enriched.append({**item, "stats": {**item["stats"], **additions}} if additions else item)
    return enriched


def hidden_items(ids, bases, scan, era):
    records = []
    for item_id in sorted(ids):
        base = bases.get(item_id)
        found = scan.get(item_id) or era.get(item_id)
        if base is None or found is None:
            continue
        from_scan = item_id in scan
        records.append(
            {
                "id": item_id,
                "quality": found["quality"],
                "ilvl": found["ilvl"],
                "reqLevel": found["reqLevel"],
                "itemClass": base["itemClass"],
                "itemSubClass": base["itemSubClass"],
                "slot": base["slot"],
                "stats": found["stats"],
                "source": "spyglass" if from_scan else "classic_era",
                "confidence": SCAN_CONFIDENCE if from_scan else ERA_CONFIDENCE,
                "classMask": era.get(item_id, {}).get("classMask"),
                "icon": base["icon"],
            }
        )
    return records


GUESSED_SPLIT = 2
CONFIRMED = 3


def split_rewards(quests, split):
    result = []
    for quest in quests:
        known = split.get(quest["id"]) if quest.get("confidence") == GUESSED_SPLIT else None
        if known and set(known[0]) | set(known[1]) == set(quest["choices"]) | set(quest["rewards"]):
            quest = {**quest, "choices": list(known[0]), "rewards": list(known[1]), "confidence": CONFIRMED}
        result.append(quest)
    return result


def mark_forever(records, classic_ids):
    return [
        record if record["id"] in classic_ids else {**record, "forever": 1}
        for record in records
    ]


ERA_FIELDS = ("quality", "ilvl", "reqLevel", "stats")


def era_differences(items, era, scan=None):
    records = []
    for item in sorted(items, key=lambda record: record["id"]):
        found = era.get(item["id"])
        if found is None or all(found[field] == item[field] for field in ERA_FIELDS):
            continue
        record = {"id": item["id"], **{field: found[field] for field in ERA_FIELDS}}
        dps = (scan or {}).get(item["id"], {}).get("stats", {}).get("DPS")
        if dps and "DPS" not in record["stats"]:
            record["stats"] = {**record["stats"], "DPS": dps}
        records.append(record)
    return records


def mark_instances(quests, areas, area_instances, instances=None):
    marked = []
    for quest in quests:
        instance = area_instances.get(areas.get(quest["id"]))
        if instance is None or (instances is not None and instance not in instances):
            marked.append(quest)
            continue
        entrance = (instances or {}).get(instance, {}).get("mapID")
        marked.append({**quest, "instance": instance, **({"mapID": entrance} if entrance else {})})
    return marked
