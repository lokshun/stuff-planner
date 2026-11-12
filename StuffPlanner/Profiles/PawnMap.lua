-- CONTRAT
-- Stats des échelles Pawn (VgerMods/Pawn, Classic et Forever) vers les clés internes (StatKeys). Pur.
-- Pawn Classic lit les cotes en pourcentage (« Per » prémultiplié) : HitRating = poids par 1 % de toucher,
-- DefenseRating par point de défense ; même unité que nos clés.
--   ns.PawnMap.convert(values) -> weights, ignored
--     values = {[statPawn] = nombre} ; weights = {[KEY] = poids non nul}, arrondi à 6 décimales ;
--     plusieurs stats Pawn vers une clé : additionnées (SPELL_POWER = SpellDamage + Healing + SpellPower,
--     RES_<école> = <École>Resist + AllResist) ; DPS = Dps + le plus fort de MeleeDps, RangedDps, MainHandDps,
--     OffHandDps, OneHandDps, TwoHandDps ;
--     ignored = stats Pawn non reprises à valeur non nulle, triées (Class et Spec jamais listées)
--   ns.PawnMap.SKIPPED -> {Class = true, Spec = true} : clés d'identité de l'échelle, pas des stats

local _, ns = ...

local PawnMap = {}
ns.PawnMap = PawnMap

PawnMap.SKIPPED = { Class = true, Spec = true }

local SUM = {
    Strength = { "STR" }, Agility = { "AGI" }, Stamina = { "STA" }, Intellect = { "INT" }, Spirit = { "SPI" },
    Ap = { "AP" }, Rap = { "RAP" }, HitRating = { "HIT" }, CritRating = { "CRIT" }, HasteRating = { "HASTE" },
    SpellDamage = { "SPELL_DMG", "SPELL_POWER" }, Healing = { "HEALING", "SPELL_POWER" },
    SpellPower = { "SPELL_POWER" }, SpellHitRating = { "SPELL_HIT" }, SpellCritRating = { "SPELL_CRIT" },
    SpellPenetration = { "SPELL_PEN" },
    HolySpellDamage = { "HOLY_DMG" }, FireSpellDamage = { "FIRE_DMG" }, NatureSpellDamage = { "NATURE_DMG" },
    FrostSpellDamage = { "FROST_DMG" }, ShadowSpellDamage = { "SHADOW_DMG" },
    ArcaneSpellDamage = { "ARCANE_DMG" },
    Armor = { "ARMOR" }, DefenseRating = { "DEF" }, DodgeRating = { "DODGE" }, ParryRating = { "PARRY" },
    BlockRating = { "BLOCK" }, BlockValue = { "BLOCK_VALUE" }, Mp5 = { "MP5" }, Hp5 = { "HP5" },
    Health = { "HEALTH" }, Mana = { "MANA" },
    FireResist = { "RES_FIRE" }, NatureResist = { "RES_NATURE" }, FrostResist = { "RES_FROST" },
    ShadowResist = { "RES_SHADOW" }, ArcaneResist = { "RES_ARCANE" },
    AllResist = { "RES_HOLY", "RES_FIRE", "RES_NATURE", "RES_FROST", "RES_SHADOW", "RES_ARCANE" },
    Dps = { "DPS" },
}

local WEAPON_DPS = { "MeleeDps", "RangedDps", "MainHandDps", "OffHandDps", "OneHandDps", "TwoHandDps" }
local ROUND = 1e6

local function isWeaponDps(stat)
    for _, name in ipairs(WEAPON_DPS) do
        if name == stat then
            return true
        end
    end
    return false
end

function PawnMap.convert(values)
    local sums, ignored, weaponDps = {}, {}, nil
    for stat, value in pairs(values) do
        local keys = SUM[stat]
        if keys then
            for _, key in ipairs(keys) do
                sums[key] = (sums[key] or 0) + value
            end
        elseif isWeaponDps(stat) then
            weaponDps = math.max(weaponDps or value, value)
        elseif not PawnMap.SKIPPED[stat] and value ~= 0 then
            ignored[#ignored + 1] = stat
        end
    end
    if weaponDps then
        sums.DPS = (sums.DPS or 0) + weaponDps
    end
    local weights = {}
    for key, value in pairs(sums) do
        local rounded = math.floor(value * ROUND + 0.5) / ROUND
        if rounded ~= 0 then
            weights[key] = rounded
        end
    end
    table.sort(ignored)
    return weights, ignored
end
