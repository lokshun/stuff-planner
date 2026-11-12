-- CONTRAT
-- Menu clic droit maison (une colonne d'entrées), au curseur. Cadres seulement (vérifiés en jeu) ;
-- textures simples comme StatPicker, sans UIDropDownMenu : même rendu sur Forever et Classic Era.
-- Charger après Theme.lua.
--   ns.RowMenu.open(entries, onPick) : entries = {{key, label}...} (RowMenuPresenter) ; onPick(key) après
--     fermeture ; rien en combat ni si entries est vide
--   ns.RowMenu.close() ; fermé aussi par Échap, clic hors du menu (écran bloquant, et GLOBAL_MOUSE_DOWN
--     hors du menu quand le client le connaît) et entrée en combat

local _, ns = ...

local RowMenu = {}
ns.RowMenu = RowMenu

local MIN_WIDTH, LINE_HEIGHT, PADDING, TEXT_INSET = 140, 18, 6, 8

local blocker, menu, onPickHandler
local buttons = {}

function RowMenu.close()
    if blocker then
        blocker:Hide()
    end
end

local function isOpen()
    return blocker ~= nil and blocker:IsShown()
end

local function onKeyDown(self, key)
    if key == "ESCAPE" then
        self:SetPropagateKeyboardInput(false)
        RowMenu.close()
    end
end

local function create()
    local colors = ns.Theme.colors
    -- Écran entier, invisible : un clic hors du menu le ferme.
    blocker = CreateFrame("Button", nil, UIParent)
    blocker:SetAllPoints(UIParent)
    blocker:SetFrameStrata("FULLSCREEN_DIALOG")
    blocker:EnableMouse(true)
    blocker:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    blocker:SetScript("OnClick", RowMenu.close)
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

local function entryButton(index)
    local button = buttons[index]
    if button then
        return button
    end
    button = CreateFrame("Button", nil, menu)
    button:SetHeight(LINE_HEIGHT)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.1)
    button.text = button:CreateFontString(nil, "OVERLAY", ns.Theme.fonts.small)
    button.text:SetPoint("LEFT", TEXT_INSET, 0)
    button.text:SetJustifyH("LEFT")
    button.text:SetWordWrap(false)
    local color = ns.Theme.colors.text
    button.text:SetTextColor(color.r, color.g, color.b)
    button:SetScript("OnClick", function(self)
        local pick = onPickHandler
        RowMenu.close()
        pick(self.key)
    end)
    buttons[index] = button
    return button
end

function RowMenu.open(entries, onPick)
    if InCombatLockdown() or #entries == 0 then
        return
    end
    if not menu then
        create()
    end
    onPickHandler = onPick
    local width = MIN_WIDTH
    for index, entry in ipairs(entries) do
        local button = entryButton(index)
        button.key = entry.key
        button.text:SetText(entry.label)
        width = math.max(width, button.text:GetStringWidth() + 2 * TEXT_INSET)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -PADDING - (index - 1) * LINE_HEIGHT)
        button:SetPoint("RIGHT", menu, "RIGHT", -1, 0)
        button:Show()
    end
    for index = #entries + 1, #buttons do
        buttons[index]:Hide()
    end
    menu:SetSize(width, 2 * PADDING + #entries * LINE_HEIGHT)
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale - 4, y / scale + 4)
    menu:SetPropagateKeyboardInput(true)
    blocker:Show()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
pcall(events.RegisterEvent, events, "GLOBAL_MOUSE_DOWN")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        RowMenu.close()
    elseif isOpen() and not menu:IsMouseOver() then
        RowMenu.close()
    end
end)
