-- CONTRAT
-- Observations locales (collecteur, ItemProbe) : couche la plus haute de ns.Data. Pur : aucune API WoW.
-- Charger avant Data/DataProvider.lua, qui l'appelle (reset à chaque Data.attach).
--   ns.Observations.reset() -> oublie tout
--   add(record, questKnown) -> bool : vrai si l'observation de la quête record.questID a changé ;
--     PNJ (npcID et mapID) toujours gardé ; quête gardée si questKnown (connue de la base) et kind
--     "detail", "complete", "log" ou "peer" (reçue d'un autre joueur, Integrations/Share.lua) ;
--     rang : "peer" < "log" < "detail" = "complete" ; une observation ne remplace pas une de rang supérieur,
--     "log" et "peer" pas une de même rang.
--   kind(questID) -> kind de l'observation gardée | nil
--   npc(id) -> {id, mapID, x, y} | nil ; mapID(questID) -> carte observée | nil
--   applyQuest(quest) -> record | nil : copie level, mapID, rewards, choices observés (non nil) dans quest
--   setItem(id, stats) ; applyItem(item) -> bool : item.stats remplacé par les stats lues en jeu

local _, ns = ...

local Observations = {}
ns.Observations = Observations

local FIELDS = { "level", "mapID", "rewards", "choices" }
local RANK = { peer = 1, log = 2, detail = 3, complete = 3 }

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
    local rank = RANK[record.kind]
    if not (id and questKnown and rank) then
        return false
    end
    local kept = quests[id]
    local keptRank = kept and RANK[kept.kind] or 0
    if keptRank > rank or (keptRank == rank and rank < RANK.detail) then
        return false
    end
    quests[id] = record
    return true
end

function Observations.npc(id)
    return npcs[id]
end

function Observations.kind(questID)
    local record = quests[questID]
    return record and record.kind or nil
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
