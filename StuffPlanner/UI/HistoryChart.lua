-- CONTRAT
-- Bloc « Progression » de la page Journal (HistoryPresenter) : trois tuiles (score actuel, gain depuis le premier
-- relevé, améliorations), courbe du score par niveau sur l'axe 1 → 60 (points reliés par Compat.CreateLine ;
-- points seuls sans l'API), aide sous l'axe si un seul niveau est relevé, dernières améliorations (ns.ItemRow).
-- Cadres seulement. Charger après Compat.lua, ItemRow.lua, History.lua, HistoryPresenter.lua, NameAsker.lua.
--   ns.HistoryChart.create(parent) -> frame : à ancrer par l'appelant (largeur du parent)
--   ns.HistoryChart.refresh() -> hauteur occupée (pixels) ; profil actif seul (L.JOURNAL_NO_PROFILE sinon)
-- Courbe redessinée quand la largeur change. Survol d'un point : niveau et score ; d'une amélioration :
-- info-bulle de l'objet, clic = source.

local _, ns = ...

local L = ns.L

local HistoryChart = {}
ns.HistoryChart = HistoryChart

local TILE_COUNT, TILE_HEIGHT = 3, 40
local CHART_HEIGHT = 90
local CHART_PAD = 8 -- marge haute et basse de la courbe dans le graphique
local AXIS_WIDTH = 36
local ROW_HEIGHT = 20
local LABEL_HEIGHT = 16
local HINT_HEIGHT = 16
local HEADER_HEIGHT = 18
local EMPTY_HEIGHT = 40
local DEFAULT_WIDTH = 400
local DOT_SIZE, DOT_HIT = 7, 14
local LINE_THICKNESS = 2
local DOT_TEXTURE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask" -- disque blanc, teinté
local GUIDES = { 0.5, 1 }

local frame, chart, maxLabel, zeroLabel, hint, recentHeader, empty
local tiles, ticks, dots, lines, rows = {}, {}, {}, {}, {}
local lastView

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

local askName = ns.NameAsker.new(function()
    ns.MainFrame.refresh()
end)

local function text(parent, font, color)
    local region = parent:CreateFontString(nil, "OVERLAY", font)
    region:SetJustifyH("LEFT")
    if color then
        setColor(region, color)
    end
    return region
end

local function faint(parent, alpha)
    local texture = parent:CreateTexture(nil, "BACKGROUND")
    texture:SetColorTexture(1, 1, 1, alpha)
    return texture
end

local function tile(index)
    if tiles[index] then
        return tiles[index]
    end
    local theme = ns.Theme
    local box = CreateFrame("Frame", nil, frame)
    faint(box, 0.05):SetAllPoints()
    box.label = text(box, theme.fonts.small, theme.colors.muted)
    box.label:SetPoint("TOPLEFT", 8, -6)
    box.label:SetPoint("RIGHT", -8, 0)
    box.label:SetWordWrap(false)
    box.value = text(box, theme.fonts.title, theme.colors.title)
    box.value:SetPoint("BOTTOMLEFT", 8, 5)
    tiles[index] = box
    return box
end

local function chartWidth()
    local width = chart:GetWidth()
    return (width and width > 0) and width or DEFAULT_WIDTH - AXIS_WIDTH
end

local function position(point, width)
    return point.x * width, CHART_PAD + point.y * (CHART_HEIGHT - 2 * CHART_PAD)
end

local function dot(index)
    if dots[index] then
        return dots[index]
    end
    local hit = CreateFrame("Frame", nil, chart)
    hit:SetSize(DOT_HIT, DOT_HIT)
    hit:SetFrameLevel(chart:GetFrameLevel() + 2)
    local color = ns.Theme.colors.gain
    hit.disc = hit:CreateTexture(nil, "OVERLAY")
    hit.disc:SetSize(DOT_SIZE, DOT_SIZE)
    hit.disc:SetPoint("CENTER")
    hit.disc:SetTexture(DOT_TEXTURE)
    hit.disc:SetVertexColor(color.r, color.g, color.b)
    hit:EnableMouse(true)
    hit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.label)
        GameTooltip:Show()
    end)
    hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    dots[index] = hit
    return hit
end

local function line(index)
    if lines[index] == nil then
        local created = ns.Compat.CreateLine(chart, "ARTWORK")
        if created then
            local color = ns.Theme.colors.gain
            created:SetThickness(LINE_THICKNESS)
            created:SetColorTexture(color.r, color.g, color.b, 0.85)
        end
        lines[index] = created or false
    end
    return lines[index] or nil
end

local function tick(index)
    if ticks[index] then
        return ticks[index]
    end
    local label = text(frame, ns.Theme.fonts.small, ns.Theme.colors.muted)
    label:SetJustifyH("CENTER")
    ticks[index] = label
    return label
end

