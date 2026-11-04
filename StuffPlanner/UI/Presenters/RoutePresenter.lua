-- CONTRAT
-- Lignes de l'onglet Parcours. Pur : aucun appel d'API.
-- Charger après RowPresenter.lua et GearPresenter.lua.
--   ns.RoutePresenter.build(tiers, data) -> {row...}, tiers = Tiers.build
--     en-tête de palier : {header = true, text = L.ROUTE_TIER ("Levels 1-10") | L.ROUTE_TIER_MAX}
--     objet : RowPresenter.present + slot, slotName (GearPresenter.slotName), source, questID (quête)

local _, ns = ...

local L = ns.L

local RoutePresenter = {}
ns.RoutePresenter = RoutePresenter

local function headerText(tier)
    if tier.min == tier.max then
        return L.ROUTE_TIER_MAX:format(tier.min)
    end
    return L.ROUTE_TIER:format(tier.min, tier.max)
end

function RoutePresenter.build(tiers, data)
    local rows = {}
    for _, tier in ipairs(tiers) do
        rows[#rows + 1] = { header = true, text = headerText(tier) }
        for _, entry in ipairs(tier.entries) do
            local row = ns.RowPresenter.present(entry, data)
            row.slot = entry.delta and entry.delta.slot
            row.slotName = row.slot and ns.GearPresenter.slotName(row.slot)
            row.source = entry.source
            if entry.source and entry.source.type == "quest" then
                row.questID = entry.source.id
            end
            rows[#rows + 1] = row
        end
    end
    return rows
end
