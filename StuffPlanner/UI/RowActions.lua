-- CONTRAT
-- Clic sur une ligne d'objet, partagé par les onglets Zone, Parcours, Équipement et le mini-suivi.
-- Modules lus à l'appel (QuestDetail, SourceDetail peuvent se charger après).
--   ns.RowActions.click(questID, itemID, itemSource) : info-bulle fermée d'abord (la fiche demande noms
--     et objets au client, leur arrivée reconstruirait l'info-bulle ouverte) ; objet sélectionné (select) ;
--     Ctrl : essayage de itemID (Compat.DressUpItem) ; quête : Maj = repère (QuestDetail.waypoint), sinon
--     fiche (QuestDetail.show) ; sans quête : fiche de la source (SourceDetail.show) si itemID et
--     itemSource sont connus.
--   select(questID, itemID, reveal?) : sélection courante (une seule, gardée jusqu'au prochain clic),
--     émet SP_SELECTION_CHANGED(reveal) ; rien sans itemID. reveal : les listes font défiler jusqu'à elle.
--   isSelected(questID, itemID) -> bool : même objet et même quête (nil = sans quête)
--   mark(button, questID, itemID) : cadre de sélection (créé au premier appel) affiché si isSelected

local _, ns = ...

local RowActions = {}
ns.RowActions = RowActions

local EDGE = 2
local FILL_ALPHA = 0.12

local selected -- {questID, itemID}

function RowActions.select(questID, itemID, reveal)
    if not itemID then
        return
    end
    selected = { questID = questID, itemID = itemID }
    ns:Send("SP_SELECTION_CHANGED", reveal == true)
end

function RowActions.isSelected(questID, itemID)
    return selected ~= nil and itemID ~= nil and selected.itemID == itemID and selected.questID == questID
end

local function edge(frame, color, a, b, width, height)
    local texture = frame:CreateTexture(nil, "OVERLAY")
    texture:SetColorTexture(color.r, color.g, color.b, 1)
    texture:SetPoint(a)
    texture:SetPoint(b)
    if width then
        texture:SetWidth(width)
    else
        texture:SetHeight(height)
    end
end

local function selectionFrame(button)
    local color = ns.Theme.colors.title
    local frame = CreateFrame("Frame", nil, button)
    frame:SetAllPoints()
    local fill = frame:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(color.r, color.g, color.b, FILL_ALPHA)
    edge(frame, color, "TOPLEFT", "TOPRIGHT", nil, EDGE)
    edge(frame, color, "BOTTOMLEFT", "BOTTOMRIGHT", nil, EDGE)
    edge(frame, color, "TOPLEFT", "BOTTOMLEFT", EDGE)
    edge(frame, color, "TOPRIGHT", "BOTTOMRIGHT", EDGE)
    return frame
end

function RowActions.mark(button, questID, itemID)
    local shown = RowActions.isSelected(questID, itemID)
    if shown and not button.selection then
        button.selection = selectionFrame(button)
    end
    if button.selection then
        button.selection:SetShown(shown)
    end
end

function RowActions.click(questID, itemID, itemSource)
    GameTooltip:Hide()
    RowActions.select(questID, itemID)
    if IsControlKeyDown() then
        if itemID then
            ns.Compat.DressUpItem(itemID)
        end
    elseif questID then
        if IsShiftKeyDown() then
            ns.QuestDetail.waypoint(questID)
        else
            ns.QuestDetail.show(questID)
        end
    elseif itemID and itemSource then
        ns.SourceDetail.show(itemID, itemSource)
    end
end
