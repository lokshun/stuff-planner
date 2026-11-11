-- CONTRAT
-- Trajet du suivi : maître de vol ou transport à prendre avant l'étape (Engine/Travel). Charger après
-- CompatTravel.lua, Engine/Travel.lua, Data/Transports.lua, Data/Names.lua et Follow.lua.
--   ns.FollowTravel.leg(step) -> {id, mapID, x, y, label} | nil (marche directe, en vol, position inconnue)
--     fly : maître de vol de départ, L.TRAVEL_FLY (départ, arrivée) ; boat, zeppelin : quai, L.TRAVEL_BOAT,
--     L.TRAVEL_ZEPPELIN (zone d'arrivée)
--   ns.FollowTravel.nodes() -> points de vol connus en coordonnées monde
-- Points de vol connus : relevés à TAXIMAP_OPENED (Compat.TaxiNodes), gardés dans
--   StuffPlannerCharDB.taxi = {[nodeID] = {name, mapID, x, y}} (ouvrir la carte de vol une fois par continent).
-- Toutes les TICK s pendant un suivi, hors combat : si le trajet de l'étape repérée change, Follow.refresh.
-- Positions monde : HereBeDragons-2.0 ; absent : aucun trajet (flèche directe).

local _, ns = ...

local L = ns.L

local FollowTravel = {}
ns.FollowTravel = FollowTravel

local TICK = 0.5
local LABELS = { boat = "TRAVEL_BOAT", zeppelin = "TRAVEL_ZEPPELIN" }

local worldNodes, worldTransports, lastID

local function hbd()
    return LibStub and LibStub("HereBeDragons-2.0", true)
end

local function saved()
    StuffPlannerCharDB = StuffPlannerCharDB or {}
    StuffPlannerCharDB.taxi = StuffPlannerCharDB.taxi or {}
    return StuffPlannerCharDB.taxi
end

local function world(lib, mapID, x, y, extra)
    local wx, wy, instance = lib:GetWorldCoordinatesFromZone(x, y, mapID)
    if not wx then
        return nil
    end
    extra.instance, extra.x, extra.y, extra.mapID, extra.mx, extra.my = instance, wx, wy, mapID, x, y
    return extra
end

function FollowTravel.nodes()
    local lib = hbd()
    if not worldNodes and lib then
        worldNodes = {}
        for id, node in pairs(saved()) do
            worldNodes[#worldNodes + 1] = world(lib, node.mapID, node.x, node.y, { id = id, name = node.name })
        end
    end
    return worldNodes or {}
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
    local transport = leg.transport
    local key = LABELS[leg.kind]
    if not key then
        return nil
    end
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
    local _, faction = UnitFactionGroup("player")
    local leg = ns.Travel.next({ instance = instance, x = px, y = py }, target, FollowTravel.nodes(),
        transports(lib), { faction = faction })
    if not leg or leg.kind == "walk" then
        return nil
    end
    return legOf(leg)
end

local function tick()
    local step = ns.Follow.current() and ns.Follow.target()
    if not step or InCombatLockdown() then
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
    worldNodes = nil
end

local events = CreateFrame("Frame")
events:RegisterEvent("TAXIMAP_OPENED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event)
    if event == "TAXIMAP_OPENED" then
        onTaxiMap()
    else
        C_Timer.NewTicker(TICK, tick)
    end
end)
