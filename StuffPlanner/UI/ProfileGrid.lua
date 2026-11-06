-- CONTRAT
-- Tableau de choix du profil de l'onglet Profil : « Choix automatique », une ligne par spé
-- (colonnes montée de niveau et 60), puis les profils personnalisés. Cadres seulement (vérifiés en jeu).
-- Charger après Theme.lua, ProfilePresenter.lua et Profiles/Customs.lua.
--   ns.ProfileGrid.create(parent) -> frame
--   ns.ProfileGrid.render(grid, onSelect, describe?) -> hauteur (pixels) ; grid = ProfilePresenter.grid ;
--     onSelect(id | nil) au clic (nil = automatique) ; describe(id | nil) -> ProfilePresenter.tooltip | nil,
--     affiché dans GameTooltip au survol d'une case ; actions? = {rename(id, text) -> bool, delete(id)} :
--     boutons Renommer (champ sur la case, Entrée garde, Échap annule) et Supprimer (second clic sur
--     « Confirmer ? ») à droite du profil personnalisé actif
-- Case active : fond et texte verts. Aucune case n'est désactivée (cliquer l'active ne change rien).

local _, ns = ...

local L = ns.L

local ProfileGrid = {}
ns.ProfileGrid = ProfileGrid

local LABEL_WIDTH, CELL_WIDTH, CELL_HEIGHT = 120, 130, 22
local HEADER_HEIGHT = 16

local ACTION_WIDTH = 86

local frame
local cells, labels, columns = {}, {}, {}
local used
local renameButton, deleteButton, nameBox
local editingID, armedID -- profil en cours de renommage ; profil dont la suppression attend confirmation

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

local function showTooltip(cell)
    local tip = cell.describe and cell.describe(cell.profileID)
    if not tip then
        return
    end
    local colors = ns.Theme.colors
    GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
    GameTooltip:AddLine(tip.title, colors.title.r, colors.title.g, colors.title.b)
    for _, line in ipairs(tip.lines) do
        local right = line.capText ~= "" and line.valueText .. "  (" .. line.capText .. ")" or line.valueText
        GameTooltip:AddDoubleLine(line.label, right, colors.text.r, colors.text.g, colors.text.b,
            colors.muted.r, colors.muted.g, colors.muted.b)
    end
    if tip.more > 0 then
        GameTooltip:AddLine(L.PROFILE_TOOLTIP_MORE:format(tip.more), colors.muted.r, colors.muted.g, colors.muted.b)
    end
    GameTooltip:Show()
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
    cell:SetScript("OnEnter", showTooltip)
    cell:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return cell
end

-- Case suivante, placée en (x, y) depuis le haut à gauche du tableau.
local function placeCell(x, y, width, text, active, id, onSelect, describe)
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
    cell.profileID, cell.onSelect, cell.describe = id, onSelect, describe
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

local function actionButton(text, onClick)
    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetSize(ACTION_WIDTH, CELL_HEIGHT)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function closeNameBox()
    editingID = nil
    nameBox:ClearFocus()
    nameBox:Hide()
end

local function onRename(self)
    editingID, armedID = self.profileID, nil
    deleteButton:SetText(L.PROFILE_DELETE)
    nameBox:ClearAllPoints()
    nameBox:SetPoint("TOPLEFT", self.cell, "TOPLEFT", 6, 0)
    nameBox:SetPoint("BOTTOMRIGHT", self.cell, "BOTTOMRIGHT", -2, 0)
    nameBox:SetFrameLevel(self.cell:GetFrameLevel() + 5)
    nameBox:SetText(self.label)
    nameBox:Show()
    nameBox:SetFocus()
    nameBox:HighlightText()
end

local function onDelete(self)
    if armedID == self.profileID then
        armedID = nil
        self:SetText(L.PROFILE_DELETE)
        self.actions.delete(self.profileID)
    else
        armedID = self.profileID
        self:SetText(L.PROFILE_DELETE_CONFIRM)
    end
end

local function createActions()
    renameButton = actionButton(L.PROFILE_RENAME, onRename)
    deleteButton = actionButton(L.PROFILE_DELETE, onDelete)
    nameBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(ns.Customs.NAME_MAX)
    nameBox:SetScript("OnEnterPressed", function(self)
        if renameButton.actions.rename(editingID, self:GetText()) then
            closeNameBox()
        end
    end)
    nameBox:SetScript("OnEscapePressed", closeNameBox)
    nameBox:SetScript("OnEditFocusLost", closeNameBox)
    nameBox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L.PROFILE_RENAME_HINT, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    nameBox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    nameBox:Hide()
end

-- Boutons Renommer / Supprimer à droite de la case du profil personnalisé actif.
local function placeActions(x, y, extra, actions)
    local cell = cells[used]
    local gap = ns.Theme.spacing.gap / 2
    renameButton:ClearAllPoints()
    renameButton:SetPoint("TOPLEFT", frame, "TOPLEFT", x + gap, y)
    deleteButton:ClearAllPoints()
    deleteButton:SetPoint("LEFT", renameButton, "RIGHT", gap, 0)
    for _, button in ipairs({ renameButton, deleteButton }) do
        button.profileID, button.label, button.cell, button.actions = extra.id, extra.label, cell, actions
        button:Show()
    end
    if armedID ~= extra.id then
        armedID = nil
        deleteButton:SetText(L.PROFILE_DELETE)
    end
    if editingID ~= extra.id and editingID ~= nil then
        closeNameBox()
    end
end

function ProfileGrid.create(parent)
    frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(LABEL_WIDTH + 2 * CELL_WIDTH, 1)
    createActions()
    return frame
end

function ProfileGrid.render(grid, onSelect, describe, actions)
    local theme = ns.Theme
    local gap = theme.spacing.gap / 2
    used = 0
    placeCell(0, 0, LABEL_WIDTH + 2 * CELL_WIDTH + gap, grid.auto.label, grid.auto.active, nil, onSelect,
        describe)
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
                    cell.active, cell.id, onSelect, describe)
            end
        end
        y = y - CELL_HEIGHT - gap
    end
    for row = #grid.specs + 1, #labels do
        labels[row]:Hide()
    end
    local withActions = false
    for _, extra in ipairs(grid.extras) do
        y = y - gap
        local width = LABEL_WIDTH + 2 * CELL_WIDTH + gap
        local editable = extra.active and actions ~= nil
        if editable then
            width = width - 2 * (ACTION_WIDTH + gap)
        end
        placeCell(0, y, width, extra.label, extra.active, extra.id, onSelect, describe)
        if editable then
            placeActions(width, y, extra, actions)
            withActions = true
        end
        y = y - CELL_HEIGHT
    end
    if not withActions then
        renameButton:Hide()
        deleteButton:Hide()
        armedID = nil
        if editingID then
            closeNameBox()
        end
    end
    for index = used + 1, #cells do
        cells[index]:Hide()
    end
    local height = -y
    frame:SetHeight(height)
    return height
end
