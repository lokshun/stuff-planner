-- CONTRAT
-- « Utile à X (+9 %) » : meilleur gain d'un objet pour un autre personnage (Data/Alts.lua). Pur : aucun appel
-- d'API. Charger après SecondaryGain.lua (ns.Scoring lu à l'appel).
--   ns.AltGain.best(fields, alts, data) -> {name, delta} | nil
--     fields = data.item(itemID) ou LiveItem.fields ; alts = Alts.others() ; Scoring.deltaFields sans cache
--     (instantané de l'autre personnage, profil enregistré avec lui) ; gain > 0 seulement ; meilleur
--     pourcentage (emplacement vide : avant tout), puis meilleur gain en points.
--   ns.AltGain.text(best) -> L.ALT_USEFUL (nom, SecondaryGain.value) | nil

local _, ns = ...

local AltGain = {}
ns.AltGain = AltGain

local EPSILON = 1e-6

local function better(a, b)
    local pa, pb = a.pct or math.huge, b.pct or math.huge
    if pa ~= pb then
        return pa > pb
    end
    return a.abs > b.abs
end

function AltGain.best(fields, alts, data)
    if not fields then
        return nil
    end
    local best
    for _, alt in ipairs(alts) do
        local delta = ns.Scoring.deltaFields(fields, alt, alt.profile, data)
        if delta and delta.abs > EPSILON and (not best or better(delta, best.delta)) then
            best = { name = alt.name, delta = delta }
        end
    end
    return best
end

function AltGain.text(best)
    if not best then
        return nil
    end
    return ns.L.ALT_USEFUL:format(best.name, ns.SecondaryGain.value(best.delta))
end
