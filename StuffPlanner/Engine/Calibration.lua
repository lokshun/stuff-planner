-- CONTRAT
-- Mesures du joueur (Data/Timings) : fenêtres glissantes bornées et médianes. Pur : aucun appel à l'API WoW.
--   ns.Calibration.KINDS -> {"quest", "dungeon", "raid", "travel"} (ordre d'affichage)
--   ns.Calibration.BOUNDS -> {[kind] = {min, max}} : quest, dungeon, raid en secondes de jeu actif ;
--     travel = durée réelle / durée prévue (sans unité)
--   ns.Calibration.WINDOW -> nombre de mesures gardées par sorte (les plus anciennes sortent)
--   ns.Calibration.add(samples, kind, value) -> bool : value dans les bornes de kind ajoutée à samples[kind]
--     (créée au besoin) ; sorte inconnue, NaN ou hors bornes : refusée, samples intact
--   ns.Calibration.median(list) -> number | nil (liste vide ou nil) ; list n'est pas modifiée
--   ns.Calibration.medians(samples) -> {{kind, median?, count}...} dans l'ordre de KINDS ; samples nil : vide

local _, ns = ...

local Calibration = {}
ns.Calibration = Calibration

Calibration.KINDS = { "quest", "dungeon", "raid", "travel" }
Calibration.BOUNDS = {
    quest = { 30, 7200 },
    dungeon = { 600, 14400 },
    raid = { 1800, 21600 },
    travel = { 0.25, 4 },
}
Calibration.WINDOW = 25

function Calibration.add(samples, kind, value)
    local bounds = Calibration.BOUNDS[kind]
    if not bounds or type(value) ~= "number" or value ~= value or value < bounds[1] or value > bounds[2] then
        return false
    end
    local list = samples[kind] or {}
    samples[kind] = list
    list[#list + 1] = value
    while #list > Calibration.WINDOW do
        table.remove(list, 1)
    end
    return true
end

function Calibration.median(list)
    if not list or #list == 0 then
        return nil
    end
    local sorted = {}
    for i, value in ipairs(list) do
        sorted[i] = value
    end
    table.sort(sorted)
    local middle = math.floor(#sorted / 2)
    if #sorted % 2 == 1 then
        return sorted[middle + 1]
    end
    return (sorted[middle] + sorted[middle + 1]) / 2
end

function Calibration.medians(samples)
    local rows = {}
    for i, kind in ipairs(Calibration.KINDS) do
        local list = samples and samples[kind]
        rows[i] = { kind = kind, median = Calibration.median(list), count = list and #list or 0 }
    end
    return rows
end
