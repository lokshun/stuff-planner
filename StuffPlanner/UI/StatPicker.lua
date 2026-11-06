-- CONTRAT
-- Menu de choix d'une stat (« Mes stats »), une colonne par groupe. Cadres seulement (vérifiés en jeu) ;
-- textures simples, sans BackdropTemplate ni UIDropDownMenu : même rendu sur Forever et Classic Era.
-- Charger après Theme.lua, avant PriorityList.lua.
--   ns.StatPicker.open(anchor, groups, onPick) : groups = ProfilePresenter.statGroups ; menu sous anchor
--     (gardé dans l'écran) ; onPick(key) après fermeture ; rien en combat ni si groups est vide
--   ns.StatPicker.close() ; fermé aussi par Échap, clic hors du menu et entrée en combat

local _, ns = ...

local StatPicker = {}
ns.StatPicker = StatPicker

local COLUMN_WIDTH, LINE_HEIGHT, PADDING = 130, 16, 8

local blocker, menu, onPickHandler
local headers, buttons = {}, {}

function StatPicker.close()
    if blocker then
        blocker:Hide()
    end
end

local function onKeyDown(self, key)
    if key == "ESCAPE" then
        self:SetPropagateKeyboardInput(false)
        StatPicker.close()
    end
end

local function create()
    local colors = ns.Theme.colors
    -- Écran entier, invisible : un clic hors du menu le ferme.
    blocker = CreateFrame("Button", nil, UIParent)
    blocker:SetAllPoints(UIParent)
    blocker:SetFrameStrata("FULLSCREEN_DIALOG")
    blocker:SetScript("OnClick", StatPicker.close)
    blocker:Hide()
    menu = CreateFrame("Frame", nil, blocker)
    menu:SetFrameLevel(blocker:GetFrameLevel() + 10)
    menu:EnableMouse(true)
    menu:SetClampedToScreen(true)
    local border = menu:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(colors.border.r, colors.border.g, colors.border.b, 1)
    local background = menu:CreateTexture(nil, "BORDER")
    background:SetPoint("TOPLEFT", 1, -1)
    background:SetPoint("BOTTOMRIGHT", -1, 1)
    background:SetColorTexture(colors.background.r, colors.background.g, colors.background.b, 0.97)
    menu:EnableKeyboard(true)
    menu:SetScript("OnKeyDown", onKeyDown)
end

local function header(index)
    local text = headers[index]
    if not text then
        text = menu:CreateFontString(nil, "OVERLAY", ns.Theme.fonts.small)
        text:SetJustifyH("LEFT")
        local color = ns.Theme.colors.title
        text:SetTextColor(color.r, color.g, color.b)
        headers[index] = text
    end
    return text
end

local function statButton(index)
    local button = buttons[index]
    if button then
        return button
    end
    button = CreateFrame("Button", nil, menu)
    button:SetSize(COLUMN_WIDTH - 4, LINE_HEIGHT)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.1)
    button.text = button:CreateFontString(nil, "OVERLAY", ns.Theme.fonts.small)
    button.text:SetPoint("LEFT", 4, 0)
    button.text:SetPoint("RIGHT", -2, 0)
    button.text:SetJustifyH("LEFT")
    button.text:SetWordWrap(false)
    local color = ns.Theme.colors.text
    button.text:SetTextColor(color.r, color.g, color.b)
    button:SetScript("OnClick", function(self)
        local pick = onPickHandler
        StatPicker.close()
        pick(self.key)
    end)
    buttons[index] = button
    return button
end

function StatPicker.open(anchor, groups, onPick)
    if InCombatLockdown() or #groups == 0 then
        return
    end
    if not menu then
        create()
    end
    onPickHandler = onPick
    local used, rows = 0, 0
    for column, group in ipairs(groups) do
        local x = PADDING + (column - 1) * COLUMN_WIDTH
        local text = header(column)
        text:ClearAllPoints()
        text:SetPoint("TOPLEFT", menu, "TOPLEFT", x, -PADDING)
        text:SetText(group.label)
        text:Show()
        for row, stat in ipairs(group.stats) do
            used = used + 1
            local button = statButton(used)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", menu, "TOPLEFT", x - 4, -PADDING - row * LINE_HEIGHT)
            button.key = stat.key
            button.text:SetText(stat.label)
            button:Show()
        end
        rows = math.max(rows, #group.stats)
    end
    for index = #groups + 1, #headers do
        headers[index]:Hide()
    end
    for index = used + 1, #buttons do
        buttons[index]:Hide()
    end
    menu:SetSize(2 * PADDING + #groups * COLUMN_WIDTH, 2 * PADDING + (rows + 1) * LINE_HEIGHT)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    menu:SetPropagateKeyboardInput(true)
    blocker:Show()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", StatPicker.close)
