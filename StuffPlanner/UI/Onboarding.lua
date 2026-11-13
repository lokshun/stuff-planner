-- CONTRAT
-- Assistant de bienvenue en 4 étapes : présentation, choix du profil de poids, tour des pages, cadre
-- flottant et surfaces (info-bulles, pastilles, halo, aide « ? »).
-- Charger après Options.lua, Skin.lua, Profiles/Manager.lua, ProfilePresenter.lua et Compat.lua.
--   ns.Onboarding.show() -> ouvre l'assistant à l'étape 1 (hors combat seulement)
-- Ouvert une fois par personnage, ONBOARD_DELAY s après PLAYER_LOGIN, hors combat ;
-- StuffPlannerCharDB.onboarded = true dès qu'il est fermé (Terminer, croix ou Échap).
-- Commande : /splan welcome. Étape 1 : habillage (option window.skin, Carnet d'aventurier ou Blizzard) et,
-- s'il diffère de l'habillage en cours (Skin.pending), bouton de rechargement (hors combat).
-- Étape 2 : une ligne par spé (ProfilePresenter.grid) : nom, puis un bouton par phase (Montée de niveau,
-- Niveau 60 ; ns.Profiles.set), profils personnalisés ensuite ; au plus MAX_ROWS lignes ; message si la classe
-- n'a pas de profil. Texte des boutons borné à leur largeur (coupé par « … »).
-- Étape 3 : une ligne par page (PageTipPresenter.list de MainFrame.pages) : icône, nom, à quoi elle sert.
-- Ouvrir l'assistant réaffiche les astuces des pages (ns.PageTip.reset).

local _, ns = ...

local L = ns.L

local Onboarding = {}
ns.Onboarding = Onboarding

local WIDTH, HEIGHT = 440, 370
local STEPS = 4
local ONBOARD_DELAY = 3
local PORTRAIT = ns.ICON -- logo de l'addon
local LABEL_WIDTH, CELL_WIDTH, BUTTON_HEIGHT = 130, 130, 22
local ROW_GAP, COLUMN_GAP, TEXT_INSET = 4, 8, 6
local MAX_ROWS = 5
local PAGE_ROW, PAGE_ICON, PAGE_NAME = 26, 18, 96
local SKINS = { { "notebook", "OPTIONS_SKIN_NOTEBOOK" }, { "blizzard", "OPTIONS_SKIN_BLIZZARD" } }

local frame, stepText, bodyText, backButton, nextButton
local cells, labels, pageRows = {}, {}, {}
local step = 1

local function markDone()
    ns.DB.char().onboarded = true
end

local function fit(button, width)
    button:SetSize(width, BUTTON_HEIGHT)
    local text = button:GetFontString()
    text:ClearAllPoints()
    text:SetPoint("LEFT", TEXT_INSET, 0)
    text:SetPoint("RIGHT", -TEXT_INSET, 0)
    text:SetWordWrap(false)
end

local function rowOffset(row)
    return -ns.Theme.spacing.gap - (row - 1) * (BUTTON_HEIGHT + ROW_GAP)
end

-- Libellé à gauche de la ligne `row`.
local function rowLabel(row, text)
    local label = labels[row]
    if not label then
        label = frame:CreateFontString(nil, "OVERLAY", ns.Theme.fonts.body)
        label:SetWidth(LABEL_WIDTH)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        labels[row] = label
    end
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", bodyText, "BOTTOMLEFT", 0, rowOffset(row) - 4)
    label:SetText(text)
    label:Show()
end

-- Bouton n° `index` (pool), en ligne `row`, colonne `column` (0 = sous le libellé, 1 et 2 à sa droite).
local function cell(index, row, column, width, text, enabled, onClick)
    local button = cells[index]
    if not button then
        button = ns.Skin.button(frame)
        cells[index] = button
    end
    fit(button, width)
    button:ClearAllPoints()
    local x = column == 0 and 0 or LABEL_WIDTH + COLUMN_GAP + (column - 1) * (CELL_WIDTH + COLUMN_GAP)
    button:SetPoint("TOPLEFT", bodyText, "BOTTOMLEFT", x, rowOffset(row))
    button:SetText(text)
    button:SetEnabled(enabled)
    button:SetScript("OnClick", onClick)
    button:Show()
end

local render

local function profileCells()
    local grid = ns.ProfilePresenter.grid(ns.Profiles.available(), ns.Profiles.get, ns.Profiles.activeID())
    local index, row = 0, 0
    local function choose(id)
        return function()
            ns.Profiles.set(id)
            render()
        end
    end
    for _, spec in ipairs(grid.specs) do
        if row >= MAX_ROWS then
            break
        end
        row = row + 1
        rowLabel(row, spec.label)
        for column, phase in ipairs(grid.phases) do
            local entry = spec.cells[phase.key]
            if entry then
                index = index + 1
                cell(index, row, column, CELL_WIDTH, phase.label, not entry.active, choose(entry.id))
            end
        end
    end
    for _, extra in ipairs(grid.extras) do
        if row >= MAX_ROWS then
            break
        end
        row = row + 1
        index = index + 1
        cell(index, row, 0, LABEL_WIDTH + COLUMN_GAP + 2 * CELL_WIDTH + COLUMN_GAP, extra.label, not extra.active,
            choose(extra.id))
    end
    return index, row, #grid.specs + #grid.extras
end

local function pageRow(index)
    local row = pageRows[index]
    if not row then
        local theme = ns.Theme
        row = CreateFrame("Frame", nil, frame)
        row:SetHeight(PAGE_ROW)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(PAGE_ICON, PAGE_ICON)
        row.icon:SetPoint("LEFT")
        row.name = row:CreateFontString(nil, "OVERLAY", theme.fonts.body)
        row.name:SetPoint("LEFT", row.icon, "RIGHT", TEXT_INSET, 0)
        row.name:SetWidth(PAGE_NAME)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.text = row:CreateFontString(nil, "OVERLAY", theme.fonts.small)
        row.text:SetPoint("LEFT", row.name, "RIGHT", TEXT_INSET, 0)
        row.text:SetPoint("RIGHT")
        row.text:SetHeight(PAGE_ROW)
        row.text:SetJustifyH("LEFT")
        local muted = theme.colors.muted
        row.text:SetTextColor(muted.r, muted.g, muted.b)
        pageRows[index] = row
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", bodyText, "BOTTOMLEFT", 0, -ns.Theme.spacing.gap - (index - 1) * PAGE_ROW)
    row:SetPoint("RIGHT", bodyText, "RIGHT")
    return row
end

local function pageCells()
    for index, page in ipairs(ns.PageTipPresenter.list(ns.MainFrame.pages())) do
        local row = pageRow(index)
        row.icon:SetTexture(page.icon)
        row.name:SetText(page.label)
        row.text:SetText(page.text)
        row:Show()
    end
end

local function reload()
    if not InCombatLockdown() then
        ReloadUI()
    end
end

local function skinCells()
    rowLabel(1, L.OPTION_WINDOW_SKIN)
    local current = ns.Options.get("window.skin")
    for column, skin in ipairs(SKINS) do
        cell(column, 1, column, CELL_WIDTH, L[skin[2]], current ~= skin[1], function()
            ns.Options.set("window.skin", skin[1])
            render()
        end)
    end
    if not ns.Skin.pending() then
        return
    end
    cell(#SKINS + 1, 2, 0, LABEL_WIDTH + COLUMN_GAP + 2 * CELL_WIDTH + COLUMN_GAP, L.OPTIONS_RELOAD, true, reload)
end

-- Tout est masqué, puis l'étape réaffiche ses libellés et boutons ; renvoie le nombre de profils (étape 2).
local function renderCells()
    for _, region in ipairs(cells) do
        region:Hide()
    end
    for _, region in ipairs(labels) do
        region:Hide()
    end
    for _, region in ipairs(pageRows) do
        region:Hide()
    end
    if step == 1 then
        skinCells()
    elseif step == 2 then
        return select(3, profileCells())
    elseif step == 3 then
        pageCells()
    end
    return 0
end

function render()
    stepText:SetText(L.ONBOARD_STEP:format(step, STEPS))
    local body = L["ONBOARD_STEP" .. step]
    local count = renderCells()
    if step == 2 and count == 0 then
        body = body .. "\n\n" .. L.ONBOARD_NO_PROFILE
    end
    bodyText:SetText(body)
    backButton:SetEnabled(step > 1)
    nextButton:SetText(step < STEPS and L.ONBOARD_NEXT or L.ONBOARD_DONE)
end

local function onNext()
    if step < STEPS then
        step = step + 1
        render()
    else
        frame:Hide()
    end
end

local function onBack()
    step = math.max(1, step - 1)
    render()
end

local function onKeyDown(self, key)
    local escape = key == "ESCAPE"
    self:SetPropagateKeyboardInput(not escape)
    if escape then
        self:Hide()
    end
end

local function button(text, onClick)
    local result = ns.Skin.button(frame)
    result:SetText(text)
    result:SetSize(100, BUTTON_HEIGHT)
    result:SetScript("OnClick", onClick)
    return result
end

local function create()
    local theme = ns.Theme
    frame = ns.Skin.window({ width = WIDTH, height = HEIGHT, title = L.ONBOARD_TITLE, portrait = PORTRAIT,
        strata = "DIALOG" })
    frame:SetPoint("CENTER", 0, 80)
    frame:EnableKeyboard(true)
    frame:SetScript("OnKeyDown", onKeyDown)
    stepText = frame:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    stepText:SetPoint("TOPLEFT", 70, -34)
    stepText:SetTextColor(theme.colors.muted.r, theme.colors.muted.g, theme.colors.muted.b)
    bodyText = frame:CreateFontString(nil, "OVERLAY", theme.fonts.body)
    bodyText:SetPoint("TOPLEFT", 16, -70)
    bodyText:SetPoint("RIGHT", -16, 0)
    bodyText:SetJustifyH("LEFT")
    bodyText:SetJustifyV("TOP")
    bodyText:SetSpacing(2)
    nextButton = button(L.ONBOARD_NEXT, onNext)
    nextButton:SetPoint("BOTTOMRIGHT", -12, 12)
    backButton = button(L.ONBOARD_BACK, onBack)
    backButton:SetPoint("RIGHT", nextButton, "LEFT", -theme.spacing.gap, 0)
    frame:Hide()
    frame:SetScript("OnHide", markDone)
end

function Onboarding.show()
    if InCombatLockdown() then
        return
    end
    if not frame then
        create()
    end
    step = 1
    ns.PageTip.reset()
    render()
    frame:Show()
end

ns:RegisterCommand("welcome", Onboarding.show, "WELCOME_COMMAND_HELP")

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
    if ns.DB.peek("char", "onboarded") then
        return
    end
    C_Timer.After(ONBOARD_DELAY, function()
        ns:RunOutOfCombat(Onboarding.show)
    end)
end)
