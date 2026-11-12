-- CONTRAT
-- Fenêtre principale à onglets (ns.Skin). Charger après Core.lua, Compat.lua et Skin.lua, avant les onglets.
--   ns.MainFrame.addTab(key, tab) -> tab = {create(parent) -> frame, refresh()?} ; remplace le
--     panneau d'attente de cet onglet ; clés et ordre fixes : zone, route, gear, profile
--   ns.MainFrame.show([key]), hide(), toggle(), isShown() ; show sans clé : dernier onglet ouvert
--   ns.MainFrame.refresh() -> rafraîchit l'onglet affiché s'il est visible
--   ns.MainFrame.frame() -> cadre de la fenêtre | nil avant le premier affichage (panneaux accolés)
-- Commandes : /splan show (bascule, aussi par le menu des addons), /splan scale <0.6-1.5>.
-- Sauvegarde : StuffPlannerDB.ui = {point, relativePoint, x, y, tab} ; échelle et opacité par ns.Options
-- (window.scale, window.alpha), appliquées sur SP_OPTION_CHANGED. Engrenage : ns.OptionsPanel.open().
--   ns.MainFrame.resetPosition() -> fenêtre recentrée
-- Fermeture par Échap (OnKeyDown, sans nom global) ; cachée en combat, ouverte hors combat seulement.
-- Créée au premier affichage : rien n'est construit tant que le joueur ne l'ouvre pas.
-- Boutons d'onglet réduits (Theme.fitWidths) si les libellés dépassent la largeur : texte tronqué,
-- libellé complet en info-bulle.

local _, ns = ...

local L = ns.L

local MainFrame = {}
ns.MainFrame = MainFrame

local WIDTH, HEIGHT = 460, 520
local TAB_KEYS = { "zone", "route", "gear", "profile" }
local TAB_LABELS = { zone = "TAB_ZONE", route = "TAB_ROUTE", gear = "TAB_GEAR", profile = "TAB_PROFILE" }
local PORTRAIT = ns.ICON -- logo de l'addon
local GEAR_ICON = "Interface\\Icons\\INV_Misc_Gear_01"
local TOP_INSET, SIDE_INSET, BOTTOM_INSET = 60, 12, 12
-- Boutons d'onglet : marge gauche (portrait), marge droite, rembourrage du texte, largeur minimale.
local TAB_LEFT, TAB_RIGHT, TAB_PADDING, TAB_TEXT_INSET, TAB_MIN_WIDTH = 64, 10, 24, 12, 40

local frame
local tabs, panels, buttons = {}, {}, {}
local current

local function settings()
    return ns.DB.account("ui")
end

local function savePosition()
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
        frame:SetPoint("CENTER")
    end
    frame:SetScale(ns.Options.get("window.scale"))
    frame:SetAlpha(ns.Options.get("window.alpha"))
end

local function createGear()
    -- Au-dessus du cadre du modèle (TitleContainer, NineSlice) : sinon caché sur Forever.
    local close = frame.CloseButton
    local gear = CreateFrame("Button", nil, frame)
    gear:SetSize(18, 18)
    gear:SetFrameLevel((close or frame):GetFrameLevel() + 2)
    if close then
        gear:SetPoint("RIGHT", close, "LEFT", -2, 0)
    else
        gear:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -26, -3)
    end
    gear:SetNormalTexture(GEAR_ICON)
    gear:SetHighlightTexture(GEAR_ICON, "ADD")
    gear:SetScript("OnClick", function()
        if ns.OptionsPanel then
            ns.OptionsPanel.open()
        end
    end)
    gear:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.OPTIONS_OPEN)
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", GameTooltip_Hide)
end

local function placeholder(parent)
    local panel = CreateFrame("Frame", nil, parent)
    local text = panel:CreateFontString(nil, "OVERLAY", ns.Theme.fonts.body)
    text:SetPoint("CENTER")
    text:SetText(L.TAB_SOON)
    return panel
end

local function panelFor(key)
    if not panels[key] then
        local tab = tabs[key]
        local panel = tab and tab.create(frame.content) or placeholder(frame.content)
        panel:SetAllPoints(frame.content)
        panels[key] = panel
    end
    return panels[key]
end

