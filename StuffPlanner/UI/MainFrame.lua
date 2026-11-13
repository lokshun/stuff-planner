-- CONTRAT
-- Fenêtre principale (ns.Skin) : onglets hors du bord gauche (ns.NavBar), titre de la page, engrenage et aide en
-- haut à droite. Charger après Core.lua, Compat.lua, Skin.lua, NavBar.lua et PageAliases.lua, avant les pages.
--   ns.MainFrame.addTab(key, tab) -> tab = {create(parent) -> frame, refresh()?, icon, label, short?, order} ;
--     clés : zone, route, dungeon, gear, profile ; une page inscrite après la création est ajoutée à la barre
--   ns.MainFrame.show([key]), hide(), toggle(), isShown() ; show sans clé : dernière page ouverte
--     (StuffPlannerDB.ui.tab, NavBar.pick : page inconnue -> première) ; en combat, show et toggle reportent
--     l'ouverture à la sortie (ns.WindowCombat.request) ; key ancienne (ns.PageAliases : wishlist, journal) :
--     page qui l'accueille, puis la fonction de MainFrame.onReveal(alias, fn) (section dépliée)
--   ns.MainFrame.page() -> clé de la page affichée en dernier | nil
--   ns.MainFrame.refresh() -> rafraîchit la page affichée si la fenêtre est visible
--   ns.MainFrame.pages() -> pages inscrites (ns.NavBar.order), pour l'accueil
--   ns.MainFrame.frame() -> cadre de la fenêtre | nil avant le premier affichage (panneaux accolés)
--   ns.MainFrame.resetPosition() -> fenêtre recentrée
--   ns.MainFrame.setBehind(on) : fenêtre passée sous le panneau de réglages du client (strate MEDIUM, Échap
--     laissé au client) tant que on est vrai
-- Commandes : /splan show (bascule ; aussi /splan seul, menu des addons, raccourci clavier), /splan scale <0.6-1.5>.
-- Sauvegarde : StuffPlannerDB.ui = {point, relativePoint, x, y, tab} ; échelle et opacité par ns.Options
-- (window.scale, window.alpha), appliquées sur SP_OPTION_CHANGED. Engrenage : ns.OptionsPanel.open() ;
-- « ? » : ns.HelpPanel.toggle() (gestes et commandes). Astuce au premier passage sur une page (ns.PageTip).
-- Échap (OnKeyDown, sans nom global) : ferme d'abord la fiche ouverte (QuestDetail, SourceDetail), puis la
-- fenêtre. Combat (cachée, rouverte) : UI/WindowCombat.lua.
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
local TITLE_LEFT = 62 -- après le portrait rond (PortraitFrameTemplate ~60 px, carnet 52 px)
local ICON_BUTTON = 22 -- engrenage et « ? »

local frame, navBar, pageTitle, pageTip
local tabs, panels, reveals = {}, {}, {}
local current
local behind = false

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
    button:SetSize(ICON_BUTTON, ICON_BUTTON)
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
    iconButton(HELP_ICON, gear, -4, function()
        ns.HelpPanel.toggle()
    end, function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.HELP_TITLE)
        GameTooltip:AddLine(L.HELP_OPEN_HINT, 1, 1, 1, true)
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
    pageTip.show(key, tabs[key].icon)
    navBar.setActive(key)
    MainFrame.refresh()
end

local function onKeyDown(self, key)
    local escape = key == "ESCAPE" and not behind
    self:SetPropagateKeyboardInput(not escape)
    if not escape then
        return
    end
    for _, detail in ipairs({ ns.QuestDetail, ns.SourceDetail }) do
        if detail and detail.isShown() then
            detail.hide()
            return
        end
    end
    self:Hide()
end

local function create()
    local width = CONTENT_WIDTH + SIDE_INSET * 2
    frame = ns.Skin.window({ width = width, height = HEIGHT, title = L.WINDOW_TITLE, portrait = PORTRAIT })
    frame:SetFrameStrata(behind and "MEDIUM" or "HIGH")
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition()
    end)
    frame:EnableKeyboard(true)
    frame:SetScript("OnKeyDown", onKeyDown)
    frame:SetClampRectInsets(-ns.NavBar.WIDTH, 0, 0, 0)
    navBar = ns.NavBar.new(frame, selectTab)
    navBar.frame:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, -TOP_INSET)
    navBar.frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, BOTTOM_INSET)
    navBar.render(ns.NavBar.order(tabs))
    local contentLeft = SIDE_INSET
    pageTitle = frame:CreateFontString(nil, "OVERLAY", ns.Theme.fonts.title)
    pageTitle:SetPoint("TOPLEFT", TITLE_LEFT, TITLE_TOP)
    pageTitle:SetJustifyH("LEFT")
    frame.content = CreateFrame("Frame", nil, frame)
    frame.content:SetPoint("TOPLEFT", contentLeft, -TOP_INSET)
    frame.content:SetPoint("BOTTOMRIGHT", -SIDE_INSET, BOTTOM_INSET)
    pageTip = ns.PageTip.new(frame, frame.content, contentLeft, TOP_INSET)
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

function MainFrame.pages()
    return ns.NavBar.order(tabs)
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

function MainFrame.onReveal(alias, fn)
    reveals[alias] = fn
end

function MainFrame.show(key)
    if InCombatLockdown() then
        ns.WindowCombat.request(key)
        return
    end
    if not frame then
        create()
    end
    frame:Show()
    local page, alias = ns.PageAliases.resolve(key)
    selectTab(ns.NavBar.pick(tabs, page, settings().tab))
    if alias and reveals[alias] and current == page then
        reveals[alias]()
    end
end

function MainFrame.setBehind(on)
    behind = on and true or false
    if frame then
        frame:SetFrameStrata(behind and "MEDIUM" or "HIGH")
    end
end

function MainFrame.hide()
    if frame then
        frame:Hide()
    end
end

function MainFrame.page()
    return current
end

function MainFrame.toggle()
    if InCombatLockdown() then
        MainFrame.show()
    elseif MainFrame.isShown() then
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

ns:RegisterCommand("show", MainFrame.toggle, "SHOW_COMMAND_HELP", { anytime = true })
ns:RegisterCommand("scale", setScale, "SCALE_COMMAND_HELP")
