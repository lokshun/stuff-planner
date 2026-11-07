-- CONTRAT
-- Chaînes de quêtes : prérequis (`quest.prereq`, schéma de tools/schema.py : nombre = requis,
-- table = « l'une de celles-ci »). Pur : aucun appel à l'API WoW.
--   remaining(questID, data, isDone?, isAllowed?) -> {questID...} | nil, "CYCLE", {questID...}
--     quêtes à faire, prérequis d'abord, questID en dernier ; vide si questID est faite.
--     Une quête faite couvre ses propres prérequis. Alternative : faite si l'une l'est, sinon
--     celle au moins d'étapes (puis au plus petit identifiant), en évitant les cycles.
--     isAllowed(questID) faux : alternative écartée (autre faction), sauf si aucune n'est permise.
--     Prérequis absent de la base : une étape sans prérequis. Cycle : les quêtes qui le forment.
--   steps(questID, data, isDone?, isAllowed?) -> nombre d'étapes (#remaining) | nil, "CYCLE", {questID...}
--   order(questIDs, data) -> {questID...} | nil, "CYCLE", {questID...}
--     tri topologique de l'ensemble (doublons retirés) : arêtes de prereq et alternatives
--     internes à l'ensemble, à égalité le plus petit identifiant ; cycle : quêtes non triées.
--   questState(quest, level, opts) -> "log" (opts.isInLog vrai) | "prereq" (un prérequis non fait
--     selon opts.isDone, alternative faite si l'une l'est) | "level" (reqLevel > level) | nil
-- data = façade DataProvider (seul data.quest est lu). Tables renvoyées neuves.

local _, ns = ...

local Chains = {}
ns.Chains = Chains

local CYCLE = "CYCLE"

local function notDone()
    return false
end

local function anyAllowed()
    return true
end

-- Ajoute à `into` les éléments de `list` absents de `seen` (l'ordre topologique est gardé).
local function append(into, seen, list)
    for _, id in ipairs(list) do
        if not seen[id] then
            seen[id] = true
            into[#into + 1] = id
        end
    end
end

local function prereqOf(data, id)
    local quest = data.quest(id)
    return quest and quest.prereq or {}
end

local resolve

-- Meilleure alternative : liste la plus courte, puis plus petit identifiant ; nil si toutes bouclent.
local function resolveAlternative(ctx, ids)
    local best, bestID, cycle, tainted
    for _, id in ipairs(ids) do
        if ctx.isDone(id) then
            return {}, nil, false
        end
    end
    local permitted = {}
    for _, id in ipairs(ids) do
        if ctx.isAllowed(id) then
            permitted[#permitted + 1] = id
        end
    end
    for _, id in ipairs(#permitted > 0 and permitted or ids) do
        local list, loop, dirty = resolve(ctx, id)
        tainted = tainted or dirty
        if list then
            if not best or #list < #best or (#list == #best and id < bestID) then
                best, bestID = list, id
            end
        else
            cycle = cycle or loop
        end
    end
    if best then
        return best, nil, tainted
    end
    return nil, cycle, true
end

-- Renvoie liste, cycle, tainted (un cycle a été croisé : résultat dépendant de la pile).
resolve = function(ctx, id)
    if ctx.isDone(id) then
        return {}, nil, false
    end
    if ctx.memo[id] then
        return ctx.memo[id], nil, false
    end
    local onStack = ctx.position[id]
    if onStack then
        local cycle = {}
        for i = onStack, #ctx.stack do
            cycle[#cycle + 1] = ctx.stack[i]
        end
        return nil, cycle, true
    end
    ctx.stack[#ctx.stack + 1] = id
    ctx.position[id] = #ctx.stack
    local result, seen, tainted, cycle = {}, {}, false, nil
    for _, element in ipairs(prereqOf(ctx.data, id)) do
        local list, loop, dirty
        if type(element) == "table" then
            list, loop, dirty = resolveAlternative(ctx, element)
        else
            list, loop, dirty = resolve(ctx, element)
        end
        tainted = tainted or dirty
        if not list then
            cycle = loop
            break
        end
        append(result, seen, list)
    end
    ctx.stack[#ctx.stack] = nil
    ctx.position[id] = nil
    if cycle then
        return nil, cycle, true
    end
    append(result, seen, { id })
    if not tainted then
        ctx.memo[id] = result
    end
    return result, nil, tainted
end

local function copy(list)
    local out = {}
    for i, id in ipairs(list) do
        out[i] = id
    end
    return out
end

function Chains.remaining(questID, data, isDone, isAllowed)
    local ctx = {
        data = data, isDone = isDone or notDone, isAllowed = isAllowed or anyAllowed,
        memo = {}, stack = {}, position = {},
    }
    local list, cycle = resolve(ctx, questID)
    if not list then
        return nil, CYCLE, cycle
    end
    return copy(list)
end

function Chains.steps(questID, data, isDone, isAllowed)
    local list, code, cycle = Chains.remaining(questID, data, isDone, isAllowed)
    if not list then
        return nil, code, cycle
    end
    return #list
end

-- Prérequis (requis et alternatives aplatis) présents dans l'ensemble.
local function edgesWithin(data, id, members)
    local out = {}
    for _, element in ipairs(prereqOf(data, id)) do
        local ids = type(element) == "table" and element or { element }
        for _, other in ipairs(ids) do
            if members[other] then
                out[other] = true
            end
        end
    end
    return out
end

function Chains.order(questIDs, data)
    local members, ids = {}, {}
    append(ids, members, questIDs)
    local pending, dependents = {}, {}
    for _, id in ipairs(ids) do
        pending[id] = 0
        dependents[id] = dependents[id] or {}
    end
    for _, id in ipairs(ids) do
        for other in pairs(edgesWithin(data, id, members)) do
            pending[id] = pending[id] + 1
            local list = dependents[other]
            list[#list + 1] = id
        end
    end
    local ready, out = {}, {}
    for _, id in ipairs(ids) do
        if pending[id] == 0 then
            ready[#ready + 1] = id
        end
    end
    while #ready > 0 do
        table.sort(ready, function(a, b)
            return a > b
        end)
        local id = table.remove(ready)
        out[#out + 1] = id
        for _, dependent in ipairs(dependents[id]) do
            pending[dependent] = pending[dependent] - 1
            if pending[dependent] == 0 then
                ready[#ready + 1] = dependent
            end
        end
    end
    if #out < #ids then
        local left = {}
        for _, id in ipairs(ids) do
            if pending[id] > 0 then
                left[#left + 1] = id
            end
        end
        table.sort(left)
        return nil, CYCLE, left
    end
    return out
end

local function prereqsDone(quest, isDone)
    for _, element in ipairs(quest.prereq or {}) do
        local alternatives = type(element) == "table" and element or { element }
        local done = false
        for _, id in ipairs(alternatives) do
            done = done or isDone(id)
        end
        if not done then
            return false
        end
    end
    return true
end

function Chains.questState(quest, level, opts)
    if opts.isInLog and opts.isInLog(quest.id) then
        return "log"
    elseif opts.isDone and not prereqsDone(quest, opts.isDone) then
        return "prereq"
    elseif quest.reqLevel and level and quest.reqLevel > level then
        return "level"
    end
    return nil
end
