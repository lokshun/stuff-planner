-- CONTRAT
-- Segment à choix unique (zone / durée de session, tous / améliorations) : boutons accolés dans un cadre commun,
-- choix actif plein, survol éclairci ; distinct d'un bouton d'action (Skin.button). Charger après Theme.lua.
--   ns.Chips.new(parent) -> bar ; bar.frame à placer par l'appelant (hauteur Chips.HEIGHT, largeur = segments)
--   bar:render(chips, onToggle) : chips = {{key, label, active}...}, un segment par entrée, de gauche à
--     droite ; clic -> onToggle(key) ; segments en trop cachés
--   ns.Chips.HEIGHT -> 20

local _, ns = ...

local Chips = {}
ns.Chips = Chips

Chips.HEIGHT = 20

local PAD = 10
local ACTIVE_ALPHA, IDLE_ALPHA, HOVER_ALPHA = 0.45, 0.08, 0.12

local Bar = {}
Bar.__index = Bar

local function edge(frame, a, b, width, height)
    local border = ns.Theme.colors.border
    local texture = frame:CreateTexture(nil, "BORDER")
    texture:SetColorTexture(border.r, border.g, border.b, 0.7)
    texture:SetPoint(a)
    texture:SetPoint(b)
    if width then
        texture:SetWidth(width)
    else
        texture:SetHeight(height)
    end
end

function Chips.new(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(Chips.HEIGHT)
    edge(frame, "TOPLEFT", "TOPRIGHT", nil, 1)
    edge(frame, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    edge(frame, "TOPLEFT", "BOTTOMLEFT", 1)
    edge(frame, "TOPRIGHT", "BOTTOMRIGHT", 1)
    return setmetatable({ frame = frame, buttons = {} }, Bar)
end

function Bar:button(index)
    local button = self.buttons[index]
    if not button then
        local theme = ns.Theme
        button = CreateFrame("Button", nil, self.frame)
        button:SetHeight(Chips.HEIGHT)
        button.bg = button:CreateTexture(nil, "BACKGROUND")
        button.bg:SetAllPoints()
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, HOVER_ALPHA)
        button.text = button:CreateFontString(nil, "OVERLAY", theme.fonts.small)
        button.text:SetPoint("CENTER")
        if index == 1 then
            button:SetPoint("LEFT", self.frame, "LEFT", 0, 0)
        else
            button:SetPoint("LEFT", self.buttons[index - 1], "RIGHT", 0, 0)
            edge(button, "TOPLEFT", "BOTTOMLEFT", 1)
        end
        self.buttons[index] = button
    end
    return button
end

function Bar:render(chips, onToggle)
    local theme = ns.Theme
    local fill = theme.colors.border
    local width = 0
    for index, chip in ipairs(chips) do
        local button = self:button(index)
        button.text:SetText(chip.label)
        button:SetWidth(math.floor(button.text:GetStringWidth() + 2 * PAD + 0.5))
        width = width + button:GetWidth()
        button.bg:SetColorTexture(fill.r, fill.g, fill.b, chip.active and ACTIVE_ALPHA or IDLE_ALPHA)
        local color = chip.active and theme.colors.title or theme.colors.muted
        button.text:SetTextColor(color.r, color.g, color.b)
        local key = chip.key
        button:SetScript("OnClick", function()
            onToggle(key)
        end)
        button:Show()
    end
    for index = #chips + 1, #self.buttons do
        self.buttons[index]:Hide()
    end
    self.frame:SetWidth(math.max(width, 1))
end
