-- CONTRAT
-- Suivi d'une suite de quêtes : la flèche (ns.Waypoint) passe seule d'étape en étape (Engine/FollowSteps).
-- Charger après Core.lua, CompatQuest.lua, Engine/Masks.lua, Engine/FollowSteps.lua, Data/Names.lua et
-- Integrations/TomTom.lua.
--   ns.Follow.start(questID) -> suit la suite qui mène à questID (quête finale) ; quête inconnue : rien
--   ns.Follow.stop() -> fin du suivi, repère posé retiré ; SP_FOLLOW_CHANGED sans argument (suite terminée :
--     SP_FOLLOW_CHANGED("done", questID final), voir plus bas)
--   ns.Follow.current() -> questID final suivi | nil ; ns.Follow.view() -> dernier FollowSteps.build | nil
--   ns.Follow.owns(key) -> bool : repère `key` posé par le suivi (Waypoint.reached le garde)
--   ns.Follow.refresh() -> recalcule les étapes (hors combat, sinon à la fin du combat)
--   ns.Follow.aim(index) -> bool : repère sur view.steps[index] (placé), gardé jusqu'au changement de
--     l'étape courante ; ns.Follow.objective(questID) -> texte du 1er objectif non fini | nil
--   ns.Follow.target() -> étape repérée (courante ou visée) | nil
-- Trajet : ns.FollowTravel.leg(step) (s'il est chargé) -> repère sur le maître de vol ou le quai, libellé
--   du trajet, sans npcID ; le repère change quand le trajet change.
-- Repère de l'étape courante : Waypoint.set(mapID, x, y, nom de la quête, questID, libellé d'étape, npcID) ;
--   libellé L.FOLLOW_PICKUP/OBJECTIVE/TURNIN (PNJ, 1er objectif non fini) ou leur variante _ANY ;
--   posé seulement si l'étape change ; étape sans position : repère retiré, suivi gardé.
-- Suite terminée : L.FOLLOW_DONE dans la discussion, puis stop. Repère retiré par ailleurs (autre repère,
--   bouton Retirer) : stop.
-- Sauvegarde StuffPlannerCharDB.follow = {questID}, reprise à SP_DATA_READY.
-- Recalcul sur QUEST_ACCEPTED, QUEST_TURNED_IN, QUEST_REMOVED, QUEST_LOG_UPDATE, PLAYER_LEVEL_UP (regroupés
--   sur BUCKET s), SP_QUEST_LOG_CHANGED. Message SP_FOLLOW_CHANGED à chaque début, fin ou changement d'étape ;
--   SP_FOLLOW_UPDATED après chaque recalcul (progression des objectifs).

local _, ns = ...

local L = ns.L

local Follow = ns:NewModule("Follow", "AceEvent-3.0", "AceBucket-3.0")
ns.Follow = Follow

