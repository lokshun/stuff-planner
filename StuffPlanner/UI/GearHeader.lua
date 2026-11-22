-- CONTRAT
-- En-tête d'une ligne de l'onglet Équipement : objet porté, nettement séparé de l'amélioration dessous.
-- Charger après Theme.lua, avant GearRows.lua.
--   ns.GearHeader.HEIGHT (px)
--   ns.GearHeader.new(button) -> header (Button en haut de button, filet doré au-dessus, petite icône,
--     texte « emplacement · row.wornText ») ; ns.GearHeader.render(header, row) (row = GearPresenter.build)
--   ns.GearHeader.showTooltip(header) : info-bulle de l'objet porté (ou de l'emplacement vide), score,
--     amélioration qui le remplacerait ; lit header:GetParent().row
-- Emplacement vide : icône d'emplacement du jeu, grisée.

local _, ns = ...

local L = ns.L

local GearHeader = {}
ns.GearHeader = GearHeader

GearHeader.HEIGHT = 18

local UNKNOWN_ICON = 134400 -- point d'interrogation (FileDataID)
local ICON_SIZE = 14
local LEFT = 6
local SEPARATOR = " · "
local HINT = { r = 0.6, g = 0.6, b = 0.6 }

local function slotLabel(row)
    return ns.Compat.GlobalString(row.slotName) or L.SLOT_FALLBACK:format(row.slot)
end

local function closeTooltip()
    GameTooltip:Hide()
end

-- En-tête : objet porté, son score et ce qui le remplacerait.
function GearHeader.showTooltip(header)
    local row = header:GetParent().row
    if not row then
        return
    end
    GameTooltip:SetOwner(header, "ANCHOR_RIGHT")
    if row.itemID then
        GameTooltip:SetInventoryItem("player", row.slot)
    else
        GameTooltip:SetText(slotLabel(row), 1, 0.82, 0)
    end
    if row.scoreText ~= "" then
        GameTooltip:AddLine(L.GEAR_TOOLTIP_SCORE:format(row.scoreText), HINT.r, HINT.g, HINT.b)
    end
    if row.scoreText == "?" then
        GameTooltip:AddLine(L.GEAR_UNKNOWN_HINT, HINT.r, HINT.g, HINT.b, true)
    end
    local upgrade = row.upgrade
    if upgrade then
        local gain = ns.Theme.colors.gain
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.GEAR_TOOLTIP_REPLACE, 1, 0.82, 0)
        GameTooltip:AddDoubleLine(upgrade.name, upgrade.gainText, upgrade.nameColor.r, upgrade.nameColor.g,
            upgrade.nameColor.b, gain.r, gain.g, gain.b)
    end
    GameTooltip:Show()
end

function GearHeader.new(button)
    local theme = ns.Theme
    local header = CreateFrame("Button", nil, button)
    header:SetHeight(GearHeader.HEIGHT)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    local edge = theme.colors.border
    local rule = header:CreateTexture(nil, "BORDER")
    rule:SetColorTexture(edge.r, edge.g, edge.b, 0.45)
    rule:SetHeight(theme.spacing.border)
    rule:SetPoint("TOPLEFT", 2, 0)
    rule:SetPoint("TOPRIGHT", -2, 0)
    header.icon = header:CreateTexture(nil, "ARTWORK")
    header.icon:SetSize(ICON_SIZE, ICON_SIZE)
    header.icon:SetPoint("LEFT", LEFT, -1)
    header.text = header:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    header.text:SetPoint("LEFT", header.icon, "RIGHT", theme.spacing.gap, 0)
    header.text:SetPoint("RIGHT", -4, -1)
    header.text:SetJustifyH("LEFT")
    header.text:SetWordWrap(false)
    local highlight = header:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)
    header:SetScript("OnEnter", GearHeader.showTooltip)
    header:SetScript("OnLeave", closeTooltip)
    return header
end

function GearHeader.render(header, row)
    local empty = row.itemID == nil
    header.icon:SetTexture(empty and (ns.Compat.GetInventorySlotTexture(row.slotName) or UNKNOWN_ICON)
        or row.icon or UNKNOWN_ICON)
    header.icon:SetDesaturated(empty)
    header.icon:SetAlpha(empty and 0.5 or 1)
    header.text:SetText(ns.Theme.colorize(slotLabel(row), ns.Theme.colors.muted) .. SEPARATOR .. row.wornText)
end
