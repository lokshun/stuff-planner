-- CONTRAT
-- Observe quêtes et butins et les garde dans StuffPlannerDB.collector. Charger après CompatQuest.lua
-- et Data/CollectorStore.lua (clé de doublon, objets équipables, migration).
--   ns.Collector.schema -> 2 ; ns.Collector.MAX_LOOT_PER_SOURCE -> butins gardés au plus par créature (ou
--     carte, sans créature)
--   ns.Collector.records() -> liste vivante d'observations, ne pas la modifier :
--     {kind, questID, level, npcID, mapID, x, y, choices={itemID...}, rewards={itemID...}}
--     kind : "detail" (QUEST_DETAIL), "complete" (QUEST_COMPLETE), "loot" (LOOT_OPENED, sans questID,
--     ni level, ni choices ; un par créature source), "log" (journal : questID, choices, rewards).
--     level nil sur Classic Era ; npcID nil si la source n'est pas une créature ; listes triées.
-- Butin : objets équipables seulement (CollectorStore.gearOnly) ; butin sans objet équipable ignoré ;
-- au plus MAX_LOOT_PER_SOURCE par source. Schéma 1 : CollectorStore.migrate au chargement.
-- Doublon : même CollectorStore.key.
-- Rien n'est observé en combat. Objet d'une quête pas encore en cache : nouvel essai toutes les
-- RETRY_DELAY s, RETRY_MAX essais au plus, tant que la même quête est affichée.
-- Journal (SP_QUEST_LOG_CHANGED, SP_DATA_READY) : chaque quête confidence 2 du journal est lue une
-- fois par Compat.QuestLogRewards ; objets pas en cache : nouvelle lecture LOG_RETRY_DELAY s plus tard.
--   ns.Collector.addLog(questID, choices, rewards) : même observation "log", lue hors journal (QuestProbe).
-- Base prête (ns.Data.ready()) : une observation qu'elle connaît déjà n'est pas gardée : PNJ connu
-- (Data.npc) ou absent, et quête aux level (si observé), mapID, choices, rewards, starter (dialogue) identiques, ou
-- butin dont chaque objet a une source chez ce PNJ ; une quête confidence 2 (récompenses devinées) est
-- toujours gardée : l'observation la confirme, de même qu'une quête confirmée seulement par un autre
-- joueur (Observations.kind "peer"). Base non prête : tout est gardé.
-- Observation gardée, base prête : transmise à Data.observe (effet immédiat) ; quête : puis
-- SP_QUEST_OBSERVED(questID) (Results et la fiche se rafraîchissent) et Share.queue (partage, si actif).
-- Une sauvegarde d'un schéma plus récent reste intacte : le collecteur est alors inactif.

local _, ns = ...

local Compat = ns.Compat

local Collector = ns:NewModule("Collector", "AceEvent-3.0")
ns.Collector = Collector

local Store = ns.CollectorStore
local SCHEMA = 2
local MAX_LOOT_PER_SOURCE = Store.MAX_LOOT_PER_SOURCE
local COORD_PRECISION = 10000
local GUESSED_QUEST = 2
local RETRY_DELAY, RETRY_MAX = 0.5, 6
local LOG_RETRY_DELAY, LOG_RETRY_MAX = 2, 3

Collector.schema = SCHEMA
Collector.MAX_LOOT_PER_SOURCE = MAX_LOOT_PER_SOURCE

local store
local seen
local lootCount
local logged, logRetries = {}, 0

local function loadStore()
    if store then
        return store
    end
    local account = ns.DB.account()
    local saved = account.collector or { schema = SCHEMA, records = {} }
    account.collector = saved
    if saved.schema and saved.schema > SCHEMA then
        store = { records = {}, inactive = true }
    else
        saved.records = saved.records or {}
        if (saved.schema or 1) < SCHEMA then
            saved.records = Store.migrate(saved.records)
        end
        saved.schema = SCHEMA
        store = saved
    end
    seen, lootCount = {}, {}
    for _, record in ipairs(store.records) do
        seen[Store.key(record)] = true
        if record.kind == "loot" then
            local source = Store.source(record)
            lootCount[source] = (lootCount[source] or 0) + 1
        end
    end
    return store
end

function Collector.records()
    return loadStore().records
end

local function sameItems(observed, known)
    if #observed ~= #(known or {}) then
        return false
    end
    local counts = {}
    for _, id in ipairs(known) do
        counts[id] = (counts[id] or 0) + 1
    end
    for _, id in ipairs(observed) do
        if not counts[id] or counts[id] == 0 then
            return false
        end
        counts[id] = counts[id] - 1
    end
    return true
end

local function knownQuest(Data, record)
    if ns.Observations and ns.Observations.kind(record.questID) == "peer" then
        return false -- la base n'est confirmée que par un autre joueur : garder la nôtre
    end
    local quest = Data.quest(record.questID)
    return quest ~= nil
        and quest.confidence ~= GUESSED_QUEST
        and (record.level == nil or record.level == quest.level)
        and record.mapID == quest.mapID
        and sameItems(record.choices, quest.choices)
        and sameItems(record.rewards, quest.rewards)
        and (record.kind ~= "detail" or record.npcID == nil or record.npcID == quest.starter)
