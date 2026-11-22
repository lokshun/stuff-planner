-- CONTRAT
-- Lignes de l'onglet Équipement (GearPresenter.build). Charger après Theme.lua, Chips.lua, RowActions.lua,
-- AltLines.lua, GearHeader.lua.
--   ns.GearRows.init(button, row) -> initialiseur de ScrollBox (construit la ligne au premier appel)
--   ns.GearRows.onToggle(fn) : fn(expandKey) au clic sur la flèche des alternatives (AltLines)
--   ns.GearRows.baseHeight(row) -> hauteur sans les alternatives : en-tête (HEADER_HEIGHT) + bloc
--     amélioration (UPGRADE_HEIGHT, NONE_HEIGHT sans) + RAID_LINE si un raid fait mieux
-- Ligne, deux étages nettement séparés :
--   en-tête (ns.GearHeader) « Tête · porté : nom (score 42) » ;
--   amélioration en ligne pleine : liseré vert, icône et nom de l'objet proposé, score de l'objet et gain
--     (points) à droite, 2e ligne detailText (source) et gain du profil comparé ; sans amélioration :
--     detailText gris seul ; ligne raid si un raid fait mieux (score, gain), cliquable à part.
-- Clic : RowActions.click sur l'amélioration (fiche, Maj : lien, Ctrl : essayage) ; clic droit : RowActions.menu.
-- Survol du bloc amélioration : info-bulle de l'objet proposé, objet porté remplacé, gain, source.
-- Alternatives (AltLines) : bouton flèche à droite de la ligne d'amélioration, sous-lignes dessous.
--   ns.GearRows.mark(button) : cadres de sélection (amélioration, ligne raid, sous-lignes)

local _, ns = ...

local L = ns.L

local GearRows = {}
ns.GearRows = GearRows

local UNKNOWN_ICON = 134400 -- point d'interrogation (FileDataID)
local LINE_HEIGHT = 14
local ICON_SIZE = 30
local ACCENT_WIDTH = 2
local HINT = { r = 0.6, g = 0.6, b = 0.6 }
local HEADER_HEIGHT = ns.GearHeader.HEIGHT
local UPGRADE_HEIGHT, NONE_HEIGHT, RAID_LINE = 40, 20, 16
local toggleHandler = function() end

local function contentLeft()
    return ACCENT_WIDTH + 4 + ICON_SIZE + ns.Theme.spacing.gap
end

function GearRows.onToggle(fn)
    toggleHandler = fn
end

local function blockBottom(row)
    return HEADER_HEIGHT + (row.upgrade and UPGRADE_HEIGHT or NONE_HEIGHT)
end

function GearRows.baseHeight(row)
    return blockBottom(row) + (row.raid and RAID_LINE or 0)
end

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

local function closeTooltip()
    GameTooltip:Hide()
end

-- Bloc amélioration : objet proposé, puis objet porté remplacé, gain et source.
local function showUpgradeTooltip(button)
    local row = button.row
    local upgrade = row and row.upgrade
    if not upgrade then
        return ns.GearHeader.showTooltip(button.header)
    end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. upgrade.itemID)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(row.wornText, 1, 1, 1)
    local gain = row.gainColor
    GameTooltip:AddDoubleLine(row.upgradeScoreText or " ", row.gainLabel, HINT.r, HINT.g, HINT.b,
        gain.r, gain.g, gain.b)
    if upgrade.secondaryLabel then
        local second = upgrade.secondaryColor
        GameTooltip:AddDoubleLine(" ", upgrade.secondaryLabel, 1, 1, 1, second.r, second.g, second.b)
    end
    if row.detailText ~= "" then
        GameTooltip:AddLine(row.detailText, 1, 1, 1, true)
    end
    GameTooltip:AddLine(L.ROW_MENU_HINT, HINT.r, HINT.g, HINT.b)
    GameTooltip:Show()
end

local function showRaidTooltip(line)
    local row = line:GetParent().row
    local raid = row and row.raid
    if not raid then
        return
    end
    GameTooltip:SetOwner(line, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. raid.itemID)
    GameTooltip:AddLine(row.raidText, 1, 1, 1, true)
    GameTooltip:AddLine(L.ROW_MENU_HINT, HINT.r, HINT.g, HINT.b)
    GameTooltip:Show()
end

local function act(mouseButton, questID, itemID, itemSource)
    if mouseButton == "RightButton" then
        ns.RowActions.menu(questID, itemID, itemSource)
    else
        ns.RowActions.click(questID, itemID, itemSource)
    end
end

local function onRaidClick(line, mouseButton)
    local raid = line:GetParent().row.raid
    if raid then
        act(mouseButton, nil, raid.itemID, raid.itemSource)
    end
end

local function onRowClick(button, mouseButton)
    local upgrade = button.row and button.row.upgrade
    if upgrade then
        act(mouseButton, upgrade.questID, upgrade.itemID, upgrade.itemSource)
    end
end

local function addHighlight(frame)
    local highlight = frame:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)
end

