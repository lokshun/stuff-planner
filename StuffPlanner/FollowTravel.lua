-- CONTRAT
-- Trajet du suivi : maître de vol ou transport à prendre avant l'étape (Engine/Travel). Charger après
-- CompatTravel.lua, Engine/Travel.lua, Data/Transports.lua, Data/Names.lua et Follow.lua.
--   ns.FollowTravel.leg(step) -> {id, mapID, x, y, label} | nil (marche directe, en vol, position inconnue)
--     fly : maître de vol de départ, L.TRAVEL_FLY (départ, arrivée) ; boat, zeppelin : quai, L.TRAVEL_BOAT,
--     L.TRAVEL_ZEPPELIN (zone d'arrivée) ; aucun chemin : nil (flèche directe)
--   ns.FollowTravel.nodes() -> points de vol connus en coordonnées monde, région (ns.TravelRegions) comprise
--   ns.FollowTravel.reset() -> oublie les positions calculées (nouveaux points de vol)
-- Points de vol connus : Compat.KnownTaxiNodes sur Kalimdor et les Royaumes de l'Est (sans ouvrir la carte
--   de vol) ; sans cette API, ceux relevés à TAXIMAP_OPENED (Compat.TaxiNodes) dans
--   StuffPlannerCharDB.taxi = {[nodeID] = {name, mapID, x, y}}.
--   ns.FollowTravel.check() -> appelé toutes les TICK s : pendant un suivi, hors combat, recalcule le trajet de
--     l'étape repérée seulement si le joueur a bougé de plus de MOVE_YARDS, changé de carte, pris ou quitté un
--     vol, si l'étape ou les points de vol ont changé ; trajet changé : Follow.refresh.
-- Graphe des points de vol et transports (Travel.prepare) gardé jusqu'à reset ou un relevé de carte de vol.
-- Positions monde : HereBeDragons-2.0 ; absent : aucun trajet (flèche directe).

local _, ns = ...

local L = ns.L

local FollowTravel = {}
ns.FollowTravel = FollowTravel

local TICK = 0.5
local CONTINENTS = { 1414, 1415 }
local LABELS = { boat = "TRAVEL_BOAT", zeppelin = "TRAVEL_ZEPPELIN" }

FollowTravel.MOVE_YARDS = 50

local worldNodes, worldTransports, lastID, graph, lastCheck

local function hbd()
    return LibStub and LibStub("HereBeDragons-2.0", true)
end

local function faction()
    local _, name = UnitFactionGroup("player")
    return name
end

local function saved()
    return ns.DB.char("taxi")
end

local function regionOf(mapID)
    return mapID and ns.TravelRegions and ns.TravelRegions[mapID] or nil
end

local function world(lib, mapID, x, y, extra, region)
    local wx, wy, instance = lib:GetWorldCoordinatesFromZone(x, y, mapID)
    if not wx then
        return nil
    end
    extra.instance, extra.x, extra.y, extra.mapID, extra.mx, extra.my = instance, wx, wy, mapID, x, y
    extra.region = region or regionOf(mapID)
    return extra
end

