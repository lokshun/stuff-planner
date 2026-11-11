-- CONTRAT
-- Flèche intégrée vers un repère, utilisée quand TomTom n'est pas chargé (Integrations/TomTom.lua).
-- Charger après Bearing.lua, Distance.lua, Theme.lua, CompatMap.lua et CompatTravel.lua, avant
-- Integrations/TomTom.lua.
--   ns.Arrow.show(key, mapID, x, y, title [, giver]) -> bool ; x, y en 0–1 ; giver : nom du donneur,
--     sous le titre ; false si la flèche est coupée
--     (arrow.enabled, /splan arrow), si HereBeDragons ou la carte manque ; remplace la cible précédente
--   ns.Arrow.hide(key) -> cache la flèche si sa cible est key
--   ns.Arrow.resetPosition() -> position par défaut
-- Position du joueur et vecteur : HereBeDragons-2.0 ; orientation : ns.Compat.PlayerFacing (nil :
-- flèche masquée, distance seule). Arrivé sous arrow.arrival : flèche invisible (cadre gardé, transparent et
-- sans souris, pour continuer à suivre), marque gardée ; réapparaît au-delà de arrow.arrival + REAPPEAR_YARDS
-- (Bearing.arrived) ou sur une autre carte.
-- Réglages ns.Options : arrow.enabled, arrow.scale, arrow.arrival, arrow.color ("direction" : vert
-- devant, rouge derrière ; "gold" : couleur du thème), arrow.locked (pas de glisser).
-- Zone de la cible si le joueur est ailleurs : L.ARROW_ZONE (nom, zones traversées : ns.Distance.hops),
-- L.ARROW_ZONE_FAR sans chemin ; en vol (Compat.OnTaxi) : flèche masquée, L.ARROW_ON_TAXI.
-- Rafraîchie à 10 Hz, figée en combat. Clic gauche maintenu : déplacer ; clic droit : cacher.
-- Sauvegarde : StuffPlannerDB.ui.arrow = {point, relativePoint, x, y} (+ réglages ci-dessus).
-- Texture : Media/Arrow3D.tga (tools/gen_arrow.py), 16 x 8 vues 3D ; image et teinte par ns.Bearing.

local _, ns = ...

local L = ns.L

local Arrow = {}
ns.Arrow = Arrow

local INTERVAL = 0.1
local ARROW_SIZE = 32
local WIDTH = 160
local TEXTURE = "Interface\\AddOns\\StuffPlanner\\Media\\Arrow3D"
local COLS, ROWS = 16, 8 -- planche de Media/Arrow3D.tga

local frame, needle, titleText, giverText, distanceText, zoneText
local target
local elapsed = 0

local function settings()
    StuffPlannerDB = StuffPlannerDB or {}
    StuffPlannerDB.ui = StuffPlannerDB.ui or {}
    StuffPlannerDB.ui.arrow = StuffPlannerDB.ui.arrow or {}
    return StuffPlannerDB.ui.arrow
end

local function hbd()
    return LibStub and LibStub("HereBeDragons-2.0", true)
end

-- Invisible sans être caché : OnUpdate continue (un cadre caché ne le reçoit plus).
local function setVisible(visible)
    frame:SetAlpha(visible and 1 or 0)
    frame:EnableMouse(visible)
end

local function close()
    target = nil
    if frame then
        frame:Hide()
    end
end

local function zoneLine()
    local playerMap = ns.Compat.PlayerMapPosition()
    if not playerMap or playerMap == target.mapID then
        return ""
    end
    if target.zoneFrom ~= playerMap then
        local hops = ns.Distance.hops(playerMap, target.mapID, ns.Data)
        local name = ns.Names.zone(target.mapID)
        target.zoneFrom = playerMap
        target.zoneLine = hops and L.ARROW_ZONE:format(name, hops) or L.ARROW_ZONE_FAR:format(name)
    end
    return target.zoneLine
end

