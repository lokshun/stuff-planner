-- CONTRAT
-- Textes de l'onglet Profil. Pur : aucun appel d'API. Charger après Format.lua.
--   ns.ProfilePresenter.options(ids, get, activeID?) -> {{id, label, active}, …} dans l'ordre de ids ;
--     get(id) -> profil ; label = L.PROFILE_OPTION (spé, phase), L.PROFILE_CUSTOM pour le profil importé,
--     L.PROFILE_MY_STATS s'il vient des priorités (champ order) ;
--     spé sans libellé SPEC_<jeton> : jeton en casse de titre
--   grid(ids, get, activeID?, manualID?) -> {auto = {label, active = pas de choix manuel},
--     phases = {{key = "leveling" | "60", label}, …}, specs = {{spec, label, cells = {[phase] =
--     {id, active}}}, …} (ordre de ids, case absente si la phase manque), extras = {{id, label,
--     active}, …} (profils CUSTOM : Mes stats ou importés)} ; active = id == activeID
--   weightRows(profile) -> {{key, label, valueText, capText, fraction}, …} : poids décroissant puis
--     clé ; fraction = poids / plus fort poids (0-1, 0 si négatif ou sans poids positif) ;
--     clés plafonnées sans poids incluses (poids 0) ; vide sans profil
--   priorityRows(order, weights?) -> {{key, label = "<rang>. <stat>", weightText}, …} ; weightText vide
--     sans poids pour la clé
--   importError(code, detail?) -> message localisé (L.IMPORT_ERR_<code>, FORMAT si inconnu)

local _, ns = ...

local L = ns.L

local ProfilePresenter = {}
ns.ProfilePresenter = ProfilePresenter

local CUSTOM_SPEC = "CUSTOM"

local function specName(spec)
    local label = rawget(L, "SPEC_" .. spec)
    if label then
        return label
    end
    return spec:sub(1, 1) .. spec:sub(2):lower()
end

local function phaseName(phase)
    return phase == "60" and L.PHASE_60 or L.PHASE_LEVELING
end

local function statLabel(key)
    return rawget(L, "STAT_" .. key) or key
end

local function label(profile)
    if profile.spec == CUSTOM_SPEC then
        return profile.order and L.PROFILE_MY_STATS or L.PROFILE_CUSTOM
    end
    return L.PROFILE_OPTION:format(specName(profile.spec), phaseName(profile.phase))
end

function ProfilePresenter.options(ids, get, activeID)
    local options = {}
    for _, id in ipairs(ids) do
        local profile = get(id)
        if profile then
            options[#options + 1] = { id = id, label = label(profile), active = id == activeID }
        end
    end
    return options
end

function ProfilePresenter.grid(ids, get, activeID, manualID)
    local grid = {
        auto = { label = L.PROFILE_AUTO, active = manualID == nil },
        phases = {
            { key = "leveling", label = L.PROFILE_COLUMN_LEVELING },
            { key = "60", label = L.PROFILE_COLUMN_60 },
        },
        specs = {},
        extras = {},
    }
    local bySpec = {}
    for _, id in ipairs(ids) do
        local profile = get(id)
        if profile and profile.spec == CUSTOM_SPEC then
            grid.extras[#grid.extras + 1] = { id = id, label = label(profile), active = id == activeID }
        elseif profile then
            local row = bySpec[profile.spec]
            if not row then
                row = { spec = profile.spec, label = specName(profile.spec), cells = {} }
                bySpec[profile.spec] = row
                grid.specs[#grid.specs + 1] = row
            end
            row.cells[profile.phase] = { id = id, active = id == activeID }
        end
    end
    return grid
end

function ProfilePresenter.weightRows(profile)
    if not profile then
        return {}
    end
    local weights, caps = profile.weights or {}, profile.caps or {}
    local keys, seen = {}, {}
    for _, values in ipairs({ weights, caps }) do
        for key in pairs(values) do
            if not seen[key] then
                seen[key] = true
                keys[#keys + 1] = key
            end
        end
    end
    table.sort(keys, function(a, b)
        local wa, wb = weights[a] or 0, weights[b] or 0
        if wa ~= wb then
            return wa > wb
        end
        return a < b
    end)
    local top = keys[1] and weights[keys[1]] or 0
    local rows = {}
    for i, key in ipairs(keys) do
        local cap = caps[key]
        local weight = weights[key] or 0
        rows[i] = {
            key = key,
            label = statLabel(key),
            valueText = ns.Format.number(weights[key] or 0, nil, 2),
            capText = cap and L.PROFILE_CAP:format(ns.Format.number(cap, nil, cap % 1 == 0 and 0 or 1)) or "",
            fraction = (top > 0 and weight > 0) and weight / top or 0,
        }
    end
    return rows
end

function ProfilePresenter.priorityRows(order, weights)
    local rows = {}
    for rank, key in ipairs(order or {}) do
        local weight = weights and weights[key]
        rows[rank] = {
            key = key,
            label = rank .. ". " .. statLabel(key),
            weightText = weight and ns.Format.number(weight, nil, 2) or "",
        }
    end
    return rows
end

function ProfilePresenter.importError(code, detail)
    local message = rawget(L, "IMPORT_ERR_" .. tostring(code)) or L.IMPORT_ERR_FORMAT
    return message:format(detail or "")
end
