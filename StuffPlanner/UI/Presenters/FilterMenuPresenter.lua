-- CONTRAT
-- Menu « Filtres » d'une page (bouton à droite de la barre) : filtres à cocher puis tri. Pur : aucun appel
-- d'API. Charger après les Locales et Engine/Origins.lua.
--   ns.FilterMenuPresenter.sorts(active, keys) -> {{key, label, active}...} ; keys parmi "gain" (L.SORT_GAIN),
--     "slot" (L.SORT_SLOT), dans l'ordre donné ; active = clé du tri en cours
--   ns.FilterMenuPresenter.entries(chips?, sorts?, origins?) -> entrées de ns.RowMenu : avec origins
--     (Origins.new) {header = true, label = L.ORIGINS_HEADER} puis par type d'Origins.KINDS
--     {key = "origin:<type>", label = L.FILTER_<TYPE>, checked = visible} ; par puce (Filters.chips)
--     {key = "filter:<clé>", label, checked = active} ; puis, avec sorts, {header = true, label =
--     L.FILTER_SORT_BY} et par tri {key = "sort:<clé>", label, checked, radio} ; {separator = true} entre groupes
--   ns.FilterMenuPresenter.label(chips?, origins?) -> L.SORT_MENU sans filtres ni origines ; sinon L.FILTER_MENU,
--     ou L.FILTER_MENU_COUNT (puces qui masquent + origines masquées)
--   ns.FilterMenuPresenter.parse(key) -> "filter" | "sort" | "origin", valeur | nil

local _, ns = ...

local L = ns.L

local FilterMenuPresenter = {}
ns.FilterMenuPresenter = FilterMenuPresenter

local SORT_LABELS = { gain = "SORT_GAIN", slot = "SORT_SLOT" }
local ORIGIN_LABELS = { quest = "FILTER_QUEST", dungeon = "FILTER_DUNGEON", raid = "FILTER_RAID",
    craft = "FILTER_CRAFT", world = "FILTER_WORLD" }

function FilterMenuPresenter.sorts(active, keys)
    local sorts = {}
    for _, key in ipairs(keys) do
        sorts[#sorts + 1] = { key = key, label = L[SORT_LABELS[key]], active = key == active }
    end
    return sorts
end

local function separate(entries)
    if #entries > 0 then
        entries[#entries + 1] = { separator = true }
    end
end

function FilterMenuPresenter.entries(chips, sorts, origins)
    local entries = {}
    if origins then
        entries[1] = { header = true, label = L.ORIGINS_HEADER }
        for _, kind in ipairs(ns.Origins.KINDS) do
            entries[#entries + 1] = { key = "origin:" .. kind, label = L[ORIGIN_LABELS[kind]],
                checked = ns.Origins.allows(origins, kind) }
        end
    end
    if chips and #chips > 0 then
        separate(entries)
    end
    for _, chip in ipairs(chips or {}) do
        entries[#entries + 1] = { key = "filter:" .. chip.key, label = chip.label, checked = chip.active == true }
    end
    if sorts and #sorts > 0 then
        separate(entries)
        entries[#entries + 1] = { header = true, label = L.FILTER_SORT_BY }
        for _, sort in ipairs(sorts) do
            entries[#entries + 1] = { key = "sort:" .. sort.key, label = sort.label, checked = sort.active == true,
                radio = true }
        end
    end
    return entries
end

function FilterMenuPresenter.label(chips, origins)
    if not chips and not origins then
        return L.SORT_MENU
    end
    local hidden = ns.Origins.hiddenCount(origins)
    for _, chip in ipairs(chips or {}) do
        if not chip.active then
            hidden = hidden + 1
        end
    end
    return hidden > 0 and L.FILTER_MENU_COUNT:format(hidden) or L.FILTER_MENU
end

function FilterMenuPresenter.parse(key)
    local kind, value = tostring(key):match("^(%a+):(.+)$")
    if kind ~= "filter" and kind ~= "sort" and kind ~= "origin" then
        return nil
    end
    return kind, value
end
