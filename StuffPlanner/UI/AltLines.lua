-- CONTRAT
-- Bouton « [+N] » et sous-lignes d'alternatives d'une ligne de liste (Parcours, Équipement).
-- Charger après Theme.lua et RowActions.lua.
--   ns.AltLines.LINE_HEIGHT, ns.AltLines.TOGGLE_WIDTH
--   ns.AltLines.extra(row) -> hauteur à ajouter à la ligne (0 si repliée ou sans row.alternatives)
--   ns.AltLines.build(button, onToggle) -> crée button.altToggle (à placer par l'appelant) et les
--     sous-lignes ; onToggle(expandKey) au clic sur le bouton
--   ns.AltLines.render(button, row, top, left) : bouton « [+N] » / « [-] » si row.alternatives, sinon
--     caché (largeur 1) ; sous-lignes sous top (px depuis le haut), décalées de left, si row.expanded.
-- Sous-ligne (RowPresenter.alternative) : icône, nom, lineText, gain ; clic = RowActions.click
-- (fiche, Maj : repère, Ctrl : essayage), survol = info-bulle de l'objet.

local _, ns = ...

local L = ns.L

local AltLines = {}
ns.AltLines = AltLines

AltLines.LINE_HEIGHT = 18
AltLines.TOGGLE_WIDTH = 30

local MAX_LINES = 3
local ICON_SIZE = 14
local UNKNOWN_ICON = 134400
local PADDING = 4
local NAME_WIDTH = 150

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

function AltLines.extra(row)
    if not row.expanded or not row.alternatives then
        return 0
    end
    return math.min(#row.alternatives, MAX_LINES) * AltLines.LINE_HEIGHT + PADDING
end

local function showTooltip(line)
    if not line.alt then
        return
    end
    GameTooltip:SetOwner(line, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. line.alt.itemID)
    GameTooltip:AddLine(line.alt.lineText, 1, 1, 1, true)
    GameTooltip:Show()
end

local function showToggleTooltip(toggle)
    GameTooltip:SetOwner(toggle, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.ALT_HINT, 1, 0.82, 0)
    GameTooltip:Show()
end

local function hideTooltip()
    GameTooltip:Hide()
end

local function onLineClick(line)
    local alt = line.alt
    if alt then
        ns.RowActions.click(alt.questID, alt.itemID, alt.itemSource)
    end
end

local function buildLine(button)
    local theme = ns.Theme
    local line = CreateFrame("Button", nil, button)
    line:SetHeight(AltLines.LINE_HEIGHT)
    line.icon = line:CreateTexture(nil, "ARTWORK")
    line.icon:SetSize(ICON_SIZE, ICON_SIZE)
    line.icon:SetPoint("LEFT")
    line.gain = line:CreateFontString(nil, "OVERLAY", theme.fonts.number)
    line.gain:SetPoint("RIGHT")
    line.name = line:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    line.name:SetPoint("LEFT", line.icon, "RIGHT", theme.spacing.gap / 2, 0)
    line.name:SetWidth(NAME_WIDTH)
    line.name:SetJustifyH("LEFT")
    line.name:SetWordWrap(false)
    line.text = line:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    line.text:SetPoint("LEFT", line.name, "RIGHT", theme.spacing.gap, 0)
    line.text:SetPoint("RIGHT", line.gain, "LEFT", -theme.spacing.gap, 0)
    line.text:SetJustifyH("LEFT")
    line.text:SetWordWrap(false)
    setColor(line.text, theme.colors.muted)
    local highlight = line:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)
    line:SetScript("OnEnter", showTooltip)
    line:SetScript("OnLeave", hideTooltip)
    line:SetScript("OnClick", onLineClick)
    return line
end

function AltLines.build(button, onToggle)
    local toggle = CreateFrame("Button", nil, button)
    toggle:SetSize(AltLines.TOGGLE_WIDTH, AltLines.LINE_HEIGHT)
    toggle.text = toggle:CreateFontString(nil, "OVERLAY", ns.Theme.fonts.small)
    toggle.text:SetAllPoints()
    toggle.text:SetJustifyH("RIGHT")
    setColor(toggle.text, ns.Theme.colors.title)
    toggle:SetScript("OnClick", function()
        local row = button.altRow
        if row and row.expandKey ~= nil then
            onToggle(row.expandKey)
        end
    end)
    toggle:SetScript("OnEnter", showToggleTooltip)
    toggle:SetScript("OnLeave", hideTooltip)
    button.altToggle = toggle
    button.altLines = {}
    for i = 1, MAX_LINES do
        button.altLines[i] = buildLine(button)
    end
end

function AltLines.render(button, row, top, left)
    local alternatives = row.alternatives or {}
    button.altRow = row
    local toggle = button.altToggle
    toggle:SetShown(#alternatives > 0)
    toggle:SetWidth(#alternatives > 0 and AltLines.TOGGLE_WIDTH or 1)
    toggle.text:SetText(row.expanded and "[-]" or ("[+" .. #alternatives .. "]"))
    for i, line in ipairs(button.altLines) do
        local alt = row.expanded and alternatives[i] or nil
        line.alt = alt
        line:SetShown(alt ~= nil)
        if alt then
            local y = -(top + (i - 1) * AltLines.LINE_HEIGHT)
            line:SetPoint("TOPLEFT", left, y)
            line:SetPoint("TOPRIGHT", -PADDING, y)
            line.icon:SetTexture(alt.icon or UNKNOWN_ICON)
            line.name:SetText(alt.name)
            setColor(line.name, alt.nameColor)
            line.text:SetText(alt.lineText)
            line.gain:SetText(alt.gainLabel)
            setColor(line.gain, alt.gainColor)
        end
    end
end
