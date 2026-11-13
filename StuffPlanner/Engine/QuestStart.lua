-- CONTRAT
-- Lieu où prendre une quête (T17.6, schéma : startKind, startID, startMap, startX, startY). Pur : aucun appel à
-- l'API WoW. Charger avant Engine/FollowSteps.lua et Engine/Effort.lua.
--   ns.QuestStart.KINDS[startKind] -> "npc" | "object" | "item" | "instance" | "zone" (tools/schema.py START_KINDS)
--   ns.QuestStart.of(quest, data) -> start | nil
--     start = {kind, id, npcID, mapID, x, y, exact} : kind de quest.startKind ("npc" si nil), id = quest.startID ;
--     quest.starter placé (data.npc avec mapID, x, y) : npcID et sa position, exact = true (donneur, ou
--     porteur de l'objet de départ) ; sinon startMap (x, y = startX, startY, exact s'ils sont connus) ;
--     nil sans l'un ni l'autre
--   ns.QuestStart.point(start) -> x, y : la position, sinon le centre de la carte (repère)

local _, ns = ...

local QuestStart = {}
ns.QuestStart = QuestStart

QuestStart.KINDS = { "npc", "object", "item", "instance", "zone" }
local CENTER = 0.5

function QuestStart.of(quest, data)
    local kind = QuestStart.KINDS[quest.startKind] or "npc"
    local npc = quest.starter and data.npc and data.npc(quest.starter)
    if npc and npc.mapID and npc.x and npc.y then
        return { kind = kind, id = quest.startID, npcID = quest.starter, mapID = npc.mapID, x = npc.x, y = npc.y,
            exact = true }
    end
    if not quest.startMap then
        return nil
    end
    local exact = quest.startX ~= nil and quest.startY ~= nil
    return { kind = kind, id = quest.startID, mapID = quest.startMap, x = exact and quest.startX or nil,
        y = exact and quest.startY or nil, exact = exact }
end

function QuestStart.point(start)
    if start.x and start.y then
        return start.x, start.y
    end
    return CENTER, CENTER
end
