-- CONTRAT
-- Texte du toast d'entrée de zone. Pur : aucun appel d'API. Charger après BadgePresenter.lua
-- (ns.L lu à l'appel).
--   ns.ZoneToastPresenter.build(results, zoneName) -> text | nil
--     results = entrées de Chat.currentZone ({itemID, delta = {abs, pct}}...), déjà filtrées (gain > 0) ;
--     text = L.ZONE_TOAST_ONE | ZONE_TOAST_MANY (zone, nombre), suivi de L.ZONE_TOAST_BEST (meilleur
--       pourcentage, BadgePresenter.percentText) si au moins une entrée a un pct ;
--     nil : results nil ou vide.

local _, ns = ...

local ZoneToastPresenter = {}
ns.ZoneToastPresenter = ZoneToastPresenter

local function bestPct(results)
    local best
    for _, entry in ipairs(results) do
        local pct = entry.delta and entry.delta.pct
        if pct and (not best or pct > best) then
            best = pct
        end
    end
    return best
end

function ZoneToastPresenter.build(results, zoneName)
    if not results or #results == 0 then
        return nil
    end
    local L = ns.L
    local count = #results
    local text = count == 1 and L.ZONE_TOAST_ONE:format(zoneName)
        or L.ZONE_TOAST_MANY:format(zoneName, count)
    local best = bestPct(results)
    if best then
        text = L.ZONE_TOAST_BEST:format(text, ns.BadgePresenter.percentText(best))
    end
    return text
end
