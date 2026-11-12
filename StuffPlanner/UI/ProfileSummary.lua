-- CONTRAT
-- Résumé du profil actif en tête de l'onglet Profil. Cadres seulement (vérifiés en jeu).
-- Charger après Theme.lua, avant ProfileTab.lua.
--   ns.ProfileSummary.create(parent, onEdit, onCompare) -> frame (largeur du parent) ; onEdit() au clic sur
--     « Modifier », onCompare(button) au clic sur « Comparer… » (sous « Modifier »)
--   ns.ProfileSummary.render(summary, compareText) -> hauteur (pixels) ; summary = ProfilePresenter.summary :
--     titre, puis stats principales, plafonds et source (lignes vides sautées), puis compareText (profil
--     comparé, en bleu) ; « Modifier » si summary.editable ; « Comparer… » toujours

local _, ns = ...

local L = ns.L

local ProfileSummary = {}
ns.ProfileSummary = ProfileSummary

local BUTTON_HEIGHT = 22
local FIELDS = { "topText", "capsText", "sourceText" }

local frame, title, editButton, compareButton, compareLine
local lines = {}

local function button(text, onClick)
    local result = ns.Skin.button(frame)
    result:SetText(text)
    result:SetSize(result:GetFontString():GetStringWidth() + 24, BUTTON_HEIGHT)
    result:SetScript("OnClick", onClick)
    return result
end

local function fontString(font, color)
    local text = frame:CreateFontString(nil, "OVERLAY", font)
    text:SetJustifyH("LEFT")
    text:SetTextColor(color.r, color.g, color.b)
    return text
end

function ProfileSummary.create(parent, onEdit, onCompare)
    local theme = ns.Theme
    frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(parent:GetWidth(), BUTTON_HEIGHT)
    editButton = button(L.PROFILE_EDIT, function()
        onEdit()
    end)
    editButton:SetPoint("TOPRIGHT")
    compareButton = button(L.PROFILE_COMPARE, function(self)
        onCompare(self)
    end)
    compareButton:SetPoint("TOPRIGHT", 0, -(BUTTON_HEIGHT + 4))
    local buttonWidth = math.max(editButton:GetWidth(), compareButton:GetWidth())
    editButton:SetWidth(buttonWidth)
    compareButton:SetWidth(buttonWidth)
    local width = frame:GetWidth() - buttonWidth - theme.spacing.gap
    title = fontString(theme.fonts.body, theme.colors.title)
    title:SetWidth(width)
    for i, field in ipairs(FIELDS) do
        lines[i] = fontString(theme.fonts.small, field == "topText" and theme.colors.text or theme.colors.muted)
        lines[i]:SetWidth(width)
    end
    compareLine = fontString(theme.fonts.small, theme.colors.instance)
    compareLine:SetWidth(width)
    return frame
end

function ProfileSummary.render(summary, compareText)
    local gap = ns.Theme.spacing.gap / 2
    title:SetText(summary.title)
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -4)
    local y = 4 + title:GetStringHeight()
    for i, field in ipairs(FIELDS) do
        local line, text = lines[i], summary[field]
        line:SetShown(text ~= "")
        if text ~= "" then
            line:SetText(text)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(y + gap))
            y = y + gap + line:GetStringHeight()
        end
    end
    compareLine:SetText(compareText or "")
    compareLine:ClearAllPoints()
    compareLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(y + gap))
    y = y + gap + compareLine:GetStringHeight()
    editButton:SetShown(summary.editable)
    local height = math.max(y, 2 * BUTTON_HEIGHT + 4)
    frame:SetHeight(height)
    return height
end
