-- CONTRAT
-- Prochaine étape d'un trajet : marche, vol (maître de vol connu) ou transport vers un autre continent.
-- Pur : aucun appel à l'API WoW. Positions en coordonnées monde (mètres-yards, HereBeDragons).
--   ns.Travel.next(from, to, nodes, transports [, opts]) -> leg | nil (from ou to nil)
--     from, to = {instance, x, y} ; nodes = {{id, name, instance, x, y}...} (points de vol connus)
--     transports = {{id, kind = "boat" | "zeppelin" | "portal", faction?, from = point, to = point}...}
--     opts.faction : transports d'une autre faction écartés
--     leg = {kind = "walk"} | {kind = "walk", unreachable = true} (autre continent, aucun transport)
--         | {kind = "fly", target = nœud de départ, dest = nœud d'arrivée, transport?}
--         | {kind = transport.kind, target = transport.from, transport}
--   Même continent : vol si marche(→ départ) + vol / TUNING.fly + TUNING.overhead + marche(arrivée →)
--     < TUNING.ratio × marche directe ; départ = nœud le plus proche du joueur, arrivée = le plus proche
--     de la cible, différents. Autre continent : transport au plus court (marche jusqu'au quai + du quai
--     d'arrivée à la cible) ; le trajet jusqu'au quai suit la règle du même continent (vol gardé).
--   ns.Travel.TUNING = {walk, fly (yards/s), overhead (s), ratio} : constantes provisoires.

local _, ns = ...

local Travel = {}
ns.Travel = Travel

Travel.TUNING = { walk = 7, fly = 30, overhead = 60, ratio = 0.85 }

local function distance(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function nearest(point, nodes)
    local best, bestDistance
    for _, node in ipairs(nodes) do
        if node.instance == point.instance then
            local d = distance(point, node)
            if not bestDistance or d < bestDistance then
                best, bestDistance = node, d
            end
        end
    end
    return best
end

local function sameContinent(from, to, nodes)
    local tuning = Travel.TUNING
    local first, last = nearest(from, nodes), nearest(to, nodes)
    if first and last and first ~= last then
        local walking = distance(from, to) / tuning.walk
        local flying = (distance(from, first) + distance(last, to)) / tuning.walk
            + distance(first, last) / tuning.fly + tuning.overhead
        if flying < tuning.ratio * walking then
            return { kind = "fly", target = first, dest = last }
        end
    end
    return { kind = "walk" }
end

local function bestTransport(from, to, transports, faction)
    local best, bestCost
    for _, transport in ipairs(transports) do
        local usable = transport.from.instance == from.instance and transport.to.instance == to.instance
            and (not transport.faction or not faction or transport.faction == faction)
        if usable then
            local cost = distance(from, transport.from) + distance(transport.to, to)
            if not bestCost or cost < bestCost then
                best, bestCost = transport, cost
            end
        end
    end
    return best
end

function Travel.next(from, to, nodes, transports, opts)
    if not (from and to) then
        return nil
    end
    nodes = nodes or {}
    if from.instance == to.instance then
        return sameContinent(from, to, nodes)
    end
    local transport = bestTransport(from, to, transports or {}, opts and opts.faction)
    if not transport then
        return { kind = "walk", unreachable = true }
    end
    local leg = sameContinent(from, transport.from, nodes)
    if leg.kind == "fly" then
        leg.transport = transport
        return leg
    end
    return { kind = transport.kind, target = transport.from, transport = transport }
end