local function update()
    zoneText:SetText(zoneLine())
    if ns.Compat.OnTaxi() then
        needle:Hide()
        distanceText:SetText(L.ARROW_ON_TAXI)
        return
    end
    local lib = hbd()
    local px, py, instance = lib:GetPlayerWorldPosition()
    if not px or instance ~= target.instance then
        if target.arrived then
            target.arrived = false
            setVisible(true)
        end
        needle:Hide()
        distanceText:SetText(L.ARROW_ELSEWHERE)
        return
    end
    local angle, distance = lib:GetWorldVector(instance, px, py, target.wx, target.wy)
    local arrival = ns.Options.get("arrow.arrival")
    local arrived = ns.Bearing.arrived(distance, arrival, target.arrived)
    if arrived ~= (target.arrived == true) then
        target.arrived = arrived
        setVisible(not arrived)
    end
    if arrived then
        return
    end
    local view = ns.Bearing.compute(angle, distance, ns.Compat.PlayerFacing(), arrival)
    if view then
        needle:SetTexCoord(ns.Bearing.texCoords(ns.Bearing.frame(view.rotation, COLS * ROWS), COLS, ROWS))
        if ns.Options.get("arrow.color") == "gold" then
            local gold = ns.Theme.colors.border
            needle:SetVertexColor(gold.r, gold.g, gold.b)
        else
            needle:SetVertexColor(ns.Bearing.color(view.rotation))
        end
    end
    needle:SetShown(view ~= nil)
    distanceText:SetText(distance and L.ARROW_DISTANCE:format(ns.Format.number(distance)) or "")
end

local function onUpdate(_, delta)
    elapsed = elapsed + delta
    if elapsed < INTERVAL or not target or InCombatLockdown() then
        return
    end
    elapsed = 0
    update()
end

local function stopMoving()
    frame:StopMovingOrSizing()
    local point, _, relativePoint, x, y = frame:GetPoint()
    local saved = settings()
    saved.point, saved.relativePoint, saved.x, saved.y = point, relativePoint, x, y
end

local function restorePosition()
    local saved = settings()
    frame:ClearAllPoints()
    if saved.point then
        frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    end
end

local function create()
    local theme = ns.Theme
    frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(WIDTH, ARROW_SIZE + 64)
    frame:SetFrameStrata("LOW")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        if not ns.Options.get("arrow.locked") then
            frame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", stopMoving)
    frame:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            close()
        end
    end)
    frame:SetScript("OnUpdate", onUpdate)
    needle = frame:CreateTexture(nil, "ARTWORK")
    needle:SetTexture(TEXTURE)
    needle:SetSize(ARROW_SIZE, ARROW_SIZE)
    needle:SetPoint("TOP")
    titleText = frame:CreateFontString(nil, "OVERLAY", theme.fonts.header)
    titleText:SetPoint("TOP", needle, "BOTTOM", 0, -2)
    titleText:SetWidth(WIDTH)
    titleText:SetWordWrap(false)
    giverText = frame:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    giverText:SetPoint("TOP", titleText, "BOTTOM", 0, -2)
    giverText:SetWidth(WIDTH)
    giverText:SetWordWrap(false)
    distanceText = frame:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    distanceText:SetPoint("TOP", giverText, "BOTTOM", 0, -2)
    zoneText = frame:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    zoneText:SetPoint("TOP", distanceText, "BOTTOM", 0, -2)
    zoneText:SetWidth(WIDTH)
    zoneText:SetWordWrap(false)
    restorePosition()
    frame:SetScale(ns.Options.get("arrow.scale"))
    frame:Hide()
end

function Arrow.show(key, mapID, x, y, title, giver)
    local lib = hbd()
    if not ns.Options.get("arrow.enabled") or not lib then
        return false
    end
    local wx, wy, instance = lib:GetWorldCoordinatesFromZone(x, y, mapID)
    if not wx then
        return false
    end
    if not frame then
        create()
    end
    target = { key = key, wx = wx, wy = wy, instance = instance, mapID = mapID }
    titleText:SetText(title or "")
    giverText:SetText(giver or "")
    distanceText:SetText("")
    zoneText:SetText("")
    needle:Hide()
    elapsed = INTERVAL
    setVisible(true)
    frame:Show()
    return true
end

function Arrow.hide(key)
    if target and target.key == key then
        close()
    end
end

function Arrow.resetPosition()
    local saved = settings()
    saved.point, saved.relativePoint, saved.x, saved.y = nil, nil, nil, nil
    if frame then
        restorePosition()
    end
end

local function toggle()
    print(ns.Options.toggle("arrow.enabled") and L.ARROW_ON or L.ARROW_OFF)
end

ns:On("SP_OPTION_CHANGED", function(key, value)
    if key == "arrow.enabled" and not value then
        close()
    elseif key == "arrow.scale" and frame then
        frame:SetScale(value)
    end
end)

ns:RegisterCommand("arrow", toggle, "ARROW_COMMAND_HELP")
