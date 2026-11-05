-- CONTRAT
-- Épingles des donneurs de quête qui apportent une amélioration (zone actuelle), carte du monde et
-- minicarte, par HereBeDragons-Pins-2.0. Charger après Chat.lua, DetailPresenter.lua, QuestDetail.lua.
-- Données : Chat.currentZone(MAX_PINS) -> DetailPresenter.pins ; une épingle par quête au donneur placé.
-- Aspect : icône du meilleur objet ; contour vert (4 traits, couleur de gain) sur l'épingle de la quête
--   qui a un repère (ns.Waypoint.has), seul marqueur du repère sur la carte et la minicarte.
-- Contours mis à jour sur SP_WAYPOINT_CHANGED et à chaque affichage de la carte.
-- Cible du repère sans épingle (première quête d'une suite, Waypoint.current) : épingle de plus, icône de
--   quête disponible ; toutes refaites sur SP_WAYPOINT_CHANGED.
-- Survol : quête, meilleur objet et gain ; clic : fiche (QuestDetail.show) ; Maj+clic : repère.
-- Rafraîchies sur SP_RESULTS_UPDATED (Results) ; jamais en combat (reporté).
-- /splan pins affiche ou masque (carte du monde et minicarte) ; réglages ns.Options pins.world et
-- pins.minimap, appliqués sur SP_OPTION_CHANGED. Sans la bibliothèque : rien.

local _, ns = ...

local L = ns.L

local MAX_PINS = 100
local PIN_SIZE = 20
local MINIMAP_SIZE = 14
local UNKNOWN_ICON = 134400
local QUEST_ICON = "Interface\\GossipFrame\\AvailableQuestIcon"
local ICON_CROP = 0.08
local SHOW_PARENT = 1 -- HBD_PINS_WORLDMAP_SHOW_PARENT

local MapPins = {}
ns.MapPins = MapPins

local pool = { world = {}, minimap = {} }
local combatPending, mapHooked = false, false

local function library()
    return LibStub and LibStub("HereBeDragons-Pins-2.0", true)
end

local function showTooltip(pin)
    local data = pin.data
    if not data then
        return
    end
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:AddLine(ns.Names.quest(data.questID), 1, 0.82, 0)
    if data.itemID then
        local row = ns.RowPresenter.present({ itemID = data.itemID, delta = data.delta }, ns.Data)
        GameTooltip:AddDoubleLine(row.name, row.gainText, row.nameColor.r, row.nameColor.g, row.nameColor.b,
            row.gainColor.r, row.gainColor.g, row.gainColor.b)
    end
    GameTooltip:AddLine(L.PIN_HINT, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function hideTooltip()
    GameTooltip:Hide()
end

local function onClick(pin)
    local questID = pin.data and pin.data.questID
    if IsShiftKeyDown() then
        ns.QuestDetail.waypoint(questID)
    else
        ns.QuestDetail.show(questID)
    end
end

-- Quatre traits sur les bords du cadre, au-dessus de l'icône ; jamais de fond plein.
local function outline(pin, thickness, color)
    local sides = {
        { "TOPLEFT", "TOPRIGHT", "height" },
        { "BOTTOMLEFT", "BOTTOMRIGHT", "height" },
        { "TOPLEFT", "BOTTOMLEFT", "width" },
        { "TOPRIGHT", "BOTTOMRIGHT", "width" },
    }
    local lines = {}
    for i, side in ipairs(sides) do
        local line = pin:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(color.r, color.g, color.b, 1)
        line:SetPoint(side[1])
        line:SetPoint(side[2])
        if side[3] == "height" then
            line:SetHeight(thickness)
        else
            line:SetWidth(thickness)
        end
        lines[i] = line
    end
    return lines
end

local function pinFrame(kind, index)
    local list = pool[kind]
    if not list[index] then
        local size = kind == "world" and PIN_SIZE or MINIMAP_SIZE
        local pin = CreateFrame("Button", nil, UIParent)
        pin:SetSize(size, size)
        local frameColor = ns.Theme.colors.gain
        pin.icon = pin:CreateTexture(nil, "ARTWORK")
        pin.icon:SetAllPoints()
        pin.outline = outline(pin, kind == "world" and 2 or 1, frameColor)
        pin.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
        pin:SetScript("OnEnter", showTooltip)
        pin:SetScript("OnLeave", hideTooltip)
        pin:SetScript("OnClick", onClick)
        list[index] = pin
    end
    return list[index]
end

local function clear(pins)
    pins:RemoveAllWorldMapIcons(MapPins)
    pins:RemoveAllMinimapIcons(MapPins)
end

-- Contour vert sur les épingles des quêtes à repère.
function MapPins.updateMarkers()
    for _, list in pairs(pool) do
        for _, pin in ipairs(list) do
            local questID = pin.data and pin.data.questID
            local marked = questID ~= nil and ns.Waypoint.has(questID)
            for _, line in ipairs(pin.outline) do
                line:SetShown(marked)
            end
        end
    end
end

function MapPins.refresh()
    local pins = library()
    if not pins then
        return
    end
    if InCombatLockdown() then
        if not combatPending then
            combatPending = true
            ns:RunOutOfCombat(function()
                combatPending = false
                MapPins.refresh()
            end)
        end
        return
    end
    if not mapHooked then
        mapHooked = true
        ns.Compat.HookWorldMap(MapPins.updateMarkers)
    end
    clear(pins)
    local onWorld, onMinimap = ns.Options.get("pins.world"), ns.Options.get("pins.minimap")
    if not onWorld and not onMinimap then
        MapPins.updateMarkers()
        return
    end
    local list = ns.DetailPresenter.pins(ns.Chat.currentZone(MAX_PINS), ns.Data)
    local target = ns.Waypoint.current()
    for _, data in ipairs(list) do
        target = target and data.questID ~= target.key and target or nil
    end
    if target then
        list[#list + 1] = { questID = target.key, mapID = target.mapID, x = target.x, y = target.y }
    end
    for index, data in ipairs(list) do
        local world, minimap = pinFrame("world", index), pinFrame("minimap", index)
        local item = data.itemID and ns.Data.item(data.itemID)
        local icon = data.itemID and (ns.Names.itemIcon(data.itemID, item and item.icon) or UNKNOWN_ICON) or QUEST_ICON
        world.data, minimap.data = data, data
        world.icon:SetTexture(icon)
        minimap.icon:SetTexture(icon)
        if onWorld then
            pins:AddWorldMapIconMap(MapPins, world, data.mapID, data.x, data.y, SHOW_PARENT)
        end
        if onMinimap then
            pins:AddMinimapIconMap(MapPins, minimap, data.mapID, data.x, data.y, false, false)
        end
    end
    MapPins.updateMarkers()
end

local function toggle()
    local shown = not (ns.Options.get("pins.world") or ns.Options.get("pins.minimap"))
    ns.Options.set("pins.world", shown)
    ns.Options.set("pins.minimap", shown)
    print(shown and L.PINS_ON or L.PINS_OFF)
end

ns:On("SP_OPTION_CHANGED", function(key)
    if key == "pins.world" or key == "pins.minimap" then
        MapPins.refresh()
    end
end)

ns:RegisterCommand("pins", toggle, "PINS_COMMAND_HELP")
ns:On("SP_RESULTS_UPDATED", MapPins.refresh)
ns:On("SP_WAYPOINT_CHANGED", MapPins.refresh)
