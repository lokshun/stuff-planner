-- CONTRAT
-- Observations locales (collecteur, ItemProbe) : couche la plus haute de ns.Data. Pur : aucune API WoW.
-- Charger avant Data/DataProvider.lua, qui l'appelle (reset à chaque Data.attach).
--   ns.Observations.reset() -> oublie tout
--   add(record, questKnown) -> bool : vrai si l'observation ou le donneur de la quête record.questID a changé ;
--     PNJ (npcID et mapID) gardé, sauf position "peer" d'un PNJ déjà placé ; quête gardée si questKnown et kind
--     "detail", "complete", "log" ou "peer" (reçue d'un autre joueur, Integrations/Share.lua) ;
--     rang : "peer" < "log" < "detail" = "complete" ; une observation ne remplace pas une de rang supérieur,
--     "log" et "peer" pas une de même rang.
--     Donneur (questKnown, kind "detail" ou "peer", npcID) gardé à part du rang : "detail" remplace tout,
--     "peer" seulement un autre "peer".
--   kind(questID) -> kind de l'observation gardée | nil ; starter(questID) -> npcID du donneur observé | nil
--   npc(id) -> {id, mapID, x, y} | nil ; mapID(questID) -> carte observée | nil
--   applyQuest(quest) -> record | nil : copie level, mapID, rewards, choices observés (non nil) dans quest ;
--     donneur : quest.starter, startKind = 1 (npc), startID = nil ; celui d'un "peer" ne remplace pas quest.starter
--   setItem(id, stats) ; applyItem(item) -> bool : item.stats remplacé par les stats lues en jeu

local _, ns = ...

local Observations = {}
ns.Observations = Observations

local FIELDS = { "level", "mapID", "rewards", "choices" }
local RANK = { peer = 1, log = 2, detail = 3, complete = 3 }
local GIVER_KINDS = { detail = true, peer = true }
local NPC_START = 1

local quests, items, npcs, starters

function Observations.reset()
    quests, items, npcs, starters = {}, {}, {}, {}
end
Observations.reset()

local function addStarter(id, record)
    local kept = starters[id]
    if not GIVER_KINDS[record.kind] or not record.npcID
        or (kept and (kept.npcID == record.npcID or (kept.kind == "detail" and record.kind == "peer"))) then
        return false
    end
    starters[id] = { npcID = record.npcID, kind = record.kind }
    return true
end

function Observations.add(record, questKnown)
    local npcID = record.npcID
    if npcID and record.mapID and not (record.kind == "peer" and npcs[npcID]) then
        npcs[npcID] = { id = npcID, mapID = record.mapID, x = record.x, y = record.y }
    end
    local id = record.questID
    local rank = RANK[record.kind]
    if not (id and questKnown and rank) then
        return false
    end
    local giverChanged = addStarter(id, record)
    local kept = quests[id]
    local keptRank = kept and RANK[kept.kind] or 0
    if keptRank > rank or (keptRank == rank and rank < RANK.detail) then
        return giverChanged
    end
    quests[id] = record
    return true
end

function Observations.npc(id)
    return npcs[id]
end

function Observations.starter(questID)
    local giver = starters[questID]
    return giver and giver.npcID or nil
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
    local giver = starters[quest.id]
    if giver and not (giver.kind == "peer" and quest.starter) then
        quest.starter, quest.startKind, quest.startID = giver.npcID, NPC_START, nil
    end
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
