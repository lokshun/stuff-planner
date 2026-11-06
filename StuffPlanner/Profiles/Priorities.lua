-- CONTRAT
-- Priorités de stats : l'utilisateur classe ses stats, on en déduit des poids. Pur : aucun appel
-- à l'API WoW. Charger après Engine/StatKeys.lua.
--   ns.Priorities.MAX = 10 ; DECAY = 0.7
--   toWeights(order) -> {KEY = DECAY^(rang-1)} (1re stat = 1, décroissance géométrique, jamais nul)
--     | nil, code, détail? ; codes : EMPTY, TOO_MANY, STAT (détail = clé), DUPLICATE (détail = clé)
--   fromWeights(weights) -> order : clés connues de poids > 0, poids décroissant puis clé, MAX au plus
--   move(order, index, delta) -> copie, rang index échangé avec index + delta (bornes : inchangée)
--   remove(order, index) -> copie sans ce rang ; add(order, key) -> copie avec key en dernier
--     (doublon, clé inconnue ou liste pleine : copie inchangée)
--   candidates(order) -> clés absentes de order, dans l'ordre de ns.StatKeyList
--   CAPPABLE = {HIT = true, SPELL_HIT = true} : seuls plafonds gérés par le moteur (en %)
--   parseCap(text) -> plafond (0 à 100, arrondi au dixième) | nil, code ; virgule décimale admise ;
--     codes : EMPTY (texte vide : pas de plafond), VALUE (illisible), RANGE (hors bornes)
--   KNOWN_CAPS[phase][key] : plafonds connus de Forever (API_NOTES.md) ; defaultCap(key, phase?,
--     baseCaps?) -> baseCaps[key] (profil de spé), sinon KNOWN_CAPS (phase « 60 » par défaut) ; nil hors CAPPABLE

local _, ns = ...

local Priorities = {}
ns.Priorities = Priorities

Priorities.MAX = 10
Priorities.DECAY = 0.7
Priorities.CAPPABLE = { HIT = true, SPELL_HIT = true }

local MAX_CAP = 100

-- Plafonds de Forever (API_NOTES.md) : 60 = cible de raid (+3 niveaux), mêlée et distance 8 %, sorts 17 % ;
-- montée de niveau = cible de même niveau, 5 % et 4 %. Arme dans chaque main ignorée (coups blancs).
Priorities.KNOWN_CAPS = {
    leveling = { HIT = 5, SPELL_HIT = 4 },
    ["60"] = { HIT = 8, SPELL_HIT = 17 },
}

function Priorities.defaultCap(key, phase, baseCaps)
    if not Priorities.CAPPABLE[key] then
        return nil
    end
    if baseCaps and baseCaps[key] then
        return baseCaps[key]
    end
    return (Priorities.KNOWN_CAPS[phase] or Priorities.KNOWN_CAPS["60"])[key]
end

function Priorities.parseCap(text)
    local trimmed = type(text) == "string" and text:match("^%s*(.-)%s*$") or ""
    if trimmed == "" then
        return nil, "EMPTY"
    end
    if not trimmed:match("^%-?%d+[.,]?%d*$") then
        return nil, "VALUE"
    end
    local value = tonumber((trimmed:gsub(",", ".")))
    if not value then
        return nil, "VALUE"
    end
    if value < 0 or value > MAX_CAP then
        return nil, "RANGE"
    end
    return math.floor(value * 10 + 0.5) / 10
end

local function known(key)
    return type(key) == "string" and rawget(ns.StatKeys, key) ~= nil
end

local function copy(order)
    local result = {}
    for i, key in ipairs(order) do
        result[i] = key
    end
    return result
end

function Priorities.toWeights(order)
    if type(order) ~= "table" or #order == 0 then
        return nil, "EMPTY"
    end
    if #order > Priorities.MAX then
        return nil, "TOO_MANY"
    end
    local weights = {}
    for rank, key in ipairs(order) do
        if not known(key) then
            return nil, "STAT", tostring(key)
        end
        if weights[key] then
            return nil, "DUPLICATE", key
        end
        weights[key] = Priorities.DECAY ^ (rank - 1)
    end
    return weights
end

function Priorities.fromWeights(weights)
    local order = {}
    for key, weight in pairs(type(weights) == "table" and weights or {}) do
        if known(key) and type(weight) == "number" and weight > 0 then
            order[#order + 1] = key
        end
    end
    table.sort(order, function(a, b)
        if weights[a] ~= weights[b] then
            return weights[a] > weights[b]
        end
        return a < b
    end)
    for i = #order, Priorities.MAX + 1, -1 do
        order[i] = nil
    end
    return order
end

function Priorities.move(order, index, delta)
    local result = copy(order)
    local target = index + delta
    if result[index] and result[target] then
        result[index], result[target] = result[target], result[index]
    end
    return result
end

function Priorities.remove(order, index)
    local result = copy(order)
    if result[index] then
        table.remove(result, index)
    end
    return result
end

local function contains(order, wanted)
    for _, key in ipairs(order) do
        if key == wanted then
            return true
        end
    end
    return false
end

function Priorities.add(order, key)
    local result = copy(order)
    if known(key) and #result < Priorities.MAX and not contains(result, key) then
        result[#result + 1] = key
    end
    return result
end

function Priorities.candidates(order)
    local result = {}
    for _, key in ipairs(ns.StatKeyList) do
        if not contains(order, key) then
            result[#result + 1] = key
        end
    end
    return result
end
