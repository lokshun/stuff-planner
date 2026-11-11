-- CONTRAT
-- Masques de classe et de race (quêtes, objets). Pur : aucun appel à l'API WoW.
--   hasClass(classMask, class) -> bool ; classMask nil = toute classe.
--   hasRace(raceMask, raceID, faction) -> bool ; raceMask nil = toute race. Bit de la race (Skyborne
--     95, 96 aux bits 32, 33) ; race inconnue : vrai si le masque a une race de `faction`, ou sans faction.
--   allows(quest, player) -> bool : hasClass et hasRace de la quête pour player (class, raceID, faction).

local _, ns = ...

local Masks = {}
ns.Masks = Masks

-- Identifiants de classe du client (bit du classMask = 2^(id-1)).
local CLASS_IDS = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
    SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
}

function Masks.hasClass(classMask, class)
    if not classMask then
        return true
    end
    local id = CLASS_IDS[class]
    if not id then
        return false
    end
    local bitValue = 2 ^ (id - 1)
    return classMask % (bitValue * 2) >= bitValue
end

-- Identifiants de race du client -> bit du raceMask (au-delà de 32 bits : arithmétique, pas `bit`).
local RACE_BITS = {
    [1] = 2 ^ 0, [2] = 2 ^ 1, [3] = 2 ^ 2, [4] = 2 ^ 3, [5] = 2 ^ 4, [6] = 2 ^ 5, [7] = 2 ^ 6, [8] = 2 ^ 7,
    [95] = 2 ^ 32, [96] = 2 ^ 33,
}
local FACTION_RACES = { Alliance = { 1, 3, 4, 7, 95 }, Horde = { 2, 5, 6, 8, 96 } }

local function hasBit(mask, bitValue)
    return mask % (bitValue * 2) >= bitValue
end

function Masks.hasRace(raceMask, raceID, faction)
    if not raceMask then
        return true
    end
    local bitValue = RACE_BITS[raceID]
    if bitValue then
        return hasBit(raceMask, bitValue)
    end
    local races = FACTION_RACES[faction]
    if not races then
        return true
    end
    for _, id in ipairs(races) do
        if hasBit(raceMask, RACE_BITS[id]) then
            return true
        end
    end
    return false
end

function Masks.allows(quest, player)
    return Masks.hasClass(quest.classMask, player.class)
        and Masks.hasRace(quest.raceMask, player.raceID, player.faction)
end
