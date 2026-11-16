-- CONTRAT
-- Filtres d'affichage des listes (page Maintenant, mode zone). Pur : aucun appel d'API. Les types de source
-- ne sont plus filtrés ici : origines choisies avant le classement (Engine/Origins.lua, Chat opts.origins).
-- Lignes = sorties de RowPresenter.present (unconfirmed, unavailable).
--   ns.Filters.new(saved) -> état ; saved = {hideUnconfirmed = bool, hideUnavailable = bool} | nil ;
--     la table sauvegardée est gardée et complétée (persistance par référence)
--   ns.Filters.toggle(state, key) ; key = "unconfirmed" ou "unavailable" (quête pas encore disponible) ;
--     clé inconnue ignorée
--   ns.Filters.apply(state, rows) -> nouvelle liste, ordre gardé
--   ns.Filters.chips(state, rows) -> {{key, label, count, active}...} : "unconfirmed", "unavailable" ; puce
--     présente si count > 0 ou si son filtre masque ; count avant filtrage ; active = lignes montrées ;
--     label = L.FILTER_CHIP (nom, count)

local _, ns = ...

local L = ns.L

local Filters = {}
ns.Filters = Filters

local UNCONFIRMED = "unconfirmed"
local UNAVAILABLE = "unavailable"

function Filters.new(saved)
    local state = type(saved) == "table" and saved or {}
    state.hideUnconfirmed = state.hideUnconfirmed == true
    state.hideUnavailable = state.hideUnavailable == true
    return state
end

function Filters.toggle(state, key)
    if key == UNCONFIRMED then
        state.hideUnconfirmed = not state.hideUnconfirmed
    elseif key == UNAVAILABLE then
        state.hideUnavailable = not state.hideUnavailable
    end
end

local function visible(state, row)
    return not ((row.unconfirmed and state.hideUnconfirmed) or (row.unavailable and state.hideUnavailable))
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
    local unconfirmed, unavailable = 0, 0
    for _, row in ipairs(rows) do
        if row.unconfirmed then
            unconfirmed = unconfirmed + 1
        end
        if row.unavailable then
            unavailable = unavailable + 1
        end
    end
    local chips = {}
    if unconfirmed > 0 or state.hideUnconfirmed then
        chips[#chips + 1] = chip(UNCONFIRMED, L.FILTER_UNCONFIRMED, unconfirmed, not state.hideUnconfirmed)
    end
    if unavailable > 0 or state.hideUnavailable then
        chips[#chips + 1] = chip(UNAVAILABLE, L.FILTER_UNAVAILABLE, unavailable, not state.hideUnavailable)
    end
    return chips
end
