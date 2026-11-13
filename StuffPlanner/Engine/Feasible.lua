-- CONTRAT
-- Faisabilité d'une quête pour un personnage (conditions du schéma 14). Pur : aucun appel à l'API WoW.
-- Charger après Engine/Masks.lua.
--   check(quest, player, isDone?, isInLog?) -> ok, raison
--     ok false : impossible, quête à retirer ; raison "class" | "race" | "event" (specialFlags 2) |
--       "maxLevel" (niveau > maxLevel) | "exclusive" (une exclusive faite ou dans le journal) |
--       "next" (suivante faite) | "reputation" (valeur >= maxRep) | "spell" (sort interdit connu).
--     ok true, raison : condition atteignable ou illisible, quête gardée (effort majoré par Effort) ;
--       "skill" (métier absent, trop bas ou professions vides : Classic Era) | "reputation" (sous minRep
--       ou inconnue) | "spell" (sort requis inconnu, ou player.knowsSpell absent ou muet).
--     ok true, nil : rien à signaler. Les conditions impossibles passent avant les atteignables.
--   allows(quest, player, isDone?, isInLog?) -> bool : premier retour de check.
-- player : class, raceID, faction, level, professions = {[skillID]=rang}, reputations = {[factionID]=valeur}
--   (absente = inconnue), knowsSpell(spellID) -> bool | nil (facultatif).

local _, ns = ...

local Feasible = {}
ns.Feasible = Feasible

local FLAG_EVENT = 2

local function hasFlag(flags, bitValue)
    return flags ~= nil and flags % (bitValue * 2) >= bitValue
end

local function anyOf(ids, fn)
    if not fn then
        return false
    end
    for _, id in ipairs(ids or {}) do
        if fn(id) then
            return true
        end
    end
    return false
end

local function reputation(player, pair)
    return player.reputations and player.reputations[pair[1]]
end

-- true, false ou nil (illisible).
local function knows(player, spellID)
    if not player.knowsSpell then
        return nil
    end
    return player.knowsSpell(spellID)
end

local function impossible(quest, player, isDone, isInLog)
    local Masks = ns.Masks
    if not Masks.hasClass(quest.classMask, player.class) then
        return "class"
    elseif not Masks.hasRace(quest.raceMask, player.raceID, player.faction) then
        return "race"
    elseif hasFlag(quest.flags, FLAG_EVENT) then
        return "event"
    elseif quest.maxLevel and player.level and player.level > quest.maxLevel then
        return "maxLevel"
    elseif anyOf(quest.exclusive, isDone) or anyOf(quest.exclusive, isInLog) then
        return "exclusive"
    elseif quest.next and isDone and isDone(quest.next) then
        return "next"
    end
    local value = quest.maxRep and reputation(player, quest.maxRep)
    if value and value >= quest.maxRep[2] then
        return "reputation"
    elseif quest.spell and quest.spell < 0 and knows(player, -quest.spell) == true then
        return "spell"
    end
    return nil
end

local function attainable(quest, player)
    if quest.skill then
        local rank = player.professions and player.professions[quest.skill[1]]
        if not rank or rank < quest.skill[2] then
            return "skill"
        end
    end
    if quest.minRep then
        local value = reputation(player, quest.minRep)
        if not value or value < quest.minRep[2] then
            return "reputation"
        end
    end
    if quest.spell and quest.spell > 0 and knows(player, quest.spell) ~= true then
        return "spell"
    end
    return nil
end

function Feasible.check(quest, player, isDone, isInLog)
    local reason = impossible(quest, player, isDone, isInLog)
    if reason then
        return false, reason
    end
    return true, attainable(quest, player)
end

function Feasible.allows(quest, player, isDone, isInLog)
    return (Feasible.check(quest, player, isDone, isInLog))
end
