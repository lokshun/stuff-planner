-- CONTRAT
-- Lignes de l'onglet Équipement (GearPresenter.build). Charger après Theme.lua, Chips.lua, RowActions.lua,
-- AltLines.lua.
--   ns.GearRows.init(button, row) -> initialiseur de ScrollBox (construit la ligne au premier appel)
--   ns.GearRows.onToggle(fn) : fn(expandKey) au clic sur « [+N] » (alternatives, AltLines)
--   ns.GearRows.baseHeight(row) -> hauteur sans les alternatives (BASE_HEIGHT, RAID_HEIGHT avec raid)
-- Ligne : liseré vert si amélioration ; icône portée (sinon icône d'emplacement vide du jeu, grisée) ;
--   emplacement, nom ; gain à droite ; 2e ligne detailText ; 3e ligne si un raid fait mieux : raidText et
--   son gain, cliquable à part (fiche de la source, Ctrl : essayage) ; la hauteur est fixée par GearTab.
-- Clic : RowActions.click sur l'amélioration (fiche, Maj : repère, Ctrl : essayage).
-- Alternatives (AltLines) : bouton flèche à droite de la 1re ligne, gain à sa gauche.
--   ns.GearRows.mark(button) : cadres de sélection (amélioration, ligne raid, sous-lignes)
-- Survol : info-bulle de l'objet porté (ou de l'emplacement vide) + score, remplacement, source, conseil.

local _, ns = ...

local L = ns.L

local GearRows = {}
ns.GearRows = GearRows

local UNKNOWN_ICON = 134400 -- point d'interrogation (FileDataID)
local SLOT_WIDTH = 66
local LINE_HEIGHT = 14
local ICON_SIZE = 30
local ACCENT_WIDTH = 2
local HINT = { r = 0.6, g = 0.6, b = 0.6 }
local BASE_HEIGHT, RAID_HEIGHT = 40, 56
local toggleHandler = function() end

function GearRows.onToggle(fn)
    toggleHandler = fn
end

function GearRows.baseHeight(row)
    return row.raid and RAID_HEIGHT or BASE_HEIGHT
end

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

local function slotLabel(row)
    return ns.Compat.GlobalString(row.slotName) or L.SLOT_FALLBACK:format(row.slot)
end

local function addUpgradeLines(row)
    local upgrade = row.upgrade
    if row.scoreText ~= "" then
        GameTooltip:AddLine(L.GEAR_TOOLTIP_SCORE:format(row.scoreText), HINT.r, HINT.g, HINT.b)
    end
    if row.scoreText == "?" then
        GameTooltip:AddLine(L.GEAR_UNKNOWN_HINT, HINT.r, HINT.g, HINT.b, true)
    end
    if not upgrade then
        return
    end
    local gain = ns.Theme.colors.gain
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.GEAR_TOOLTIP_REPLACE, 1, 0.82, 0)
    GameTooltip:AddDoubleLine(upgrade.name, upgrade.gainText, upgrade.nameColor.r, upgrade.nameColor.g,
        upgrade.nameColor.b, gain.r, gain.g, gain.b)
    GameTooltip:AddLine(row.detailText, 1, 1, 1, true)
    GameTooltip:AddLine(L.GEAR_CLICK_HINT, HINT.r, HINT.g, HINT.b, true)
end

local function showTooltip(button)
    local row = button.row
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if row.itemID then
        GameTooltip:SetInventoryItem("player", row.slot)
    else
        GameTooltip:SetText(slotLabel(row), 1, 0.82, 0)
    end
    addUpgradeLines(row)
    GameTooltip:Show()
end

local function showRaidTooltip(line)
    local raid = line:GetParent().row.raid
    if not raid then
        return
    end
    GameTooltip:SetOwner(line, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. raid.itemID)
    GameTooltip:AddLine(line:GetParent().row.raidText, 1, 1, 1, true)
    GameTooltip:AddLine(L.GEAR_CLICK_HINT, HINT.r, HINT.g, HINT.b, true)
    GameTooltip:Show()
end

local function onRaidClick(line)
    local raid = line:GetParent().row.raid
    if raid then
        ns.RowActions.click(nil, raid.itemID, raid.itemSource)
    end
end

