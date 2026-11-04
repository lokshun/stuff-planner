-- CONTRAT
-- Tableau de choix du profil de l'onglet Profil : « Choix automatique », une ligne par spé
-- (colonnes montée de niveau et 60), puis les profils personnalisés. Cadres seulement (vérifiés en jeu).
-- Charger après Theme.lua et ProfilePresenter.lua.
--   ns.ProfileGrid.create(parent) -> frame
--   ns.ProfileGrid.render(grid, onSelect) -> hauteur (pixels) ; grid = ProfilePresenter.grid ;
--     onSelect(id | nil) au clic (nil = automatique)
-- Case active : fond et texte verts. Aucune case n'est désactivée (cliquer l'active ne change rien).

local _, ns = ...

local ProfileGrid = {}
ns.ProfileGrid = ProfileGrid

local LABEL_WIDTH, CELL_WIDTH, CELL_HEIGHT = 120, 130, 22
local HEADER_HEIGHT = 16

local frame
local cells, labels, columns = {}, {}, {}
local used

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

local function newCell()
    local theme = ns.Theme
    local cell = CreateFrame("Button", nil, frame)
    cell:SetHeight(CELL_HEIGHT)
    cell.bg = cell:CreateTexture(nil, "BACKGROUND")
    cell.bg:SetAllPoints()
    local highlight = cell:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)
    cell.text = cell:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    cell.text:SetPoint("LEFT", 6, 0)
    cell.text:SetPoint("RIGHT", -6, 0)
    cell.text:SetJustifyH("CENTER")
    cell.text:SetWordWrap(false)
    cell:SetScript("OnClick", function(self)
        self.onSelect(self.profileID)
    end)
    return cell
end

-- Case suivante, placée en (x, y) depuis le haut à gauche du tableau.
local function placeCell(x, y, width, text, active, id, onSelect)
    used = used + 1
    local cell = cells[used] or newCell()
    cells[used] = cell
    local theme = ns.Theme
    cell:ClearAllPoints()
    cell:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
    cell:SetWidth(width)
    cell.text:SetText(text)
    local tint = active and theme.colors.gain or theme.colors.border
    cell.bg:SetColorTexture(tint.r, tint.g, tint.b, active and 0.35 or 0.1)
    setColor(cell.text, active and theme.colors.gain or theme.colors.text)
    cell.profileID, cell.onSelect = id, onSelect
    cell:Show()
end

local function fontString(pool, index, font)
    local text = pool[index]
    if not text then
        text = frame:CreateFontString(nil, "OVERLAY", font)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(false)
        pool[index] = text
    end
    text:Show()
    return text
end

function ProfileGrid.create(parent)
    frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(LABEL_WIDTH + 2 * CELL_WIDTH, 1)
    return frame
end

function ProfileGrid.render(grid, onSelect)
    local theme = ns.Theme
    local gap = theme.spacing.gap / 2
    used = 0
    placeCell(0, 0, LABEL_WIDTH + 2 * CELL_WIDTH + gap, grid.auto.label, grid.auto.active, nil, onSelect)
    local y = -(CELL_HEIGHT + theme.spacing.gap)
    for index, phase in ipairs(grid.phases) do
        local column = fontString(columns, index, theme.fonts.small)
        column:ClearAllPoints()
        column:SetPoint("TOPLEFT", frame, "TOPLEFT", LABEL_WIDTH + (index - 1) * (CELL_WIDTH + gap), y)
        column:SetWidth(CELL_WIDTH)
        column:SetJustifyH("CENTER")
        column:SetText(phase.label)
        setColor(column, theme.colors.muted)
    end
    y = y - HEADER_HEIGHT
    for row, spec in ipairs(grid.specs) do
        local label = fontString(labels, row, theme.fonts.body)
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, y - 4)
        label:SetWidth(LABEL_WIDTH - gap)
        label:SetText(spec.label)
        setColor(label, theme.colors.text)
        for index, phase in ipairs(grid.phases) do
            local cell = spec.cells[phase.key]
            if cell then
                placeCell(LABEL_WIDTH + (index - 1) * (CELL_WIDTH + gap), y, CELL_WIDTH, phase.label,
                    cell.active, cell.id, onSelect)
            end
        end
        y = y - CELL_HEIGHT - gap
    end
    for row = #grid.specs + 1, #labels do
        labels[row]:Hide()
    end
    for _, extra in ipairs(grid.extras) do
        y = y - gap
        placeCell(0, y, LABEL_WIDTH + 2 * CELL_WIDTH + gap, extra.label, extra.active, extra.id, onSelect)
        y = y - CELL_HEIGHT
    end
    for index = used + 1, #cells do
        cells[index]:Hide()
    end
    local height = -y
    frame:SetHeight(height)
    return height
end
