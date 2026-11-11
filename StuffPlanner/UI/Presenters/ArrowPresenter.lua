-- CONTRAT
-- Textes de la flèche (UI/Arrow.lua). Pur : noms par ns.Names, distance par ns.Distance.
--   ns.ArrowPresenter.zoneLine(playerMap, targetMap, data) -> texte : "" si même carte ou carte inconnue ;
--     L.ARROW_ZONE (nom de la zone cible, zones traversées) ; L.ARROW_ZONE_FAR (nom) sans chemin connu
--     (Distance.hops renvoie son plafond sans chemin : plafond MAX_HOPS = trop loin ou inconnu)

local _, ns = ...

local L = ns.L

local MAX_HOPS = 12

local ArrowPresenter = {}
ns.ArrowPresenter = ArrowPresenter

function ArrowPresenter.zoneLine(playerMap, targetMap, data)
    if not playerMap or not targetMap or playerMap == targetMap then
        return ""
    end
    local name = ns.Names.zone(targetMap)
    local hops = ns.Distance.hops(playerMap, targetMap, data, MAX_HOPS)
    if hops and hops < MAX_HOPS then
        return L.ARROW_ZONE:format(name, hops)
    end
    return L.ARROW_ZONE_FAR:format(name)
end