end

local function knownLoot(Data, record)
    if not record.npcID then
        return false
    end
    for _, itemID in ipairs(record.rewards) do
        local found = false
        for _, source in ipairs(Data.sourcesOf(itemID)) do
            found = found or source.npcID == record.npcID
        end
        if not found then
            return false
        end
    end
    return true
end

local function redundant(record)
    local Data = ns.Data
    if not (Data and Data.ready()) then
        return false
    end
    if record.npcID and not Data.npc(record.npcID) then
        return false
    end
    if record.kind == "loot" then
        return knownLoot(Data, record)
    end
    return knownQuest(Data, record)
end

local function add(record)
    local current = loadStore()
    if current.inactive or redundant(record) then
        return
    end
    local key = Store.key(record)
    local source = record.kind == "loot" and Store.source(record)
    if source and (lootCount[source] or 0) >= MAX_LOOT_PER_SOURCE then
        return
    end
    if not seen[key] then
        seen[key] = true
        if source then
            lootCount[source] = (lootCount[source] or 0) + 1
        end
        current.records[#current.records + 1] = record
        local Data = ns.Data
        if Data and Data.ready() then
            Data.observe(record)
            if record.questID then
                ns:Send("SP_QUEST_OBSERVED", record.questID)
                if ns.Share then
                    ns.Share.queue(record)
                end
            end
        end
    end
end

function Collector.addLog(questID, choices, rewards)
    logged[questID] = true
    add({ kind = "log", questID = questID, choices = choices, rewards = rewards })
end

local function npcIDFromGUID(guid)
    local unitType, id = (guid or ""):match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if unitType == "Creature" or unitType == "Vehicle" then
        return tonumber(id)
    end
    return nil
end

local function roundCoord(value)
    return value and math.floor(value * COORD_PRECISION + 0.5) / COORD_PRECISION
end

local function newRecord(kind)
    local mapID, x, y = Compat.PlayerMapPosition()
    return { kind = kind, mapID = mapID, x = roundCoord(x), y = roundCoord(y) }
end

local function readQuestItems(itemType, count)
    local items = {}
    for index = 1, count do
        local link = GetQuestItemLink(itemType, index)
        local id = link and link:match("item:(%d+)")
        if not id then
            return nil
        end
        items[index] = tonumber(id)
    end
    table.sort(items)
    return items
end

local function outOfCombat(observe, ...)
    if not InCombatLockdown() then
        observe(...)
    end
end

local function observeQuest(kind, attempt)
    local questID = GetQuestID()
    if not questID or questID == 0 then
        return
    end
    local choices = readQuestItems("choice", GetNumQuestChoices())
    local rewards = readQuestItems("reward", GetNumQuestRewards())
    if not (choices and rewards) then
        attempt = attempt or 1
        if attempt < RETRY_MAX then
            C_Timer.After(RETRY_DELAY, function()
                if GetQuestID() == questID then
                    outOfCombat(observeQuest, kind, attempt + 1)
                end
            end)
        end
        return
    end
    local record = newRecord(kind)
    record.questID = questID
    record.level = Compat.GetQuestLevel(questID)
    record.npcID = npcIDFromGUID(UnitGUID("npc"))
    record.choices = choices
    record.rewards = rewards
    add(record)
end

local function observeLoot()
    local bySource = {}
    for _, slot in ipairs(Compat.GetLootSlots()) do
        local source = npcIDFromGUID(slot.sourceGUID) or false
        bySource[source] = bySource[source] or {}
        table.insert(bySource[source], slot.itemID)
    end
    for source, items in pairs(bySource) do
        items = Store.gearOnly(items)
        table.sort(items)
        if #items > 0 then
            local record = newRecord("loot")
            record.npcID = source or nil
            record.rewards = items
            add(record)
        end
    end
end

local function observeLog()
    local Data = ns.Data
    if not (Data and Data.ready()) or InCombatLockdown() then
        return
    end
    local missing = false
    for questID in pairs(Compat.QuestLogIDs()) do
        local quest = not logged[questID] and Data.quest(questID)
        if quest and quest.confidence == GUESSED_QUEST then
            local choices, rewards = Compat.QuestLogRewards(questID)
            if choices then
                logged[questID] = true
                add({ kind = "log", questID = questID, choices = choices, rewards = rewards })
            else
                missing = true
            end
        end
    end
    if not missing then
        logRetries = 0
    elseif logRetries < LOG_RETRY_MAX then
        logRetries = logRetries + 1
        C_Timer.After(LOG_RETRY_DELAY, observeLog)
    end
end

Collector:RegisterEvent("QUEST_DETAIL", function()
    outOfCombat(observeQuest, "detail")
end)

Collector:RegisterEvent("QUEST_COMPLETE", function()
    outOfCombat(observeQuest, "complete")
end)

Collector:RegisterEvent("LOOT_OPENED", function()
    outOfCombat(observeLoot)
end)

ns:On("SP_QUEST_LOG_CHANGED", observeLog)
ns:On("SP_DATA_READY", observeLog)
