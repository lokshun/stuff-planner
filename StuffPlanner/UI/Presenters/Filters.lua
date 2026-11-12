-- CONTRAT
-- Filtres en puces des listes (onglet Zone actuelle). Pur : aucun appel d'API.
-- Lignes = sorties de RowPresenter.present (sourceKind, unconfirmed, unavailable).
--   ns.Filters.new(saved) -> état ; saved = {hidden = {[type]=true}, hideUnconfirmed = bool,
--     hideUnavailable = bool} | nil ;
--     la table sauvegardée est gardée et complétée (persistance par référence)
--   ns.Filters.toggle(state, key) ; key = type de source ("quest", "dungeon", "raid", "craft", "world")
--     ou "unconfirmed" ou "unavailable" (quête pas encore disponible) ; clé inconnue ignorée
--   ns.Filters.apply(state, rows) -> nouvelle liste, ordre gardé ; une ligne sans source reste
--   ns.Filters.chips(state, rows) -> {{key, label, count, active}...} ; types dans l'ordre ci-dessus
--     puis "unconfirmed", "unavailable" ; puce présente si count > 0 ou si son filtre masque ; count avant filtrage ;
--     active = lignes montrées ; label = L.FILTER_CHIP (nom, count)

local _, ns = ...

local L = ns.L

local Filters = {}
ns.Filters = Filters

local KINDS = { "quest", "dungeon", "raid", "craft", "world" }
local KIND_LABELS = { quest = "FILTER_QUEST", dungeon = "FILTER_DUNGEON", raid = "FILTER_RAID", craft = "FILTER_CRAFT",
    world = "FILTER_WORLD" }
local UNCONFIRMED = "unconfirmed"
local UNAVAILABLE = "unavailable"

function Filters.new(saved)
    local state = type(saved) == "table" and saved or {}
    if type(state.hidden) ~= "table" then
        state.hidden = {}
    end
    state.hideUnconfirmed = state.hideUnconfirmed == true
    state.hideUnavailable = state.hideUnavailable == true
    return state
end

function Filters.toggle(state, key)
    if key == UNCONFIRMED then
        state.hideUnconfirmed = not state.hideUnconfirmed
    elseif key == UNAVAILABLE then
        state.hideUnavailable = not state.hideUnavailable
    elseif KIND_LABELS[key] then
        state.hidden[key] = not state.hidden[key] or nil
    end
end

local function visible(state, row)
    if (row.unconfirmed and state.hideUnconfirmed) or (row.unavailable and state.hideUnavailable) then
        return false
    end
    return not (row.sourceKind and state.hidden[row.sourceKind])
end

function Filters.apply(state, rows)
    local out = {}
    for _, row in ipairs(rows) do
        if visible(state, row) then
            out[#out + 1] = row
        end
    end
    return out
end

local function chip(key, name, count, active)
    return { key = key, label = L.FILTER_CHIP:format(name, count), count = count, active = active }
end

function Filters.chips(state, rows)
    local counts, unconfirmed, unavailable = {}, 0, 0
    for _, row in ipairs(rows) do
        if row.sourceKind then
            counts[row.sourceKind] = (counts[row.sourceKind] or 0) + 1
        end
        if row.unconfirmed then
            unconfirmed = unconfirmed + 1
        end
        if row.unavailable then
            unavailable = unavailable + 1
        end
    end
    local chips = {}
    for _, kind in ipairs(KINDS) do
        local count = counts[kind] or 0
        if count > 0 or state.hidden[kind] then
            chips[#chips + 1] = chip(kind, L[KIND_LABELS[kind]], count, not state.hidden[kind])
        end
    end
    if unconfirmed > 0 or state.hideUnconfirmed then
        chips[#chips + 1] = chip(UNCONFIRMED, L.FILTER_UNCONFIRMED, unconfirmed, not state.hideUnconfirmed)
    end
    if unavailable > 0 or state.hideUnavailable then
        chips[#chips + 1] = chip(UNAVAILABLE, L.FILTER_UNAVAILABLE, unavailable, not state.hideUnavailable)
    end
    return chips
end
