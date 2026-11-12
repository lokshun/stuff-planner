-- CONTRAT
-- Fenêtre du journal de progression (FloatingFrame) : score porté par niveau en barres (HistoryPresenter),
-- dernières améliorations. Charger après FloatingFrame.lua, History.lua, HistoryPresenter.lua, NameAsker.lua.
--   ns.HistoryChart.toggle() : affiche ou cache ; /splan journal. Jamais en combat (commande reportée).
-- Rafraîchie à l'affichage, sur SP_HISTORY_CHANGED et SP_PROFILE_CHANGED (fenêtre affichée seulement).
-- Survol d'une barre : niveau et score ; d'une amélioration : info-bulle de l'objet.
-- Sauvegarde : StuffPlannerDB.ui.journal = {point, relativePoint, x, y}.

local _, ns = ...

local L = ns.L

local HistoryChart = {}
ns.HistoryChart = HistoryChart

local WIDTH = 340
local CHART_HEIGHT = 110
local AXIS_WIDTH = 36
local ROW_HEIGHT = 20
local BAR_GAP = 1

local frame, summary, chart, maxLabel, minLevelLabel, maxLevelLabel, recentHeader, empty
local bars, rows = {}, {}
local refresh

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

local askName = ns.NameAsker.new(function()
    refresh()
end)

local function hint(owner, text)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(text)
    GameTooltip:Show()
end

local function text(font, color)
    local region = frame:CreateFontString(nil, "OVERLAY", font)
    region:SetJustifyH("LEFT")
    if color then
        setColor(region, color)
    end
    return region
end

local function bar(index)
    if bars[index] then
        return bars[index]
    end
    local button = CreateFrame("Frame", nil, chart)
    button.fill = button:CreateTexture(nil, "ARTWORK")
    button.fill:SetPoint("BOTTOMLEFT")
    button.fill:SetPoint("BOTTOMRIGHT")
    local color = ns.Theme.colors.gain
    button.fill:SetColorTexture(color.r, color.g, color.b, 0.8)
    button:EnableMouse(true)
    button:SetScript("OnEnter", function(self) hint(self, self.label) end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bars[index] = button
    return button
end

local function row(index)
    if rows[index] then
        return rows[index]
    end
    local theme = ns.Theme
    local button = CreateFrame("Button", nil, frame)
    button:SetHeight(ROW_HEIGHT)
    button:SetPoint("TOPLEFT", recentHeader, "BOTTOMLEFT", 0, -2 - (index - 1) * ROW_HEIGHT)
    button:SetPoint("RIGHT", frame, "RIGHT", -theme.spacing.padding, 0)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(16, 16)
    button.icon:SetPoint("LEFT")
    button.text = button:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    button.text:SetPoint("RIGHT")
    button.text:SetJustifyH("RIGHT")
    button.name = button:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    button.name:SetPoint("LEFT", button.icon, "RIGHT", theme.spacing.gap, 0)
    button.name:SetPoint("RIGHT", button.text, "LEFT", -theme.spacing.gap, 0)
    button.name:SetJustifyH("LEFT")
    button.name:SetWordWrap(false)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. self.itemID)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[index] = button
    return button
end

