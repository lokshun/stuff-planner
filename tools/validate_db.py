"""CONTRAT
Valide les enregistrements de la base avant écriture ; aucune lecture de fichier.
  validate(tables) -> [Finding], erreurs bloquantes d'abord ; tables = {"quests", "items", "origins", "instances", "npcs"}
  Finding : category, blocking, count, examples (3 identifiants triés au plus)
  report_lines(findings) -> une ligne par catégorie
Bloquant : doublons, origine sans cible, prérequis négatif ou sur soi-même, niveau < 1, niveaux
d'instance inversés, donneur absent de `npcs`, position hors de [0, 1]. Le reste signale des manques connus des sources, sans arrêter la construction.
"""

from collections import Counter
from dataclasses import dataclass

import schema

MAX_LEVEL = 60
MAX_EXAMPLES = 3
ESTIMATED_CONFIDENCE = 1
DUPLICATE_LABELS = {
    "quests": "doublons de quêtes",
    "items": "doublons d'objets",
    "origins": "doublons d'origines",
    "instances": "doublons d'instances",
    "npcs": "doublons de PNJ",
}


@dataclass(frozen=True)
class Finding:
    category: str
    blocking: bool
    count: int
    examples: list


def _finding(category, blocking, ids):
    unique = sorted(set(ids))
    return Finding(category, blocking, len(unique), unique[:MAX_EXAMPLES])


def _duplicates(tables):
    for table, label in DUPLICATE_LABELS.items():
        counts = Counter(record["id"] for record in tables[table])
        yield label, True, [record_id for record_id, count in counts.items() if count > 1]


def _flat(prereq):
    for entry in prereq:
        if isinstance(entry, list):
            yield from entry
        else:
            yield entry


def _origin_checks(tables):
    items = {record["id"] for record in tables["items"]}
    quests = {record["id"] for record in tables["quests"]}
    instances = {record["id"] for record in tables["instances"]}
    kinds = schema.ORIGIN_KINDS
    no_quest, no_instance, bad_kind = [], [], []
    for origin in tables["origins"]:
        for entry in origin["entries"]:
            kind, target = entry[0], entry[1]
            if kind == kinds["quest"]:
                if target not in quests:
                    no_quest.append(origin["id"])
            elif kind in (kinds["dungeon"], kinds["raid"]):
                if target not in instances:
                    no_instance.append(origin["id"])
            elif kind != kinds["craft"]:
                bad_kind.append(origin["id"])
    yield "origines sans objet", True, [o["id"] for o in tables["origins"] if o["id"] not in items]
    yield "origines sans quête", True, no_quest
    yield "origines sans instance", True, no_instance
    yield "origines de type inconnu", True, bad_kind
    with_origin = {origin["id"] for origin in tables["origins"]}
    yield "objets sans source", False, items - with_origin


def _quest_checks(tables):
    quests = tables["quests"]
    known = {quest["id"] for quest in quests}
    items = {item["id"] for item in tables["items"]}
    yield "prérequis invalides", True, [
        q["id"] for q in quests if any(p <= 0 or p == q["id"] for p in _flat(q["prereq"]))
    ]
    yield "prérequis absents de la base", False, [
        q["id"] for q in quests if any(p > 0 and p not in known for p in _flat(q["prereq"]))
    ]
    yield "récompenses absentes de la base", False, [
        q["id"] for q in quests if any(i not in items for i in q["rewards"] + q["choices"])
    ]
    yield "niveaux de quête invalides", True, [
        q["id"] for q in quests if q["level"] < 1 or q["reqLevel"] < 1
    ]
    yield "quêtes : niveau requis > niveau", False, [
        q["id"] for q in quests if q["reqLevel"] > q["level"]
    ]
    yield "quêtes de niveau > 60", False, [q["id"] for q in quests if q["level"] > MAX_LEVEL]


def _item_checks(tables):
    items = tables["items"]
    yield "niveaux d'objet invalides", True, [
        i["id"] for i in items if i["ilvl"] < 1 or i["reqLevel"] < 1
    ]
    yield "objets : niveau requis > 60", False, [i["id"] for i in items if i["reqLevel"] > MAX_LEVEL]
    yield "objets : niveau requis > niveau d'objet", False, [
        i["id"] for i in items if i["reqLevel"] > i["ilvl"]
    ]
    yield "objets sans stats", False, [i["id"] for i in items if not i["stats"]]
    yield "objets à stats estimées", False, [
        i["id"] for i in items if i["confidence"] == ESTIMATED_CONFIDENCE
    ]


def _instance_checks(tables):
    yield "niveaux d'instance inversés", True, [
        record["id"]
        for record in tables["instances"]
        if record.get("minLevel") is not None
        and record.get("maxLevel") is not None
        and record["minLevel"] > record["maxLevel"]
    ]


def _npc_checks(tables):
    npcs = {record["id"] for record in tables["npcs"]}
    yield "donneurs absents de la base", True, [
        q["id"] for q in tables["quests"] if q.get("starter") is not None and q["starter"] not in npcs
    ]
    yield "positions de PNJ hors carte", True, [
        n["id"] for n in tables["npcs"] if not (0 <= n["x"] <= 1 and 0 <= n["y"] <= 1)
    ]


def validate(tables):
    checks = (
        _duplicates, _origin_checks, _quest_checks, _item_checks, _instance_checks, _npc_checks,
    )
    found = [
        _finding(category, blocking, ids)
        for check in checks
        for category, blocking, ids in check(tables)
        if ids
    ]
    return sorted(found, key=lambda finding: not finding.blocking)


def report_lines(findings):
    lines = []
    for finding in findings:
        label = "ERREUR" if finding.blocking else "Avertissement"
        examples = ", ".join(str(example) for example in finding.examples)
        lines.append(f"{label} {finding.category} : {finding.count} (ex. {examples})")
    return lines
