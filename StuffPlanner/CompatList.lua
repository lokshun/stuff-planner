-- CONTRAT
-- Suite de ns.Compat : listes défilantes (WowScrollBoxList). Charger après Compat.lua.
--   SetRows(scrollBox, rows, keep) : nouvelles lignes (CreateDataProvider) ; keep vrai : position de
--     défilement gardée (ScrollBoxConstants.RetainScrollPosition, si le client le connaît), sinon retour en
--     haut. Rafraîchir une page (clic, dépliage, étoile) garde la position ; changer de contenu remonte.

local _, ns = ...

local Compat = ns.Compat

function Compat.SetRows(scrollBox, rows, keep)
    local constants = keep and rawget(_G, "ScrollBoxConstants")
    scrollBox:SetDataProvider(CreateDataProvider(rows), constants and constants.RetainScrollPosition or nil)
end
