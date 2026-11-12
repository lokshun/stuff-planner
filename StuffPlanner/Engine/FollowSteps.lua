-- CONTRAT
-- Étapes du suivi d'une suite de quêtes : prendre, faire l'objectif, rendre. Pur : aucun appel à l'API WoW.
-- Charger après Engine/Chains.lua.
--   build(finalQuestID, data, state, level) -> view | nil (quête inconnue) | nil, "CYCLE", {questID...}
--     quêtes = Chains.remaining(final, data, state.isDone, state.isAllowed) (faites retirées) ;
--     state = {isDone, isInLog, isComplete, isAllowed?} : fonctions(questID) -> bool ;
--     level : niveau du joueur (nil : ignoré)
--     view = {final, steps = {step...}, current = indice | nil, finished = bool (plus rien à faire)}
--     step = {questID, kind = "pickup" | "objective" | "turnin", state = "done" | "current" | "todo",
--             npcID?, mapID?, x?, y?, blocked = "prereq" | "level" | nil}
--       pickup : donneur (quest.starter, data.npc) ; objective : quest.objMap/objX/objY ;
--       turnin : PNJ de rendu (quest.ender, data.npc) ; sans position : mapID, x, y nil.
--     Au journal : prise faite ; complète (isComplete) : objectif fait aussi. Hors journal : prise
--       bloquée si un prérequis manque (« prereq ») ou si reqLevel > level (« level »).
--     current = première étape non faite d'une quête non bloquée (journal ou prise possible).
--     upcoming = sans current : première prise bloquée par le niveau seul (repère du suivi) | nil
-- data = façade DataProvider (quest, npc). Tables renvoyées neuves.

local _, ns = ...

local FollowSteps = {}
ns.FollowSteps = FollowSteps

local function npcStep(questID, kind, npcID, data)
    local step = { questID = questID, kind = kind, npcID = npcID, state = "todo" }
    local npc = npcID and data.npc(npcID)
    if npc and npc.mapID and npc.x and npc.y then
        step.mapID, step.x, step.y = npc.mapID, npc.x, npc.y
    end
    return step
end

local function objectiveStep(quest)
    local step = { questID = quest.id, kind = "objective", state = "todo" }
    if quest.objMap and quest.objX and quest.objY then
        step.mapID, step.x, step.y = quest.objMap, quest.objX, quest.objY
    end
    return step
end

-- Étapes d'une quête, marquées ; renvoie aussi l'indice local de l'étape à faire (nil si bloquée).
local function questSteps(quest, data, state, level)
    local pickup = npcStep(quest.id, "pickup", quest.starter, data)
    local objective = objectiveStep(quest)
    local turnin = npcStep(quest.id, "turnin", quest.ender, data)
    local steps = { pickup, objective, turnin }
    local blocked = ns.Chains.questState(quest, level, { isInLog = state.isInLog, isDone = state.isDone })
    if blocked == "log" then
        pickup.state = "done"
        if state.isComplete(quest.id) then
            objective.state = "done"
            return steps, 3
        end
        return steps, 2
    end
    pickup.blocked = blocked
    return steps, blocked == nil and 1 or nil
end

function FollowSteps.build(final, data, state, level)
    if not data.quest(final) then
        return nil
    end
    local ids, err, cycle = ns.Chains.remaining(final, data, state.isDone, state.isAllowed)
    if not ids then
        return nil, err, cycle
    end
    local view = { final = final, steps = {}, finished = #ids == 0 }
    for _, questID in ipairs(ids) do
        local quest = data.quest(questID)
        if quest then
            local steps, next = questSteps(quest, data, state, level)
            for index, step in ipairs(steps) do
                view.steps[#view.steps + 1] = step
                if index == next and not view.current then
                    step.state = "current"
                    view.current = #view.steps
                elseif step.blocked == "level" and not view.upcoming then
                    view.upcoming = #view.steps
                end
            end
        end
    end
    if view.current then
        view.upcoming = nil
    end
    return view
end
