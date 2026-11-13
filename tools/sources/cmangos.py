"""CONTRAT
Répartition des récompenses de quête, rang des créatures et butin des trash d'instance depuis CMaNGOS
classic-db (GPL-3.0), github.com/cmangos/classic-db, dump complet Full_DB (contenu Classic 1.12, pas les
ajouts de Forever).
  COMMIT -> révision épinglée ; la changer est le seul moyen de rafraîchir les données
  fetch(cache_dir, opener=None) -> dossier cache_dir/COMMIT avec DUMP_FILE ; RuntimeError si réseau en échec
  load_quest_rewards(source_dir) -> {questID: (choices, rewards)} de `quest_template` : RewChoiceItemId1-6
    (au choix), RewItemId1-4 (fixes), ids 0 retirés, listes triées ; sans réseau ; ValueError sans la table
  load_ranks(source_dir) -> {npcID: Rank} de `creature_template` (0 normal, 1 élite, 2 élite rare, 3 boss, 4 rare)
  load_random_spawns(source_dir) -> {npcID} à apparition aléatoire : membre d'un pool (`pool_creature` par
    `creature`.guid, `pool_creature_template`) ou entrée tirée parmi plusieurs (`creature_spawn_entry`)
  load_trash_drops(source_dir, npc_zones, areas, raids, bosses) -> [{"item", "instance", "raid", "chance", "npc"}]
    npc_zones = {npcID: zone} (Questie), areas = {zone: instanceID}, raids = {instanceID: bool}, bosses = {npcID} ;
    créatures de l'instance hors bosses et hors Rank 3 ; objets de qualité RARE_QUALITY (3) ou mieux d'item_template ;
    chance = % par mort au meilleur taux des créatures, npc None, triés par (instance, item). Taux d'une ligne :
    groupe 0 = son taux ; groupe > 0 = son taux, ou part égale du reste du groupe s'il vaut 0 ; taux négatif
    (objet de quête) ignoré ; référence (mincountOrRef < 0) : taux de la ligne × min(1, taux dans la
    référence × maxcount), trois niveaux au plus. Chances arrondies à 0,001 %, nulles retirées.
Lecture du texte SQL seulement (colonnes du CREATE TABLE, tuples des INSERT, chaînes échappées) :
aucun SQL exécuté. Les autres tables du dump sont ignorées.
"""

import functools
import gzip
import re
from collections import defaultdict
from pathlib import Path

from sources import cache

COMMIT = "37eeeeb1d4c12f00ded1b542e758f71d6135d391"
DUMP_PATH = "Full_DB/ClassicDB_1_12_1_z2815.sql.gz"
DUMP_FILE = "ClassicDB.sql.gz"
RAW_URL = "https://raw.githubusercontent.com/cmangos/classic-db/{commit}/{path}"
TABLE = "quest_template"
CHOICE_COLUMNS = tuple(f"RewChoiceItemId{i}" for i in range(1, 7))
REWARD_COLUMNS = tuple(f"RewItemId{i}" for i in range(1, 5))

_COLUMN = re.compile(r"^\s*`(\w+)`", re.M)
_VALUE = re.compile(r"'(?:[^'\\]|\\.)*'|NULL|[^,]+")
RARE_QUALITY = 3
BOSS_RANK = 3
MAX_DEPTH = 3


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


@functools.lru_cache(maxsize=1)
def _dump(path, stamp):
    with gzip.open(path, "rt", encoding="utf-8", errors="replace") as handle:
        return handle.read()


def _table(source_dir, name):
    """(colonnes {nom: position}, lignes [[valeur...]]) d'une table du dump ; ValueError si absente."""
    path = Path(source_dir) / DUMP_FILE
    text = _dump(str(path), path.stat().st_mtime_ns)
    create = re.search(r"CREATE TABLE `" + name + r"` \((.*?)\n\)", text, re.S)
    if not create:
        raise ValueError(f"table {name} absente du dump")
    columns = {column: position for position, column in enumerate(_COLUMN.findall(create.group(1)))}
    insert = "INSERT INTO `" + name + "` VALUES "
    rows = []
    begin = text.find(insert, create.end())
    while begin != -1:
        end = text.find(";\n", begin)
        for row in _tuples(text[begin + len(insert) : end]):
            rows.append([value.strip() for value in _VALUE.findall(row)])
        begin = text.find(insert, end)
    return columns, rows


