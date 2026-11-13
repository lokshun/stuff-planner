-- CONTRAT
-- Gains de la zone actuelle et de ses voisines tenus à jour par Recompute, partagés par l'onglet
-- Zone, le mini-suivi, les épingles et /splan best. Charger après Engine/Recompute.lua,
-- Data/Loader.lua et Profiles/Manager.lua.
--   ns.Results.player() -> instantané partagé, pris à la demande s'il manque ; nil si Data
--     n'est pas prête ou sans profil actif
--   ns.Results.delta(itemID) -> Scoring.delta pour cet instantané et le profil actif, gardé ;
--     nil si player() l'est
--   ns.Results.busy() -> vrai pendant le calcul de la portée
--   ns.Results.scope() -> {itemID...} de la dernière portée (zone et voisines) ; {} avant le premier calcul
--   ns.Results.secondaryDelta(itemID) -> Scoring.delta pour le même instantané et Profiles.secondary() ;
--     calculé à la demande seulement (aucun calcul de portée), gardé ; nil sans secondaire ou si player()
--     l'est. SP_SECONDARY_CHANGED : oublié, puis SP_RESULTS_UPDATED (hors calcul en cours).
-- SP_PLAYER_CHANGED : nouvel instantané, seuls les objets touchés sont oubliés (Recompute) ;
-- SP_PROFILE_CHANGED, SP_DATA_READY, SP_ITEMS_CONFIRMED (stats lues en jeu), SP_QUEST_OBSERVED
-- (récompenses observées) : tout est oublié.
-- Puis calcul des récompenses de la zone et des voisines (Data.neighbors) par coroutine,
-- Loader.SLICE_MS par image, en pause en combat ; enfin SP_RESULTS_UPDATED,
-- émis tout de suite quand rien n'est calculable.
-- SP_QUEST_LOG_CHANGED : gains inchangés, SP_RESULTS_UPDATED tout de suite (hors calcul en cours)
-- pour que les listes relisent l'état des quêtes (journal, faites).

local _, ns = ...

local Results = {}
ns.Results = Results

local COMBAT_DELAY = 0.5

local store = ns.Recompute.new()
local secondaryStore = ns.Recompute.new()
local current, job, sliceStart
local lastScope = {}

local function activeProfile()
    return ns.Data.ready() and ns.Profiles.active() or nil
end

-- Instantané courant ; force : nouvel instantané même s'il en existe un.
local function snapshot(force)
    local profile = activeProfile()
    if not profile then
        current = nil
        return nil
    end
    if force or not current or store.profile ~= profile then
        current = force and ns.Player.snapshot() or current or ns.Player.snapshot()
        store:apply(current, profile, ns.Data)
    end
    return current
end

function Results.player()
    return snapshot(false)
end

function Results.delta(itemID)
    if not snapshot(false) then
        return nil
    end
    return store:delta(itemID)
end

function Results.secondaryDelta(itemID)
    local player = snapshot(false)
    local profile = player and ns.Profiles.secondary()
    if not profile then
        return nil
    end
    if secondaryStore.player ~= player or secondaryStore.profile ~= profile then
        secondaryStore:apply(player, profile, ns.Data)
    end
    return secondaryStore:delta(itemID)
end

function Results.scope()
    return lastScope
end

function Results.busy()
    return job ~= nil
end

local function tick()
    if ns.Loader.clock() - sliceStart >= ns.Loader.SLICE_MS then
        coroutine.yield()
    end
end

local function resume()
    if not job then
        return
    end
    if InCombatLockdown() then
        C_Timer.After(COMBAT_DELAY, resume)
        return
    end
    sliceStart = ns.Loader.clock()
    local ok, err = coroutine.resume(job)
    if ns.Perf then
        ns.Perf.slice("zone", ns.Loader.clock() - sliceStart, not ok or coroutine.status(job) == "dead")
    end
    if not ok then
        job = nil
        geterrorhandler()(err)
    elseif coroutine.status(job) == "dead" then
        job = nil
        ns:Send("SP_RESULTS_UPDATED")
    else
        C_Timer.After(0, resume)
    end
end

local function scope(player)
    local mapIDs = { player.mapID }
    for _, mapID in ipairs(player.mapID and ns.Data.neighbors(player.mapID) or {}) do
        mapIDs[#mapIDs + 1] = mapID
    end
    return ns.Recompute.zoneItems(mapIDs, ns.Data)
end

local function start()
    local player = snapshot(true)
    if not player then
        job = nil
        ns:Send("SP_RESULTS_UPDATED")
        return
    end
    local itemIDs = scope(player)
    lastScope = itemIDs
    store:keep(itemIDs)
    local idle = job == nil
    job = coroutine.create(function()
        store:fill(itemIDs, tick)
    end)
    if idle then
        C_Timer.After(0, resume)
    end
end

local function restart()
    ns:RunOutOfCombat(function()
        store:reset()
        secondaryStore:reset()
        start()
    end)
end

ns:On("SP_PLAYER_CHANGED", function()
    ns:RunOutOfCombat(start)
end)
ns:On("SP_PROFILE_CHANGED", restart)
ns:On("SP_DATA_READY", restart)
ns:On("SP_ITEMS_CONFIRMED", restart)
ns:On("SP_QUEST_OBSERVED", restart)
ns:On("SP_SECONDARY_CHANGED", function()
    secondaryStore:reset()
    if not Results.busy() then
        ns:Send("SP_RESULTS_UPDATED")
    end
end)
ns:On("SP_QUEST_LOG_CHANGED", function()
    if not Results.busy() then
        ns:Send("SP_RESULTS_UPDATED")
    end
end)
