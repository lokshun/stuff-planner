-- CONTRAT
-- Fenêtre principale (ns.Skin) : barre d'icônes à gauche (ns.NavBar), titre de la page, engrenage et aide en
-- haut à droite. Charger après Core.lua, Compat.lua, Skin.lua et NavBar.lua, avant les pages.
--   ns.MainFrame.addTab(key, tab) -> tab = {create(parent) -> frame, refresh()?, icon, label, order} ;
--     clés existantes : zone, route, gear, profile ; une page inscrite après la création est ajoutée à la barre
--   ns.MainFrame.show([key]), hide(), toggle(), isShown() ; show sans clé : dernière page ouverte
--     (StuffPlannerDB.ui.tab, NavBar.pick : page inconnue -> première)
--   ns.MainFrame.refresh() -> rafraîchit la page affichée si la fenêtre est visible
--   ns.MainFrame.frame() -> cadre de la fenêtre | nil avant le premier affichage (panneaux accolés)
--   ns.MainFrame.resetPosition() -> fenêtre recentrée
-- Commandes : /splan show (bascule, aussi par le menu des addons), /splan scale <0.6-1.5>.
-- Sauvegarde : StuffPlannerDB.ui = {point, relativePoint, x, y, tab} ; échelle et opacité par ns.Options
-- (window.scale, window.alpha), appliquées sur SP_OPTION_CHANGED. Engrenage : ns.OptionsPanel.open() ;
-- « ? » : info-bulle des gestes (clics des lignes, menu).
-- Fermeture par Échap (OnKeyDown, sans nom global) ; cachée en combat, ouverte hors combat seulement.
-- Créée au premier affichage : rien n'est construit tant que le joueur ne l'ouvre pas.

local _, ns = ...

local L = ns.L

local MainFrame = {}
ns.MainFrame = MainFrame

local CONTENT_WIDTH, HEIGHT = 436, 520
local PORTRAIT = ns.ICON -- logo de l'addon
local GEAR_ICON = "Interface\\Icons\\INV_Misc_Gear_01"
local HELP_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local TOP_INSET, SIDE_INSET, BOTTOM_INSET, TITLE_TOP = 60, 12, 12, -34

local frame, navBar, pageTitle
local tabs, panels = {}, {}
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

local function iconButton(icon, anchor, x, onClick, onEnter)
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(18, 18)
    -- Au-dessus du cadre du modèle (TitleContainer, NineSlice) : sinon caché sur Forever.
    button:SetFrameLevel((frame.CloseButton or frame):GetFrameLevel() + 2)
    button:SetPoint("RIGHT", anchor, "LEFT", x, 0)
    button:SetNormalTexture(icon)
    button:SetHighlightTexture(icon, "ADD")
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", onEnter)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

local function createButtons()
    local gear = iconButton(GEAR_ICON, frame.CloseButton, -2, function()
        if ns.OptionsPanel then
            ns.OptionsPanel.open()
        end
    end, function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.OPTIONS_OPEN)
        GameTooltip:Show()
    end)
    iconButton(HELP_ICON, gear, -4, nil, function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.WINDOW_TITLE)
        GameTooltip:AddLine(L.ROW_CLICK_HINT, 1, 1, 1, true)
        GameTooltip:AddLine(L.ROW_MENU_HINT, 1, 1, 1, true)
        GameTooltip:Show()
    end)
end

local function panelFor(key)
    if not panels[key] then
        local panel = tabs[key].create(frame.content)
        panel:SetAllPoints(frame.content)
        panels[key] = panel
    end
    return panels[key]
end

local function selectTab(key)
    if not key then
        return
    end
    current = key
    settings().tab = key
    for tabKey, panel in pairs(panels) do
        panel:SetShown(tabKey == key)
    end
    panelFor(key):Show()
    pageTitle:SetText(tabs[key].label or "")
    navBar.setActive(key)
    MainFrame.refresh()
end

local function onKeyDown(self, key)
    local escape = key == "ESCAPE"
    self:SetPropagateKeyboardInput(not escape)
    if escape then
        self:Hide()
    end
end

local function create()
    local width = CONTENT_WIDTH + ns.NavBar.WIDTH + SIDE_INSET * 3
    frame = ns.Skin.window({ width = width, height = HEIGHT, title = L.WINDOW_TITLE, portrait = PORTRAIT })
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition()
    end)
    frame:EnableKeyboard(true)
    frame:SetScript("OnKeyDown", onKeyDown)
    navBar = ns.NavBar.new(frame, selectTab)
    navBar.frame:SetPoint("TOPLEFT", SIDE_INSET, -TOP_INSET)
    navBar.frame:SetPoint("BOTTOMLEFT", SIDE_INSET, BOTTOM_INSET)
    navBar.render(ns.NavBar.order(tabs))
    local contentLeft = SIDE_INSET * 2 + ns.NavBar.WIDTH
    pageTitle = frame:CreateFontString(nil, "OVERLAY", ns.Theme.fonts.title)
    pageTitle:SetPoint("TOPLEFT", contentLeft, TITLE_TOP)
    pageTitle:SetJustifyH("LEFT")
    frame.content = CreateFrame("Frame", nil, frame)
    frame.content:SetPoint("TOPLEFT", contentLeft, -TOP_INSET)
    frame.content:SetPoint("BOTTOMRIGHT", -SIDE_INSET, BOTTOM_INSET)
    createButtons()
    restorePosition()
    frame:Hide()
end

function MainFrame.addTab(key, tab)
    tabs[key] = tab
    if navBar then
        navBar.render(ns.NavBar.order(tabs))
        navBar.setActive(current)
    end
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
    selectTab(ns.NavBar.pick(tabs, key, settings().tab))
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
