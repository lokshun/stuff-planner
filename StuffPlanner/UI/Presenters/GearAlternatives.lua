-- CONTRAT
-- Alternatives d'un emplacement de l'onglet Équipement (sorties de GearPresenter). Pur : aucun appel
-- d'API. Charger après RowPresenter.lua, avant GearPresenter.lua.
--   ns.GearAlternatives.of(slot, chosen, ctx) -> {RowPresenter.alternative…} | nil
--     chosen = objet proposé (itemID, sourceKind, questID) ; ctx = {entries, route, routeAlternatives, data,
--       quest (ligne de quête imposée : Tiers quests[slot]) | nil, needQuest (bool)}
--     autres objets de l'emplacement (gain > 0, hors raid et objet proposé), MAX au plus : zone d'abord
--     (L.EFFORT_NEAR, par gain), puis palier courant et ses alternatives, par effort ;
--     needQuest : la quête de plus fort gain en tête, à défaut ctx.quest (gain > 0, autre objet)
--   ns.GearAlternatives.MAX = 3

local _, ns = ...

local L = ns.L

local GearAlternatives = {}
ns.GearAlternatives = GearAlternatives

GearAlternatives.MAX = 3

local function isRaid(entry)
    return entry.source ~= nil and entry.source.type == "raid"
end

local function usable(entry, slot, seen)
    return entry.delta and entry.delta.slot == slot and entry.delta.abs > 0 and not isRaid(entry)
        and not seen[entry.itemID]
end

local function byEase(a, b)
    if a.ease ~= b.ease then
        return a.ease < b.ease
    end
    if a.gain ~= b.gain then
        return a.gain > b.gain
    end
    return a.itemID < b.itemID
end

local function questFirst(found, seen, ctx)
    local best
    for i, row in ipairs(found) do
        if row.questID and (not best or row.gain > found[best].gain) then
            best = i
        end
    end
    if best then
        table.insert(found, 1, table.remove(found, best))
        return
    end
    local quest = ctx.quest
    if quest and quest.delta and quest.delta.abs > 0 and not seen[quest.itemID] then
        local row = ns.RowPresenter.alternative(quest, ctx.data)
        row.ease, row.gain = quest.effort or math.huge, quest.delta.abs
        table.insert(found, 1, row)
    end
end

function GearAlternatives.of(slot, chosen, ctx)
    local seen, found = { [chosen.itemID] = true }, {}
    local function add(entry, ease, effortText)
        if usable(entry, slot, seen) then
            seen[entry.itemID] = true
            local row = ns.RowPresenter.alternative(entry, ctx.data, effortText)
            row.ease, row.gain = ease, entry.delta.abs
            found[#found + 1] = row
        end
    end
    for _, entry in ipairs(ctx.entries or {}) do
        add(entry, -1, L.EFFORT_NEAR)
    end
    local alternatives = ctx.routeAlternatives
    for _, entry in ipairs(ctx.route or {}) do
        add(entry, entry.effort or math.huge)
        for _, other in ipairs(alternatives and alternatives[entry.itemID] or {}) do
            add(other, other.effort or math.huge)
        end
    end
    table.sort(found, byEase)
    if ctx.needQuest then
        questFirst(found, seen, ctx)
    end
    for i = #found, GearAlternatives.MAX + 1, -1 do
        found[i] = nil
    end
    return #found > 0 and found or nil
end
