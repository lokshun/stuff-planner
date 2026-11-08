-- CONTRAT
-- Distance entre cartes en nombre de zones traversées. Pur : aucun appel d'API.
--   hops(fromMap, toMap, data, max?) -> 0 même carte, n zones (parcours en largeur sur data.neighbors,
--     absent : aucune voisine) ;
--     max (MAX_HOPS par défaut) au plus, et sans chemin ou carte nil
--   label(hops) -> "near" (0-1), "mid" (2), "far" (3 et plus, ou nil)
-- Parcours gardé pour la dernière carte de départ et la dernière façade (un seul en mémoire).

local _, ns = ...

local Distance = {}
ns.Distance = Distance

Distance.MAX_HOPS = 3

local cachedFrom, cachedData, cachedLimit, cachedDepth

-- Profondeur des cartes à moins de limit zones de fromMap.
local function explore(fromMap, data, limit)
    local depth, frontier = { [fromMap] = 0 }, { fromMap }
    for level = 1, limit - 1 do
        local nextFrontier = {}
        for _, mapID in ipairs(frontier) do
            for _, other in ipairs(data.neighbors and data.neighbors(mapID) or {}) do
                if depth[other] == nil then
                    depth[other] = level
                    nextFrontier[#nextFrontier + 1] = other
                end
            end
        end
        frontier = nextFrontier
    end
    return depth
end

function Distance.hops(fromMap, toMap, data, max)
    max = max or Distance.MAX_HOPS
    if fromMap == nil or toMap == nil then
        return max
    end
    if fromMap ~= cachedFrom or data ~= cachedData or max ~= cachedLimit then
        cachedFrom, cachedData, cachedLimit = fromMap, data, max
        cachedDepth = explore(fromMap, data, max)
    end
    return cachedDepth[toMap] or max
end

function Distance.label(hops)
    if hops ~= nil and hops <= 1 then
        return "near"
    elseif hops == 2 then
        return "mid"
    end
    return "far"
end
