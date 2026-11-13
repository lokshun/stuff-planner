"""CONTRAT
Répartition fixes / au choix des récompenses de quête selon ForeverChanges (foreverchanges.pro,
Waypoint Digital SL), reprise avec l'accord de l'éditeur (2026-11-13).
  SNAPSHOT -> date du relevé épinglé ; la changer est le seul moyen de rafraîchir les données
  fetch(cache_dir, opener=None) -> dossier cache_dir/SNAPSHOT avec LIST_FILE ; une seule requête,
    jamais de pages en masse ; RuntimeError si réseau en échec
  load_split(source_dir) -> {questID: (choices, rewards)}, sans réseau ; listes d'itemID triées ;
    quêtes sans objet ignorées
Format de /quests/list.json : liste de quêtes, `i` id, `r` fixes et `k` au choix, chaque entrée
[itemID, icône, qualité] (un itemID nu est accepté).
"""

import json
from pathlib import Path

from sources import cache

SNAPSHOT = "2026-11-13"
LIST_URL = "https://foreverchanges.pro/quests/list.json"
LIST_FILE = "list.json"


def fetch(cache_dir, opener=None):
    return cache.complete(Path(cache_dir) / SNAPSHOT, {LIST_FILE: LIST_URL}, opener)


def _quests(data):
    if isinstance(data, dict):
        data = next((value for value in data.values() if isinstance(value, list)), [])
    return [quest for quest in data if isinstance(quest, dict)]


def _items(entries):
    items = set()
    for entry in entries or ():
        item = entry[0] if isinstance(entry, list) and entry else entry
        if isinstance(item, int) and item > 0:
            items.add(item)
    return sorted(items)


def load_split(source_dir):
    data = json.loads((Path(source_dir) / LIST_FILE).read_text(encoding="utf-8"))
    split = {}
    for quest in _quests(data):
        quest_id = quest.get("i")
        choices, rewards = _items(quest.get("k")), _items(quest.get("r"))
        if isinstance(quest_id, int) and (choices or rewards):
            split[quest_id] = (choices, rewards)
    return split