local function buildRaidLine(button)
    local theme = ns.Theme
    local line = CreateFrame("Button", nil, button)
    line:SetHeight(LINE_HEIGHT)
    line:SetPoint("TOPLEFT", button.detail, "BOTTOMLEFT", 0, -2)
    line:SetPoint("RIGHT", -(4 + ns.AltLines.TOGGLE_WIDTH + theme.spacing.gap), 0)
    line.gain = line:CreateFontString(nil, "OVERLAY", theme.fonts.number)
    line.gain:SetPoint("RIGHT")
    line.text = line:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    line.text:SetPoint("LEFT")
    line.text:SetPoint("RIGHT", line.gain, "LEFT", -theme.spacing.gap, 0)
    line.text:SetJustifyH("LEFT")
    line.text:SetWordWrap(false)
    local highlight = line:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)
    line:SetScript("OnEnter", showRaidTooltip)
    line:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    line:SetScript("OnClick", onRaidClick)
    button.raidLine = line
end

local function onRowClick(button)
    local upgrade = button.row and button.row.upgrade
    if upgrade then
        ns.RowActions.click(upgrade.questID, upgrade.itemID, upgrade.itemSource)
    end
end

local function buildRow(button)
    local theme = ns.Theme
    local gain = theme.colors.gain
    button.accent = button:CreateTexture(nil, "ARTWORK")
    button.accent:SetPoint("TOPLEFT", 0, -3)
    button.accent:SetPoint("BOTTOMLEFT", 0, 3)
    button.accent:SetWidth(ACCENT_WIDTH)
    button.accent:SetColorTexture(gain.r, gain.g, gain.b, 0.9)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(ICON_SIZE, ICON_SIZE)
    button.icon:SetPoint("TOPLEFT", ACCENT_WIDTH + 4, -5)
    button.slotText = button:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    button.slotText:SetPoint("TOPLEFT", button.icon, "TOPRIGHT", theme.spacing.gap, -1)
    button.slotText:SetWidth(SLOT_WIDTH)
    button.slotText:SetJustifyH("LEFT")
    button.slotText:SetWordWrap(false)
    setColor(button.slotText, theme.colors.muted)
    button.gain = button:CreateFontString(nil, "OVERLAY", theme.fonts.number)
    ns.AltLines.build(button, function(key)
        toggleHandler(key)
    end)
    button.altToggle:SetPoint("TOPRIGHT", -4, -2)
    button.gain:SetPoint("TOPRIGHT", button.altToggle, "TOPLEFT", -theme.spacing.gap, -3)
    button.name = button:CreateFontString(nil, "OVERLAY", theme.fonts.body)
    button.name:SetPoint("LEFT", button.slotText, "RIGHT", theme.spacing.gap, 0)
    button.name:SetPoint("RIGHT", button.gain, "LEFT", -theme.spacing.gap, 0)
    button.name:SetJustifyH("LEFT")
    button.name:SetWordWrap(false)
    button.detail = button:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    button.detail:SetPoint("TOPLEFT", button.slotText, "BOTTOMLEFT", 0, -4)
    button.detail:SetPoint("RIGHT", -4, 0)
    button.detail:SetJustifyH("LEFT")
    button.detail:SetWordWrap(false)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)
    button:SetScript("OnEnter", showTooltip)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", onRowClick)
    buildRaidLine(button)
end

function GearRows.mark(button)
    local row = button.row
    if not row then
        return
    end
    local upgrade, raid = row.upgrade, row.raid
    ns.RowActions.mark(button, upgrade and upgrade.questID, upgrade and upgrade.itemID, GearRows.baseHeight(row))
    ns.RowActions.mark(button.raidLine, nil, raid and raid.itemID)
    ns.AltLines.mark(button)
end

function GearRows.init(button, row)
    if not button.icon then
        buildRow(button)
    end
    button.row = row
    button.accent:SetShown(row.upgrade ~= nil)
    local empty = row.itemID == nil
    button.icon:SetTexture(empty and (ns.Compat.GetInventorySlotTexture(row.slotName) or UNKNOWN_ICON)
        or row.icon or UNKNOWN_ICON)
    button.icon:SetDesaturated(empty)
    button.icon:SetAlpha(empty and 0.5 or 1)
    button.slotText:SetText(slotLabel(row))
    button.name:SetText(row.name)
    setColor(button.name, row.nameColor)
    button.gain:SetText(row.gainLabel)
    setColor(button.gain, row.gainColor)
    button.detail:SetText(row.detailText)
    setColor(button.detail, row.detailColor)
    ns.AltLines.render(button, row, GearRows.baseHeight(row), ACCENT_WIDTH + 4 + ICON_SIZE + ns.Theme.spacing.gap)
    button.raidLine:SetShown(row.raid ~= nil)
    if row.raid then
        button.raidLine.text:SetText(row.raidText)
        setColor(button.raidLine.text, ns.Theme.colors.text)
        button.raidLine.gain:SetText(row.raidGainLabel)
        setColor(button.raidLine.gain, row.raidGainColor)
    end
    GearRows.mark(button)
end
