-- CONTRAT
-- Observations locales (collecteur, ItemProbe) : couche la plus haute de ns.Data. Pur : aucune API WoW.
-- Charger avant Data/DataProvider.lua, qui l'appelle (reset à chaque Data.attach).
--   ns.Observations.reset() -> oublie tout
--   add(record, questKnown) -> bool : vrai si l'observation de la quête record.questID a changé ;
--     PNJ (npcID et mapID) toujours gardé ; quête gardée si questKnown (connue de la base) et kind
--     "detail", "complete" ou "log" ; "log" ne remplace pas une observation déjà gardée.
--   npc(id) -> {id, mapID, x, y} | nil ; mapID(questID) -> carte observée | nil
--   applyQuest(quest) -> record | nil : copie level, mapID, rewards, choices observés (non nil) dans quest
--   setItem(id, stats) ; applyItem(item) -> bool : item.stats remplacé par les stats lues en jeu

local _, ns = ...

local Observations = {}
ns.Observations = Observations

local FIELDS = { "level", "mapID", "rewards", "choices" }
local QUEST_KINDS = { detail = true, complete = true, log = true }

local quests, items, npcs

function Observations.reset()
    quests, items, npcs = {}, {}, {}
end
Observations.reset()

function Observations.add(record, questKnown)
    if record.npcID and record.mapID then
        npcs[record.npcID] = { id = record.npcID, mapID = record.mapID, x = record.x, y = record.y }
    end
    local id = record.questID
    if not (id and questKnown and QUEST_KINDS[record.kind]) or (record.kind == "log" and quests[id]) then
        return false
    end
    quests[id] = record
    return true
end

function Observations.npc(id)
    return npcs[id]
end

function Observations.mapID(questID)
    local record = quests[questID]
    return record and record.mapID or nil
end

function Observations.applyQuest(quest)
    local record = quests[quest.id]
    if not record then
        return nil
    end
    for _, field in ipairs(FIELDS) do
        if record[field] ~= nil then
            quest[field] = record[field]
        end
    end
    return record
end

function Observations.setItem(id, stats)
    items[id] = stats
end

function Observations.applyItem(item)
    local stats = items[item.id]
    if not stats then
        return false
    end
    item.stats = stats
    return true
end