local function create()
    local theme = ns.Theme
    local pad = theme.spacing.padding
    frame = ns.FloatingFrame.new({ width = WIDTH, alpha = 0.9, saved = function()
        return ns.DB.account("ui", "journal")
    end, default = { point = "CENTER", x = 0, y = 80 } })
    frame:SetFrameStrata("MEDIUM")
    local title = text(theme.fonts.header, theme.colors.title)
    title:SetPoint("TOPLEFT", pad, -pad)
    title:SetText(L.JOURNAL_TITLE)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    summary = text(theme.fonts.small, theme.colors.text)
    summary:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    summary:SetPoint("RIGHT", frame, "RIGHT", -pad, 0)
    chart = CreateFrame("Frame", nil, frame)
    chart:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", AXIS_WIDTH, -theme.spacing.gap)
    chart:SetPoint("RIGHT", frame, "RIGHT", -pad, 0)
    chart:SetHeight(CHART_HEIGHT)
    local back = chart:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(1, 1, 1, 0.05)
    maxLabel = text(theme.fonts.small, theme.colors.muted)
    maxLabel:SetPoint("TOPRIGHT", chart, "TOPLEFT", -4, 0)
    minLevelLabel = text(theme.fonts.small, theme.colors.muted)
    minLevelLabel:SetPoint("TOPLEFT", chart, "BOTTOMLEFT", 0, -2)
    maxLevelLabel = text(theme.fonts.small, theme.colors.muted)
    maxLevelLabel:SetPoint("TOPRIGHT", chart, "BOTTOMRIGHT", 0, -2)
    recentHeader = text(theme.fonts.header, theme.colors.title)
    recentHeader:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -CHART_HEIGHT - 2 * theme.spacing.gap - 14)
    recentHeader:SetText(L.JOURNAL_RECENT)
    empty = text(theme.fonts.small, theme.colors.muted)
    empty:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, 0)
    empty:SetPoint("RIGHT", frame, "RIGHT", -pad, 0)
    frame:Hide()
end

local function renderBars(view)
    local count = #view.bars
    local width = WIDTH - AXIS_WIDTH - 2 * ns.Theme.spacing.padding
    local barWidth = count > 0 and math.max(1, width / count - BAR_GAP) or 0
    for index = 1, math.max(count, #bars) do
        local data = view.bars[index]
        local button = bar(index)
        button:SetShown(data ~= nil)
        if data then
            button:ClearAllPoints()
            button:SetPoint("BOTTOMLEFT", (index - 1) * (barWidth + BAR_GAP), 0)
            button:SetSize(barWidth, CHART_HEIGHT)
            button.fill:SetHeight(math.max(1, data.ratio * CHART_HEIGHT))
            button.label = data.label
        end
    end
end

local function renderRecent(view)
    for index = 1, math.max(#view.recent, #rows) do
        local data = view.recent[index]
        local button = row(index)
        button:SetShown(data ~= nil)
        if data then
            askName("item", data.itemID)
            button.itemID = data.itemID
            button.icon:SetTexture(data.icon)
            button.name:SetText(data.name)
            setColor(button.name, data.nameColor)
            button.text:SetText(data.text)
            setColor(button.text, ns.Theme.colors.gain)
        end
    end
    return #view.recent
end

function refresh()
    if not frame or not frame:IsShown() or InCombatLockdown() then
        return
    end
    local profileID = ns.Profiles.activeID()
    local view = ns.HistoryPresenter.build(ns.History.entries(), profileID, ns.Data)
    local message = not profileID and L.JOURNAL_NO_PROFILE or view.empty
    empty:SetText(message or "")
    empty:SetShown(message ~= nil)
    local shown = message == nil
    for _, region in ipairs({ summary, chart, maxLabel, minLevelLabel, maxLevelLabel, recentHeader }) do
        region:SetShown(shown)
    end
    if not shown then
        renderRecent({ recent = {} })
        frame:SetHeight(80)
        return
    end
    summary:SetText(view.summary)
    maxLabel:SetText(view.maxScore)
    minLevelLabel:SetText(view.minLevel)
    maxLevelLabel:SetText(view.maxLevel)
    renderBars(view)
    local count = renderRecent(view)
    recentHeader:SetShown(count > 0)
    frame:SetHeight(110 + CHART_HEIGHT + count * ROW_HEIGHT)
end

function HistoryChart.toggle()
    if InCombatLockdown() then
        return
    end
    if not frame then
        create()
    end
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        ns.History.record()
        refresh()
    end
end

ns:On("SP_HISTORY_CHANGED", refresh)
ns:On("SP_PROFILE_CHANGED", refresh)
ns:RegisterCommand("journal", HistoryChart.toggle, "JOURNAL_COMMAND_HELP")
