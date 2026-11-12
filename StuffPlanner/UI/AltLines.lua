-- CONTRAT
-- Bouton à flèche (celui de « Mes stats », PriorityRows) et sous-lignes d'alternatives d'une ligne de
-- liste (Parcours, Équipement). Charger après Theme.lua, RowActions.lua et ItemRow.lua ; PriorityRows lu à build.
--   ns.AltLines.LINE_HEIGHT, ns.AltLines.TOGGLE_WIDTH
--   ns.AltLines.extra(row) -> hauteur à ajouter à la ligne (0 si repliée ou sans row.alternatives)
--   ns.AltLines.build(button, onToggle) -> crée button.altToggle (à placer par l'appelant : à droite,
--     le gain à sa gauche) et les sous-lignes ; onToggle(expandKey) au clic sur le bouton
--   ns.AltLines.render(button, row, top, left) : bouton flèche bas (replié) / haut (déplié) si
--     row.alternatives, sinon caché (largeur 1) ; sous-lignes sous top (px depuis le haut), décalées de
--     left, si row.expanded, gain aligné sur celui de la ligne ; cadre de sélection (mark).
--   ns.AltLines.mark(button) : cadre de sélection des sous-lignes (RowActions.mark), sur SP_SELECTION_CHANGED
-- Sous-ligne (RowPresenter.alternative, ns.ItemRow compacte) : icône, nom, lineText, gain (et gain comparé à
-- sa droite) ; clic = RowActions.click
-- (fiche, Maj : repère, Ctrl : essayage), survol = info-bulle de l'objet.

local _, ns = ...

local L = ns.L

local AltLines = {}
ns.AltLines = AltLines

AltLines.LINE_HEIGHT = 18
AltLines.TOGGLE_WIDTH = 22

local MAX_LINES = 3
local ICON_SIZE = 14
local PADDING = 4
local NAME_WIDTH = 150
local GAIN_WIDTH = 60

function AltLines.extra(row)
    if not row.expanded or not row.alternatives then
        return 0
    end
    return math.min(#row.alternatives, MAX_LINES) * AltLines.LINE_HEIGHT + PADDING
end

local function lineText(_, alt)
    GameTooltip:AddLine(alt.lineText, 1, 1, 1, true)
end

local function showToggleTooltip(toggle)
    GameTooltip:SetOwner(toggle, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.ALT_HINT, 1, 0.82, 0)
    GameTooltip:Show()
end

local function hideTooltip()
    GameTooltip:Hide()
end

local LINE_OPTS = {
    height = AltLines.LINE_HEIGHT, iconSize = ICON_SIZE, compact = true, nameWidth = NAME_WIDTH,
    gainWidth = GAIN_WIDTH, tooltip = lineText,
}

local function buildLine(button)
    return ns.ItemRow.new(button, LINE_OPTS)
end

function AltLines.build(button, onToggle)
    local rows = ns.PriorityRows
    local toggle = rows.arrowButton(button, rows.ARROW_DOWN, function()
        local row = button.altRow
        if row and row.expandKey ~= nil then
            onToggle(row.expandKey)
        end
    end)
    toggle:SetScript("OnEnter", showToggleTooltip)
    toggle:SetScript("OnLeave", hideTooltip)
    button.altToggle = toggle
    button.altLines = {}
    for i = 1, MAX_LINES do
        button.altLines[i] = buildLine(button)
    end
end

function AltLines.render(button, row, top, left)
    local alternatives = row.alternatives or {}
    button.altRow = row
    local toggle = button.altToggle
    toggle:SetShown(#alternatives > 0)
    toggle:SetWidth(#alternatives > 0 and AltLines.TOGGLE_WIDTH or 1)
    local rows = ns.PriorityRows
    toggle.arrow:SetTexCoord(unpack(row.expanded and rows.ARROW_UP or rows.ARROW_DOWN))
    for i, line in ipairs(button.altLines) do
        local alt = row.expanded and alternatives[i] or nil
        line.alt = alt
        line:SetShown(alt ~= nil)
        if alt then
            local y = -(top + (i - 1) * AltLines.LINE_HEIGHT)
            line:SetPoint("TOPLEFT", left, y)
            line:SetPoint("TOPRIGHT", -(PADDING + AltLines.TOGGLE_WIDTH + ns.Theme.spacing.gap), y)
            ns.ItemRow.set(line, {
                row = alt, questID = alt.questID, itemID = alt.itemID, itemSource = alt.itemSource,
                icon = alt.icon, name = alt.name, nameColor = alt.nameColor, detail = alt.lineText,
                gain = alt.gainLabel, gainColor = alt.gainColor, gain2 = alt.secondaryLabel,
                gain2Color = alt.secondaryColor,
            })
        end
    end
    AltLines.mark(button)
end

function AltLines.mark(button)
    for _, line in ipairs(button.altLines or {}) do
        local alt = line:IsShown() and line.alt or nil
        ns.RowActions.mark(line, alt and alt.questID, alt and alt.itemID)
    end
end
