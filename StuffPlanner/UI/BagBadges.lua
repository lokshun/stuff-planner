-- CONTRAT
-- Pastilles de gain (ItemBadge) sur les objets des sacs ouverts, sacs réunis ou séparés (CompatBags).
-- Charger après ItemBadge.lua et CompatBags.lua.
-- Mises à jour des sacs (Compat.HookBagUpdates) regroupées : un seul parcours à l'image suivante,
-- reporté après le combat. Option badges.bags coupée : pastilles des sacs retirées, plus de parcours.
-- Un bouton dont l'emplacement est vide perd sa pastille.

local _, ns = ...

local BagBadges = {}
ns.BagBadges = BagBadges

local OPTION = "badges.bags"

local seen = setmetatable({}, { __mode = "k" }) -- boutons de sac déjà rencontrés
local scanner
local waitingCombat = false

local function afterCombat()
    waitingCombat = false
    BagBadges.schedule()
end

local function scan()
    scanner:Hide()
    if InCombatLockdown() then
        if not waitingCombat then
            waitingCombat = true
            ns:RunOutOfCombat(afterCombat)
        end
        return
    end
    ns.Compat.EachBagButton(function(button, bag, slot)
        seen[button] = true
        ns.ItemBadge.show(button, ns.Compat.GetContainerItemLink(bag, slot))
    end)
end

function BagBadges.schedule()
    if ns.Options.get(OPTION) then
        scanner:Show()
    end
end

local function clearAll()
    for button in pairs(seen) do
        ns.ItemBadge.hide(button)
    end
end

scanner = CreateFrame("Frame")
scanner:Hide()
scanner:SetScript("OnUpdate", scan)

ns.Compat.HookBagUpdates(BagBadges.schedule)

ns:On("SP_OPTION_CHANGED", function(key, value)
    if key ~= OPTION then
        return
    end
    if value then
        BagBadges.schedule()
    else
        scanner:Hide()
        clearAll()
    end
end)
