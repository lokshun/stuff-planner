-- CONTRAT
-- Clic sur une ligne d'objet, partagé par les onglets Zone, Parcours et Équipement.
-- Modules lus à l'appel (QuestDetail, SourceDetail peuvent se charger après).
--   ns.RowActions.click(questID, itemID, itemSource) : info-bulle fermée d'abord (la fiche demande noms
--     et objets au client, leur arrivée reconstruirait l'info-bulle ouverte) ; Ctrl : essayage de itemID
--     (Compat.DressUpItem) ; quête : Maj = repère (QuestDetail.waypoint), sinon fiche (QuestDetail.show) ;
--     sans quête : fiche de la source (SourceDetail.show) si itemID et itemSource sont connus.

local _, ns = ...

local RowActions = {}
ns.RowActions = RowActions

function RowActions.click(questID, itemID, itemSource)
    GameTooltip:Hide()
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
