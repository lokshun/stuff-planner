-- CONTRAT
-- Bloc « Progression » de la page Journal : score porté par niveau en barres (HistoryPresenter), dernières
-- améliorations (lignes ns.ItemRow). Cadres seulement. Charger après ItemRow.lua, History.lua,
-- HistoryPresenter.lua, NameAsker.lua.
--   ns.HistoryChart.create(parent) -> frame : à ancrer par l'appelant (largeur du parent)
--   ns.HistoryChart.refresh() -> hauteur occupée (pixels) ; profil actif seul (L.JOURNAL_NO_PROFILE sinon)
-- Survol d'une barre : niveau et score ; d'une amélioration : info-bulle de l'objet, clic = source.

local _, ns = ...

local L = ns.L

local HistoryChart = {}
ns.HistoryChart = HistoryChart

local CHART_HEIGHT = 90
local AXIS_WIDTH = 36
local ROW_HEIGHT = 20
local BAR_GAP = 1
local SUMMARY_HEIGHT = 16
local LABEL_HEIGHT = 16
local HEADER_HEIGHT = 18
local EMPTY_HEIGHT = 40
local DEFAULT_WIDTH = 400

local frame, summary, chart, maxLabel, minLevelLabel, maxLevelLabel, recentHeader, empty
local bars, rows = {}, {}

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

local askName = ns.NameAsker.new(function()
    ns.MainFrame.refresh()
end)

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
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.label)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bars[index] = button
    return button
end

local ROW_OPTS = { iconSize = 16, compact = true, nameWidth = 200, gainWidth = 170, height = ROW_HEIGHT }

local function row(index)
    if rows[index] then
        return rows[index]
    end
    local button = ns.ItemRow.new(frame, ROW_OPTS)
    button:SetPoint("TOPLEFT", recentHeader, "BOTTOMLEFT", 0, -2 - (index - 1) * ROW_HEIGHT)
    button:SetPoint("RIGHT", frame, "RIGHT")
    rows[index] = button
    return button
end

function HistoryChart.create(parent)
    local theme = ns.Theme
    frame = CreateFrame("Frame", nil, parent)
    summary = text(theme.fonts.small, theme.colors.text)
    summary:SetPoint("TOPLEFT")
    summary:SetPoint("RIGHT")
    summary:SetHeight(SUMMARY_HEIGHT)
    chart = CreateFrame("Frame", nil, frame)
    chart:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", AXIS_WIDTH, 0)
    chart:SetPoint("RIGHT")
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
    recentHeader:SetPoint("TOPLEFT", chart, "BOTTOMLEFT", -AXIS_WIDTH, -LABEL_HEIGHT)
    recentHeader:SetHeight(HEADER_HEIGHT)
    recentHeader:SetText(L.JOURNAL_RECENT)
    empty = text(theme.fonts.small, theme.colors.muted)
    empty:SetPoint("TOPLEFT")
    empty:SetPoint("RIGHT")
    empty:SetWordWrap(true)
    return frame
end

local function renderBars(view)
    local count = #view.bars
    local width = chart:GetWidth()
    width = (width and width > 0) and width or DEFAULT_WIDTH - AXIS_WIDTH
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

local function renderRecent(recent)
    for index = 1, math.max(#recent, #rows) do
        local data = recent[index]
        local button = row(index)
        button:SetShown(data ~= nil)
        if data then
            askName("item", data.itemID)
            ns.ItemRow.set(button, { itemID = data.itemID, icon = data.icon, name = data.name,
                nameColor = data.nameColor, gain = data.text, gainColor = ns.Theme.colors.gain })
        end
    end
    return #recent
end

function HistoryChart.refresh()
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
        renderRecent({})
        frame:SetHeight(EMPTY_HEIGHT)
        return EMPTY_HEIGHT
    end
    summary:SetText(view.summary)
    maxLabel:SetText(view.maxScore)
    minLevelLabel:SetText(view.minLevel)
    maxLevelLabel:SetText(view.maxLevel)
    renderBars(view)
    local count = renderRecent(view.recent)
    recentHeader:SetShown(count > 0)
    local height = SUMMARY_HEIGHT + CHART_HEIGHT + LABEL_HEIGHT
        + (count > 0 and HEADER_HEIGHT + 2 + count * ROW_HEIGHT or 0)
    frame:SetHeight(height)
    return height
end
