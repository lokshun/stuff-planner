-- CONTRAT
-- Mesures de performance et outils de débogage. Charger après Core.lua, Compat.lua, Locales/Format.lua
-- et Debug/Pseudo.lua, avant Data/Loader.lua.
--   ns.Perf.BUDGETS -> {memoryMB = 15, sliceMS = 8, zoneMS = 50} (docs/ARCHITECTURE.md, Budgets)
--   ns.Perf.slice(name, ms, done) -> ajoute une tranche (ms de travail dans une image) au calcul `name`
--     en cours ; done : calcul fini, il devient le dernier mesuré et le suivant repart de zéro
--   ns.Perf.stats(name) -> {slices, total, max} du dernier calcul fini | nil
-- Calculs mesurés : "load" (Loader), "zone" (Results), "route" (RouteTab) ; l'appelant teste ns.Perf.
-- /splan perf : mémoire (Compat.AddOnMemory) après collectgarbage, comparée au budget, et avant (déchets
--   compris) ; puis les derniers calculs, comparés aux budgets ; puis, si ns.Timings est chargé, les
--   médianes du joueur (Timings.medians : durée Format.duration, trajet en rapport ×1.25, nombre de mesures).
-- /splan debug pseudo : bascule StuffPlannerDB.debug.pseudo ; actif, ns.Pseudo.apply(ns.L) à
--   l'initialisation de l'addon : effet après /reload.
-- /splan debug effort : bascule StuffPlannerDB.debug.legacyEffort (ancien effort du Parcours, RouteResults),
--   Parcours recalculé aussitôt.

local _, ns = ...

local L = ns.L
local Format = ns.Format

local Perf = ns:NewModule("Perf")
ns.Perf = Perf

Perf.BUDGETS = { memoryMB = 15, sliceMS = 8, zoneMS = 50 }

local ADDONS = { "StuffPlanner", "StuffPlanner_Data" }
local RUNS = {
    { name = "load", label = "PERF_LOAD" },
    { name = "zone", label = "PERF_ZONE", totalBudget = "zoneMS" },
    { name = "route", label = "PERF_ROUTE" },
}

local running, finished = {}, {}

function Perf.slice(name, ms, done)
    local run = running[name] or { slices = 0, total = 0, max = 0 }
    run.slices = run.slices + 1
    run.total = run.total + ms
    run.max = math.max(run.max, ms)
    if done then
        finished[name], running[name] = run, nil
    else
        running[name] = run
    end
end

function Perf.stats(name)
    return finished[name]
end

local function status(ok)
    return ok and L.PERF_OK or L.PERF_OVER
end

local function ms(value)
    return Format.number(value, nil, 1)
end

local function totalMB(usage)
    return (usage.StuffPlanner + usage.StuffPlanner_Data) / 1024
end

local function memoryLine()
    local before = ns.Compat.AddOnMemory(ADDONS)
    if not before then
        return L.PERF_MEMORY_UNKNOWN
    end
    collectgarbage("collect")
    local usage = ns.Compat.AddOnMemory(ADDONS)
    local total = totalMB(usage)
    return L.PERF_MEMORY:format(Format.number(usage.StuffPlanner), Format.number(usage.StuffPlanner_Data),
        Format.number(total, nil, 1), Perf.BUDGETS.memoryMB, status(total < Perf.BUDGETS.memoryMB),
        Format.number(totalMB(before), nil, 1))
end

local function runLine(run)
    local stats = finished[run.name]
    local label = L[run.label]
    if not stats then
        return L.PERF_NONE:format(label)
    end
    local sliceBudget = Perf.BUDGETS.sliceMS
    local ok = stats.max <= sliceBudget
    if run.totalBudget then
        local totalBudget = Perf.BUDGETS[run.totalBudget]
        ok = ok and stats.total < totalBudget
        return L.PERF_RUN_BUDGET:format(label, ms(stats.max), sliceBudget, ms(stats.total), totalBudget,
            stats.slices, status(ok))
    end
    return L.PERF_RUN:format(label, ms(stats.max), sliceBudget, ms(stats.total), stats.slices, status(ok))
end

local TIMING_LABELS = {
    quest = "PERF_TIMING_QUEST", dungeon = "PERF_TIMING_DUNGEON", raid = "PERF_TIMING_RAID",
    travel = "PERF_TIMING_TRAVEL",
}

local function timingLine(row)
    local label = L[TIMING_LABELS[row.kind]]
    if not row.median then
        return L.PERF_TIMING_NONE:format(label)
    end
    local value = row.kind == "travel" and L.PERF_TIMING_RATIO:format(Format.number(row.median, nil, 2))
        or Format.duration(row.median)
    return L.PERF_TIMING:format(label, value, row.count)
end

local function showPerf()
    print(L.PERF_HEADER)
    print(memoryLine())
    for _, run in ipairs(RUNS) do
        print(runLine(run))
    end
    if ns.Timings then
        print(L.PERF_TIMINGS:format(ns.Calibration.WINDOW))
        for _, row in ipairs(ns.Timings.medians()) do
            print(timingLine(row))
        end
    end
end

local function debugCommand(args)
    local command = args:lower()
    local debug = ns.DB.account("debug")
    if command == "pseudo" then
        local enabled = not debug.pseudo
        debug.pseudo = enabled
        print(enabled and L.DEBUG_PSEUDO_ON or L.DEBUG_PSEUDO_OFF)
    elseif command == "effort" then
        local legacy = not debug.legacyEffort or nil
        debug.legacyEffort = legacy
        print(legacy and L.DEBUG_EFFORT_LEGACY or L.DEBUG_EFFORT_SECONDS)
        ns.RouteResults.invalidate()
    else
        print(L.DEBUG_USAGE)
    end
end

function Perf:OnInitialize() -- luacheck: ignore 212/self
    if ns.DB.peek("account", "debug", "pseudo") then
        ns.Pseudo.apply(L)
    end
end

ns:RegisterCommand("perf", showPerf, "PERF_COMMAND_HELP")
ns:RegisterCommand("debug", debugCommand, "DEBUG_COMMAND_HELP")
