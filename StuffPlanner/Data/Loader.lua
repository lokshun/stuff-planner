-- CONTRAT
-- Charge StuffPlanner_Data (LoadOnDemand) au premier PLAYER_ENTERING_WORLD, puis remplit ns.Data
-- par coroutine, une tranche par image. Charger après DataProvider.lua, InstanceIndex.lua et Collector.lua.
--   ns.Loader.BUDGET_MS -> 8, travail maximal par image ; SLICE_MS -> 7, seuil de pause des coroutines
--     (Loader, Results, RouteTab) : 1 ms de marge pour l'unité de travail en cours
--   ns.Loader.clock() -> millisecondes (debugprofilestop) ; remplaçable par les tests
--   ns.Loader.step() -> une tranche ; true quand il n'y a plus rien à faire
--   ns.Addon:RegisterData(db) -> appelé par Register.lua de l'addon de données avec son ns
-- Ordre : observations du collecteur, index des quêtes et des instances par carte, butin par
-- instance (InstanceIndex), Data prête, décodage des quêtes
-- de la zone actuelle et de leurs objets, puis SP_DATA_READY. Le reste se décode à la demande.
-- Data.finish et SP_DATA_READY (ses abonnés tournent dans la tranche) ouvrent chacun une tranche.
-- Rien en combat : la tranche est sautée. Base absente ou d'un autre schéma : Data reste non prête.
-- Classic Era (Compat.client() == "vanilla") : contenu `forever` masqué (Data.attach, hideForever),
--   objets lus dans EraItems (opts.era).
-- QuestieDB chargé (contrat 4) : ns.QuestieAdapter passé à Data.attach (opts.external).

local _, ns = ...

local Loader = ns:NewModule("Loader", "AceEvent-3.0")
ns.Loader = Loader

local DATA_ADDON = "StuffPlanner_Data"

Loader.BUDGET_MS = 8
Loader.SLICE_MS = 7

function Loader.clock()
    return debugprofilestop()
end

local worker
local frame
local sliceStart = 0

local function tick()
    if Loader.clock() - sliceStart >= Loader.SLICE_MS then
        coroutine.yield()
    end
end

local function warm(questID)
    local quest = ns.Data.quest(questID)
    for _, list in ipairs({ quest.rewards, quest.choices }) do
        for _, itemID in ipairs(list) do
            ns.Data.item(itemID)
            tick()
        end
    end
end

local function work(db)
    for _, record in ipairs(ns.Collector.records()) do
        ns.Data.observe(record)
        tick()
    end
    for id in pairs(db.Quests) do
        ns.Data.indexQuest(id)
        tick()
    end
    for id in pairs(db.Instances) do
        ns.Data.indexInstance(id)
    end
    for itemID in pairs(db.Origins) do
        ns.Data.indexOrigin(itemID)
        tick()
    end
    ns.Data.finish()
    coroutine.yield()
    local mapID = ns.Compat.PlayerMapPosition()
    if mapID then
        for _, questID in ipairs(ns.Data.questsInMap(mapID)) do
            warm(questID)
            tick()
        end
    end
    coroutine.yield()
    ns:Send("SP_DATA_READY")
end

function Loader.step()
    if not worker or coroutine.status(worker) == "dead" then
        return true
    end
    if InCombatLockdown() then
        return false
    end
    sliceStart = Loader.clock()
    local ok, err = coroutine.resume(worker)
    if not ok then
        geterrorhandler()(err)
    end
    local done = coroutine.status(worker) == "dead"
    if ns.Perf then
        ns.Perf.slice("load", Loader.clock() - sliceStart, done)
    end
    return done
end

function ns.Addon:RegisterData(db) -- luacheck: ignore 212/self
    local questie = ns.QuestieAdapter.attach() and ns.QuestieAdapter or nil
    local vanilla = ns.Compat.client() == "vanilla"
    if not ns.Data.attach(db, { hideForever = vanilla, era = vanilla, external = questie }) then
        return
    end
    worker = coroutine.create(function()
        work(db)
    end)
    frame = frame or CreateFrame("Frame")
    frame:SetScript("OnUpdate", function()
        if Loader.step() then
            frame:SetScript("OnUpdate", nil)
        end
    end)
end

Loader:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    Loader:UnregisterEvent("PLAYER_ENTERING_WORLD")
    ns.Compat.LoadAddOn(DATA_ADDON)
end)
