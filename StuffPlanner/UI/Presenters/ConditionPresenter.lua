-- CONTRAT
-- Texte d'une condition atteignable de quête (Engine/Feasible : métier, réputation, sort). Charger après
-- Theme.lua. Pur : noms par ns.Names (profession, faction, standing, spell).
--   ns.ConditionPresenter.text(condition, data) -> texte | nil
--     condition = {reason, questID} (Effort.of, ligne de Planner.rank) | nil ; champs lus dans data.quest(questID) :
--     "skill" : L.REQ_SKILL (métier, rang) ; "reputation" : L.REQ_REP (faction, rang nommé, sinon valeur) ;
--     "spell" : L.REQ_SPELL (sort) ; sans condition, quête inconnue, champ absent ou autre raison : nil
--   ns.ConditionPresenter.standingIndex(value) -> 1 (Haï) ... 8 (Exalté) ; valeur comptée depuis Neutre
--     (Amical 3000), comme les conditions de réputation

local _, ns = ...

local L = ns.L

local ConditionPresenter = {}
ns.ConditionPresenter = ConditionPresenter

-- Seuil bas de chaque rang, du plus haut (8 Exalté) au plus bas (2 Hostile) ; en dessous : 1 Haï.
local THRESHOLDS = { 42000, 21000, 9000, 3000, 0, -3000, -6000 }

function ConditionPresenter.standingIndex(value)
    for i, threshold in ipairs(THRESHOLDS) do
        if value >= threshold then
            return 9 - i
        end
    end
    return 1
end

local function reputationText(pair)
    local standing = ns.Names.standing(ConditionPresenter.standingIndex(pair[2])) or tostring(pair[2])
    return L.REQ_REP:format(ns.Names.faction(pair[1]), standing)
end

function ConditionPresenter.text(condition, data)
    local quest = condition and data.quest(condition.questID)
    if not quest then
        return nil
    end
    local reason = condition.reason
    if reason == "skill" and quest.skill then
        return L.REQ_SKILL:format(ns.Names.profession(quest.skill[1]), quest.skill[2])
    elseif reason == "reputation" and quest.minRep then
        return reputationText(quest.minRep)
    elseif reason == "spell" and quest.spell and quest.spell > 0 then
        return L.REQ_SPELL:format(ns.Names.spell(quest.spell))
    end
    return nil
end
