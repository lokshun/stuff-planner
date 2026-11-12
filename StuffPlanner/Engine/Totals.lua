-- CONTRAT
-- Score total de l'équipement porté (journal de progression). Pur : aucun appel à l'API WoW.
-- Charger après Engine/Scoring.lua.
--   ns.Totals.equipped(player, profile, data) -> total, bySlot = {[slot]=score de l'objet seul}
--     stats d'un emplacement : player.equippedStats[slot], sinon data.item(itemID).stats, sinon vides ;
--     plafonds (profile.caps) sur la somme des objets, la part hors équipement des totaux du joueur
--     (Scoring.PLAYER_TOTALS : toucher) comptée d'abord ; bySlot sans plafond. Sans profil : 0, {}.

local _, ns = ...

local Totals = {}
ns.Totals = Totals

local function slotStats(slot, itemID, player, data)
    local stats = player.equippedStats and player.equippedStats[slot]
    if stats then
        return stats
    end
    local fields = data.item(itemID)
    return fields and fields.stats or {}
end

function Totals.equipped(player, profile, data)
    local bySlot = {}
    if not profile then
        return 0, bySlot
    end
    local sum = {}
    for slot, itemID in pairs(player.equipped or {}) do
        local stats = slotStats(slot, itemID, player, data)
        bySlot[slot] = ns.Scoring.score(stats, profile.weights)
        for key, value in pairs(stats) do
            sum[key] = (sum[key] or 0) + value
        end
    end
    local base = {}
    for key, field in pairs(ns.Scoring.PLAYER_TOTALS) do
        base[key] = math.max(0, (player[field] or 0) - (sum[key] or 0))
    end
    return ns.Scoring.score(sum, profile.weights, { caps = profile.caps, base = base }), bySlot
end