local function renderCurve(view)
    local width = chartWidth()
    for index = 1, math.max(#view.points, #dots) do
        local point = view.points[index]
        local hit = dot(index)
        hit:SetShown(point ~= nil)
        if point then
            local x, y = position(point, width)
            hit:ClearAllPoints()
            hit:SetPoint("CENTER", chart, "BOTTOMLEFT", x, y)
            hit.label = point.label
        end
    end
    for index = 1, math.max(#view.points - 1, #lines) do
        local from, to = view.points[index], view.points[index + 1]
        local segment = line(index)
        if segment then
            segment:SetShown(to ~= nil)
            if to then
                segment:SetStartPoint("BOTTOMLEFT", chart, position(from, width))
                segment:SetEndPoint("BOTTOMLEFT", chart, position(to, width))
            end
        end
    end
    for index = 1, math.max(#view.ticks, #ticks) do
        local data = view.ticks[index]
        local label = tick(index)
        label:SetShown(data ~= nil)
        if data then
            label:ClearAllPoints()
            label:SetPoint("TOP", chart, "BOTTOMLEFT", data.x * width, -2)
            label:SetText(data.level)
        end
    end
end

function HistoryChart.create(parent)
    local theme = ns.Theme
    frame = CreateFrame("Frame", nil, parent)
    chart = CreateFrame("Frame", nil, frame)
    chart:SetPoint("TOPLEFT", frame, "TOPLEFT", AXIS_WIDTH, -(TILE_HEIGHT + theme.spacing.gap))
    chart:SetPoint("RIGHT", -8, 0)
    chart:SetHeight(CHART_HEIGHT)
    faint(chart, 0.04):SetAllPoints()
    for _, ratio in ipairs(GUIDES) do
        local guide = faint(chart, 0.08)
        guide:SetHeight(1)
        guide:SetPoint("LEFT", chart, "BOTTOMLEFT", 0, CHART_PAD + ratio * (CHART_HEIGHT - 2 * CHART_PAD))
        guide:SetPoint("RIGHT", chart, "BOTTOMRIGHT", 0, CHART_PAD + ratio * (CHART_HEIGHT - 2 * CHART_PAD))
    end
    maxLabel = text(frame, theme.fonts.small, theme.colors.muted)
    maxLabel:SetPoint("RIGHT", chart, "BOTTOMLEFT", -4, CHART_HEIGHT - CHART_PAD)
    zeroLabel = text(frame, theme.fonts.small, theme.colors.muted)
    zeroLabel:SetPoint("RIGHT", chart, "BOTTOMLEFT", -4, CHART_PAD)
    zeroLabel:SetText("0")
    hint = text(frame, theme.fonts.small, theme.colors.muted)
    hint:SetPoint("TOPLEFT", chart, "BOTTOMLEFT", 0, -LABEL_HEIGHT)
    hint:SetPoint("RIGHT", chart, "RIGHT")
    recentHeader = text(frame, theme.fonts.header, theme.colors.title)
    recentHeader:SetHeight(HEADER_HEIGHT)
    recentHeader:SetText(L.JOURNAL_RECENT)
    empty = text(frame, theme.fonts.small, theme.colors.muted)
    empty:SetPoint("TOPLEFT")
    empty:SetPoint("RIGHT")
    empty:SetWordWrap(true)
    chart:SetScript("OnSizeChanged", function()
        if lastView then
            renderCurve(lastView)
        end
    end)
    return frame
end

local function renderTiles(view)
    local theme = ns.Theme
    local width = ((frame:GetWidth() or 0) > 0 and frame:GetWidth() or DEFAULT_WIDTH)
    local tileWidth = (width - (TILE_COUNT - 1) * theme.spacing.gap) / TILE_COUNT
    for index = 1, TILE_COUNT do
        local data = view.tiles[index]
        local box = tile(index)
        box:SetShown(data ~= nil)
        if data then
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", frame, "TOPLEFT", (index - 1) * (tileWidth + theme.spacing.gap), 0)
            box:SetSize(tileWidth, TILE_HEIGHT)
            box.label:SetText(data.label)
            box.value:SetText(data.value)
            setColor(box.value, index == 2 and theme.colors.gain or theme.colors.title)
        end
    end
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

local function setShown(shown)
    for _, region in ipairs({ chart, maxLabel, zeroLabel, hint, recentHeader }) do
        region:SetShown(shown)
    end
    for _, group in ipairs({ tiles, ticks }) do
        for _, region in ipairs(group) do
            region:SetShown(shown)
        end
    end
end

function HistoryChart.refresh()
    local profileID = ns.Profiles.activeID()
    local view = ns.HistoryPresenter.build(ns.History.entries(), profileID, ns.Data)
    local message = not profileID and L.JOURNAL_NO_PROFILE or view.empty
    empty:SetText(message or "")
    empty:SetShown(message ~= nil)
    setShown(message == nil)
    if message then
        lastView = nil
        renderRecent({})
        frame:SetHeight(EMPTY_HEIGHT)
        return EMPTY_HEIGHT
    end
    lastView = view
    renderTiles(view)
    maxLabel:SetText(view.maxScore)
    renderCurve(view)
    hint:SetText(view.hint or "")
    hint:SetShown(view.hint ~= nil)
    local below = LABEL_HEIGHT + (view.hint and HINT_HEIGHT or 0)
    recentHeader:ClearAllPoints()
    recentHeader:SetPoint("TOPLEFT", chart, "BOTTOMLEFT", -AXIS_WIDTH, -below)
    local count = renderRecent(view.recent)
    recentHeader:SetShown(count > 0)
    local height = TILE_HEIGHT + ns.Theme.spacing.gap + CHART_HEIGHT + below
        + (count > 0 and HEADER_HEIGHT + 2 + count * ROW_HEIGHT or 0)
    frame:SetHeight(height)
    return height
end
