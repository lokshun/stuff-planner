-- CONTRAT
-- Lignes de l'onglet Parcours. Pur : aucun appel d'API.
-- Charger après RowPresenter.lua et GearPresenter.lua.
--   ns.RoutePresenter.build(tiers, data, open?, expanded?) -> {row...}, tiers = Tiers.build
--     en-tête de palier : {header = true, text = L.ROUTE_TIER ("Levels 1-10") | L.ROUTE_TIER_MAX}
--     palier passé (tier.past) : en-tête + toggle = tier.min, texte « [+] » (replié) ou « [-] » (ouvert,
--       open[tier.min] vrai) devant L.ROUTE_PAST ; lignes seulement si ouvert
--     objet : RowPresenter.present + slot, slotName (GearPresenter.slotName), source, questID (quête) ;
--       palier passé : muted = true, noteText = L.ROUTE_BEATEN (entry.beaten) · L.ROUTE_DONE (entry.done)
--       | nil ; palier courant ou futur avec tier.alternatives[itemID] : effortText (RowPresenter),
--       alternatives = {RowPresenter.alternative...}, expandKey = "<min>:<itemID>",
--       expanded = expanded[expandKey] == true

local _, ns = ...

local L = ns.L

local RoutePresenter = {}
ns.RoutePresenter = RoutePresenter

local SEPARATOR = " · "

local function headerText(tier)
    if tier.min == tier.max then
        return L.ROUTE_TIER_MAX:format(tier.min)
    end
    return L.ROUTE_TIER:format(tier.min, tier.max)
end

local function header(tier, open)
    if not tier.past then
        return { header = true, text = headerText(tier) }
    end
    local mark = open and "[-] " or "[+] "
    return { header = true, toggle = tier.min, text = mark .. L.ROUTE_PAST:format(headerText(tier)) }
end

local function note(entry)
    local parts = {}
    if entry.beaten then
        parts[#parts + 1] = L.ROUTE_BEATEN
    end
    if entry.done then
        parts[#parts + 1] = L.ROUTE_DONE
    end
    return #parts > 0 and table.concat(parts, SEPARATOR) or nil
end

local function itemRow(entry, data, past, tier, expanded)
    local row = ns.RowPresenter.present(entry, data)
    row.slot = entry.delta and entry.delta.slot
    row.slotName = row.slot and ns.GearPresenter.slotName(row.slot)
    row.source = entry.source
    if entry.source and entry.source.type == "quest" then
        row.questID = entry.source.id
    end
    if past then
        row.muted, row.noteText = true, note(entry)
        return row
    end
    local alternatives = tier.alternatives and tier.alternatives[entry.itemID]
    if alternatives and #alternatives > 0 then
        row.effortText = ns.RowPresenter.effortText(entry)
        row.alternatives = {}
        for i, alternative in ipairs(alternatives) do
            row.alternatives[i] = ns.RowPresenter.alternative(alternative, data)
        end
        row.expandKey = tier.min .. ":" .. entry.itemID
        row.expanded = expanded[row.expandKey] == true
    end
    return row
end

function RoutePresenter.build(tiers, data, open, expanded)
    open, expanded = open or {}, expanded or {}
    local rows = {}
    for _, tier in ipairs(tiers) do
        local shown = not tier.past or open[tier.min] == true
        rows[#rows + 1] = header(tier, shown)
        if shown then
            for _, entry in ipairs(tier.entries) do
                rows[#rows + 1] = itemRow(entry, data, tier.past, tier, expanded)
            end
        end
    end
    return rows
end
