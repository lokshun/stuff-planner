-- CONTRAT
-- Classement du Parcours 1-60 (Planner, Tiers) partagé par les onglets Parcours et Équipement.
-- Charger après Engine/Planner.lua, Engine/Tiers.lua, Data/Loader.lua et Profiles/Manager.lua.
--   ns.RouteResults.get() -> tiers (Tiers.build, paliers passés compris), evaluated (objets évalués) | nil, message
--     (L.ROUTE_COMPUTING | BEST_NOT_READY | BEST_NO_PROFILE) ; lance le calcul s'il manque
--   ns.RouteResults.current(level) -> entrées du palier contenant level (Tiers.current) | nil ;
--     ne lance pas le calcul
--   ns.RouteResults.busy() -> vrai pendant le calcul
-- Calcul par coroutine (Loader.SLICE_MS par image, en pause en combat), raids compris ; second
-- classement en mode référence (Planner, maxLevel = fin du palier précédant celui du joueur) pour les
-- paliers passés, sauté au premier palier ; à la fin,
-- SP_ROUTE_UPDATED (aussi quand le résultat est jeté parce qu'invalidé pendant le calcul).
-- SP_PLAYER_CHANGED, SP_DATA_READY, SP_PROFILE_CHANGED : classement oublié, recalculé au
-- prochain get().

local _, ns = ...

local L = ns.L

local RouteResults = {}
ns.RouteResults = RouteResults

local COMBAT_DELAY = 0.5

local tiers, evaluated, dirty, job = nil, 0, true, nil
local sliceStart = 0

local function tick()
    if ns.Loader.clock() - sliceStart >= ns.Loader.SLICE_MS then
        coroutine.yield()
    end
end

-- Corps de la coroutine : paliers calculés.
local function work(player, profile)
    local data = ns.Data
    local itemIDs = data.itemIDs()
    local candidates = ns.Planner.candidates(itemIDs, data, tick)
    local opts = { isDone = ns.Compat.IsQuestCompleted, step = tick, pause = coroutine.yield, includeRaids = true }
    local rows = ns.Planner.rank(candidates, player, profile, data, opts)
    local reference
    local first = ns.Tiers.indexOf(player.level)
    if first > 1 then
        local refOpts = { isDone = opts.isDone, step = tick, pause = coroutine.yield, includeRaids = true,
            reference = true, maxLevel = ns.Tiers.BOUNDS[first - 1][2] }
        reference = ns.Planner.rank(candidates, player, profile, data, refOpts)
    end
    evaluated = #itemIDs
    coroutine.yield()
    return ns.Tiers.build(rows, player, reference)
end

local resume

local function finish(ok, result)
    job = nil
    if not ok then
        geterrorhandler()(result)
    elseif not dirty then
        tiers = result
    end
    ns:Send("SP_ROUTE_UPDATED")
end

resume = function()
    if not job then
        return
    end
    if InCombatLockdown() then
        C_Timer.After(COMBAT_DELAY, resume)
        return
    end
    sliceStart = ns.Loader.clock()
    local ok, result = coroutine.resume(job)
    local done = not ok or coroutine.status(job) == "dead"
    if ns.Perf then
        ns.Perf.slice("route", ns.Loader.clock() - sliceStart, done)
    end
    if done then
        finish(ok, result)
    else
        C_Timer.After(0, resume)
    end
end

function RouteResults.get()
    if job then
        return nil, L.ROUTE_COMPUTING
    end
    if not dirty and tiers then
        return tiers, evaluated
    end
    if not ns.Data.ready() then
        return nil, L.BEST_NOT_READY
    end
    local profile = ns.Profiles.active()
    if not profile then
        return nil, L.BEST_NO_PROFILE
    end
    dirty, tiers = false, nil
    local player = ns.Player.snapshot()
    job = coroutine.create(function()
        return work(player, profile)
    end)
    C_Timer.After(0, resume)
    return nil, L.ROUTE_COMPUTING
end

function RouteResults.current(level)
    local tier = not dirty and ns.Tiers.current(tiers, level)
    return tier and tier.entries or nil
end

function RouteResults.busy()
    return job ~= nil
end

local function invalidate()
    dirty = true
end

ns:On("SP_PLAYER_CHANGED", invalidate)
ns:On("SP_DATA_READY", invalidate)
ns:On("SP_PROFILE_CHANGED", invalidate)
