-- CONTRAT
-- Panneau d'aide « ? » de la fenêtre principale : gestes et commandes (HelpPresenter, ns:Commands()).
-- Charger après Skin.lua et HelpPresenter.lua.
--   ns.HelpPanel.toggle() -> ouvre ou ferme le panneau (hors combat) ; ns.HelpPanel.hide()
-- Fenêtre ns.Skin (strate DIALOG), déplaçable, fermée par Échap ou la croix ; contenu construit au premier
-- affichage dans un cadre défilant : titre de section, puis lignes « geste » (couleur de titre) + effet.

local _, ns = ...

local L = ns.L

local HelpPanel = {}
ns.HelpPanel = HelpPanel

local WIDTH, HEIGHT = 440, 460
local PAD = 16
local KEY_WIDTH = 150
local CONTENT_WIDTH = WIDTH - PAD * 2 - 24

local frame

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

local function onKeyDown(self, key)
    local escape = key == "ESCAPE"
    self:SetPropagateKeyboardInput(not escape)
    if escape then
        self:Hide()
    end
end

local function addLine(content, y, line)
    local theme = ns.Theme
    local key = content:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    key:SetPoint("TOPLEFT", 0, y)
    key:SetWidth(KEY_WIDTH)
    key:SetJustifyH("LEFT")
    key:SetText(line.key)
    setColor(key, theme.colors.title)
    local text = content:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    text:SetPoint("TOPLEFT", KEY_WIDTH + theme.spacing.gap, y)
    text:SetWidth(CONTENT_WIDTH - KEY_WIDTH - theme.spacing.gap)
    text:SetJustifyH("LEFT")
    text:SetText(line.text)
    setColor(text, theme.colors.text)
    return y - math.max(key:GetStringHeight(), text:GetStringHeight()) - 4
end

local function addTitle(content, y, title)
    local theme = ns.Theme
    local header = content:CreateFontString(nil, "OVERLAY", theme.fonts.header)
    header:SetPoint("TOPLEFT", 0, y)
    header:SetText(title)
    setColor(header, theme.colors.title)
    local rule = content:CreateTexture(nil, "ARTWORK")
    local gold = theme.colors.border
    rule:SetColorTexture(gold.r, gold.g, gold.b, 0.5)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    rule:SetWidth(CONTENT_WIDTH)
    return y - header:GetStringHeight() - 8
end

local function fill(content)
    local y = 0
    for index, section in ipairs(ns.HelpPresenter.build(ns:Commands())) do
        if index > 1 then
            y = y - 10
        end
        y = addTitle(content, y, section.title)
        for _, line in ipairs(section.lines) do
            y = addLine(content, y, line)
        end
    end
    content:SetHeight(-y + PAD)
end

local function create()
    frame = ns.Skin.window({ width = WIDTH, height = HEIGHT, title = L.HELP_TITLE, portrait = ns.ICON,
        strata = "DIALOG" })
    frame:SetPoint("CENTER", 0, 40)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:EnableKeyboard(true)
    frame:SetScript("OnKeyDown", onKeyDown)
    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", PAD, -64)
    scroll:SetPoint("BOTTOMRIGHT", -PAD - 24, PAD)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(CONTENT_WIDTH)
    scroll:SetScrollChild(content)
    fill(content)
    frame:Hide()
end

function HelpPanel.toggle()
    if InCombatLockdown() then
        return
    end
    if not frame then
        create()
    end
    frame:SetShown(not frame:IsShown())
end

function HelpPanel.hide()
    if frame then
        frame:Hide()
    end
end
