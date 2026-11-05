"""CONTRAT
Importe les objets équipables du client Forever depuis wago.tools (tables DB2 en CSV).
  BUILD -> build épinglé ; le changer est le seul moyen de rafraîchir les données
  TABLES -> tables nécessaires
  STAT_KEYS -> {code de stat du client: clé interne} ; RATING_PER_PERCENT -> points pour 1 %
  fetch(cache_dir, opener=None) -> dossier cache_dir/BUILD complété ; RuntimeError si réseau en échec
  fetch_locale(cache_dir, locale, tables, opener=None) -> dossier cache_dir/BUILD/locale, tables dans
    cette langue (`&locale=` de wago.tools) ; mêmes erreurs que fetch
  load_bases(source_dir) -> {itemID: {"itemClass", "itemSubClass", "slot", "icon"}}, équipement seul,
    objets masqués compris : Item.csv les connaît, pas ItemSparse
  load_items(source_dir) -> enregistrements `items` triés par id, sans réseau ; ValueError si une
    colonne attendue a disparu
  load_recipes(source_dir) -> {itemID: [(spellID, skillLine), ...]}, sorts de métier créant l'objet
  load_crafts(source_dir) -> {spellID: (jaune, gris, ((itemID, quantité), ...))}, sorts de métier ;
    jaune, gris = TrivialSkillLineRankLow, High (lecture de TrinityCore) ; sans seuil ni composant : omis
  read_table(source_dir, table, columns) -> {ID: ligne} ; ValueError si une colonne a disparu
  mask(value) -> entier positif, ou None
  percent(rating, rate) -> pourcentage, entier s'il tombe juste
Objets gardés : classes arme et armure, emplacement non nul, présents dans ItemSparse.
Stats : round(budget * StatPercentEditor / 10000), budget = RandPropPoints[ilvl][qualité_colonne].
  HIT, CRIT, DODGE, PARRY, BLOCK, HASTE en %, comme dans les info-bulles ; le reste en points.
  ARMOR = round(total[ilvl][matière] * qualité[ilvl] * emplacement) + bonus du code 50 ;
  bouclier : table ItemArmorShield. Vérifié sur info-bulles.
  Absents d'ici : DPS et puissance des sorts des armes de lanceur, ajoutés depuis les scans Spyglass.
confidence : 3 toutes stats comprises, 2 un code inconnu ignoré, 1 aucun budget pour cet objet.
"""

import csv
from pathlib import Path

from sources import cache

BUILD = "1.60.1.70790"
URL = "https://wago.tools/db2/{table}/csv?build={build}"
TABLES = (
    "Item",
    "ItemSparse",
    "RandPropPoints",
    "ItemArmorQuality",
    "ItemArmorTotal",
    "ItemArmorShield",
    "ArmorLocation",
    "SpellEffect",
    "SkillLineAbility",
    "SpellReagents",
)
REAGENT_SLOTS = 8
ARMOR_CLASS = 4
SHIELD_SUBCLASS = 6
CLOAK_SLOT = 16
CLOTH_SUBCLASS = 1
ROBE_SLOT = 20
CHEST_SLOT = 5
MATERIALS = {
    1: ("Cloth", "Clothmodifier"),
    2: ("Leather", "Leathermodifier"),
    3: ("Mail", "Chainmodifier"),
    4: ("Plate", "Platemodifier"),
}
MAX_ARMOR_QUALITY = 6
GEAR_CLASSES = frozenset({2, 4})
STAT_SLOTS = 10
CREATE_ITEM_EFFECT = 24
PROFESSIONS = frozenset({129, 164, 165, 171, 182, 185, 186, 197, 202, 333, 356, 393})

STAT_KEYS = {
    3: "AGI",
    4: "STR",
    5: "INT",
    6: "SPI",
    7: "STA",
    12: "DEF",
    13: "DODGE",
    14: "PARRY",
    15: "BLOCK",
    31: "HIT",
    32: "CRIT",
    36: "HASTE",
    38: "AP",
    39: "RAP",
    41: "HEALING",
    42: "SPELL_DMG",
    43: "MP5",
    45: "SPELL_POWER",
    46: "HP5",
    47: "SPELL_PEN",
    48: "BLOCK_VALUE",
    50: "ARMOR",
    51: "RES_FIRE",
    52: "RES_FROST",
    53: "RES_HOLY",
    54: "RES_SHADOW",
    55: "RES_NATURE",
    56: "RES_ARCANE",
    84: "HOLY_DMG",
    85: "FIRE_DMG",
    86: "NATURE_DMG",
    87: "FROST_DMG",
    88: "SHADOW_DMG",
    89: "ARCANE_DMG",
}
RATING_PER_PERCENT = {"HIT": 10, "CRIT": 14, "DODGE": 12, "PARRY": 15, "BLOCK": 5, "HASTE": 10}

