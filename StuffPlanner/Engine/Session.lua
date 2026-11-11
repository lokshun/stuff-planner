-- CONTRAT
-- Session de jeu : objectifs du Parcours qui tiennent dans un budget de temps. Pur : aucun appel à l'API WoW.
--   ns.Session.plan(rows, budgetSeconds?, travel?) -> plan = {objectives = {{row, seconds, travel, at}...},
--     seconds, value} : objectifs ordonnés ; seconds (somme) <= budgetSeconds (nil : sans limite).
--     rows = lignes de Planner.rank {itemID, source, delta = {abs, slot}, seconds, trip?, priority} ;
--     trip = part de seconds passée à rejoindre l'objectif depuis le joueur (absente : 0).
--     travel(from, to) -> secondes | nil : trajet entre deux lignes (from nil : position du joueur) ; nil
--     ou travel absent : row.trip gardé. Demandé une fois par paire (cache du calcul).
--     Coût d'un objectif après `from` = seconds - trip + trajet ; objective.travel = trajet compté,
--     objective.at = début (secondes depuis le début de la session).
--   Choix : glouton sur la valeur par seconde (value / coût depuis l'objectif précédent), un objectif par
--     emplacement (delta.slot) et par source (type, id : une quête ne se rend qu'une fois) ; relancé depuis
--     chacun des STARTS meilleurs premiers objectifs, plan de plus forte valeur gardé (le premier à égalité).
--     Lignes sans seconds, de valeur nulle ou plus longues que le budget ignorées ; MAX_ROWS lignes au
--     plus (meilleures priorités).
--   ns.Session.value(row) -> gain pondéré de la ligne (priority × seconds / 60 : gain × durée de vie + XP)
--   ns.Session.simple(rows, budgetSeconds?) -> plan du tri simple (priorité décroissante, une ligne prise si
--     elle tient encore, row.seconds sans chaînage ; mêmes règles d'emplacement et de source), pour comparer.

local _, ns = ...

local Session = {}
ns.Session = Session

Session.MAX_ROWS = 40
Session.STARTS = 8

function Session.value(row)
    return (row.priority or 0) * (row.seconds or 0) / 60
end

local function sourceKey(row)
    local source = row.source
    return source and (tostring(source.type) .. ":" .. tostring(source.id)) or ("item:" .. tostring(row.itemID))
end

local function byPriority(a, b)
    if a.priority ~= b.priority then
        return a.priority > b.priority
    end
    return a.itemID < b.itemID
end

-- Lignes retenues, triées par priorité, au plus MAX_ROWS.
local function usable(rows, budget)
    local list = {}
    for _, row in ipairs(rows or {}) do
        if row.seconds and row.seconds > 0 and row.seconds - (row.trip or 0) <= budget and row.priority
            and Session.value(row) > 0 then
            list[#list + 1] = row
        end
    end
    table.sort(list, byPriority)
    for i = #list, Session.MAX_ROWS + 1, -1 do
        list[i] = nil
    end
    return list
end

-- Coût d'une ligne après `from` (nil : départ), trajet compris ; trajets mis en cache.
local function costFn(travel)
    local cache = {}
    return function(from, row)
        local trip = row.trip or 0
        local leg = trip
        if travel then
            local key = from or cache
            cache[key] = cache[key] or {}
            local known = cache[key][row]
            if known == nil then
                known = travel(from, row) or false
                cache[key][row] = known
            end
            leg = known or trip
        end
        return row.seconds - trip + leg, leg
    end
end

local function newPlan()
    return { objectives = {}, seconds = 0, value = 0, slots = {}, sources = {} }
end

local function free(plan, row)
    return not (row.delta and plan.slots[row.delta.slot]) and not plan.sources[sourceKey(row)]
end

local function add(plan, row, seconds, leg)
    plan.objectives[#plan.objectives + 1] = { row = row, seconds = seconds, travel = leg, at = plan.seconds }
    plan.seconds = plan.seconds + seconds
    plan.value = plan.value + Session.value(row)
    if row.delta and row.delta.slot then
        plan.slots[row.delta.slot] = true
    end
    plan.sources[sourceKey(row)] = true
end

-- Meilleure ligne libre qui tient après `from` : row, coût, trajet.
local function best(plan, rows, budget, cost, from)
    local chosen, chosenCost, chosenLeg, chosenRatio
    for _, row in ipairs(rows) do
        if free(plan, row) then
            local seconds, leg = cost(from, row)
            if plan.seconds + seconds <= budget then
                local ratio = Session.value(row) / math.max(seconds, 1)
                if not chosen or ratio > chosenRatio or (ratio == chosenRatio and row.itemID < chosen.itemID) then
                    chosen, chosenCost, chosenLeg, chosenRatio = row, seconds, leg, ratio
                end
            end
        end
    end
    return chosen, chosenCost, chosenLeg
end

local function greedy(rows, budget, cost, first)
    local plan = newPlan()
    local seconds, leg = cost(nil, first)
    if seconds > budget then
        return nil
    end
    add(plan, first, seconds, leg)
    local from = first
    while true do
        local row, rowCost, rowLeg = best(plan, rows, budget, cost, from)
        if not row then
            break
        end
        add(plan, row, rowCost, rowLeg)
        from = row
    end
    return plan
end

-- Premiers objectifs essayés : les STARTS meilleurs rapports depuis le joueur.
local function starts(rows, budget, cost)
    local list = {}
    for _, row in ipairs(rows) do
        local seconds = cost(nil, row)
        if seconds <= budget then
            list[#list + 1] = { row = row, ratio = Session.value(row) / math.max(seconds, 1) }
        end
    end
    table.sort(list, function(a, b)
        if a.ratio ~= b.ratio then
            return a.ratio > b.ratio
        end
        return a.row.itemID < b.row.itemID
    end)
    return list
end

local function finish(plan)
    plan.slots, plan.sources = nil, nil
    return plan
end

function Session.plan(rows, budgetSeconds, travel)
    local budget = budgetSeconds or math.huge
    local list = usable(rows, budget)
    local cost = costFn(travel)
    local kept
    for i, start in ipairs(starts(list, budget, cost)) do
        if i > Session.STARTS then
            break
        end
        local plan = greedy(list, budget, cost, start.row)
        if plan and (not kept or plan.value > kept.value) then
            kept = plan
        end
    end
    return finish(kept or newPlan())
end

function Session.simple(rows, budgetSeconds)
    local budget = budgetSeconds or math.huge
    local plan = newPlan()
    for _, row in ipairs(usable(rows, budget)) do
        if free(plan, row) and plan.seconds + row.seconds <= budget then
            add(plan, row, row.seconds, row.trip or 0)
        end
    end
    return finish(plan)
end
