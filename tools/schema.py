"""CONTRAT
Définition unique des enregistrements positionnels de StuffPlanner_Data.
  VERSION -> int, à augmenter si l'ordre ou le sens d'un champ change
  FIELDS[table] -> noms des champs, dans l'ordre du tuple ; l'identifiant est la clé de la table Lua
  OPTIONAL[table] -> champs pouvant valoir nil
  SOURCES[nom] -> code entier du champ `source` (aucun texte dans la base)
  ORIGIN_KINDS[nom] -> code entier du type d'origine d'un objet, 1re position d'une entrée d'`origins`
classMask, raceMask : nil = aucune restriction. raceMask dépasse 32 bits : pas de bibliothèque bit.
Lua lit ces positions dans ns.Schema, généré dans StuffPlanner_Data/Schema.lua : indice base 1.
Version 5 : chaque tuple est émis en chaîne (emit_lua.record_string), décodée par ns.Codec.
Version 6 : `forever` (1 | nil) en fin de quests et items : absent de Classic Era, masqué sur ce client.
Version 7 : `starter` (npcID | nil) en fin de quests ; table `npcs` (mapID, x, y en fraction 0–1 de la carte).
Version 8 : table `eraItems` (quality, ilvl, reqLevel, stats) : objets communs dont Classic Era diffère,
  émise dans EraItems.lua, cité par le seul TOC Vanilla ; Data remplace ces champs sur ce client.
Version 9 : `instance` (instanceID | nil) en fin de quests : quête de donjon ou de raid (zone de la quête).
Version 10 : `ender` (npcID | nil), `objMap`, `objX`, `objY` (lieu d'objectif, fraction 0–1 | nil) en fin de
  quests (suivi des suites, sources/quest_steps.py) ; `npcs` couvre donneurs et PNJ de rendu.
Version 11 : `bosses` ({npcID...} | nil) en fin d'instances : boss dans l'ordre du donjon (NorgannonDB,
  sinon Spyglass).
Version 12 : type d'origine `world` (butin de monde voté par merge_exports.py) : {5, mapID, nil, npcID | nil, x, y}.
Version 13 : `rares` ({npcID...} | nil) en fin d'instances : boss de `bosses` de rang élite rare ou rare
  (Questie, sinon CMaNGOS) ; butin des trash rare et mieux de CMaNGOS (tables de référence comprises).
Version 14 : conditions de faisabilité en fin de quests (Questie, nil si absentes) : `skill` {skillID, rang},
  `minRep`, `maxRep` {factionID, valeur}, `flags` (specialFlags : 1 répétable), `exclusive` {questID...},
  `maxLevel`, `spell` (signé), `parent`, `next` (questID). Liste noire et quêtes d'événement retirées.
quests.prereq : quêtes toutes requises ; un élément liste signifie « l'une de celles-ci ».
Aucun nom de quête ou d'objet ici : ils viennent du client.
"""

VERSION = 14

FIELDS = {
    "quests": (
        "level",
        "reqLevel",
        "mapID",
        "rewards",
        "choices",
        "prereq",
        "source",
        "confidence",
        "classMask",
        "raceMask",
        "forever",
        "starter",
        "instance",
        "ender",
        "objMap",
        "objX",
        "objY",
        "skill",
        "minRep",
        "maxRep",
        "flags",
        "exclusive",
        "maxLevel",
        "spell",
        "parent",
        "next",
    ),
    "items": (
        "quality",
        "ilvl",
        "reqLevel",
        "itemClass",
        "itemSubClass",
        "slot",
        "stats",
        "source",
        "confidence",
        "classMask",
        "icon",
        "forever",
    ),
    "origins": ("entries",),
    "instances": ("minLevel", "maxLevel", "reqLevel", "mapID", "size", "raid", "bosses", "rares"),
    "npcs": ("mapID", "x", "y"),
    "eraItems": ("quality", "ilvl", "reqLevel", "stats"),
}

OPTIONAL = {
    "quests": frozenset({"mapID", "classMask", "raceMask", "forever", "starter", "instance", "ender", "objMap", "objX", "objY",
                          "skill", "minRep", "maxRep", "flags", "exclusive", "maxLevel", "spell", "parent", "next"}),
    "items": frozenset({"slot", "classMask", "icon", "forever"}),
    "origins": frozenset(),
    "instances": frozenset({"minLevel", "maxLevel", "reqLevel", "mapID", "size", "bosses", "rares"}),
    "npcs": frozenset(),
    "eraItems": frozenset(),
}

ORIGIN_KINDS = {
    "quest": 1,
    "dungeon": 2,
    "raid": 3,
    "craft": 4,
    "world": 5,
}

SOURCES = {
    "questie": 1,
    "wago": 2,
    "forever_changes": 3,
    "overlay": 4,
    "spyglass": 5,
    "classic_era": 6,
}
