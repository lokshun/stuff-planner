-- CONTRAT
-- Poids d'un profil en barres horizontales (onglet Profil). Cadres seulement (vérifiés en jeu).
-- Charger après Theme.lua.
--   ns.WeightBars.create(parent) -> frame (largeur WIDTH)
--   ns.WeightBars.render(rows) -> hauteur (pixels) ; rows = ProfilePresenter.weightRows ; une ligne
--     par stat : libellé, barre (fraction de la plus longue), valeur et plafond
--   ns.WeightBars.WIDTH

local _, ns = ...

local WeightBars = {}
ns.WeightBars = WeightBars

local LABEL_WIDTH, BAR_WIDTH, VALUE_WIDTH = 140, 150, 110
local LINE_HEIGHT, BAR_HEIGHT = 16, 10
local MIN_BAR = 1

WeightBars.WIDTH = LABEL_WIDTH + BAR_WIDTH + VALUE_WIDTH

local frame
local lines = {}

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

local function newLine(index)
    local theme = ns.Theme
    local y = -(index - 1) * LINE_HEIGHT
    local line = {}
    line.label = frame:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    line.label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, y)
    line.label:SetSize(LABEL_WIDTH - 4, LINE_HEIGHT)
    line.label:SetJustifyH("LEFT")
    line.label:SetWordWrap(false)
    line.track = frame:CreateTexture(nil, "BACKGROUND")
    line.track:SetPoint("TOPLEFT", frame, "TOPLEFT", LABEL_WIDTH, y - (LINE_HEIGHT - BAR_HEIGHT) / 2)
    line.track:SetSize(BAR_WIDTH, BAR_HEIGHT)
    local border = theme.colors.border
    line.track:SetColorTexture(border.r, border.g, border.b, 0.12)
    line.bar = frame:CreateTexture(nil, "ARTWORK")
    line.bar:SetPoint("TOPLEFT", line.track, "TOPLEFT")
    line.bar:SetHeight(BAR_HEIGHT)
    local gain = theme.colors.gain
    line.bar:SetColorTexture(gain.r, gain.g, gain.b, 0.8)
    line.value = frame:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    line.value:SetPoint("TOPLEFT", frame, "TOPLEFT", LABEL_WIDTH + BAR_WIDTH + 6, y)
    line.value:SetSize(VALUE_WIDTH - 6, LINE_HEIGHT)
    line.value:SetJustifyH("LEFT")
    line.value:SetWordWrap(false)
    setColor(line.value, theme.colors.muted)
    lines[index] = line
    return line
end

local function setShown(line, shown)
    line.label:SetShown(shown)
    line.track:SetShown(shown)
    line.bar:SetShown(shown)
    line.value:SetShown(shown)
end

function WeightBars.create(parent)
    frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(WeightBars.WIDTH, 1)
    return frame
end

function WeightBars.render(rows)
    for index, row in ipairs(rows) do
        local line = lines[index] or newLine(index)
        line.label:SetText(row.label)
        setColor(line.label, ns.Theme.colors.text)
        line.bar:SetWidth(math.max(MIN_BAR, row.fraction * BAR_WIDTH))
        line.value:SetText(row.capText ~= "" and (row.valueText .. " (" .. row.capText .. ")") or row.valueText)
        setShown(line, true)
        line.bar:SetShown(row.fraction > 0)
    end
    for index = #rows + 1, #lines do
        setShown(lines[index], false)
    end
    local height = math.max(1, #rows * LINE_HEIGHT)
    frame:SetHeight(height)
    return height
end
