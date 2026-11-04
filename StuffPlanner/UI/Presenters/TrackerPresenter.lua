-- CONTRAT
-- Contenu du mini-suivi : les 3 meilleures améliorations. Pur : aucun appel d'API.
-- Charger après RowPresenter.lua.
--   ns.TrackerPresenter.build(entries, data [, message [, limit]]) -> {lines = {row...}, empty = string | nil}
--     limit : lignes au plus (3 par défaut)
--     entries = {{itemID, questID, delta}...} (Chat.bestInZone, ordre quelconque) | nil ;
--     garde delta.abs > 0, un objet une fois (première entrée), tri par gain décroissant puis
--     itemID, 3 au plus ; row = RowPresenter.questRow (source quête, état, questID).
--     empty : message si entries vaut nil (L.BEST_NOT_READY…), L.TRACKER_EMPTY si aucune ligne.

local _, ns = ...

local L = ns.L

local TrackerPresenter = {}
ns.TrackerPresenter = TrackerPresenter

local LIMIT = 3

local function byGain(a, b)
    if a.delta.abs ~= b.delta.abs then
        return a.delta.abs > b.delta.abs
    end
    return a.itemID < b.itemID
end

local function candidates(entries)
    local list, seen = {}, {}
    for _, entry in ipairs(entries) do
        if entry.delta and entry.delta.abs > 0 and not seen[entry.itemID] then
            seen[entry.itemID] = true
            list[#list + 1] = entry
        end
    end
    table.sort(list, byGain)
    return list
end

function TrackerPresenter.build(entries, data, message, limit)
    if not entries then
        return { lines = {}, empty = message }
    end
    local lines = {}
    for i, entry in ipairs(candidates(entries)) do
        if i > (limit or LIMIT) then
            break
        end
        lines[i] = ns.RowPresenter.questRow(entry, data)
    end
    return { lines = lines, empty = #lines == 0 and L.TRACKER_EMPTY or nil }
end
