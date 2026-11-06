"""CONTRAT
Répartition des récompenses de quête (fixes ou au choix) depuis CMaNGOS classic-db (GPL-3.0),
github.com/cmangos/classic-db, dump complet Full_DB (contenu Classic 1.12, pas les ajouts de Forever).
  COMMIT -> révision épinglée ; la changer est le seul moyen de rafraîchir les données
  fetch(cache_dir, opener=None) -> dossier cache_dir/COMMIT avec DUMP_FILE ; RuntimeError si réseau en échec
  load_quest_rewards(source_dir) -> {questID: (choices, rewards)} de `quest_template` : RewChoiceItemId1-6
    (au choix), RewItemId1-4 (fixes), ids 0 retirés, listes triées ; sans réseau ; ValueError sans la table
Lecture du texte SQL seulement (colonnes du CREATE TABLE, tuples des INSERT, chaînes échappées) :
aucun SQL exécuté. Les autres tables du dump sont ignorées.
"""

import gzip
import re
from pathlib import Path

from sources import cache

COMMIT = "37eeeeb1d4c12f00ded1b542e758f71d6135d391"
DUMP_PATH = "Full_DB/ClassicDB_1_12_1_z2815.sql.gz"
DUMP_FILE = "ClassicDB.sql.gz"
RAW_URL = "https://raw.githubusercontent.com/cmangos/classic-db/{commit}/{path}"
TABLE = "quest_template"
CHOICE_COLUMNS = tuple(f"RewChoiceItemId{i}" for i in range(1, 7))
REWARD_COLUMNS = tuple(f"RewItemId{i}" for i in range(1, 5))

_CREATE = re.compile(r"CREATE TABLE `" + TABLE + r"` \((.*?)\n\)", re.S)
_COLUMN = re.compile(r"^\s*`(\w+)`", re.M)
_INSERT = "INSERT INTO `" + TABLE + "` VALUES "
_VALUE = re.compile(r"'(?:[^'\\]|\\.)*'|NULL|[^,]+")


def fetch(cache_dir, opener=None):
    target = Path(cache_dir) / COMMIT
    return cache.complete(target, {DUMP_FILE: RAW_URL.format(commit=COMMIT, path=DUMP_PATH)}, opener)


def _tuples(body):
    """Contenu de chaque « (...) » de premier niveau, parenthèses des chaînes ignorées."""
    depth, start, quoted, escaped = 0, 0, False, False
    for index, char in enumerate(body):
        if quoted:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == "'":
                quoted = False
        elif char == "'":
            quoted = True
        elif char == "(":
            if depth == 0:
                start = index + 1
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                yield body[start:index]


def _ids(values, positions):
    return sorted({int(values[position]) for position in positions} - {0})


def load_quest_rewards(source_dir):
    with gzip.open(Path(source_dir) / DUMP_FILE, "rt", encoding="utf-8", errors="replace") as handle:
        text = handle.read()
    create = _CREATE.search(text)
    if not create:
        raise ValueError(f"table {TABLE} absente du dump")
    columns = {name: position for position, name in enumerate(_COLUMN.findall(create.group(1)))}
    entry = columns["entry"]
    choices = [columns[name] for name in CHOICE_COLUMNS]
    rewards = [columns[name] for name in REWARD_COLUMNS]
    result = {}
    start = text.find(_INSERT, create.end())
    while start != -1:
        end = text.find(";\n", start)
        for row in _tuples(text[start + len(_INSERT) : end]):
            values = [value.strip() for value in _VALUE.findall(row)]
            result[int(values[entry])] = (_ids(values, choices), _ids(values, rewards))
        start = text.find(_INSERT, end)
    return result
