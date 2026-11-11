-- CONTRAT
-- Lit en jeu les stats des objets estimés (Data.item confidence 1) et les garde dans
-- StuffPlannerDB.items. Charger après Compat.lua, Engine/StatParser.lua, Data/Loader.lua.
--   ns.ItemProbe.RATE -> 5 lectures par seconde ; BATCH -> 25 objets lus entre deux SP_ITEMS_CONFIRMED
--   ns.ItemProbe.records() -> {{kind="item", itemID, stats}...} triés par itemID (pour l'export)
--   ns.ItemProbe.progress() -> confirmed, remaining ; remaining nil tant que la liste n'est pas faite
--   ns.ItemProbe.step() -> une étape (minuterie ou tests) ; true quand il n'y a plus rien à lire
-- Sauvegarde {schema = 1, build, stats = {[itemID] = {[StatKey] = value}}} ; build de GetBuildInfo
--   différent : tout est oublié (stats possiblement changées), les objets seront relus.
-- SP_DATA_READY : stats gardées passées à Data.observeItem, puis liste des objets confidence 1 non
--   lus, par tranches de Loader.SLICE_MS, puis une lecture toutes les 1/RATE s.
-- Lecture d'un objet en cache (Compat.GetItemName connu) : StatParser.merge(fromApi(Compat.GetItemStats),
--   fromLines(lignes d'info-bulle)) ; hors cache : Compat.RequestItemData, relu une fois à
--   GET_ITEM_INFO_RECEIVED(itemID, ok) ; ok faux, toujours hors cache ou sans réponse 10 s après la
--   fin de la liste : abandonné pour la session.
-- Rien en combat ni pendant qu'une info-bulle du jeu est affichée (étape repoussée, réponse remise en fin
--   de liste) : sur Classic Era, chaque objet reçu reconstruit l'info-bulle ouverte et efface ses lignes.
-- SP_ITEMS_CONFIRMED tous les BATCH objets lus et à la fin.

local _, ns = ...

local Compat = ns.Compat
local StatParser = ns.StatParser

local ItemProbe = ns:NewModule("ItemProbe", "AceEvent-3.0")
ns.ItemProbe = ItemProbe

ItemProbe.RATE = 5
ItemProbe.BATCH = 25

local SCHEMA = 1
local ESTIMATED = 1
local GRACE_SECONDS = 10

local store, patterns
local queue, position, waiting, scanner, sliceStart, grace
local unsent = 0

local function build()
    local _, number = GetBuildInfo()
    return number
end

local function loadStore()
    if store then
        return store
    end
    local account = ns.DB.account()
    local saved = account.items
    if type(saved) ~= "table" or saved.schema ~= SCHEMA or saved.build ~= build() then
        saved = { schema = SCHEMA, build = build(), stats = {} }
        account.items = saved
    end
    store = saved
    return store
end

function ItemProbe.records()
    local records = {}
    for itemID, stats in pairs(loadStore().stats) do
        records[#records + 1] = { kind = "item", itemID = itemID, stats = stats }
    end
    table.sort(records, function(a, b)
        return a.itemID < b.itemID
    end)
    return records
end

function ItemProbe.progress()
    local confirmed = 0
    for _ in pairs(loadStore().stats) do
        confirmed = confirmed + 1
    end
    return confirmed, queue and (#queue - position + 1) or nil
end

local function notify(force)
    if unsent > 0 and (force or unsent >= ItemProbe.BATCH) then
        unsent = 0
        ns:Send("SP_ITEMS_CONFIRMED")
    end
end

-- Lit un objet en cache ; false s'il ne l'est pas.
local function read(itemID)
    if not Compat.GetItemName(itemID) then
        return false
    end
    local link = "item:" .. itemID
    patterns = patterns or StatParser.buildPatterns(Compat.GlobalString)
    local stats = StatParser.merge(StatParser.fromApi(Compat.GetItemStats(link)),
        StatParser.fromLines(Compat.GetTooltipLines(link), patterns))
    loadStore().stats[itemID] = stats
    ns.Data.observeItem(itemID, stats)
    unsent = unsent + 1
    notify(false)
    return true
end

local function tick()
    if ns.Loader.clock() - sliceStart >= ns.Loader.SLICE_MS then
        coroutine.yield()
    end
end

local function scan()
    local list, saved = {}, loadStore().stats
    for _, itemID in ipairs(ns.Data.itemIDs()) do
        local item = not saved[itemID] and ns.Data.item(itemID)
        if item and item.confidence == ESTIMATED then
            list[#list + 1] = itemID
        end
        tick()
    end
    queue, position = list, 1
end

function ItemProbe.step()
    if scanner then
        sliceStart = ns.Loader.clock()
        local ok, err = coroutine.resume(scanner)
        if not ok then
            scanner = nil
            geterrorhandler()(err)
            return true
        end
        if coroutine.status(scanner) == "dead" then
            scanner = nil
        end
        return false
    end
    if not queue then
        return true
    end
    local itemID = queue[position]
    if not itemID then
        grace = grace + 1
        if next(waiting) == nil or grace > ItemProbe.RATE * GRACE_SECONDS then
            waiting = {}
            notify(true)
            return true
        end
        return false
    end
    position = position + 1
    if not read(itemID) then
        waiting[itemID] = true
        Compat.RequestItemData(itemID)
    end
    return false
end

local function paused()
    return InCombatLockdown() or (GameTooltip ~= nil and GameTooltip:IsShown())
end

local function schedule()
    local delay = scanner and 0 or 1 / ItemProbe.RATE
    C_Timer.After(delay, function()
        if paused() then
            schedule()
        elseif not ItemProbe.step() then
            schedule()
        end
    end)
end

function ItemProbe.start()
    local saved = loadStore().stats
    for itemID, stats in pairs(saved) do
        ns.Data.observeItem(itemID, stats)
    end
    queue, position, waiting, unsent, grace = nil, 1, {}, 0, 0
    scanner = coroutine.create(scan)
    schedule()
end

ItemProbe:RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, itemID, ok)
    if not (waiting and waiting[itemID]) then
        return
    end
    waiting[itemID] = nil
    if ok == false then
        return
    end
    if paused() then
        queue[#queue + 1] = itemID
    else
        read(itemID)
    end
end)

ns:On("SP_DATA_READY", ItemProbe.start)
