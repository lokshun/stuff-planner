-- CONTRAT
-- Énumération des stats internes, mêmes noms que la base générée (tools/sources/wago.py).
--   ns.StatKeys.<KEY> -> "<KEY>" ; lire une clé inconnue lève une erreur (faute de frappe)
--   ns.StatKeyList -> {"STR", "AGI", …} : toutes les clés dans un ordre fixe (copie, à ne pas modifier)
-- Unités : HIT, CRIT, SPELL_HIT, SPELL_CRIT, DODGE, PARRY, BLOCK, HASTE, AVOID_MISS, AVOID_CRIT
-- en % ; le reste en points
-- (HEALTH, MANA : points de vie et de mana, pour « Mes stats » et Pawn ; la base générée ne les émet pas).
-- AVOID_MISS (chance d'être raté), AVOID_CRIT (critiques subis en moins) : « Mes stats » seulement (via DEF).

local _, ns = ...

local KEYS = {
    "STR", "AGI", "STA", "INT", "SPI",
    "AP", "RAP", "HIT", "CRIT", "HASTE", "DPS",
    "SPELL_POWER", "SPELL_DMG", "HEALING", "SPELL_HIT", "SPELL_CRIT", "SPELL_PEN",
    "HOLY_DMG", "FIRE_DMG", "NATURE_DMG", "FROST_DMG", "SHADOW_DMG", "ARCANE_DMG",
    "ARMOR", "DEF", "DODGE", "PARRY", "BLOCK", "BLOCK_VALUE", "AVOID_MISS", "AVOID_CRIT",
    "MP5", "HP5", "HEALTH", "MANA",
    "RES_HOLY", "RES_FIRE", "RES_NATURE", "RES_FROST", "RES_SHADOW", "RES_ARCANE",
}

local StatKeys = {}
for _, key in ipairs(KEYS) do
    StatKeys[key] = key
end

setmetatable(StatKeys, {
    __index = function(_, key)
        error("StatKeys : clé inconnue " .. tostring(key), 2)
    end,
})

ns.StatKeys = StatKeys

local list = {}
for i, key in ipairs(KEYS) do
    list[i] = key
end
ns.StatKeyList = list
