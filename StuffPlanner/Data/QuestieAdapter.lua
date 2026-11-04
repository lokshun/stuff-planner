-- CONTRAT
-- Lecture facultative de l'addon QuestieDB (global LibQuestieDB, contrat 4). Aucune API WoW.
--   ns.QuestieAdapter.attach(lib?) -> bool ; lib = LibQuestieDB par défaut ; false si absent,
--     RequireContract(4) refusé, Quest ou Npc manquants ; zones : Support.Get("ZoneDB").private,
--     areaIdToUiMapId puis areaIdToUiMapIdOverride (chaînes « return {…} », la seconde l'emporte)
--   available() -> bool
--   quest(id) -> {level, reqLevel, prereq, classMask?, raceMask?, starter?} | nil, mêmes règles que
--     tools/sources/questie.py : reqLevel <= 0 -> 1 ; level <= 0 -> reqLevel ; prereq = groupe
--     (valeur absolue, sans la quête elle-même) puis alternatives (une seule : obligatoire,
--     plusieurs : liste) ; masque 0 -> nil ; starter = PNJ donneur d'ID le plus bas qui a une position
--   npc(id) -> {id, mapID, x, y} (0–1, 4 décimales) | nil ; zone d'origine (zoneID) d'abord, puis
--     zones par ID croissant ; premier point dont x et y sont dans 0–100
--   npcName(id) -> nom dans la langue choisie par QuestieDB | nil
-- Toute erreur levée par QuestieDB vaut une absence. PNJ mis en cache jusqu'au prochain attach.

local _, ns = ...

local Adapter = {}
ns.QuestieAdapter = Adapter

local CONTRACT = 4
local CREATURES = 1
local AREA_TABLES = { "areaIdToUiMapId", "areaIdToUiMapIdOverride" }

local lib, areas, npcCache

local function call(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, value = pcall(fn, ...)
    if ok then
        return value
    end
    return nil
end

local function loadAreas(support)
    local result = {}
    local zoneDB = type(support) == "table" and call(support.Get, "ZoneDB")
    local private = type(zoneDB) == "table" and zoneDB.private or {}
    for _, key in ipairs(AREA_TABLES) do
        local text = private[key]
        local chunk = type(text) == "string" and loadstring(text)
        local map = chunk and call(chunk)
        for areaID, mapID in pairs(type(map) == "table" and map or {}) do
            result[areaID] = mapID
        end
    end
    return result
end

function Adapter.attach(candidate)
    lib, areas, npcCache = nil, nil, {}
    candidate = candidate or _G.LibQuestieDB
    if type(candidate) ~= "table" or type(candidate.Quest) ~= "table" or type(candidate.Npc) ~= "table" then
        return false
    end
    if not call(candidate.RequireContract, CONTRACT) then
        return false
    end
    lib, areas = candidate, loadAreas(candidate.Support)
    return true
end

function Adapter.available()
    return lib ~= nil
end

local function positive(value)
    return type(value) == "number" and value > 0 and value or nil
end

local function ints(list)
    local result = {}
    for _, value in ipairs(type(list) == "table" and list or {}) do
        if type(value) == "number" then
            result[#result + 1] = value
        end
    end
    table.sort(result)
    return result
end

local function prereqOf(id, group, single)
    local prereq, seen = {}, { [id] = true }
    for _, value in ipairs(ints(group)) do
        value = math.abs(value)
        if not seen[value] then
            seen[value] = true
            prereq[#prereq + 1] = value
        end
    end
    table.sort(prereq)
    local alternatives = {}
    for _, value in ipairs(ints(single)) do
        if value ~= id then
            alternatives[#alternatives + 1] = value
        end
    end
    if #alternatives == 1 then
        prereq[#prereq + 1] = alternatives[1]
    elseif #alternatives > 1 then
        prereq[#prereq + 1] = alternatives
    end
    return prereq
end

local function round(value)
    return math.floor(value / 100 * 10000 + 0.5) / 10000
end

local function valid(coordinate)
    return type(coordinate) == "number" and coordinate >= 0 and coordinate <= 100
end

local function pointOf(points)
    for _, point in ipairs(type(points) == "table" and points or {}) do
        if type(point) == "table" and valid(point[1]) and valid(point[2]) then
            return point[1], point[2]
        end
    end
    return nil
end

local function position(id)
    local spawns = call(lib.Npc.spawns, id)
    if type(spawns) ~= "table" then
        return nil
    end
    local zones, home = {}, call(lib.Npc.zoneID, id)
    for zone in pairs(spawns) do
        if type(zone) == "number" and zone ~= home then
            zones[#zones + 1] = zone
        end
    end
    table.sort(zones)
    if spawns[home] then
        table.insert(zones, 1, home)
    end
    for _, zone in ipairs(zones) do
        local mapID = areas[zone]
        local x, y = pointOf(spawns[zone])
        if mapID and x then
            return { id = id, mapID = mapID, x = round(x), y = round(y) }
        end
    end
    return nil
end

function Adapter.npc(id)
    if not lib then
        return nil
    end
    local entry = npcCache[id]
    if entry == nil then
        entry = position(id) or false
        npcCache[id] = entry
    end
    return entry or nil
end

function Adapter.npcName(id)
    local name = lib and call(lib.Npc.name, id)
    return type(name) == "string" and name or nil
end

local function starterOf(startedBy)
    local creatures = type(startedBy) == "table" and startedBy[CREATURES]
    for _, npcID in ipairs(ints(creatures)) do
        if Adapter.npc(npcID) then
            return npcID
        end
    end
    return nil
end

function Adapter.quest(id)
    local quest = lib and lib.Quest
    if not quest or not call(quest.Exists, id) then
        return nil
    end
    local reqLevel = positive(call(quest.requiredLevel, id)) or 1
    return {
        level = positive(call(quest.questLevel, id)) or reqLevel,
        reqLevel = reqLevel,
        prereq = prereqOf(id, call(quest.preQuestGroup, id), call(quest.preQuestSingle, id)),
        classMask = positive(call(quest.requiredClasses, id)),
        raceMask = positive(call(quest.requiredRaces, id)),
        starter = starterOf(call(quest.startedBy, id)),
    }
end
