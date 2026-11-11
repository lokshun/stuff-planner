-- CONTRAT
-- Suite de ns.Compat : points de vol et vol en cours. Charger après Compat.lua.
-- Détection par fonctionnalité ; API absente : liste vide ou false, jamais d'erreur.
--   TaxiNodes() -> {{nodeID, name, mapID, x, y, known}...} : nœuds de la carte de vol ouverte
--     (GetTaxiMapID) ; C_TaxiMap.GetAllTaxiNodes (state 2 = inaccessible : known faux), sinon
--     NumTaxiNodes/TaxiNodeName/TaxiNodePosition/TaxiNodeGetType ("NONE" : known faux, nodeID = nom)
--   OnTaxi() -> bool : le joueur est en vol (UnitOnTaxi)

local _, ns = ...

local Compat = ns.Compat

local UNREACHABLE = 2

local function modernNodes(mapID)
    local nodes = {}
    for _, node in ipairs(C_TaxiMap.GetAllTaxiNodes(mapID) or {}) do
        local position = node.position
        if position then
            nodes[#nodes + 1] = { nodeID = node.nodeID, name = node.name, mapID = mapID, x = position.x,
                y = position.y, known = node.state ~= UNREACHABLE }
        end
    end
    return nodes
end

local function legacyNodes(mapID)
    local nodes = {}
    for index = 1, NumTaxiNodes() do
        local name = TaxiNodeName(index)
        local x, y = TaxiNodePosition(index)
        if name and x and y then
            nodes[#nodes + 1] = { nodeID = name, name = name, mapID = mapID, x = x, y = y,
                known = TaxiNodeGetType(index) ~= "NONE" }
        end
    end
    return nodes
end

function Compat.TaxiNodes()
    local mapID = GetTaxiMapID and GetTaxiMapID()
    if not mapID then
        return {}
    end
    if C_TaxiMap and C_TaxiMap.GetAllTaxiNodes then
        return modernNodes(mapID)
    end
    if NumTaxiNodes and TaxiNodeName and TaxiNodePosition and TaxiNodeGetType then
        return legacyNodes(mapID)
    end
    return {}
end

function Compat.OnTaxi()
    return UnitOnTaxi ~= nil and UnitOnTaxi("player") == true
end
