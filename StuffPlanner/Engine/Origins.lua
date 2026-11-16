-- CONTRAT
-- Origines des objets choisies par une page (quête, donjon, raid, artisanat, butin du monde). Pur : aucun
-- appel à l'API WoW. Filtre appliqué avant le classement (Planner opts.origins, Chat.bestInZone opts.origins).
--   ns.Origins.KINDS -> {"quest", "dungeon", "raid", "craft", "world"} (ordre d'affichage)
--   ns.Origins.new(saved) -> état {hidden = {[kind] = true}} ; la table sauvegardée est gardée et nettoyée
--     (persistance par référence) ; clés inconnues retirées ; tout masqué -> tout remontré
--   ns.Origins.allows(state | nil, kind) -> bool ; nil, type absent ou inconnu : vrai
--   ns.Origins.toggle(state, kind) -> bool (changé) ; refuse de masquer la dernière origine visible
--   ns.Origins.isLast(state, kind) -> vrai si kind est la seule origine visible
--   ns.Origins.key(state | nil) -> origines masquées triées, jointes par « , » ; "" = toutes (clé de cache)
--   ns.Origins.hiddenCount(state | nil) -> nombre d'origines masquées

local _, ns = ...

local Origins = {}
ns.Origins = Origins

Origins.KINDS = { "quest", "dungeon", "raid", "craft", "world" }

local KNOWN = {}
for _, kind in ipairs(Origins.KINDS) do
    KNOWN[kind] = true
end

local function visibleCount(state)
    local count = 0
    for _, kind in ipairs(Origins.KINDS) do
        if not state.hidden[kind] then
            count = count + 1
        end
    end
    return count
end

function Origins.new(saved)
    local state = type(saved) == "table" and saved or {}
    if type(state.hidden) ~= "table" then
        state.hidden = {}
    end
    for kind, value in pairs(state.hidden) do
        if not KNOWN[kind] or value ~= true then
            state.hidden[kind] = nil
        end
    end
    if visibleCount(state) == 0 then
        state.hidden = {}
    end
    return state
end

function Origins.allows(state, kind)
    return not (state and kind and state.hidden[kind])
end

function Origins.isLast(state, kind)
    return not state.hidden[kind] and visibleCount(state) == 1
end

function Origins.toggle(state, kind)
    if not KNOWN[kind] or Origins.isLast(state, kind) then
        return false
    end
    state.hidden[kind] = not state.hidden[kind] or nil
    return true
end

function Origins.key(state)
    local hidden = {}
    for _, kind in ipairs(Origins.KINDS) do
        if state and state.hidden[kind] then
            hidden[#hidden + 1] = kind
        end
    end
    table.sort(hidden)
    return table.concat(hidden, ",")
end

function Origins.hiddenCount(state)
    return state and #Origins.KINDS - visibleCount(state) or 0
end
