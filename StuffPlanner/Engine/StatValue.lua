-- CONTRAT
-- Poids effectifs d'un profil « Mes stats » : rang -> poids comparables entre stats. Pur : aucun appel
-- à l'API WoW. Charger après Engine/StatKeys.lua.
--   ns.StatValue.COST[key] : coût d'une unité en points de caractéristique (stats en % : cotes Forever
--     par %, API_NOTES ; points : valeurs provisoires, DECISIONS 2026-11-12)
--   CRIT_PER_AGI[class], CRIT_PER_INT[class] : % de crit par point au niveau 60 (WoWSims Forever)
--   expand(rankWeights, class, level) -> weights (nouvelle table) :
--     1. base[k] = rankWeights[k] * COST[k] ;
--     2. part dérivée toujours ajoutée : weights[from] += parPoint * base[to] pour chaque conversion
--        de la classe dont base[to] > 0 (une passe, sans enchaînement), même si from n'est pas classée.
--   Conversions : INT -> SPELL_CRIT ; AGI -> CRIT, DODGE (x2 voleur, chasseur), ARMOR (2) ; STR -> AP
--     (2 guerrier, paladin, chaman, druide ; 1 sinon) ; AGI -> AP (1 voleur, chasseur) ; AGI -> RAP
--     (2 chasseur, 1 guerrier, voleur) ; STR -> BLOCK_VALUE (1/20 guerrier, paladin, chaman).
--     SPI -> MP5 (classes à mana) et HP5 : regen Classic 1.12 par 5 s * REGEN_SHARE (0,5 : l'Esprit ne
--     rend que hors règle des 5 s ou hors combat, MP5/HP5 tout le temps), sans échelle de niveau.
--     Crit et esquive avant 60 : ratio * 60 / niveau (niveau borné à 10). Classe inconnue : coûts seuls.

local _, ns = ...

local StatValue = {}
ns.StatValue = StatValue

local MAX_LEVEL, MIN_LEVEL = 60, 10

local COST = {
    STR = 1, AGI = 1, STA = 1, INT = 1, SPI = 1,
    AP = 0.5, RAP = 0.4, HIT = 10, CRIT = 14, HASTE = 10, DPS = 7,
    SPELL_POWER = 0.85, SPELL_DMG = 0.85, HEALING = 0.45, SPELL_HIT = 10, SPELL_CRIT = 14, SPELL_PEN = 0.8,
    HOLY_DMG = 0.7, FIRE_DMG = 0.7, NATURE_DMG = 0.7, FROST_DMG = 0.7, SHADOW_DMG = 0.7, ARCANE_DMG = 0.7,
    ARMOR = 0.1, DEF = 1.5, DODGE = 12, PARRY = 15, BLOCK = 5, BLOCK_VALUE = 0.5,
    MP5 = 2.5, HP5 = 2.5,
    RES_HOLY = 1, RES_FIRE = 1, RES_NATURE = 1, RES_FROST = 1, RES_SHADOW = 1, RES_ARCANE = 1,
}
StatValue.COST = COST

StatValue.CRIT_PER_AGI = {
    WARRIOR = 0.05, PALADIN = 0.0506, HUNTER = 0.0189, ROGUE = 0.0345, PRIEST = 0.05,
    SHAMAN = 0.0508, MAGE = 0.0514, WARLOCK = 0.05, DRUID = 0.05,
}
StatValue.CRIT_PER_INT = {
    PALADIN = 0.0167, HUNTER = 0.0165, PRIEST = 0.0168, SHAMAN = 0.0169, MAGE = 0.0168,
    WARLOCK = 0.0165, DRUID = 0.0167,
}

-- Regen par Esprit (Classic 1.12, par point et par 5 s) : mana hors règle des 5 s, vie hors combat.
StatValue.REGEN_SHARE = 0.5
local SPI_MANA = { PRIEST = 0.625, MAGE = 0.625, DRUID = 0.5, HUNTER = 0.5, PALADIN = 0.5, SHAMAN = 0.5,
    WARLOCK = 0.5 }
local SPI_HEALTH = { WARRIOR = 2, ROGUE = 1.25, HUNTER = 0.625, PALADIN = 0.625, SHAMAN = 0.275, DRUID = 0.225,
    MAGE = 0.25, PRIEST = 0.25, WARLOCK = 0.175 }

local DODGE_FACTOR = { ROGUE = 2, HUNTER = 2 }
local STR_AP = { WARRIOR = 2, PALADIN = 2, SHAMAN = 2, DRUID = 2 }
local AGI_AP = { ROGUE = 1, HUNTER = 1 }
local AGI_RAP = { HUNTER = 2, WARRIOR = 1, ROGUE = 1 }
local STR_BLOCK = { WARRIOR = 0.05, PALADIN = 0.05, SHAMAN = 0.05 }

-- Conversions de la classe : {from, to, parPoint}.
local function conversions(class, level)
    if not StatValue.CRIT_PER_AGI[class] then
        return {}
    end
    local scale = MAX_LEVEL / math.max(MIN_LEVEL, math.min(MAX_LEVEL, level or MAX_LEVEL))
    local agiCrit = StatValue.CRIT_PER_AGI[class] * scale
    local list = {
        { "AGI", "CRIT", agiCrit },
        { "AGI", "DODGE", agiCrit * (DODGE_FACTOR[class] or 1) },
        { "AGI", "ARMOR", 2 },
        { "STR", "AP", STR_AP[class] or 1 },
    }
    local optional = {
        { "INT", "SPELL_CRIT", StatValue.CRIT_PER_INT[class] and StatValue.CRIT_PER_INT[class] * scale },
        { "AGI", "AP", AGI_AP[class] },
        { "AGI", "RAP", AGI_RAP[class] },
        { "STR", "BLOCK_VALUE", STR_BLOCK[class] },
        { "SPI", "MP5", SPI_MANA[class] and SPI_MANA[class] * StatValue.REGEN_SHARE },
        { "SPI", "HP5", SPI_HEALTH[class] and SPI_HEALTH[class] * StatValue.REGEN_SHARE },
    }
    for _, conversion in ipairs(optional) do
        if conversion[3] then
            list[#list + 1] = conversion
        end
    end
    return list
end

function StatValue.expand(rankWeights, class, level)
    local base, weights = {}, {}
    for key, weight in pairs(rankWeights or {}) do
        base[key] = weight * (COST[key] or 1)
        weights[key] = base[key]
    end
    for _, conversion in ipairs(conversions(class, level)) do
        local from, to, perPoint = conversion[1], conversion[2], conversion[3]
        if (base[to] or 0) > 0 then
            weights[from] = (weights[from] or 0) + perPoint * base[to]
        end
    end
    return weights
end
