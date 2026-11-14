-- CONTRAT
-- Repère d'une quête : marque suivie par l'addon (contour vert de l'épingle, MapPins) et, si TomTom est
-- chargé, repère TomTom ; sinon flèche intégrée (ns.Arrow, UI/Arrow.lua) si elle est chargée.
-- Le repère du jeu n'est jamais posé (choix de l'utilisateur : pas de rond vert).
-- Réglage waypoint.preferTomTom (ns.Options) faux : TomTom ignoré, flèche intégrée.
-- Charger après Names.lua et Format.lua.
--   ns.Waypoint.set(mapID, x, y, title [, key [, giver [, npcID]]]) -> "tomtom" | "arrow" | "mark" | "chat" ;
--     x, y en 0–1 ; npcID : PNJ visé (Waypoint.reached) ;
--     giver (nom du donneur) : 2e ligne de la flèche, joint au titre (WAYPOINT_TITLE_GIVER) pour TomTom
--     et la discussion ;
--     un seul repère à la fois : toute pose retire d'abord les marques existantes (TomTom, flèche) ;
--     key (questID) : marque posée ; "arrow" : marque + flèche affichée ;
--     sans key ni TomTom : coordonnées écrites dans la discussion ("chat"), flèche aussi si possible
--   ns.Waypoint.has(key) -> bool : marque présente (repère TomTom effacé dans TomTom : marque oubliée)
--   ns.Waypoint.clear(key) -> retire la marque, le repère TomTom et la flèche de key
--   ns.Waypoint.current() -> {key, mapID, x, y, npcID} de la marque posée (ns.Waypoint.has vrai) | nil
--   ns.Waypoint.reached(npcID) -> bool : PNJ visé atteint, repère retiré en entier (Waypoint.clear : TomTom,
--     flèche, marque des cartes) ; déclenché par
--     GOSSIP_SHOW, QUEST_GREETING, QUEST_DETAIL, QUEST_PROGRESS, QUEST_COMPLETE, PNJ lu par UnitGUID("npc"))
--     repère posé par le suivi (ns.Follow.owns) : gardé, le suivi passe lui-même à l'étape suivante
--   ns.Waypoint.dialogNpc() -> identifiant du PNJ en discussion (UnitGUID("npc"), créature ou véhicule) | nil
--   Message SP_WAYPOINT_CHANGED après chaque pose ou retrait effectif.
-- TomTom : AddWaypoint(mapID, x, y, opts) -> uid, RemoveWaypoint(uid), IsValidWaypoint(uid).
-- Flèche : ns.Arrow.show(key, mapID, x, y, title, giver) -> bool, ns.Arrow.hide(key).

local _, ns = ...

local L = ns.L

local Waypoint = {}
ns.Waypoint = Waypoint

local marks = {} -- [key] = uid TomTom | false
local current -- {key, mapID, x, y} de la dernière marque posée

local function tomtom()
    local addon = _G.TomTom
    if ns.Options and not ns.Options.get("waypoint.preferTomTom") then
        return nil
    end
    if type(addon) == "table" and type(addon.AddWaypoint) == "function" then
        return addon
    end
    return nil
end

function Waypoint.current()
    if current and Waypoint.has(current.key) then
        return current
    end
    return nil
end

local function coord(value)
    return ns.Format.number(value * 100, nil, 1)
end

local function announce()
    if ns.Send then
        ns:Send("SP_WAYPOINT_CHANGED")
    end
end

function Waypoint.has(key)
    local uid = key ~= nil and marks[key]
    if uid == nil then
        return false
    elseif uid == false then
        return true
    end
    local addon = tomtom()
    if addon and (not addon.IsValidWaypoint or addon:IsValidWaypoint(uid)) then
        return true
    end
    marks[key] = nil
    return false
end

local function remove(key)
    if not Waypoint.has(key) then
        return false
    end
    local uid = marks[key]
    if uid then
        tomtom():RemoveWaypoint(uid)
    end
    if ns.Arrow then
        ns.Arrow.hide(key)
    end
    marks[key] = nil
    return true
end

function Waypoint.clear(key)
    if remove(key) then
        announce()
    end
end

local function removeAll()
    local keys = {}
    for key in pairs(marks) do
        keys[#keys + 1] = key
    end
    local removed = false
    for _, key in ipairs(keys) do
        removed = remove(key) or removed
    end
    return removed
end

function Waypoint.set(mapID, x, y, title, key, giver, npcID)
    local fullTitle = giver and L.WAYPOINT_TITLE_GIVER:format(title, giver) or title
    if removeAll() and key == nil then
        announce()
    end
    local addon = tomtom()
    local uid, arrow
    if addon then
        uid = addon:AddWaypoint(mapID, x, y, {
            title = fullTitle,
            from = "StuffPlanner",
            persistent = false,
            minimap = true,
            world = true,
        })
    elseif ns.Arrow then
        arrow = ns.Arrow.show(key, mapID, x, y, title, giver)
    end
    if key ~= nil then
        marks[key] = uid or false
        current = { key = key, mapID = mapID, x = x, y = y, npcID = npcID }
        announce()
    elseif not addon then
        print(L.WAYPOINT_CHAT:format(fullTitle, ns.Names.zone(mapID), coord(x), coord(y)))
        return "chat"
    end
    if addon then
        return "tomtom"
    end
    return arrow and "arrow" or "mark"
end

function Waypoint.reached(npcID)
    local mark = Waypoint.current()
    if npcID == nil or not mark or mark.npcID ~= npcID or (ns.Follow and ns.Follow.owns(mark.key)) then
        return false
    end
    Waypoint.clear(mark.key)
    return true
end

function Waypoint.dialogNpc()
    return ns.Compat.CreatureIDFromGUID(UnitGUID("npc")) -- GUID secret (Forever) : nil
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function()
    Waypoint.reached(Waypoint.dialogNpc())
end)
