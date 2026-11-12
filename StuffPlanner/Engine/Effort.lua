-- CONTRAT
-- Effort d'une source en secondes (règles décrites dans l'en-tête de Planner.lua : quête, donjon, raid, monde,
-- artisanat, trajet). Pur : aucun appel à l'API WoW. Charger après Engine/Scoring.lua, Engine/Chains.lua et
-- Engine/Distance.lua, avant Engine/Planner.lua.
--   ns.Effort.of(source, player, data, opts, tuning) -> seconds, xp, hops, steps, trip, place | nil (écartée)
--     opts = {isDone, includeRaids, travel} ; tuning = constantes de Planner.TUNING (déjà fusionnées).
--     xp : étapes non grises (quête), 0 sinon ; hops : zones vers la source | nil ; steps : étapes restantes
--     (quête) ; trip : part du trajet (nil pour l'artisanat) ; place : donneur de la 1re étape (quête).

local _, ns = ...

local Effort = {}
ns.Effort = Effort

local MAX_LEVEL = 60

-- Niveau de quête sous lequel elle est grise (règle de Classic).
local function greyLevel(level)
    if level <= 5 then
        return 0
    elseif level <= 39 then
        return level - 5 - math.floor(level / 10)
    end
    return level - 1 - math.floor(level / 5)
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

-- Trajet : opts.travel vers target ({mapID, x, y}) en secondes, sinon par zones.
local function travel(hops, tuning, opts, target)
    local factor = tuning.TRAVEL_FACTOR
    if opts.travel and target and target.mapID then
        local seconds = opts.travel(target.mapID, target.x, target.y)
        if seconds then
            return seconds * factor
        end
    end
    return (hops or 0) * tuning.TRAVEL * factor
end

-- Donneur de la première étape restante, s'il est placé.
local function starterOf(steps, data)
    local first = data.quest(steps[1])
    return first and first.starter and data.npc and data.npc(first.starter) or nil
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
    local starter = starterOf(steps, data)
    local trip = travel(hops, tuning, opts, starter)
    return #steps * tuning.QUEST_STEP + trip, questXP(steps, player, data), hops, #steps, trip, starter
end

local function runs(source, tuning)
    local chance = math.max(source.chance or tuning.DEFAULT_CHANCE, tuning.MIN_CHANCE)
    return 100 / chance
end

-- Tentatives × perRun + trajet vers mapID ; entrée d'instance sans position : par zones.
local function farmEffort(source, mapID, player, data, opts, tuning, perRun)
    local hops = hopsTo(mapID, player, data, tuning)
    local trip = travel(hops, tuning, opts, source.x and source or nil)
    return perRun * runs(source, tuning) + trip, 0, hops, nil, trip
end

function Effort.of(source, player, data, opts, tuning)
    local kind = source.type
    if kind == "quest" then
        return questEffort(source, player, data, opts, tuning)
    elseif kind == "world" then
        return farmEffort(source, source.mapID, player, data, opts, tuning, tuning.WORLD_KILL)
    elseif kind == "dungeon" or (kind == "raid" and opts.includeRaids) then
        local instance = data.instance and data.instance(source.id)
        local perRun = kind == "raid" and tuning.RAID_RUN or tuning.DUNGEON_RUN
        return farmEffort(source, instance and instance.mapID, player, data, opts, tuning, perRun)
    elseif kind == "craft" then
        local known = player.professions and player.professions[source.skillLine]
        return known and tuning.CRAFT or tuning.CRAFT_UNKNOWN, 0
    end
    return nil
end
