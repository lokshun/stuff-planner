-- CONTRAT
-- Session de jeu du Parcours (Engine/Session) et son suivi de quête en quête (Follow). Charger après
-- Engine/Session.lua, RouteResults.lua, Follow.lua et FollowTravel.lua.
--   ns.SessionPlan.BUDGETS -> {1800, 3600, 7200} (puces 30 min, 1 h, 2 h)
--   ns.SessionPlan.budget() -> secondes | nil (tout le Parcours) ; setBudget(seconds | nil) : gardé dans
--     StuffPlannerDB.ui.routeSession
--   ns.SessionPlan.rows(tiers, level) -> entrées et alternatives du palier courant (Tiers.current) de
--     niveau d'obtention <= level, sans doublon ; {} sans palier
--   ns.SessionPlan.get(budget) -> plan (Session.plan) | nil, message (RouteResults.get) ; niveau :
--     Results.player() ; trajets chaînés par FollowTravel.between (lieu row.place) ; plan gardé tant que
--     le classement (table des paliers) et le budget sont les mêmes
--   ns.SessionPlan.follow(plan) -> nombre de quêtes en file : objectifs de quête du plan, dans l'ordre ;
--     Follow.start(première) ; file gardée dans StuffPlannerCharDB.session.queue
--   ns.SessionPlan.queue() -> copie de la file ; following() -> file non vide
--   ns.SessionPlan.toggle(key, plan?) -> puce cliquée : "all" (budget nil), un budget, "follow" (suivre
--     plan, ou arrêter : Follow.stop et file vidée)
-- SP_FOLLOW_CHANGED("done", final) avec final = première de la file : retirée, suivante suivie, sinon
--   L.SESSION_DONE dans la discussion. Autre SP_FOLLOW_CHANGED : file vidée si la quête suivie n'est
--   plus la première (arrêt manuel, autre quête suivie).

local _, ns = ...

local L = ns.L

local SessionPlan = {}
ns.SessionPlan = SessionPlan

SessionPlan.BUDGETS = { 1800, 3600, 7200 }

local cached

function SessionPlan.budget()
    return ns.DB.peek("account", "ui", "routeSession")
end

function SessionPlan.setBudget(seconds)
    ns.DB.account("ui").routeSession = seconds
end

function SessionPlan.rows(tiers, level)
    local tier = tiers and ns.Tiers.current(tiers, level)
    local list, seen = {}, {}
    local function add(row)
        if not seen[row] and (row.level or 0) <= level then
            seen[row] = true
            list[#list + 1] = row
        end
    end
    for _, row in ipairs(tier and tier.entries or {}) do
        add(row)
    end
    for _, alternatives in pairs(tier and tier.alternatives or {}) do
        for _, row in ipairs(alternatives) do
            add(row)
        end
    end
    return list
end

local function travel()
    local between = ns.FollowTravel and ns.FollowTravel.between()
    return between and function(from, to)
        return from and between(from.place, to.place) or nil
    end or nil
end

function SessionPlan.get(budget)
    local tiers, info = ns.RouteResults.get()
    if not tiers then
        return nil, info
    end
    if cached and cached.tiers == tiers and cached.budget == budget then
        return cached.plan
    end
    local player = ns.Results.player()
    local level = player and player.level or 1
    local plan = ns.Session.plan(SessionPlan.rows(tiers, level), budget, travel())
    cached = { tiers = tiers, budget = budget, plan = plan }
    return plan
end

local function saved()
    return ns.DB.char("session")
end

function SessionPlan.queue()
    local copy = {}
    for i, questID in ipairs(saved().queue or {}) do
        copy[i] = questID
    end
    return copy
end

function SessionPlan.following()
    local queue = ns.DB.peek("char", "session", "queue")
    return queue ~= nil and #queue > 0
end

function SessionPlan.follow(plan)
    local queue = {}
    for _, objective in ipairs(plan and plan.objectives or {}) do
        local source = objective.row.source
        if source and source.type == "quest" and ns.Data.quest(source.id) then
            queue[#queue + 1] = source.id
        end
    end
    saved().queue = queue
    if queue[1] then
        ns.Follow.start(queue[1])
    end
    return #queue
end

function SessionPlan.toggle(key, plan)
    if key == "all" then
        SessionPlan.setBudget(nil)
    elseif key == "follow" then
        if SessionPlan.following() then
            saved().queue = nil
            ns.Follow.stop()
        else
            SessionPlan.follow(plan)
        end
    else
        SessionPlan.setBudget(key)
    end
end

ns:On("SP_FOLLOW_CHANGED", function(reason, final)
    local queue = ns.DB.peek("char", "session", "queue")
    if not queue or #queue == 0 then
        return
    end
    if reason == "done" and final == queue[1] then
        table.remove(queue, 1)
        if queue[1] then
            ns.Follow.start(queue[1])
        else
            saved().queue = nil
            print(L.SESSION_DONE)
        end
    elseif ns.Follow.current() ~= queue[1] then
        saved().queue = nil
    end
end)
