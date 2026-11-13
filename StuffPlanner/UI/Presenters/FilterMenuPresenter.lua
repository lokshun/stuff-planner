-- CONTRAT
-- Menu « Filtres » d'une page (bouton à droite de la barre) : filtres à cocher puis tri. Pur : aucun appel
-- d'API. Charger après les Locales.
--   ns.FilterMenuPresenter.sorts(active, keys) -> {{key, label, active}...} ; keys parmi "gain" (L.SORT_GAIN),
--     "slot" (L.SORT_SLOT), dans l'ordre donné ; active = clé du tri en cours
--   ns.FilterMenuPresenter.entries(chips?, sorts?) -> entrées de ns.RowMenu : par puce (Filters.chips)
--     {key = "filter:<clé>", label, checked = active} ; puis, avec sorts : {separator = true} (s'il y a des
--     filtres), {header = true, label = L.FILTER_SORT_BY}, et par tri {key = "sort:<clé>", label, checked, radio}
--   ns.FilterMenuPresenter.label(chips?) -> L.SORT_MENU sans filtres (nil) ; sinon L.FILTER_MENU, ou
--     L.FILTER_MENU_COUNT (nombre de filtres qui masquent : active = false)
--   ns.FilterMenuPresenter.parse(key) -> "filter" | "sort", valeur | nil

local _, ns = ...

local L = ns.L

local FilterMenuPresenter = {}
ns.FilterMenuPresenter = FilterMenuPresenter

local SORT_LABELS = { gain = "SORT_GAIN", slot = "SORT_SLOT" }

function FilterMenuPresenter.sorts(active, keys)
    local sorts = {}
    for _, key in ipairs(keys) do
        sorts[#sorts + 1] = { key = key, label = L[SORT_LABELS[key]], active = key == active }
    end
    return sorts
end

function FilterMenuPresenter.entries(chips, sorts)
    local entries = {}
    for _, chip in ipairs(chips or {}) do
        entries[#entries + 1] = { key = "filter:" .. chip.key, label = chip.label, checked = chip.active == true }
    end
    if sorts and #sorts > 0 then
        if #entries > 0 then
            entries[#entries + 1] = { separator = true }
        end
        entries[#entries + 1] = { header = true, label = L.FILTER_SORT_BY }
        for _, sort in ipairs(sorts) do
            entries[#entries + 1] = { key = "sort:" .. sort.key, label = sort.label, checked = sort.active == true,
                radio = true }
        end
    end
    return entries
end

function FilterMenuPresenter.label(chips)
    if not chips then
        return L.SORT_MENU
    end
    local hidden = 0
    for _, chip in ipairs(chips) do
        if not chip.active then
            hidden = hidden + 1
        end
    end
    return hidden > 0 and L.FILTER_MENU_COUNT:format(hidden) or L.FILTER_MENU
end

function FilterMenuPresenter.parse(key)
    local kind, value = tostring(key):match("^(%a+):(.+)$")
    if kind ~= "filter" and kind ~= "sort" then
        return nil
    end
    return kind, value
end
