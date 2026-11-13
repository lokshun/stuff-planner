-- CONTRAT
-- Effort d'une source en secondes (règles décrites dans l'en-tête de Planner.lua : quête, donjon, raid, monde,
-- artisanat, trajet). Pur : aucun appel à l'API WoW. Charger après Engine/Feasible.lua, Engine/Chains.lua et
-- Engine/Distance.lua et Engine/QuestStart.lua, avant Engine/Planner.lua.
--   ns.Effort.of(source, player, data, opts, tuning) -> seconds, xp, hops, steps, trip, place, condition | nil
--     opts = {isDone, isInLog, includeRaids, travel, reference} ; tuning = constantes de Planner.TUNING.
--     Quête : Feasible.check sur la quête et chaque étape restante ; une impossible écarte la source,
--     chaque atteignable ajoute CONDITION, condition = {reason, questID} de la première (nil sinon) ;
--     opts.reference : classe et race seules (Masks.allows).
--     xp : étapes non grises (quête), 0 sinon ; hops : zones vers la source | nil ; steps : étapes restantes
--     (quête) ; trip : part du trajet (nil pour l'artisanat) ; place : départ de la 1re étape (QuestStart.of,
--     quête) ; départ connu sans position exacte (zone, donjon, objet non placé) : + UNPLACED.

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

-- Départ de la première étape restante (QuestStart) | nil.
local function starterOf(steps, data)
    local first = data.quest(steps[1])
    return first and ns.QuestStart.of(first, data) or nil
end

-- Mode référence (paliers passés, « comme si on y était ») : classe et race seules.
local function referenceCheck(quest, player)
    return ns.Masks.allows(quest, player), nil
end

-- Surcoût des conditions atteignables des étapes et raison de la première ; nil si une étape est impossible.
local function conditions(steps, player, data, opts, tuning, check)
    local extra, condition = 0, nil
    for _, id in ipairs(steps) do
        local step = data.quest(id)
        if step then
            local ok, reason = check(step, player, opts.isDone, opts.isInLog)
            if not ok then
                return nil
            elseif reason then
                extra = extra + tuning.CONDITION
                condition = condition or { reason = reason, questID = id }
            end
        end
    end
    return extra, condition
end

-- Renvoie effort, xp, hops, steps, trip, place, condition ; nil si la source est écartée.
local function questEffort(source, player, data, opts, tuning)
    local check = opts.reference and referenceCheck or ns.Feasible.check
    local quest = data.quest(source.id)
    if not quest or not check(quest, player, opts.isDone, opts.isInLog) then
        return nil
    end
    local steps = ns.Chains.remaining(source.id, data, opts.isDone, function(id)
        local step = data.quest(id)
        return not step or (check(step, player, opts.isDone, opts.isInLog))
    end)
    if not steps or #steps == 0 then
        return nil
    end
    local extra, condition = conditions(steps, player, data, opts, tuning, check)
    if not extra then
        return nil
    end
    local hops = hopsTo(quest.mapID, player, data, tuning)
    local starter = starterOf(steps, data)
    local trip = travel(hops, tuning, opts, starter)
    if starter and not starter.exact then
        extra = extra + tuning.UNPLACED
    end
    return #steps * tuning.QUEST_STEP + extra + trip, questXP(steps, player, data), hops, #steps, trip, starter,
        condition
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
