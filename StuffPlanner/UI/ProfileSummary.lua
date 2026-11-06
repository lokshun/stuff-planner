-- CONTRAT
-- Résumé du profil actif en tête de l'onglet Profil. Cadres seulement (vérifiés en jeu).
-- Charger après Theme.lua, avant ProfileTab.lua.
--   ns.ProfileSummary.create(parent, onEdit) -> frame (largeur du parent) ; onEdit() au clic sur « Modifier »
--   ns.ProfileSummary.render(summary) -> hauteur (pixels) ; summary = ProfilePresenter.summary : titre,
--     puis stats principales, plafonds et source (lignes vides sautées) ; « Modifier » si summary.editable

local _, ns = ...

local L = ns.L

local ProfileSummary = {}
ns.ProfileSummary = ProfileSummary

local BUTTON_HEIGHT = 22
local FIELDS = { "topText", "capsText", "sourceText" }

local frame, title, editButton
local lines = {}

local function fontString(font, color)
    local text = frame:CreateFontString(nil, "OVERLAY", font)
    text:SetJustifyH("LEFT")
    text:SetTextColor(color.r, color.g, color.b)
    return text
end

function ProfileSummary.create(parent, onEdit)
    local theme = ns.Theme
    frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(parent:GetWidth(), BUTTON_HEIGHT)
    editButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    editButton:SetText(L.PROFILE_EDIT)
    editButton:SetSize(editButton:GetFontString():GetStringWidth() + 24, BUTTON_HEIGHT)
    editButton:SetPoint("TOPRIGHT")
    editButton:SetScript("OnClick", function()
        onEdit()
    end)
    local width = frame:GetWidth() - editButton:GetWidth() - theme.spacing.gap
    title = fontString(theme.fonts.body, theme.colors.title)
    title:SetWidth(width)
    for i, field in ipairs(FIELDS) do
        lines[i] = fontString(theme.fonts.small, field == "topText" and theme.colors.text or theme.colors.muted)
        lines[i]:SetWidth(width)
    end
    return frame
end

function ProfileSummary.render(summary)
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
    editButton:SetShown(summary.editable)
    local height = math.max(y, BUTTON_HEIGHT)
    frame:SetHeight(height)
    return height
end
