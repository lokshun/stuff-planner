-- CONTRAT
-- Prochaine étape d'un trajet : marche, vol (points de vol connus) ou transport. Pur : aucun appel à
-- l'API WoW. Positions en coordonnées monde (yards, HereBeDragons).
--   ns.Travel.next(from, to, nodes, transports [, opts]) -> leg | nil (from ou to nil)
--     point = {instance, x, y, region?} : region = île (Teldrassil) ; à pied seulement dans la même
--       instance et la même région (nil = terre principale)
--     nodes = {{id, name, instance, x, y, region?}...} (points de vol connus, reliés entre eux sur un même
--       continent) ; transports = {{id, kind = "boat" | "zeppelin" | "portal", faction?, from, to}...}
--       (un sens, dans le même continent ou non) ; opts.faction : transports d'une autre faction écartés
--     leg = {kind = "walk"} | {kind = "walk", unreachable = true} (aucun chemin)
--         | {kind = "fly", target = nœud de départ, dest = nœud d'arrivée, transport? (pris ensuite)}
--         | {kind = transport.kind, target = transport.from, transport}
--   Plus court chemin (Dijkstra) en secondes : marche distance / TUNING.walk ; vol distance / TUNING.fly
--     + TUNING.overhead ; transport TUNING.transport ; vol et transport divisés par TUNING.ratio (on ne
--     quitte la marche que si on y gagne). leg = première étape non à pied du chemin, sinon marche.
--   ns.Travel.TUNING = {walk, fly (yards/s), overhead, transport (s), ratio} : constantes provisoires.

local _, ns = ...

local Travel = {}
ns.Travel = Travel

Travel.TUNING = { walk = 7, fly = 30, overhead = 60, transport = 120, ratio = 0.85 }

local INFINITE = math.huge

local function distance(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function walkable(a, b)
    return a.instance == b.instance and a.region == b.region
end

-- Sommets : 1 = départ, 2 = arrivée, puis nœuds de vol, puis extrémités des transports.
local function graph(from, to, nodes, transports, faction)
    local vertices = { { point = from }, { point = to } }
    for _, node in ipairs(nodes) do
        vertices[#vertices + 1] = { point = node, node = node }
    end
    for _, transport in ipairs(transports) do
        if not transport.faction or not faction or transport.faction == faction then
            local arrival = { point = transport.to }
            vertices[#vertices + 1] = { point = transport.from, transport = transport, arrival = arrival }
            vertices[#vertices + 1] = arrival
        end
    end
    return vertices
end

-- Coût et genre de l'arête u -> v, ou nil.
local function edge(u, v)
    local tuning = Travel.TUNING
    if u.arrival == v then
        return tuning.transport / tuning.ratio, "transport"
    end
    local a, b = u.point, v.point
    if u.node and v.node and a.instance == b.instance then
        local walking = walkable(a, b) and distance(a, b) / tuning.walk or INFINITE
        local flying = (distance(a, b) / tuning.fly + tuning.overhead) / tuning.ratio
        if flying < walking then
            return flying, "fly"
        end
    end
    if walkable(a, b) then
        return distance(a, b) / tuning.walk, "walk"
    end
    return nil
end

local function shortest(vertices)
    local cost, previous, kinds, done = { [1] = 0 }, {}, {}, {}
    while true do
        local u, best = nil, INFINITE
        for index in ipairs(vertices) do
            if not done[index] and (cost[index] or INFINITE) < best then
                u, best = index, cost[index]
            end
        end
        if not u or u == 2 then
            return previous, kinds, u == 2
        end
        done[u] = true
        for v in ipairs(vertices) do
            if not done[v] then
                local weight, kind = edge(vertices[u], vertices[v])
                if weight and best + weight < (cost[v] or INFINITE) then
                    cost[v], previous[v], kinds[v] = best + weight, u, kind
                end
            end
        end
    end
end

local function firstLeg(vertices, previous, kinds)
    local path = {}
    local v = 2
    while previous[v] do
        table.insert(path, 1, { from = previous[v], to = v, kind = kinds[v] })
        v = previous[v]
    end
    for index, step in ipairs(path) do
        if step.kind == "fly" then
            local last = index
            while path[last + 1] and path[last + 1].kind == "fly" do
                last = last + 1
            end
            local leg = { kind = "fly", target = vertices[step.from].node, dest = vertices[path[last].to].node }
            for later = last + 1, #path do
                if path[later].kind == "transport" then
                    leg.transport = vertices[path[later].from].transport
                    break
                end
            end
            return leg
        elseif step.kind == "transport" then
            local transport = vertices[step.from].transport
            return { kind = transport.kind, target = transport.from, transport = transport }
        end
    end
    return { kind = "walk" }
end

function Travel.next(from, to, nodes, transports, opts)
    if not (from and to) then
        return nil
    end
    local vertices = graph(from, to, nodes or {}, transports or {}, opts and opts.faction)
    local previous, kinds, found = shortest(vertices)
    if not found then
        return { kind = "walk", unreachable = true }
    end
    return firstLeg(vertices, previous, kinds)
end
