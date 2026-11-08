-- CONTRAT
-- Priorité de parcours : (gain × durée de vie + ALPHA × XP) / effort. Pur : aucun appel à l'API WoW.
-- Charger après Engine/Scoring.lua, Engine/Chains.lua et Engine/Distance.lua.
--   candidates(itemIDs, data, step?) -> {{itemID, source}...}, une entrée par source de data.sourcesOf ;
--     step() appelé après chaque objet (sourcesOf décode la base : à étaler)
--   rank(candidates, player, profile, data, opts?) -> {{itemID, source, delta, effort, xp, level, hops,
--     priority}...} : un objet une fois (sa meilleure source), tri par priorité décroissante
--     puis itemID ; delta = Scoring.delta ({abs, pct, slot}), objets à gain abs <= 0 écartés.
--     opts.isDone(questID) ; opts.includeRaids (raids écartés sinon) ; opts.tuning = {clé=valeur}
--     remplace les constantes de Planner.TUNING ; opts.step() appelé après chaque candidat
--     (coroutine.yield pour étaler le calcul sur plusieurs images) ; opts.pause() appelé une fois avant
--     le tri final (yield sans condition : le tri ne partage pas son image).
-- level = niveau d'obtention : max(reqLevel de l'objet, niveau de la quête | minLevel de l'instance) ;
--   les récompenses de quête de Classic n'ont souvent pas de niveau requis (reqLevel 1).
-- Durée de vie : min(LIFESPAN, 60 - L) / LIFESPAN, L = max(niveau du joueur, level) ; 1 si L >= 60.
-- Trajet : TRAVEL × hops, hops = Distance.hops(carte du joueur, carte de la source, MAX_HOPS) ; carte de la
--   quête, entrée de l'instance (donjon, raid) ; 0 et hops nil si l'une est inconnue ou pour l'artisanat.
-- Effort : quête = étapes restantes (Chains.steps) × QUEST_STEP + trajet ; écartée si faite, en cycle,
--   inconnue, d'une autre classe ou race (Scoring.allows) ;
--   alternative de prérequis d'une autre race écartée (Chains, isAllowed).
--   Donjon, raid = DUNGEON_RUN, RAID_RUN × 100 / chance (DEFAULT_CHANCE sans taux, MIN_CHANCE au
--   moins) + trajet ; artisanat = CRAFT si player.professions[skillLine], CRAFT_UNKNOWN sinon.
-- XP : quêtes seulement, nombre d'étapes restantes non grises ; 0 au niveau 60.

local _, ns = ...

local Planner = {}
ns.Planner = Planner

local MAX_LEVEL = 60

Planner.TUNING = {
    LIFESPAN = 8,
    ALPHA = 0.1,
    QUEST_STEP = 1,
    TRAVEL = 1,
    MAX_HOPS = 3,
    DUNGEON_RUN = 4,
    RAID_RUN = 20,
    DEFAULT_CHANCE = 5,
    MIN_CHANCE = 1,
    CRAFT = 2,
    CRAFT_UNKNOWN = 6,
}