local function knownNodes()
    local list, api = {}, false
    for _, continent in ipairs(CONTINENTS) do
        local nodes = ns.Compat.KnownTaxiNodes(continent, faction())
        if nodes then
            api = true
            for _, node in ipairs(nodes) do
                list[#list + 1] = node
            end
        end
    end
    if not api then
        for id, node in pairs(saved()) do
            list[#list + 1] = { nodeID = id, name = node.name, mapID = node.mapID, x = node.x, y = node.y }
        end
    end
    return list
end

function FollowTravel.nodes()
    local lib = hbd()
    if not worldNodes and lib then
        worldNodes = {}
        for _, node in ipairs(knownNodes()) do
            local region = regionOf(ns.Compat.MapAt(node.mapID, node.x, node.y))
            worldNodes[#worldNodes + 1] = world(lib, node.mapID, node.x, node.y,
                { id = node.nodeID, name = node.name }, region)
        end
    end
    return worldNodes or {}
end

function FollowTravel.reset()
    worldNodes, worldTransports, lastID, graph, lastCheck = nil, nil, nil, nil, nil
end

local function transports(lib)
    if not worldTransports then
        worldTransports = {}
        for _, entry in ipairs(ns.Transports or {}) do
            for _, ends in ipairs({ { entry.a, entry.b }, { entry.b, entry.a } }) do
                local from = world(lib, ends[1][1], ends[1][2], ends[1][3], {})
                local to = world(lib, ends[2][1], ends[2][2], ends[2][3], {})
                if from and to then
                    worldTransports[#worldTransports + 1] = { id = entry.id .. ":" .. ends[1][1], kind = entry.kind,
                        faction = entry.faction, from = from, to = to }
                end
            end
        end
    end
    return worldTransports
end

local function legOf(leg)
    if leg.kind == "fly" then
        local first = leg.target
        return { id = "fly:" .. tostring(first.id), mapID = first.mapID, x = first.mx, y = first.my,
            label = L.TRAVEL_FLY:format(first.name, leg.dest.name) }
    end
    local key = LABELS[leg.kind]
    if not key then
        return nil
    end
    local transport = leg.transport
    return { id = transport.id, mapID = transport.from.mapID, x = transport.from.mx, y = transport.from.my,
        label = L[key]:format(ns.Names.zone(transport.to.mapID)) }
end

function FollowTravel.leg(step)
    local lib = hbd()
    if not (lib and step and step.mapID) or ns.Compat.OnTaxi() then
        return nil
    end
    local px, py, instance = lib:GetPlayerWorldPosition()
    local target = world(lib, step.mapID, step.x, step.y, {})
    if not (px and target) then
        return nil
    end
    local from = { instance = instance, x = px, y = py, region = regionOf(ns.Compat.PlayerMapPosition()) }
    graph = graph or ns.Travel.prepare(FollowTravel.nodes(), transports(lib), { faction = faction() })
    local leg = ns.Travel.route(graph, from, target)
    if not leg or leg.kind == "walk" then
        return nil
    end
    return legOf(leg)
end

local function stepKey(step)
    return table.concat({ tostring(step.questID), tostring(step.kind), tostring(step.mapID), tostring(step.x),
        tostring(step.y) }, ":")
end

-- Position et contexte du dernier calcul ; vrai si rien n'a assez changé pour recalculer.
local function unchanged(step)
    local lib = hbd()
    local x, y, instance
    if lib then
        x, y, instance = lib:GetPlayerWorldPosition()
    end
    local state = { key = stepKey(step), x = x, y = y, instance = instance, mapID = ns.Compat.PlayerMapPosition(),
        taxi = ns.Compat.OnTaxi() and true or false }
    local last = lastCheck
    lastCheck = state
    if not (last and x and last.x) then
        return false
    end
    local dx, dy = x - last.x, y - last.y
    local moved = dx * dx + dy * dy > FollowTravel.MOVE_YARDS * FollowTravel.MOVE_YARDS
    if moved or last.key ~= state.key or last.instance ~= instance or last.mapID ~= state.mapID
        or last.taxi ~= state.taxi then
        return false
    end
    lastCheck = last -- la distance se compte depuis le dernier calcul
    return true
end

function FollowTravel.check()
    local step = ns.Follow.current() and ns.Follow.target()
    if not step or InCombatLockdown() or unchanged(step) then
        return
    end
    local leg = FollowTravel.leg(step)
    local id = leg and leg.id or false
    if id ~= lastID then
        lastID = id
        ns.Follow.refresh()
    end
end

local function onTaxiMap()
    local store = saved()
    for _, node in ipairs(ns.Compat.TaxiNodes()) do
        if node.known then
            store[node.nodeID] = { name = node.name, mapID = node.mapID, x = node.x, y = node.y }
        end
    end
    worldNodes, graph, lastCheck = nil, nil, nil
end

local events = CreateFrame("Frame")
events:RegisterEvent("TAXIMAP_OPENED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event)
    if event == "TAXIMAP_OPENED" then
        onTaxiMap()
    else
        C_Timer.NewTicker(TICK, FollowTravel.check)
    end
end)
