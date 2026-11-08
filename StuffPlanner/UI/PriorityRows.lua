-- CONTRAT
-- Lignes de « Mes stats » : rang et stat, poids, flèches haut/bas, x, plafond en % (stats plafonnables).
-- Cadres seulement (vérifiés en jeu). Charger après Theme.lua, avant PriorityList.lua.
--   ns.PriorityRows.ROW_HEIGHT, ARROW_SIZE, ARROW_TEXTURE, ARROW_UP, ARROW_DOWN, SMALL_BUTTON (repris par
--     le bouton « Ajouter » et AltLines)
--   ns.PriorityRows.smallButton(parent, text, onClick) -> bouton carré de la hauteur d'une ligne
--   ns.PriorityRows.arrowButton(parent, coords, onClick) -> smallButton à flèche dessinée ; button.arrow
--   ns.PriorityRows.create(parent, index, handlers) -> ligne (à placer par l'appelant) ;
--     handlers = {move(index, delta), remove(index), cap(index, text)} ; cap à Entrée ou perte du focus,
--     Échap rend le texte affiché
--   ns.PriorityRows.render(line, data?, count) : data = ProfilePresenter.priorityRows[i], nil = cachée ;
--     case de plafond visible si data.capText ~= nil (texte gardé pendant la saisie)

local _, ns = ...

local L = ns.L

local PriorityRows = {}
ns.PriorityRows = PriorityRows

PriorityRows.ROW_HEIGHT = 18
PriorityRows.ARROW_SIZE = 10
PriorityRows.ARROW_TEXTURE = "Interface\\ChatFrame\\ChatFrameExpandArrow"
PriorityRows.ARROW_DOWN = { 0, 1, 1, 1, 0, 0, 1, 0 }

PriorityRows.SMALL_BUTTON = 22
PriorityRows.ARROW_UP = { 1, 0, 0, 0, 1, 1, 0, 1 }

local SMALL_BUTTON = PriorityRows.SMALL_BUTTON
local CAP_WIDTH = 40
local ARROW_UP = PriorityRows.ARROW_UP

function PriorityRows.smallButton(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(SMALL_BUTTON, PriorityRows.ROW_HEIGHT)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

-- Bouton à flèche dessinée (les glyphes ^ et v ne sont pas centrés dans la police du jeu) :
-- texture de flèche vers la droite tournée d'un quart de tour par SetTexCoord.
function PriorityRows.arrowButton(parent, coords, onClick)
    local button = PriorityRows.smallButton(parent, "", onClick)
    local arrow = button:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(PriorityRows.ARROW_SIZE, PriorityRows.ARROW_SIZE)
    arrow:SetPoint("CENTER")
    arrow:SetTexture(PriorityRows.ARROW_TEXTURE)
    arrow:SetTexCoord(unpack(coords))
    button.arrow = arrow
    return button
end

local function capBox(line, index, handlers)
    local box = CreateFrame("EditBox", nil, line, "InputBoxTemplate")
    box:SetSize(CAP_WIDTH, PriorityRows.ROW_HEIGHT)
    box:SetAutoFocus(false)
    box:SetMaxLetters(5)
    box:SetJustifyH("CENTER")
    box:SetTextInsets(0, 6, 0, 0) -- bord droit du cadre de InputBoxTemplate
    box:SetScript("OnEnterPressed", box.ClearFocus)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText(line.capText or "")
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", function(self)
        handlers.cap(index, self:GetText())
    end)
    box:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L.PRIORITY_CAP_HINT, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    box:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    local percent = line:CreateFontString(nil, "OVERLAY", ns.Theme.fonts.small)
    percent:SetPoint("LEFT", box, "RIGHT", 2, 0)
    percent:SetText("%")
    box.percent = percent
    return box
end

function PriorityRows.create(parent, index, handlers)
    local theme = ns.Theme
    local line = CreateFrame("Frame", nil, parent)
    line:SetSize(400, PriorityRows.ROW_HEIGHT)
    line.label = line:CreateFontString(nil, "OVERLAY", theme.fonts.body)
    line.label:SetPoint("LEFT")
    line.label:SetWidth(220)
    line.label:SetJustifyH("LEFT")
    line.weight = line:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    line.weight:SetPoint("LEFT", 225, 0)
    line.weight:SetTextColor(theme.colors.muted.r, theme.colors.muted.g, theme.colors.muted.b)
    line.up = PriorityRows.arrowButton(line, ARROW_UP, function()
        handlers.move(index, -1)
    end)
    line.up:SetPoint("LEFT", 270, 0)
    line.down = PriorityRows.arrowButton(line, PriorityRows.ARROW_DOWN, function()
        handlers.move(index, 1)
    end)
    line.down:SetPoint("LEFT", line.up, "RIGHT", 2, 0)
    line.remove = PriorityRows.smallButton(line, "x", function()
        handlers.remove(index)
    end)
    line.remove:SetPoint("LEFT", line.down, "RIGHT", 2, 0)
    line.cap = capBox(line, index, handlers)
    line.cap:SetPoint("LEFT", line.remove, "RIGHT", 10, 0)
    line.index = index
    return line
end

function PriorityRows.render(line, data, count)
    line:SetShown(data ~= nil)
    if not data then
        return
    end
    line.label:SetText(data.label)
    line.weight:SetText(data.weightText)
    line.up:SetEnabled(line.index > 1)
    line.down:SetEnabled(line.index < count)
    line.capText = data.capText
    local cappable = data.capText ~= nil
    line.cap:SetShown(cappable)
    line.cap.percent:SetShown(cappable)
    if cappable and not line.cap:HasFocus() then
        line.cap:SetText(data.capText)
    end
end