def load_quest_rewards(source_dir):
    columns, rows = _table(source_dir, TABLE)
    entry = columns["entry"]
    choices = [columns[name] for name in CHOICE_COLUMNS]
    rewards = [columns[name] for name in REWARD_COLUMNS]
    return {int(values[entry]): (_ids(values, choices), _ids(values, rewards)) for values in rows}


def load_ranks(source_dir):
    columns, rows = _table(source_dir, "creature_template")
    return {int(row[columns["Entry"]]): int(row[columns["Rank"]]) for row in rows}


def load_random_spawns(source_dir):
    columns, rows = _table(source_dir, "creature")
    npc_of = {int(row[columns["guid"]]): int(row[columns["id"]]) for row in rows}
    columns, rows = _table(source_dir, "pool_creature")
    spawns = {npc_of[guid] for guid in (int(row[columns["guid"]]) for row in rows) if guid in npc_of}
    columns, rows = _table(source_dir, "pool_creature_template")
    spawns |= {int(row[columns["id"]]) for row in rows}
    columns, rows = _table(source_dir, "creature_spawn_entry")
    entries = defaultdict(set)
    for row in rows:
        entries[int(row[columns["guid"]])].add(int(row[columns["entry"]]))
    return spawns | {npc for group in entries.values() if len(group) > 1 for npc in group}


def _loot(source_dir, name):
    columns, rows = _table(source_dir, name)
    fields = ("item", "ChanceOrQuestChance", "groupid", "mincountOrRef", "maxcount")
    loot = defaultdict(list)
    for row in rows:
        item, chance, group, ref, count = (row[columns[field]] for field in fields)
        loot[int(row[columns["entry"]])].append((int(item), float(chance), int(group), int(ref), int(count)))
    return loot


def _row_chances(rows):
    """[(ligne, probabilité 0–1)] : groupe 0 indépendant, groupe > 0 partagé ; taux négatif ignoré."""
    shares = {}
    for group in {row[2] for row in rows if row[2] > 0}:
        members = [row for row in rows if row[2] == group and row[1] >= 0]
        explicit = sum(row[1] for row in members if row[1] > 0)
        zeros = sum(1 for row in members if row[1] == 0)
        shares[group] = max(0.0, 100 - explicit) / zeros if zeros else 0.0
    result = []
    for row in rows:
        chance = row[1]
        if chance < 0:
            continue
        if chance == 0 and row[2] > 0:
            chance = shares[row[2]]
        if chance > 0:
            result.append((row, chance / 100))
    return result


def _chances(rows, refs, depth=0):
    """{item: probabilité 0–1 par mort} d'une table de butin, références comprises."""
    result = {}

    def add(item, p):
        result[item] = 1 - (1 - result.get(item, 0)) * (1 - p)

    for row, p in _row_chances(rows):
        if row[3] < 0:
            if depth < MAX_DEPTH:
                for item, q in _chances(refs.get(-row[3], ()), refs, depth + 1).items():
                    add(item, p * min(1.0, q * max(1, row[4])))
        elif row[3] > 0:
            add(row[0], p)
    return result


def load_trash_drops(source_dir, npc_zones, areas, raids, bosses):
    columns, rows = _table(source_dir, "item_template")
    rare = {int(row[columns["entry"]]) for row in rows if int(row[columns["Quality"]]) >= RARE_QUALITY}
    columns, rows = _table(source_dir, "creature_template")
    loot, refs = _loot(source_dir, "creature_loot_template"), _loot(source_dir, "reference_loot_template")
    best = {}
    for row in rows:
        npc, rank, loot_id = (int(row[columns[field]]) for field in ("Entry", "Rank", "LootId"))
        instance = areas.get(npc_zones.get(npc))
        if instance is None or npc in bosses or rank == BOSS_RANK or not loot_id:
            continue
        for item, p in _chances(loot.get(loot_id, ()), refs).items():
            chance = round(p * 100, 3)
            if item in rare and chance > 0:
                best[(instance, item)] = max(best.get((instance, item), 0), chance)
    return [
        {"item": item, "instance": instance, "raid": raids.get(instance, False), "chance": chance, "npc": None}
        for (instance, item), chance in sorted(best.items())
    ]
