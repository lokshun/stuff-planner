-- CONTRAT
-- Textes du départ d'une quête (T17.6, Engine/QuestStart.lua). Pur : noms par ns.Names, nombres par ns.Format.
--   ns.StartPresenter.label(kind, id, npcID, mapID) -> nom du départ | nil : PNJ (npc, ou npcID sans kind),
--     objet du monde, objet de sac, donjon (id), zone (mapID)
--   ns.StartPresenter.stepName(step) -> nom d'une étape de suivi (FollowSteps) : prise = label du départ, rendu =
--     PNJ | nil
--   ns.StartPresenter.text(start) -> texte de la fiche ; start = QuestStart.of | nil :
--     npc : L.DETAIL_GIVER (nom, zone, x, y) ; object : L.START_OBJECT ; item : L.START_ITEM_DROP (porteur placé),
--     sinon L.START_ITEM ; instance : L.START_INSTANCE (donjon, zone de l'entrée) ; zone : L.START_ZONE ;
--     lieu = L.START_PLACE (zone, x, y) si exact, sinon la zone ; nil : L.DETAIL_NO_GIVER

local _, ns = ...

local L = ns.L

local StartPresenter = {}
ns.StartPresenter = StartPresenter

local function coord(value)
    return ns.Format.number(value * 100, nil, 1)
end

local LABELS = {
    object = function(id) return ns.Names.object(id) end,
    item = function(id) return ns.Names.item(id) end,
    instance = function(id) return ns.Names.instance(id) end,
}

function StartPresenter.label(kind, id, npcID, mapID)
    if LABELS[kind] and id then
        return LABELS[kind](id)
    elseif (kind == nil or kind == "npc") and npcID then
        return ns.Names.npc(npcID)
    elseif kind == "zone" and mapID then
        return ns.Names.zone(mapID)
    end
    return nil
end

function StartPresenter.stepName(step)
    if step.kind == "pickup" then
        return StartPresenter.label(step.startKind, step.startID, step.npcID, step.mapID)
    end
    return step.npcID and ns.Names.npc(step.npcID) or nil
end

local function place(start)
    local zone = ns.Names.zone(start.mapID)
    return start.exact and L.START_PLACE:format(zone, coord(start.x), coord(start.y)) or zone
end

function StartPresenter.text(start)
    if not start then
        return L.DETAIL_NO_GIVER
    end
    local kind = start.kind
    if kind == "npc" and start.npcID then
        return L.DETAIL_GIVER:format(ns.Names.npc(start.npcID), ns.Names.zone(start.mapID), coord(start.x),
            coord(start.y))
    elseif kind == "object" and start.id then
        return L.START_OBJECT:format(ns.Names.object(start.id), place(start))
    elseif kind == "item" and start.id then
        if start.npcID then
            return L.START_ITEM_DROP:format(ns.Names.item(start.id), ns.Names.npc(start.npcID), place(start))
        end
        return L.START_ITEM:format(ns.Names.item(start.id), place(start))
    elseif kind == "instance" and start.id then
        return L.START_INSTANCE:format(ns.Names.instance(start.id), ns.Names.zone(start.mapID))
    end
    return L.START_ZONE:format(ns.Names.zone(start.mapID))
end
