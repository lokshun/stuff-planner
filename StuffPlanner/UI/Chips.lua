-- CONTRAT
-- Barre de puces de filtre (onglets Zone et Équipement). Charger après Theme.lua.
--   ns.Chips.new(parent) -> bar ; bar.frame à placer par l'appelant (hauteur Chips.HEIGHT)
--   bar:render(chips, onToggle) : chips = {{key, label, active}...}, une puce par entrée, de gauche à
--     droite ; puce active plus contrastée ; clic -> onToggle(key) ; puces en trop cachées
--   ns.Chips.HEIGHT -> 20

local _, ns = ...

local Chips = {}
ns.Chips = Chips

Chips.HEIGHT = 20

local Bar = {}
Bar.__index = Bar

function Chips.new(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(Chips.HEIGHT)
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
        button.text = button:CreateFontString(nil, "OVERLAY", theme.fonts.small)
        button.text:SetPoint("CENTER")
        if index == 1 then
            button:SetPoint("LEFT", self.frame, "LEFT", 0, 0)
        else
            button:SetPoint("LEFT", self.buttons[index - 1], "RIGHT", theme.spacing.gap, 0)
        end
        self.buttons[index] = button
    end
    return button
end

function Bar:render(chips, onToggle)
    local theme = ns.Theme
    local border = theme.colors.border
    for index, chip in ipairs(chips) do
        local button = self:button(index)
        button.text:SetText(chip.label)
        button:SetWidth(button.text:GetStringWidth() + 2 * theme.spacing.gap)
        button.bg:SetColorTexture(border.r, border.g, border.b, chip.active and 0.35 or 0.08)
        local color = chip.active and theme.colors.text or theme.colors.muted
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
end