# Colonne de RandPropPoints par InventoryType : celle qui donne des stats entières sur le build.
# Preuve faible pour 25 (jet) et 28 (relique), trop peu d'objets ou de stats pour trancher.
BUDGET_COLUMN = {
    1: 0, 5: 0, 7: 0, 17: 0, 20: 0,
    3: 1, 6: 1, 8: 1, 10: 1, 12: 1,
    2: 2, 9: 2, 11: 2, 14: 2, 16: 2, 23: 2,
    13: 3, 21: 3, 22: 3,
    15: 4, 25: 4, 26: 4, 28: 4,
}
QUALITY_COLUMN = {0: "Good", 1: "Good", 2: "Good", 3: "Superior"}
DEFAULT_QUALITY_COLUMN = "Epic"

STAT_COLUMNS = tuple(
    column
    for slot in range(STAT_SLOTS)
    for column in (f"StatModifier_bonusStat_{slot}", f"StatPercentEditor_{slot}")
)
COLUMNS = {
    "Item": ("ID", "ClassID", "SubclassID", "InventoryType", "IconFileDataID"),
    "ItemSparse": (
        "ID",
        "ItemLevel",
        "RequiredLevel",
        "InventoryType",
        "OverallQualityID",
        "AllowableClass",
    )
    + STAT_COLUMNS,
    "RandPropPoints": ("ID", "Good_0", "Superior_0", "Epic_0", "Good_4", "Superior_4", "Epic_4"),
    "ItemArmorQuality": ("ID", "Qualitymod_0", "Qualitymod_6"),
    "ItemArmorTotal": ("ID", "Cloth", "Leather", "Mail", "Plate"),
    "ItemArmorShield": ("ID", "Quality_0", "Quality_6"),
    "ArmorLocation": ("ID", "Clothmodifier", "Leathermodifier", "Chainmodifier", "Platemodifier"),
    "SpellEffect": ("ID", "Effect", "EffectItemType", "SpellID"),
    "SkillLineAbility": ("ID", "SkillLine", "Spell", "TrivialSkillLineRankLow", "TrivialSkillLineRankHigh"),
    "SpellReagents": ("ID", "SpellID")
    + tuple(f"Reagent_{i}" for i in range(REAGENT_SLOTS))
    + tuple(f"ReagentCount_{i}" for i in range(REAGENT_SLOTS)),
}
ARMOR_TABLES = ("ItemArmorQuality", "ItemArmorTotal", "ItemArmorShield", "ArmorLocation")


def fetch(cache_dir, opener=None):
    urls = {f"{table}.csv": URL.format(table=table, build=BUILD) for table in TABLES}
    return cache.complete(Path(cache_dir) / BUILD, urls, opener)


def fetch_locale(cache_dir, locale, tables, opener=None):
    urls = {f"{table}.csv": URL.format(table=table, build=BUILD) + f"&locale={locale}" for table in tables}
    return cache.complete(Path(cache_dir) / BUILD / locale, urls, opener)


def read_table(source_dir, table, columns):
    path = Path(source_dir) / f"{table}.csv"
    with path.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        missing = [column for column in columns if column not in (reader.fieldnames or ())]
        if missing:
            raise ValueError(f"{table} : colonnes absentes : {', '.join(missing)}")
        return {int(row["ID"]): row for row in reader}


def _table(source_dir, table):
    return read_table(source_dir, table, COLUMNS[table])


def percent(rating, rate):
    value = round(rating / rate, 2)
    return int(value) if value == int(value) else value


def _budget(row, budgets):
    level = budgets.get(int(row["ItemLevel"]))
    column = BUDGET_COLUMN.get(int(row["InventoryType"]))
    if level is None or column is None:
        return None
    quality = QUALITY_COLUMN.get(int(row["OverallQualityID"]), DEFAULT_QUALITY_COLUMN)
    return int(level[f"{quality}_{column}"])


def _stats(row, budget):
    stats = {}
    unknown = False
    for slot in range(STAT_SLOTS):
        code = int(row[f"StatModifier_bonusStat_{slot}"])
        if code < 0:
            continue
        key = STAT_KEYS.get(code)
        if key is None:
            unknown = True
            continue
        value = round(budget * int(row[f"StatPercentEditor_{slot}"]) / 10000)
        if value:
            rate = RATING_PER_PERCENT.get(key)
            stats[key] = percent(value, rate) if rate else value
    return stats, unknown