local BUCKET = 0.5
local EVENTS = { "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "QUEST_LOG_UPDATE", "PLAYER_LEVEL_UP" }

local view, placedKey, placedStep, placedTarget, placing, waiting, announce, currentKey, aimed

local function saved()
    return ns.DB.peek("char", "follow")
end

local function save(questID)
    ns.DB.char().follow = questID and { questID = questID } or nil
end

local function playerInfo()
    local _, class = UnitClass("player")
    local _, _, raceID = UnitRace("player")
    return { class = class, raceID = raceID, faction = UnitFactionGroup("player") }
end

local function state()
    local player = playerInfo()
    local Compat = ns.Compat
    return {
        isDone = Compat.IsQuestCompleted,
        isInLog = Compat.IsOnQuest,
        isComplete = Compat.IsQuestComplete,
        isAllowed = function(questID)
            local quest = ns.Data.quest(questID)
            return quest == nil or ns.Masks.allows(quest, player)
        end,
    }
end

function Follow.objective(questID)
    for _, objective in ipairs(ns.Compat.QuestObjectives(questID)) do
        if not objective.finished and objective.text then
            return objective.text
        end
    end
    return nil
end

local function objectiveText(questID)
    local text = Follow.objective(questID)
    return text and L.FOLLOW_OBJECTIVE:format(text) or L.FOLLOW_OBJECTIVE_ANY
end

local function keyOf(step)
    return step and (step.questID .. ":" .. step.kind) or nil
end

local LABELS = {
    pickup = { L.FOLLOW_PICKUP, L.FOLLOW_PICKUP_ANY },
    turnin = { L.FOLLOW_TURNIN, L.FOLLOW_TURNIN_ANY },
}

local function stepLabel(step)
    if step.kind == "objective" then
        return objectiveText(step.questID)
    end
    local name = step.npcID and ns.Names.npc(step.npcID)
    local labels = LABELS[step.kind]
    return name and labels[1]:format(name) or labels[2]
end

local function clearMark()
    if placedKey ~= nil then
        local key = placedKey
        placedKey, placedStep, placedTarget = nil, nil, nil
        ns.Waypoint.clear(key)
    end
end

local function place(step)
    local leg = ns.FollowTravel and ns.FollowTravel.leg(step)
    local stepKey = keyOf(step) .. (leg and ("@" .. leg.id) or "")
    placedTarget = step
    if stepKey == placedStep and ns.Waypoint.has(placedKey) then
        return false
    end
    placing = true
    local title = ns.Names.quest(step.questID)
    if leg then
        ns.Waypoint.set(leg.mapID, leg.x, leg.y, title, step.questID, leg.label)
    else
        ns.Waypoint.set(step.mapID, step.x, step.y, title, step.questID, stepLabel(step), step.npcID)
    end
    placing = false
    placedKey, placedStep = step.questID, stepKey
    return true
end

local function finish(final)
    print(L.FOLLOW_DONE:format(ns.Names.quest(final) or tostring(final)))
    Follow.stop("done", final)
end

local function compute()
    waiting = false
    local final = Follow.current()
    if not final or not ns.Data.ready() then
        return
    end
    view = ns.FollowSteps.build(final, ns.Data, state(), UnitLevel("player"))
    if not view then
        Follow.stop()
        return
    end
    if view.finished then
        finish(final)
        return
    end
    local step = view.current and view.steps[view.current]
    local key = keyOf(step)
    if aimed and aimed.key ~= key then
        aimed = nil
    end
    if aimed then
        place(aimed.step)
    else
        if step and step.mapID then
            place(step)
        else
            clearMark()
            placedStep = key
        end
    end
    if key ~= currentKey or announce then
        currentKey, announce = key, false
        ns:Send("SP_FOLLOW_CHANGED")
    end
    ns:Send("SP_FOLLOW_UPDATED")
end

function Follow.refresh()
    if waiting then
        return
    end
    waiting = true
    ns:RunOutOfCombat(compute)
end

function Follow.current()
    local entry = saved()
    return entry and entry.questID or nil
end

function Follow.view()
    return Follow.current() and view or nil
end

function Follow.target()
    return Follow.current() and placedTarget or nil
end

function Follow.owns(key)
    return key ~= nil and key == placedKey
end

function Follow.aim(index)
    local step = Follow.view() and view.steps[index]
    if not (step and step.mapID) then
        return false
    end
    place(step)
    aimed = { key = currentKey, step = step }
    return true
end

function Follow.start(questID)
    if not (questID and ns.Data.quest(questID)) then
        return
    end
    clearMark()
    save(questID)
    view, announce, currentKey, aimed = nil, true, nil, nil
    Follow.refresh()
end

function Follow.stop(reason, final)
    if not Follow.current() then
        return
    end
    save(nil)
    view, currentKey, aimed = nil, nil, nil
    clearMark()
    ns:Send("SP_FOLLOW_CHANGED", reason, final)
end

Follow:RegisterBucketEvent(EVENTS, BUCKET, Follow.refresh)
ns:On("SP_QUEST_LOG_CHANGED", Follow.refresh)
ns:On("SP_DATA_READY", Follow.refresh)
ns:On("SP_WAYPOINT_CHANGED", function()
    if not placing and placedKey ~= nil and not ns.Waypoint.has(placedKey) then
        placedKey, placedStep = nil, nil
        Follow.stop()
    end
end)