function Planner.candidates(itemIDs, data, step)
    local out = {}
    for _, itemID in ipairs(itemIDs) do
        for _, source in ipairs(data.sourcesOf(itemID) or {}) do
            out[#out + 1] = { itemID = itemID, source = source }
        end
        if step then
            step()
        end
    end
    return out
end

-- Niveau de quête sous lequel elle est grise (règle de Classic).
local function greyLevel(level)
    if level <= 5 then
        return 0
    elseif level <= 39 then
        return level - 5 - math.floor(level / 10)
    end
    return level - 1 - math.floor(level / 5)
end

local function obtainLevel(item, source, data)
    local level = item and item.reqLevel or 1
    if source.type == "quest" then
        local quest = data.quest(source.id)
        level = math.max(level, quest and (quest.level or quest.reqLevel) or 1)
    elseif source.type == "dungeon" or source.type == "raid" then
        local instance = data.instance and data.instance(source.id)
        level = math.max(level, instance and instance.minLevel or 1)
    end
    return level
end

local function lifetime(obtained, player, tuning)
    local level = math.max(player.level or 1, obtained)
    if level >= MAX_LEVEL then
        return 1
    end
    return math.min(tuning.LIFESPAN, MAX_LEVEL - level) / tuning.LIFESPAN
end

local function questXP(steps, player, data)
    local level = player.level or 1
    if level >= MAX_LEVEL then
        return 0
    end
    local grey, xp = greyLevel(level), 0
    for _, id in ipairs(steps) do
        local quest = data.quest(id)
        if quest and (quest.level or 0) > grey then
            xp = xp + 1
        end
    end
    return xp
end

-- Zones entre le joueur et mapID ; nil si l'une des cartes est inconnue.
local function hopsTo(mapID, player, data, tuning)
    if not mapID or not player.mapID then
        return nil
    end
    return ns.Distance.hops(player.mapID, mapID, data, tuning.MAX_HOPS)
end

local function travel(hops, tuning)
    return (hops or 0) * tuning.TRAVEL
end

-- Renvoie effort, xp, hops ; nil si la source est écartée.
local function questEffort(source, player, data, opts, tuning)
    local quest = data.quest(source.id)
    if not quest or not ns.Scoring.allows(quest, player) then
        return nil
    end
    local steps = ns.Chains.remaining(source.id, data, opts.isDone, function(id)
        local step = data.quest(id)
        return not step or ns.Scoring.allows(step, player)
    end)
    if not steps or #steps == 0 then
        return nil
    end
    local hops = hopsTo(quest.mapID, player, data, tuning)
    return #steps * tuning.QUEST_STEP + travel(hops, tuning), questXP(steps, player, data), hops
end

local function runs(source, tuning)
    local chance = math.max(source.chance or tuning.DEFAULT_CHANCE, tuning.MIN_CHANCE)
    return 100 / chance
end

local function instanceEffort(source, player, data, tuning, perRun)
    local instance = data.instance and data.instance(source.id)
    local hops = hopsTo(instance and instance.mapID, player, data, tuning)
    return perRun * runs(source, tuning) + travel(hops, tuning), 0, hops
end

local function effortOf(source, player, data, opts, tuning)
    local kind = source.type
    if kind == "quest" then
        return questEffort(source, player, data, opts, tuning)
    elseif kind == "dungeon" then
        return instanceEffort(source, player, data, tuning, tuning.DUNGEON_RUN)
    elseif kind == "raid" then
        if not opts.includeRaids then
            return nil
        end
        return instanceEffort(source, player, data, tuning, tuning.RAID_RUN)
    elseif kind == "craft" then
        local known = player.professions and player.professions[source.skillLine]
        return known and tuning.CRAFT or tuning.CRAFT_UNKNOWN, 0
    end
    return nil
end

local function tuningOf(opts)
    local tuning = {}
    for key, value in pairs(Planner.TUNING) do
        tuning[key] = value
    end
    for key, value in pairs(opts.tuning or {}) do
        tuning[key] = value
    end
    return tuning
end

function Planner.rank(candidates, player, profile, data, opts)
    opts = opts or {}
    local tuning = tuningOf(opts)
    local best, deltas = {}, {}
    for _, candidate in ipairs(candidates) do
        local itemID = candidate.itemID
        if deltas[itemID] == nil then
            deltas[itemID] = ns.Scoring.delta(itemID, player, profile, data) or false
        end
        local delta = deltas[itemID]
        if delta and delta.abs > 0 then
            local effort, xp, hops = effortOf(candidate.source, player, data, opts, tuning)
            if effort and effort > 0 then
                local level = obtainLevel(data.item(itemID), candidate.source, data)
                local gain = delta.abs * lifetime(level, player, tuning)
                local priority = (gain + tuning.ALPHA * xp) / effort
                local current = best[itemID]
                if not current or priority > current.priority then
                    best[itemID] = {
                        itemID = itemID,
                        source = candidate.source,
                        delta = delta,
                        effort = effort,
                        xp = xp,
                        level = level,
                        hops = hops,
                        priority = priority,
                    }
                end
            end
        end
        if opts.step then
            opts.step()
        end
    end
    if opts.pause then
        opts.pause()
    end
    local out = {}
    for _, row in pairs(best) do
        out[#out + 1] = row
    end
    table.sort(out, function(a, b)
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end
        return a.itemID < b.itemID
    end)
    return out
end
