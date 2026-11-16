-- CONTRAT
-- Classement du Parcours 1-60 (Planner, Tiers) partagé par les onglets Parcours, Équipement et la session.
-- Charger après Engine/Origins.lua, Engine/Planner.lua, Engine/Tiers.lua, Data/Loader.lua, Profiles/Manager.lua
-- et Results.lua. Instantané du joueur : ns.Results.player() (partagé, cache de Scoring commun).
-- origins (Origins.new | nil = toutes) : un classement par clé (Origins.key), MAX_KEYS gardés (le plus ancien
--   demandé oublié) ; un seul calcul à la fois : get d'une autre clé pendant un calcul -> ROUTE_COMPUTING, la page
--   redemande au SP_ROUTE_UPDATED de fin.
--   ns.RouteResults.get(origins?) -> tiers (Tiers.build, paliers passés compris), evaluated (objets évalués) | nil,
--     message (L.ROUTE_COMPUTING | BEST_NOT_READY | BEST_NO_PROFILE) ; lance le calcul s'il manque
--   ns.RouteResults.current(level, origins?) -> entrées, alternatives, quests du palier contenant level
--     (Tiers.current) | nil ; ne lance pas le calcul
--   ns.RouteResults.busy() -> vrai pendant un calcul
-- Calcul par coroutine (Loader.SLICE_MS par image, en pause en combat), raids compris, repli hors profil
-- (Planner opts.fallback), opts.origins ; second classement en mode référence (Planner, maxLevel = fin du
-- palier précédant celui du joueur) pour les paliers passés, sauté au premier palier ; à la fin,
-- SP_ROUTE_UPDATED (aussi quand le résultat est jeté parce qu'invalidé pendant le calcul).
-- SP_PLAYER_CHANGED (émis seulement sur un vrai changement, voir Player), SP_DATA_READY,
-- SP_PROFILE_CHANGED : tous les classements oubliés, recalculés au prochain get().
-- Candidats (Planner.candidates, toute la base) partagés entre clés, refaits après SP_DATA_READY.
-- Trajet : FollowTravel.estimator() au lancement du calcul (position du joueur à ce moment).
--   Option planner.calibrate : opts.tuning = Calibration.tuning(Timings.samples()), changement = invalidate.
--   ns.RouteResults.invalidate() -> classements oubliés, SP_ROUTE_UPDATED (les onglets redemandent get())
--   ns.RouteResults.secondsOf(source) -> secondes de la ligne du Parcours pour cette source (type, id ;
--     entrées et alternatives de tous les paliers de tous les classements gardés, la plus courte) | nil ;
--     ne lance pas le calcul (fiches)

local _, ns = ...

local L = ns.L

local RouteResults = {}
ns.RouteResults = RouteResults

local COMBAT_DELAY = 0.5
local MAX_KEYS = 3

local results, order = {}, {} -- results[key] = {tiers, evaluated} ; order : clés, plus récente à la fin
local generation = 0 -- incrémentée par invalidate : un calcul d'une génération passée est jeté
local job, jobKey, jobGeneration
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

-- Corps de la coroutine : paliers calculés, objets évalués.
local function work(player, profile, travel, origins)
    local data = ns.Data
    local itemIDs = data.itemIDs()
    local list = candidates or ns.Planner.candidates(itemIDs, data, tick)
    candidates = list
    local tuning = tuningOf()
    local opts = { isDone = ns.Compat.IsQuestCompleted, isInLog = ns.Compat.IsOnQuest, step = tick,
        pause = coroutine.yield, includeRaids = true, travel = travel, tuning = tuning, fallback = true,
        origins = origins }
    local rows = ns.Planner.rank(list, player, profile, data, opts)
    local reference
    local first = ns.Tiers.indexOf(player.level)
    if first > 1 then
        local refOpts = { isDone = opts.isDone, step = tick, pause = coroutine.yield, includeRaids = true,
            reference = true, maxLevel = ns.Tiers.BOUNDS[first - 1][2], travel = travel, tuning = tuning,
            origins = origins }
        reference = ns.Planner.rank(list, player, profile, data, refOpts)
    end
    coroutine.yield()
    return ns.Tiers.build(rows, player, reference), #itemIDs
end

local function touch(key)
    for i, other in ipairs(order) do
        if other == key then
            table.remove(order, i)
            break
        end
    end
    order[#order + 1] = key
    while #order > MAX_KEYS do
        results[table.remove(order, 1)] = nil
    end
end

local resume

local function finish(ok, tiers, evaluated)
    local key, gen = jobKey, jobGeneration
    job, jobKey, jobGeneration = nil, nil, nil
    if not ok then
        geterrorhandler()(tiers)
    elseif gen == generation then
        results[key] = { tiers = tiers, evaluated = evaluated }
        touch(key)
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
    local ok, tiers, evaluated = coroutine.resume(job)
    local done = not ok or coroutine.status(job) == "dead"
    if ns.Perf then
        ns.Perf.slice("route", ns.Loader.clock() - sliceStart, done)
    end
    if done then
        finish(ok, tiers, evaluated)
    else
        C_Timer.After(0, resume)
    end
end

function RouteResults.get(origins)
    local key = ns.Origins.key(origins)
    local cached = results[key]
    if cached then
        touch(key)
        return cached.tiers, cached.evaluated
    end
    if job then
        return nil, L.ROUTE_COMPUTING
    end
    if not ns.Data.ready() then
        return nil, L.BEST_NOT_READY
    end
    local profile = ns.Profiles.active()
    if not profile then
        return nil, L.BEST_NO_PROFILE
    end
    local player = ns.Results.player() or ns.Player.snapshot()
    local travel = ns.FollowTravel and ns.FollowTravel.estimator() or nil
    jobKey, jobGeneration = key, generation
    job = coroutine.create(function()
        return work(player, profile, travel, origins)
    end)
    C_Timer.After(0, resume)
    return nil, L.ROUTE_COMPUTING
end

function RouteResults.current(level, origins)
    local cached = results[ns.Origins.key(origins)]
    local tier = cached and ns.Tiers.current(cached.tiers, level)
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
    if not source then
        return nil
    end
    local best
    for _, cached in pairs(results) do
        for _, tier in ipairs(cached.tiers) do
            for _, row in ipairs(tier.entries) do
                best = shorter(best, row, source)
            end
            for _, list in pairs(tier.alternatives or {}) do
                for _, row in ipairs(list) do
                    best = shorter(best, row, source)
                end
            end
        end
    end
    return best
end

function RouteResults.busy()
    return job ~= nil
end

local function invalidate()
    generation = generation + 1
    results, order = {}, {}
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
