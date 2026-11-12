-- CONTRAT
-- Classement du Parcours 1-60 (Planner, Tiers) partagé par les onglets Parcours et Équipement.
-- Charger après Engine/Planner.lua, Engine/Tiers.lua, Data/Loader.lua, Profiles/Manager.lua et Results.lua.
-- Instantané du joueur : ns.Results.player() (partagé, cache de Scoring commun).
--   ns.RouteResults.get() -> tiers (Tiers.build, paliers passés compris), evaluated (objets évalués) | nil, message
--     (L.ROUTE_COMPUTING | BEST_NOT_READY | BEST_NO_PROFILE) ; lance le calcul s'il manque
--   ns.RouteResults.current(level) -> entrées, alternatives, quests du palier contenant level (Tiers.current)
--     | nil ;
--     ne lance pas le calcul
--   ns.RouteResults.busy() -> vrai pendant le calcul
-- Calcul par coroutine (Loader.SLICE_MS par image, en pause en combat), raids compris ; second
-- classement en mode référence (Planner, maxLevel = fin du palier précédant celui du joueur) pour les
-- paliers passés, sauté au premier palier ; à la fin,
-- SP_ROUTE_UPDATED (aussi quand le résultat est jeté parce qu'invalidé pendant le calcul).
-- SP_PLAYER_CHANGED (émis seulement sur un vrai changement, voir Player), SP_DATA_READY,
-- SP_PROFILE_CHANGED : classement oublié, recalculé au prochain get().
-- Candidats (Planner.candidates, toute la base) gardés d'un calcul à l'autre, refaits après SP_DATA_READY.
-- Trajet : FollowTravel.estimator() au lancement du calcul (position du joueur à ce moment) ; ancien calcul
--   Option planner.calibrate : opts.tuning = Calibration.tuning(Timings.samples()), changement = invalidate.
--   ns.RouteResults.invalidate() -> classement oublié, SP_ROUTE_UPDATED (l'onglet redemande get())
--   ns.RouteResults.secondsOf(source) -> secondes de la ligne du Parcours pour cette source (type, id ;
--     entrées et alternatives de tous les paliers, la plus courte) | nil ; ne lance pas le calcul (fiches)

local _, ns = ...

local L = ns.L

local RouteResults = {}
ns.RouteResults = RouteResults

local COMBAT_DELAY = 0.5

local tiers, evaluated, dirty, job = nil, 0, true, nil
local candidates
local sliceStart = 0

local function tick()
    if ns.Loader.clock() - sliceStart >= ns.Loader.SLICE_MS then
        coroutine.yield()
    end
end

-- Constantes mesurées du joueur (planner.calibrate), sinon défauts.
local function tuningOf()
    if ns.Options.get("planner.calibrate") and ns.Timings then
        return ns.Calibration.tuning(ns.Timings.samples(), ns.Planner.TUNING)
    end
end

-- Corps de la coroutine : paliers calculés.
local function work(player, profile, travel)
    local data = ns.Data
    local itemIDs = data.itemIDs()
    local list = candidates or ns.Planner.candidates(itemIDs, data, tick)
    candidates = list
    local tuning = tuningOf()
    local opts = { isDone = ns.Compat.IsQuestCompleted, step = tick, pause = coroutine.yield, includeRaids = true,
        travel = travel, tuning = tuning }
    local rows = ns.Planner.rank(list, player, profile, data, opts)
    local reference
    local first = ns.Tiers.indexOf(player.level)
    if first > 1 then
        local refOpts = { isDone = opts.isDone, step = tick, pause = coroutine.yield, includeRaids = true,
            reference = true, maxLevel = ns.Tiers.BOUNDS[first - 1][2], travel = travel, tuning = tuning }
        reference = ns.Planner.rank(list, player, profile, data, refOpts)
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
    local player = ns.Results.player() or ns.Player.snapshot()
    local travel = ns.FollowTravel and ns.FollowTravel.estimator() or nil
    job = coroutine.create(function()
        return work(player, profile, travel)
    end)
    C_Timer.After(0, resume)
    return nil, L.ROUTE_COMPUTING
end

function RouteResults.current(level)
    local tier = not dirty and ns.Tiers.current(tiers, level)
    if not tier then
        return nil
    end
    return tier.entries, tier.alternatives, tier.quests
end

local function shorter(best, row, source)
    local other = row.source
    if row.seconds and other and other.type == source.type and other.id == source.id then
        return math.min(best or math.huge, row.seconds)
    end
    return best
end

function RouteResults.secondsOf(source)
    if dirty or not tiers or not source then
        return nil
    end
    local best
    for _, tier in ipairs(tiers) do
        for _, row in ipairs(tier.entries) do
            best = shorter(best, row, source)
        end
        for _, list in pairs(tier.alternatives or {}) do
            for _, row in ipairs(list) do
                best = shorter(best, row, source)
            end
        end
    end
    return best
end

function RouteResults.busy()
    return job ~= nil
end

local function invalidate()
    dirty = true
end

function RouteResults.invalidate()
    invalidate()
    ns:Send("SP_ROUTE_UPDATED")
end

ns:On("SP_PLAYER_CHANGED", invalidate)
ns:On("SP_DATA_READY", function()
    candidates = nil
    invalidate()
end)
ns:On("SP_PROFILE_CHANGED", invalidate)
ns:On("SP_OPTION_CHANGED", function(key)
    if key == "planner.calibrate" then
        RouteResults.invalidate()
    end
end)
