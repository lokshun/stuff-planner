"""CONTRAT
Lit les objets du client Classic Era depuis wago.tools : repli pour les objets masqués de Forever.
  BUILD -> build épinglé
  TABLES -> tables nécessaires
  fetch(cache_dir, opener=None) -> dossier cache_dir/BUILD complété ; RuntimeError si réseau en échec
  load_items(source_dir) -> {itemID: {"quality", "ilvl", "reqLevel", "classMask", "stats"}}
Valeurs absolues de Classic : pas le budget de Forever, pas d'effets « Équipé » (puissance des sorts
comprise, souvent une part majeure d'un objet de lanceur). Estimation seulement.
"""

from pathlib import Path

from sources import cache, wago

BUILD = "1.15.9.70576"
TABLES = ("ItemSparse",)
RESISTANCES = {
    0: "ARMOR",
    1: "RES_HOLY",
    2: "RES_FIRE",
    3: "RES_NATURE",
    4: "RES_FROST",
    5: "RES_SHADOW",
    6: "RES_ARCANE",
}
COLUMNS = (
    "ID",
    "ItemLevel",
    "RequiredLevel",
    "OverallQualityID",
    "AllowableClass",
    "StatModifier_bonusAmount_0",
    "Resistances_0",
)


def fetch(cache_dir, opener=None):
    urls = {f"{table}.csv": wago.URL.format(table=table, build=BUILD) for table in TABLES}
    return cache.complete(Path(cache_dir) / BUILD, urls, opener)


def _stats(row):
    stats = {}
    for slot in range(wago.STAT_SLOTS):
        key = wago.STAT_KEYS.get(int(row[f"StatModifier_bonusStat_{slot}"]))
        amount = int(row[f"StatModifier_bonusAmount_{slot}"])
        if key and amount:
            rate = wago.RATING_PER_PERCENT.get(key)
            stats[key] = wago.percent(amount, rate) if rate else amount
    for index, key in RESISTANCES.items():
        amount = int(row[f"Resistances_{index}"])
        if amount:
            stats[key] = amount
    return stats


def load_items(source_dir):
    return {
        item_id: {
            "quality": int(row["OverallQualityID"]),
            "ilvl": int(row["ItemLevel"]),
            "reqLevel": max(int(row["RequiredLevel"]), 1),
            "classMask": wago.mask(row["AllowableClass"]),
            "stats": _stats(row),
        }
        for item_id, row in wago.read_table(source_dir, "ItemSparse", COLUMNS).items()
    }
