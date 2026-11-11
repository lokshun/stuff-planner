-- CONTRAT
-- Pastilles de gain (ItemBadge) sur les lignes « Parcourir » de l'hôtel des ventes classique (CompatAuction).
-- Charger après ItemBadge.lua et CompatAuction.lua. Ne dépend d'aucun addon de prix.
-- Parcours demandé par Compat.HookAuctionUpdates (liste reçue, défilement), regroupé par ItemBadge.scheduler ;
-- ligne cachée ou vide : pastille retirée. Option badges.auction coupée : pastilles retirées, plus de parcours.
-- Hôtel des ventes moderne : rien (CompatAuction ne donne aucune ligne).
--   ns.AuctionBadges.scan() : parcours immédiat (tests)

local _, ns = ...

local AuctionBadges = {}
ns.AuctionBadges = AuctionBadges

local OPTION = "badges.auction"

local seen = setmetatable({}, { __mode = "k" })

function AuctionBadges.scan()
    if not ns.Options.get(OPTION) then
        return
    end
    ns.Compat.EachAuctionButton(function(button, link)
        seen[button] = true
        ns.ItemBadge.show(button, link)
    end)
end

local schedule = ns.ItemBadge.scheduler(AuctionBadges.scan)

local function request()
    if ns.Options.get(OPTION) then
        schedule()
    end
end

ns.Compat.HookAuctionUpdates(request)

ns:On("SP_OPTION_CHANGED", function(key, value)
    if key ~= OPTION then
        return
    end
    if value then
        request()
    else
        for button in pairs(seen) do
            ns.ItemBadge.hide(button)
        end
    end
end)
