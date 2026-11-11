-- CONTRAT
-- Pastilles de gain (ItemBadge) sur les objets des sacs ouverts, sacs réunis ou séparés (CompatBags).
-- Charger après ItemBadge.lua et CompatBags.lua.
-- Mises à jour des sacs (Compat.HookBagUpdates) regroupées par ItemBadge.scheduler : un seul
-- parcours à l'image suivante, reporté après le combat. Option badges.bags coupée : pastilles des
-- sacs retirées, plus de parcours. Un bouton dont l'emplacement est vide perd sa pastille.
--   ns.BagBadges.schedule() : parcours demandé (rien si l'option est coupée)

local _, ns = ...

local BagBadges = {}
ns.BagBadges = BagBadges

local OPTION = "badges.bags"

local seen = setmetatable({}, { __mode = "k" }) -- boutons de sac déjà rencontrés

local function scan()
    if not ns.Options.get(OPTION) then
        return
    end
    ns.Compat.EachBagButton(function(button, bag, slot)
        seen[button] = true
        ns.ItemBadge.show(button, ns.Compat.GetContainerItemLink(bag, slot))
    end)
end

local schedule = ns.ItemBadge.scheduler(scan)

function BagBadges.schedule()
    if ns.Options.get(OPTION) then
        schedule()
    end
end

ns.Compat.HookBagUpdates(BagBadges.schedule)

ns:On("SP_OPTION_CHANGED", function(key, value)
    if key ~= OPTION then
        return
    end
    if value then
        BagBadges.schedule()
    else
        for button in pairs(seen) do
            ns.ItemBadge.hide(button)
        end
    end
end)
