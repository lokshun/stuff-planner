-- CONTRAT
-- Menu clic droit maison (une colonne d'entrées), au curseur. Cadres seulement (vérifiés en jeu) ;
-- textures simples comme StatPicker, sans UIDropDownMenu : même rendu sur Forever et Classic Era.
-- Charger après Theme.lua.
--   ns.RowMenu.open(entries, onPick, opts?) : entries = {{key, label}...} (RowMenuPresenter) ; onPick(key) après
--     fermeture ; rien en combat ni si entries est vide. Entrée : checked (true/false : case cochée ou vide,
--     radio = même rendu), {separator = true} (filet), {header = true, label} (titre pâle, non cliquable).
--     opts = {anchor = cadre (menu sous lui, aligné à droite ; sinon au curseur), keepOpen = onPick appelé menu
--     ouvert, son retour (entrées) redessine le menu (filtres à cocher en série)}
--   ns.RowMenu.render(entries) : redessine le menu ouvert
--   ns.RowMenu.close() ; fermé aussi par Échap, clic hors du menu (écran bloquant, et GLOBAL_MOUSE_DOWN
--     hors du menu quand le client le connaît) et entrée en combat

local _, ns = ...

local RowMenu = {}
ns.RowMenu = RowMenu

local MIN_WIDTH, LINE_HEIGHT, PADDING, TEXT_INSET = 140, 18, 6, 8
local SEPARATOR_HEIGHT, CHECK_SIZE = 7, 14
local CHECK_ICON = "Interface\\Buttons\\UI-CheckBox-Check"
local BOX_ICON = "Interface\\Buttons\\UI-CheckBox-Up"

local blocker, menu, onPickHandler, keepOpen
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
    button.highlight = highlight
    button.check = button:CreateTexture(nil, "ARTWORK")
    button.check:SetSize(CHECK_SIZE, CHECK_SIZE)
    button.check:SetPoint("LEFT", TEXT_INSET - 2, 0)
    button.line = button:CreateTexture(nil, "ARTWORK")
    button.line:SetHeight(1)
    button.line:SetPoint("LEFT", TEXT_INSET, 0)
    button.line:SetPoint("RIGHT", -TEXT_INSET, 0)
    local border = ns.Theme.colors.border
    button.line:SetColorTexture(border.r, border.g, border.b, 0.5)
    button.text = button:CreateFontString(nil, "OVERLAY", ns.Theme.fonts.small)
    button.text:SetJustifyH("LEFT")
    button.text:SetWordWrap(false)
    button:SetScript("OnClick", function(self)
        local pick = onPickHandler
        if keepOpen then
            local entries = pick(self.key)
            if type(entries) == "table" and #entries > 0 then
                RowMenu.render(entries)
            else
                RowMenu.close()
            end
            return
        end
        RowMenu.close()
        pick(self.key)
    end)
    buttons[index] = button
    return button
end

local function hasChecks(entries)
    for _, entry in ipairs(entries) do
        if entry.checked ~= nil then
            return true
        end
    end
    return false
end

local function setEntry(button, entry, inset)
    local colors = ns.Theme.colors
    local plain = not entry.separator and not entry.header
    button.key = entry.key
    button:SetHeight(entry.separator and SEPARATOR_HEIGHT or LINE_HEIGHT)
    button:EnableMouse(plain)
    button.highlight:SetShown(plain)
    button.line:SetShown(entry.separator == true)
    button.check:SetShown(entry.checked ~= nil)
    button.check:SetTexture(entry.checked and CHECK_ICON or BOX_ICON)
    button.text:ClearAllPoints()
    button.text:SetPoint("LEFT", entry.header and TEXT_INSET or inset, 0)
    button.text:SetText(entry.separator and "" or entry.label)
    local color = entry.header and colors.muted or colors.text
    button.text:SetTextColor(color.r, color.g, color.b)
end

function RowMenu.render(entries)
    local inset = hasChecks(entries) and TEXT_INSET + CHECK_SIZE + 2 or TEXT_INSET
    local width, y = MIN_WIDTH, PADDING
    for index, entry in ipairs(entries) do
        local button = entryButton(index)
        setEntry(button, entry, inset)
        width = math.max(width, button.text:GetStringWidth() + inset + TEXT_INSET)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -y)
        button:SetPoint("RIGHT", menu, "RIGHT", -1, 0)
        button:Show()
        y = y + button:GetHeight()
    end
    for index = #entries + 1, #buttons do
        buttons[index]:Hide()
    end
    menu:SetSize(width, y + PADDING)
end

function RowMenu.open(entries, onPick, opts)
    if InCombatLockdown() or #entries == 0 then
        return
    end
    if not menu then
        create()
    end
    onPickHandler, keepOpen = onPick, opts and opts.keepOpen == true
    RowMenu.render(entries)
    menu:ClearAllPoints()
    if opts and opts.anchor then
        menu:SetPoint("TOPRIGHT", opts.anchor, "BOTTOMRIGHT", 0, -2)
    else
        local scale = UIParent:GetEffectiveScale()
        local x, y = GetCursorPosition()
        menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale - 4, y / scale + 4)
    end
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
