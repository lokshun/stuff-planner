-- CONTRAT
-- Section à en-tête repliable (flèche à droite repliée, vers le bas ouverte), état sauvegardé par clé dans
-- StuffPlannerDB.ui. Charger après DB.lua et Theme.lua.
--   spec = {key, open = défaut (false si absent), invert = la clé sauvegarde « replié » (true ou nil)}
--   ns.Section.isOpen(spec) -> bool ; ns.Section.setOpen(spec, open) ; ns.Section.toggle(spec) -> bool
--     sans invert : true ouvert, false replié (format de l'onglet Profil) ; rien écrit avant un clic
--   ns.Section.new(parent, spec, onToggle) -> section ; spec gagne title (texte de l'en-tête)
--     section.header : bouton de l'en-tête (largeur du parent) ; section.setTitle(text)
--     section.place(y) -> open, y' : en-tête en haut à gauche du parent à y, flèche à jour, y' sous l'en-tête
--     clic : état basculé puis onToggle(section)
--   ns.Section.HEIGHT -> hauteur de l'en-tête (pixels)

local _, ns = ...

local Section = {}
ns.Section = Section

Section.HEIGHT = 20

local ARROW_SIZE = 12
local ARROW_TEXTURE = "Interface\\ChatFrame\\ChatFrameExpandArrow"

function Section.isOpen(spec)
    local saved = ns.DB.peek("account", "ui", spec.key)
    if saved == nil then
        return spec.open == true
    end
    if spec.invert then
        return not saved
    end
    return saved == true
end

function Section.setOpen(spec, open)
    local ui = ns.DB.account("ui")
    if spec.invert then
        ui[spec.key] = (not open) or nil
    else
        ui[spec.key] = open and true or false
    end
end

function Section.toggle(spec)
    Section.setOpen(spec, not Section.isOpen(spec))
    return Section.isOpen(spec)
end

-- Flèche vers la droite (repliée) ou tournée d'un quart de tour vers le bas (ouverte).
local function setArrow(arrow, open)
    if open then
        arrow:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
    else
        arrow:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
    end
end

function Section.new(parent, spec, onToggle)
    local theme = ns.Theme
    local header = CreateFrame("Button", nil, parent)
    header:SetHeight(Section.HEIGHT)
    local arrow = header:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(ARROW_SIZE, ARROW_SIZE)
    arrow:SetPoint("LEFT")
    arrow:SetTexture(ARROW_TEXTURE)
    local text = header:CreateFontString(nil, "OVERLAY", theme.fonts.header)
    text:SetPoint("LEFT", arrow, "RIGHT", theme.spacing.gap / 2, 0)
    text:SetPoint("RIGHT")
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(spec.title or "")
    local highlight = header:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.05)
    local section = { header = header, spec = spec }
    function section.setTitle(value)
        text:SetText(value)
    end
    function section.place(y)
        local open = Section.isOpen(spec)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        header:SetPoint("RIGHT", parent, "RIGHT")
        setArrow(arrow, open)
        return open, y - Section.HEIGHT
    end
    header:SetScript("OnClick", function()
        Section.toggle(spec)
        if onToggle then
            onToggle(section)
        end
    end)
    return section
end