local function buildRaidLine(button)
    local theme = ns.Theme
    local line = CreateFrame("Button", nil, button)
    line:SetHeight(LINE_HEIGHT)
    line:SetPoint("RIGHT", -(4 + ns.AltLines.TOGGLE_WIDTH + theme.spacing.gap), 0)
    line.gain = line:CreateFontString(nil, "OVERLAY", theme.fonts.number)
    line.gain:SetPoint("RIGHT")
    line.score = line:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    line.score:SetPoint("RIGHT", line.gain, "LEFT", -theme.spacing.gap, 0)
    setColor(line.score, theme.colors.muted)
    line.text = line:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    line.text:SetPoint("LEFT")
    line.text:SetPoint("RIGHT", line.score, "LEFT", -theme.spacing.gap, 0)
    line.text:SetJustifyH("LEFT")
    line.text:SetWordWrap(false)
    addHighlight(line)
    line:SetScript("OnEnter", showRaidTooltip)
    line:SetScript("OnLeave", closeTooltip)
    line:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    line:SetScript("OnClick", onRaidClick)
    button.raidLine = line
end

local function buildRow(button)
    local theme = ns.Theme
    local gain = theme.colors.gain
    local top = -HEADER_HEIGHT
    button.header = ns.GearHeader.new(button)
    button.accent = button:CreateTexture(nil, "ARTWORK")
    button.accent:SetPoint("TOPLEFT", 0, top - 3)
    button.accent:SetSize(ACCENT_WIDTH, UPGRADE_HEIGHT - 6)
    button.accent:SetColorTexture(gain.r, gain.g, gain.b, 0.9)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(ICON_SIZE, ICON_SIZE)
    button.icon:SetPoint("TOPLEFT", ACCENT_WIDTH + 4, top - 5)
    ns.AltLines.build(button, function(key)
        toggleHandler(key)
    end)
    button.altToggle:SetPoint("TOPRIGHT", -4, top - 2)
    button.gain = button:CreateFontString(nil, "OVERLAY", theme.fonts.number)
    button.gain:SetPoint("TOPRIGHT", button.altToggle, "TOPLEFT", -theme.spacing.gap, -3)
    button.score = button:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    button.score:SetPoint("RIGHT", button.gain, "LEFT", -theme.spacing.gap, 0)
    setColor(button.score, theme.colors.muted)
    button.name = button:CreateFontString(nil, "OVERLAY", theme.fonts.body)
    button.name:SetPoint("TOPLEFT", contentLeft(), top - 6)
    button.name:SetPoint("RIGHT", button.score, "LEFT", -theme.spacing.gap, 0)
    button.name:SetJustifyH("LEFT")
    button.name:SetWordWrap(false)
    button.gain2 = button:CreateFontString(nil, "OVERLAY", theme.fonts.number)
    button.gain2:SetPoint("TOPRIGHT", button.gain, "BOTTOMRIGHT", 0, -4)
    button.detail = button:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    button.detail:SetPoint("RIGHT", button.gain2, "LEFT", -theme.spacing.gap, 0)
    button.detail:SetJustifyH("LEFT")
    button.detail:SetWordWrap(false)
    addHighlight(button)
    button:SetScript("OnEnter", showUpgradeTooltip)
    button:SetScript("OnLeave", closeTooltip)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
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

local function renderUpgrade(button, row)
    local upgrade, colors = row.upgrade, ns.Theme.colors
    button.accent:SetShown(upgrade ~= nil)
    button.icon:SetShown(upgrade ~= nil)
    button.name:SetShown(upgrade ~= nil)
    button.detail:ClearAllPoints()
    button.detail:SetPoint("RIGHT", button.gain2, "LEFT", -ns.Theme.spacing.gap, 0)
    if upgrade then
        button.icon:SetTexture(row.upgradeIcon or UNKNOWN_ICON)
        button.name:SetText(upgrade.name)
        setColor(button.name, upgrade.nameColor)
        button.detail:SetPoint("TOPLEFT", button.name, "BOTTOMLEFT", 0, -4)
    else
        button.detail:SetPoint("TOPLEFT", contentLeft(), -(HEADER_HEIGHT + 4))
    end
    button.score:SetText(row.upgradeScoreText or "")
    button.gain:SetText(row.gainLabel)
    setColor(button.gain, row.gainColor)
    button.gain2:SetText(upgrade and upgrade.secondaryLabel or "")
    setColor(button.gain2, upgrade and upgrade.secondaryColor or colors.muted)
    button.detail:SetText(row.detailText)
    setColor(button.detail, row.detailColor)
end

local function renderRaid(button, row)
    local line = button.raidLine
    line:SetShown(row.raid ~= nil)
    if not row.raid then
        return
    end
    line:SetPoint("TOPLEFT", contentLeft(), -(blockBottom(row) - 2))
    line.text:SetText(row.raidText)
    setColor(line.text, ns.Theme.colors.text)
    line.score:SetText(row.raidScoreText or "")
    line.gain:SetText(row.raidGainLabel)
    setColor(line.gain, row.raidGainColor)
end

function GearRows.init(button, row)
    if not button.icon then
        buildRow(button)
    end
    button.row = row
    ns.GearHeader.render(button.header, row)
    renderUpgrade(button, row)
    renderRaid(button, row)
    ns.AltLines.render(button, row, GearRows.baseHeight(row), contentLeft())
    GearRows.mark(button)
end
