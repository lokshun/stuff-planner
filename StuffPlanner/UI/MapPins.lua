-- CONTRAT
-- Épingles des donneurs de quête qui apportent une amélioration (zone actuelle), carte du monde et
-- minicarte, par HereBeDragons-Pins-2.0. Charger après Chat.lua, DetailPresenter.lua, QuestDetail.lua.
-- Données : Chat.currentZone(MAX_PINS) -> DetailPresenter.pins ; une épingle par quête à son départ (QuestStart).
-- Aspect (ns.PinPresenter.layout, réglage pins.style) : pastille ronde de l'icône du meilleur objet
--   (Compat.CircleTexture, liseré sombre) posée en haut à droite du donneur pour laisser lisible le « ! » /
--   « ? » du jeu ou de Questie ; « center » = ancienne icône carrée centrée. Le cadre placé par
--   HereBeDragons ne prend pas la souris : seule la pastille (bouton enfant) est survolable et cliquable.
--   Anneau vert (couleur de gain) autour de la pastille de la quête qui a un repère (ns.Waypoint.has), seul
--   marqueur du repère sur la carte et la minicarte ; mis à jour sur SP_WAYPOINT_CHANGED et à l'affichage
--   de la carte.
-- Cible du repère sans épingle (première quête d'une suite, Waypoint.current) : épingle de plus, icône de
--   quête disponible ; toutes refaites sur SP_WAYPOINT_CHANGED.
-- Survol : quête, meilleur objet et gain ; clic : fiche (QuestDetail.show) ; Maj+clic : lien de l'objet.
-- Rafraîchies sur SP_RESULTS_UPDATED (Results) ; jamais en combat (reporté).
-- MapPins.focus(target) : ping pulsant au donneur ({mapID, x, y, title?, giver?}), même épingles masquées ;
--   retiré à la fermeture de la carte ; false sans HereBeDragons.
-- /splan pins affiche ou masque (carte du monde et minicarte) ; réglages ns.Options pins.world et
-- pins.minimap, appliqués sur SP_OPTION_CHANGED. Sans la bibliothèque : rien.
-- Taille et décalage : PinPresenter × pins.worldScale (carte) ou pins.minimapScale (minicarte), appliqués aux
--   épingles existantes sur SP_OPTION_CHANGED (échelles, pins.style) ; le ping de MapPins.focus garde sa taille.

local _, ns = ...

local L = ns.L

local MAX_PINS = 100
local PIN_SIZE = 20 -- icône du ping de MapPins.focus
local RIM, RING = 2, 4 -- liseré sombre et anneau du repère : px de plus que l'icône
local UNKNOWN_ICON = 134400
local QUEST_ICON = "Interface\\GossipFrame\\AvailableQuestIcon"
local FOCUS_RING = "Interface\\Cooldown\\star4"
local FOCUS_SIZE = 32
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
    GameTooltip:AddLine(L.FOLLOW_QUEST_HINT, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function hideTooltip()
    GameTooltip:Hide()
end

local function onClick(pin)
    local data = pin.data
    if IsShiftKeyDown() and data and data.itemID and ns.Compat.InsertChatLink(data.itemID) then
        return
    end
    ns.QuestDetail.show(data and data.questID)
end

local function layoutOf(kind)
    local scale = ns.Options.get(kind == "world" and "pins.worldScale" or "pins.minimapScale")
    return ns.PinPresenter.layout(kind, ns.Options.get("pins.style"), scale)
end

-- Pastille, liseré (pastille ronde seulement) et anneau placés selon PinPresenter.
local function apply(pin, kind)
    local layout = layoutOf(kind)
    local size = layout.size
    pin:SetSize(size, size)
    local badge = pin.badge
    badge:ClearAllPoints()
    badge:SetPoint("CENTER", pin, "CENTER", layout.x, layout.y)
    badge:SetSize(size, size)
    badge.rim:SetSize(size + RIM, size + RIM)
    badge.rim:SetShown(layout.round)
    badge.ring:SetSize(size + RING, size + RING)
end

local function resize(kind)
    for _, pin in ipairs(pool[kind]) do
        apply(pin, kind)
    end
end

local function circle(badge, layer, sublevel)
    local texture = ns.Compat.CircleTexture(badge, layer)
    texture:SetDrawLayer(layer, sublevel)
    texture:SetPoint("CENTER")
    return texture
end

local function pinFrame(kind, index)
    local list = pool[kind]
    if not list[index] then
        local pin = CreateFrame("Frame", nil, UIParent)
        pin:EnableMouse(false)
        local badge = CreateFrame("Button", nil, pin)
        badge.ring = circle(badge, "BACKGROUND", 0)
        local gain = ns.Theme.colors.gain
        badge.ring:SetColorTexture(gain.r, gain.g, gain.b, 1)
        badge.rim = circle(badge, "BACKGROUND", 1)
        badge.rim:SetColorTexture(0, 0, 0, 0.85)
        badge.icon = circle(badge, "ARTWORK", 0)
        badge.icon:SetAllPoints()
        badge.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
        badge:SetScript("OnEnter", showTooltip)
        badge:SetScript("OnLeave", hideTooltip)
        badge:SetScript("OnClick", onClick)
        pin.badge = badge
        apply(pin, kind)
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
            local questID = pin.badge.data and pin.badge.data.questID
            pin.badge.ring:SetShown(questID ~= nil and ns.Waypoint.has(questID))
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
        world.badge.data, minimap.badge.data = data, data
        world.badge.icon:SetTexture(icon)
        minimap.badge.icon:SetTexture(icon)
        if onWorld then
            pins:AddWorldMapIconMap(MapPins, world, data.mapID, data.x, data.y, SHOW_PARENT)
        end
        if onMinimap then
            pins:AddMinimapIconMap(MapPins, minimap, data.mapID, data.x, data.y, false, false)
        end
    end
    MapPins.updateMarkers()
end

-- Ping de « Voir sur la carte » : anneau pulsant au donneur, indépendant des réglages des épingles,
-- retiré à la fermeture de la carte ou au ping suivant.
local focusRef, focusPin = {}, nil

local function createFocusPin()
    local pin = CreateFrame("Frame", nil, UIParent)
    pin:SetSize(FOCUS_SIZE, FOCUS_SIZE)
    pin:EnableMouse(true)
    local color = ns.Theme.colors.gain
    local ring = pin:CreateTexture(nil, "BACKGROUND")
    ring:SetTexture(FOCUS_RING)
    ring:SetBlendMode("ADD")
    ring:SetVertexColor(color.r, color.g, color.b)
    ring:SetPoint("CENTER")
    ring:SetSize(FOCUS_SIZE, FOCUS_SIZE)
    local icon = pin:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(QUEST_ICON)
    icon:SetPoint("CENTER")
    icon:SetSize(PIN_SIZE, PIN_SIZE)
    local pulse = ring:CreateAnimationGroup()
    pulse:SetLooping("REPEAT")
    local grow = pulse:CreateAnimation("Scale")
    grow:SetScale(2.5, 2.5)
    grow:SetDuration(1)
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(1)
    pin.pulse = pulse
    pin:SetScript("OnEnter", function(self)
        local target = self.target
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(target.giver or target.title, 1, 0.82, 0)
        if target.giver and target.title then
            GameTooltip:AddLine(target.title, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", hideTooltip)
    WorldMapFrame:HookScript("OnHide", function()
        local pins = library()
        if pins then
            pins:RemoveAllWorldMapIcons(focusRef)
        end
        pin.pulse:Stop()
    end)
    return pin
end

-- target = {mapID, x, y (0–1), title?, giver?} ; false sans bibliothèque ni carte.
function MapPins.focus(target)
    local pins = library()
    if not pins or not WorldMapFrame or not (target and target.mapID and target.x and target.y) then
        return false
    end
    focusPin = focusPin or createFocusPin()
    focusPin.target = target
    pins:RemoveAllWorldMapIcons(focusRef)
    pins:AddWorldMapIconMap(focusRef, focusPin, target.mapID, target.x, target.y, SHOW_PARENT)
    focusPin:SetFrameLevel(focusPin:GetFrameLevel() + 10)
    focusPin.pulse:Play()
    return true
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
    elseif key == "pins.worldScale" or key == "pins.minimapScale" or key == "pins.style" then
        ns:RunOutOfCombat(function()
            resize("world")
            resize("minimap")
        end)
    end
end)

ns:RegisterCommand("pins", toggle, "PINS_COMMAND_HELP")
ns:On("SP_RESULTS_UPDATED", MapPins.refresh)
ns:On("SP_WAYPOINT_CHANGED", MapPins.refresh)