def _base_armor(row, base, tables):
    if int(base["ClassID"]) != ARMOR_CLASS:
        return 0
    level = int(row["ItemLevel"])
    quality = min(int(row["OverallQualityID"]), MAX_ARMOR_QUALITY)
    subclass = int(base["SubclassID"])
    slot = int(row["InventoryType"])
    if subclass == SHIELD_SUBCLASS:
        shield = tables["ItemArmorShield"].get(level)
        return round(float(shield[f"Quality_{quality}"])) if shield else 0
    subclass = CLOTH_SUBCLASS if slot == CLOAK_SLOT else subclass
    total = tables["ItemArmorTotal"].get(level)
    factor = tables["ItemArmorQuality"].get(level)
    location = tables["ArmorLocation"].get(CHEST_SLOT if slot == ROBE_SLOT else slot)
    if subclass not in MATERIALS or not (total and factor and location):
        return 0
    material, modifier = MATERIALS[subclass]
    return round(float(total[material]) * float(factor[f"Qualitymod_{quality}"]) * float(location[modifier]))


def mask(value):
    number = int(value)
    return number if number > 0 else None


def _record(item_id, row, base, budgets, armor_tables):
    budget = _budget(row, budgets)
    stats, unknown = _stats(row, budget) if budget is not None else ({}, False)
    armor = _base_armor(row, base, armor_tables)
    if armor:
        stats["ARMOR"] = stats.get("ARMOR", 0) + armor
    return {
        "id": item_id,
        "quality": int(row["OverallQualityID"]),
        "ilvl": int(row["ItemLevel"]),
        "reqLevel": max(int(row["RequiredLevel"]), 1),
        "itemClass": int(base["ClassID"]),
        "itemSubClass": int(base["SubclassID"]),
        "slot": int(row["InventoryType"]),
        "stats": stats,
        "source": "wago",
        "confidence": 1 if budget is None else 2 if unknown else 3,
        "classMask": mask(row["AllowableClass"]),
        "icon": mask(base["IconFileDataID"]),
    }


def load_items(source_dir):
    bases = _table(source_dir, "Item")
    sparse = _table(source_dir, "ItemSparse")
    budgets = _table(source_dir, "RandPropPoints")
    armor_tables = {table: _table(source_dir, table) for table in ARMOR_TABLES}
    return [
        _record(item_id, sparse[item_id], bases[item_id], budgets, armor_tables)
        for item_id in sorted(sparse)
        if item_id in bases
        and int(bases[item_id]["ClassID"]) in GEAR_CLASSES
        and int(sparse[item_id]["InventoryType"]) != 0
    ]


def load_bases(source_dir):
    return {
        item_id: {
            "itemClass": int(row["ClassID"]),
            "itemSubClass": int(row["SubclassID"]),
            "slot": int(row["InventoryType"]),
            "icon": mask(row["IconFileDataID"]),
        }
        for item_id, row in _table(source_dir, "Item").items()
        if int(row["ClassID"]) in GEAR_CLASSES and int(row["InventoryType"]) != 0
    }


def load_recipes(source_dir):
    skills = {}
    for row in _table(source_dir, "SkillLineAbility").values():
        if int(row["SkillLine"]) in PROFESSIONS:
            skills[int(row["Spell"])] = int(row["SkillLine"])
    recipes = {}
    for row in _table(source_dir, "SpellEffect").values():
        spell = int(row["SpellID"])
        if int(row["Effect"]) == CREATE_ITEM_EFFECT and spell in skills:
            recipes.setdefault(int(row["EffectItemType"]), set()).add((spell, skills[spell]))
    return {item_id: sorted(recipes[item_id]) for item_id in sorted(recipes)}


def load_crafts(source_dir):
    thresholds = {}
    for row in _table(source_dir, "SkillLineAbility").values():
        if int(row["SkillLine"]) in PROFESSIONS:
            low, high = int(row["TrivialSkillLineRankLow"]), int(row["TrivialSkillLineRankHigh"])
            thresholds[int(row["Spell"])] = (low, high)
    reagents = {}
    for row in _table(source_dir, "SpellReagents").values():
        pairs = []
        for i in range(REAGENT_SLOTS):
            item, count = int(row[f"Reagent_{i}"]), int(row[f"ReagentCount_{i}"])
            if item > 0 and count > 0:
                pairs.append((item, count))
        reagents[int(row["SpellID"])] = tuple(pairs)
    crafts = {}
    for spell in sorted(thresholds):
        low, high = thresholds[spell]
        pairs = reagents.get(spell, ())
        if low > 0 or high > 0 or pairs:
            crafts[spell] = (low, high, pairs)
    return crafts