local function selectTab(key)
    current = key
    settings().tab = key
    for _, tabKey in ipairs(TAB_KEYS) do
        local active = tabKey == key
        if panels[tabKey] then
            panels[tabKey]:SetShown(active)
        end
        buttons[tabKey]:SetEnabled(not active)
    end
    panelFor(key):Show()
    MainFrame.refresh()
end

local function onKeyDown(self, key)
    local escape = key == "ESCAPE"
    self:SetPropagateKeyboardInput(not escape)
    if escape then
        self:Hide()
    end
end

local function showLabel(button)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(button:GetText())
    GameTooltip:Show()
end

local function fitTabButtons()
    local widths = {}
    for i, key in ipairs(TAB_KEYS) do
        widths[i] = buttons[key]:GetFontString():GetStringWidth() + TAB_PADDING
    end
    local available = WIDTH - TAB_LEFT - TAB_RIGHT
    local fitted, shrunk = ns.Theme.fitWidths(widths, available, ns.Theme.spacing.gap, TAB_MIN_WIDTH)
    for i, key in ipairs(TAB_KEYS) do
        local button = buttons[key]
        button:SetWidth(fitted[i])
        local text = button:GetFontString()
        text:SetWordWrap(false)
        text:SetWidth(shrunk and fitted[i] - TAB_TEXT_INSET or 0)
        button:SetScript("OnEnter", shrunk and fitted[i] < widths[i] and showLabel or nil)
        button:SetScript("OnLeave", shrunk and GameTooltip_Hide or nil)
    end
end

local function createTabButtons()
    local previous
    for _, key in ipairs(TAB_KEYS) do
        local button = ns.Skin.button(frame)
        button:SetText(L[TAB_LABELS[key]])
        button:SetHeight(22)
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", ns.Theme.spacing.gap, 0)
        else
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", TAB_LEFT, -30)
        end
        button:SetScript("OnClick", function()
            selectTab(key)
        end)
        buttons[key], previous = button, button
    end
    fitTabButtons()
end

local function create()
    frame = ns.Skin.window({ width = WIDTH, height = HEIGHT, title = L.WINDOW_TITLE, portrait = PORTRAIT })
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition()
    end)
    frame:EnableKeyboard(true)
    frame:SetScript("OnKeyDown", onKeyDown)
    frame.content = CreateFrame("Frame", nil, frame)
    frame.content:SetPoint("TOPLEFT", SIDE_INSET, -TOP_INSET)
    frame.content:SetPoint("BOTTOMRIGHT", -SIDE_INSET, BOTTOM_INSET)
    createTabButtons()
    createGear()
    restorePosition()
    frame:Hide()
end

function MainFrame.addTab(key, tab)
    tabs[key] = tab
end

function MainFrame.frame()
    return frame
end

function MainFrame.isShown()
    return frame ~= nil and frame:IsShown()
end

function MainFrame.refresh()
    local tab = current and tabs[current]
    if MainFrame.isShown() and tab and tab.refresh then
        tab.refresh()
    end
end

function MainFrame.show(key)
    if InCombatLockdown() then
        return
    end
    if not frame then
        create()
    end
    frame:Show()
    selectTab(TAB_LABELS[key] and key or settings().tab or TAB_KEYS[1])
end

function MainFrame.hide()
    if frame then
        frame:Hide()
    end
end

function MainFrame.toggle()
    if MainFrame.isShown() then
        MainFrame.hide()
    else
        MainFrame.show()
    end
end

function MainFrame.resetPosition()
    local saved = settings()
    saved.point, saved.relativePoint, saved.x, saved.y = nil, nil, nil, nil
    if frame then
        restorePosition()
    end
end

local function setScale(input)
    local scale = tonumber(input)
    if not scale then
        local spec = ns.Options.spec("window.scale")
        print(L.SCALE_USAGE:format(spec.min, spec.max))
        return
    end
    ns.Options.set("window.scale", scale)
end

ns:On("SP_OPTION_CHANGED", function(key, value)
    if not frame then
        return
    elseif key == "window.scale" then
        frame:SetScale(value)
    elseif key == "window.alpha" then
        frame:SetAlpha(value)
    end
end)

ns:RegisterCommand("show", MainFrame.toggle, "SHOW_COMMAND_HELP")
ns:RegisterCommand("scale", setScale, "SCALE_COMMAND_HELP")

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", MainFrame.hide)
