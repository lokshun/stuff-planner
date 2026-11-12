-- CONTRAT
-- Habillage des cadres au choix du joueur (option window.skin) : « notebook » (carnet d'aventurier,
-- couleurs de ns.Theme) ou « blizzard » (modèles et fonds du client). Charger après Options.lua et Theme.lua.
--   ns.Skin.name() -> "notebook" | "blizzard" : lu au premier appel, fixe jusqu'au rechargement
--   ns.Skin.pending() -> bool : l'option diffère de l'habillage en cours (rechargement à faire)
--   ns.Skin.window(opts) -> frame : fenêtre à titre, portrait et frame.CloseButton
--     opts = {width, height, title, portrait, strata}
--   ns.Skin.panel(frame, opts?) -> fond d'un cadre existant ; opts = {alpha, edges = "horizontal" (défaut,
--     filets haut et bas) | "full" | "none"} ; edges ignoré par l'habillage Blizzard (bordure du client)
--   ns.Skin.button(parent) -> bouton à texte (SetText, GetFontString, SetEnabled comme UIPanelButtonTemplate)
-- Rien n'est relu après la création : changer d'habillage demande /reload.

local _, ns = ...

local Skin = {}
ns.Skin = Skin

local BLIZZARD_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local PORTRAIT_SIZE, TITLE_TOP, CLOSE_INSET = 44, -8, 2

local active

function Skin.name()
    if not active then
        active = ns.Options.get("window.skin")
    end
    return active
end

function Skin.pending()
    return Skin.name() ~= ns.Options.get("window.skin")
end

local function edge(frame, color, alpha, a, b, vertical)
    local size = ns.Theme.spacing.border
    local texture = frame:CreateTexture(nil, "BORDER")
    texture:SetColorTexture(color.r, color.g, color.b, alpha)
    if vertical then
        texture:SetWidth(size)
    else
        texture:SetHeight(size)
    end
    texture:SetPoint(a)
    texture:SetPoint(b)
end

local function notebookPanel(frame, alpha, edges)
    local theme = ns.Theme
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    local bg = theme.colors.background
    background:SetColorTexture(bg.r, bg.g, bg.b, alpha)
    if edges == "none" then
        return
    end
    local border = theme.colors.border
    edge(frame, border, 0.8, "TOPLEFT", "TOPRIGHT")
    edge(frame, border, 0.8, "BOTTOMLEFT", "BOTTOMRIGHT")
    if edges == "full" then
        edge(frame, border, 0.8, "TOPLEFT", "BOTTOMLEFT", true)
        edge(frame, border, 0.8, "TOPRIGHT", "BOTTOMRIGHT", true)
    end
end

function Skin.panel(frame, opts)
    opts = opts or {}
    local alpha = opts.alpha or 1
    if Skin.name() == "blizzard" and ns.Compat.SetBackdrop(frame, BLIZZARD_BACKDROP, 0, 0, 0, alpha) then
        return
    end
    notebookPanel(frame, alpha, opts.edges)
end

local function blizzardWindow(opts)
    local frame = CreateFrame("Frame", nil, UIParent, "PortraitFrameTemplate")
    ns.Compat.SetFrameTitle(frame, opts.title)
    ns.Compat.SetFramePortrait(frame, opts.portrait)
    return frame
end

local function notebookWindow(opts)
    local theme = ns.Theme
    local frame = CreateFrame("Frame", nil, UIParent)
    notebookPanel(frame, 0.95, "full")
    local portrait = frame:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
    portrait:SetPoint("TOPLEFT", 8, -8)
    portrait:SetTexture(opts.portrait)
    local title = frame:CreateFontString(nil, "OVERLAY", theme.fonts.header)
    title:SetPoint("TOP", 0, TITLE_TOP)
    title:SetText(opts.title)
    local color = theme.colors.title
    title:SetTextColor(color.r, color.g, color.b)
    frame.TitleText = title
    frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.CloseButton:SetPoint("TOPRIGHT", CLOSE_INSET, CLOSE_INSET)
    return frame
end

function Skin.window(opts)
    local frame = Skin.name() == "blizzard" and blizzardWindow(opts) or notebookWindow(opts)
    frame:SetSize(opts.width, opts.height)
    frame:SetFrameStrata(opts.strata or "HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    return frame
end

local function notebookButton(parent)
    local theme = ns.Theme
    local button = CreateFrame("Button", nil, parent)
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.24, 0.19, 0.11, 0.9)
    local border = theme.colors.border
    edge(button, border, 0.6, "TOPLEFT", "TOPRIGHT")
    edge(button, border, 0.6, "BOTTOMLEFT", "BOTTOMRIGHT")
    edge(button, border, 0.6, "TOPLEFT", "BOTTOMLEFT", true)
    edge(button, border, 0.6, "TOPRIGHT", "BOTTOMRIGHT", true)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(border.r, border.g, border.b, 0.2)
    local text = button:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER")
    button:SetFontString(text)
    button:SetNormalFontObject(theme.fonts.header)
    button:SetHighlightFontObject(theme.fonts.body)
    button:SetDisabledFontObject("GameFontDisable")
    button:SetPushedTextOffset(1, -1)
    return button
end

function Skin.button(parent)
    if Skin.name() == "blizzard" then
        return CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    end
    return notebookButton(parent)
end
