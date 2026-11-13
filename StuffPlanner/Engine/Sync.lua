-- CONTRAT
-- Protocole de partage des confirmations de quête entre joueurs (transport : Integrations/Share.lua).
-- Pur : aucun appel à l'API WoW, aucune bibliothèque. Confirmation = {questID, level?, mapID?, rewards, choices,
-- npcID?, x?, y?}, listes d'itemID triées, sans doublon, MAX_ITEMS au plus ; npcID = donneur (dialogue), x, y en 0–1
-- arrondis au millième (sur la carte mapID).
--   ns.Sync.VERSION -> 2 ; MAX_ENTRIES -> 20 par message ; MAX_ITEMS -> 8 par liste ; MAX_LENGTH -> 1000 octets
--   ns.Sync.entry(record) -> confirmation | nil : observation du collecteur kind "detail", "complete" ou "log"
--     (kind ne sort pas ; npcID et position seulement pour "detail", position seulement avec un npcID valide) ;
--     nil si un champ de quête est invalide ou hors bornes
--   ns.Sync.encode(entries) -> {message...} : "<VERSION>|q:l:m:r.r:c.c:n:x:y;..." (champ vide = nil, liste vide ;
--     x, y en millièmes 0–1000), MAX_ENTRIES et MAX_LENGTH par message ; {} sans confirmation.
--     Version 1 (lue seulement) : "1|q:l:m:r.r:c.c;..."
--   ns.Sync.decode(message) -> entries | nil, err [, version] ; jamais d'erreur Lua. err : "type" (pas une
--     chaîne), "length" (> MAX_LENGTH), "version" (plus récente que VERSION, renvoyée en 3e), "format" (en-tête,
--     champ ou entrée invalide : le message entier est rejeté), "count" (> MAX_ENTRIES). Listes reçues triées.
--   ns.Sync.newSeen(limit?) -> mémoire de dédoublonnage (MAX_SEEN = 500 par défaut, les plus anciennes oubliées)
--   ns.Sync.fresh(seen, entry) -> bool : vrai la première fois que cette confirmation exacte est vue
--   ns.Sync.dedup(entries, seen) -> nouvelle liste, ordre gardé, confirmations déjà vues retirées
-- Nombres : entiers décimaux sans zéro initial, 1 à 2^31 - 1 ; niveau 1 à MAX_LEVEL (100).

local _, ns = ...

local Sync = {}
ns.Sync = Sync

Sync.VERSION = 2
Sync.MAX_ENTRIES = 20
Sync.MAX_ITEMS = 8
Sync.MAX_LENGTH = 1000
Sync.MAX_SEEN = 500

local MAX_ID = 2147483647
local MAX_LEVEL = 100
local QUEST_KINDS = { detail = true, complete = true, log = true }
local SCALE = 1000
local FIELD_COUNT = { 5, 8 }

local function isID(value, max)
    return type(value) == "number" and value >= 1 and value <= (max or MAX_ID) and value == math.floor(value)
end

local function isCoord(value)
    return type(value) == "number" and value >= 0 and value <= 1
end

local function rounded(value)
    return math.floor(value * SCALE + 0.5) / SCALE
end

-- Copie triée d'une liste d'identifiants ; nil si invalide, trop longue ou avec doublon.
local function cleanList(list)
    if type(list) ~= "table" or #list > Sync.MAX_ITEMS then
        return nil
    end
    local copy = {}
    for i, value in ipairs(list) do
        if not isID(value) then
            return nil
        end
        copy[i] = value
    end
    table.sort(copy)
    for i = 2, #copy do
        if copy[i] == copy[i - 1] then
            return nil
        end
    end
    return copy
end

function Sync.entry(record)
    if type(record) ~= "table" or not QUEST_KINDS[record.kind] or not isID(record.questID) then
        return nil
    end
    local level, mapID = record.level, record.mapID
    if (level ~= nil and not isID(level, MAX_LEVEL)) or (mapID ~= nil and not isID(mapID)) then
        return nil
    end
    local rewards, choices = cleanList(record.rewards), cleanList(record.choices)
    if not (rewards and choices) then
        return nil
    end
    local entry = { questID = record.questID, level = level, mapID = mapID, rewards = rewards, choices = choices }
    if record.kind == "detail" and isID(record.npcID) then
        entry.npcID = record.npcID
        if isCoord(record.x) and isCoord(record.y) then
            entry.x, entry.y = rounded(record.x), rounded(record.y)
        end
    end
    return entry
end

local function optional(value)
    return value and tostring(value) or ""
end

local function encodeEntry(entry)
    return table.concat({
        tostring(entry.questID), optional(entry.level), optional(entry.mapID),
        table.concat(entry.rewards, "."), table.concat(entry.choices, "."),
        optional(entry.npcID), optional(entry.x and math.floor(entry.x * SCALE + 0.5)),
        optional(entry.y and math.floor(entry.y * SCALE + 0.5)),
    }, ":")
end

function Sync.encode(entries)
    local messages, current, length = {}, {}, 0
    local header = Sync.VERSION .. "|"
    local function flush()
        if #current > 0 then
            messages[#messages + 1] = header .. table.concat(current, ";")
            current, length = {}, 0
        end
    end
    for _, entry in ipairs(entries) do
        local text = encodeEntry(entry)
        if #current >= Sync.MAX_ENTRIES or #header + length + #text + 1 > Sync.MAX_LENGTH then
            flush()
        end
        current[#current + 1] = text
        length = length + #text + 1
    end
    flush()
    return messages
end

local function parseNumber(text, max)
    if not text:match("^[1-9]%d*$") or #text > 10 then
        return nil
    end
    local value = tonumber(text)
    return value <= max and value or nil
end

-- Champ optionnel : vide = nil (ok), sinon nombre ; renvoie ok, valeur.
local function parseOptional(text, max)
    if text == "" then
        return true, nil
    end
    local value = parseNumber(text, max)
    return value ~= nil, value
end

local function parseList(text)
    local list = {}
    if text == "" then
        return list
    end
    for part in (text .. "."):gmatch("([^.]*)%.") do
        local value = parseNumber(part, MAX_ID)
        if not value or #list >= Sync.MAX_ITEMS then
            return nil
        end
        list[#list + 1] = value
    end
    return cleanList(list)
end

-- Coordonnées en millièmes : toutes deux vides, ou toutes deux 0 à SCALE (avec un donneur).
local function parseCoords(xText, yText)
    if xText == "" and yText == "" then
        return true, nil, nil
    end
    local x = xText == "0" and 0 or parseNumber(xText, SCALE)
    local y = yText == "0" and 0 or parseNumber(yText, SCALE)
    if not (x and y) then
        return false
    end
    return true, x / SCALE, y / SCALE
end

local function decodeGiver(fields, entry)
    if #fields == FIELD_COUNT[1] then
        return true
    end
    local okNpc, npcID = parseOptional(fields[6], MAX_ID)
    local okCoords, x, y = parseCoords(fields[7], fields[8])
    if not (okNpc and okCoords) or (x and not npcID) then
        return false
    end
    entry.npcID, entry.x, entry.y = npcID, x, y
    return true
end

local function decodeEntry(text, version)
    local fields = {}
    for part in (text .. ":"):gmatch("([^:]*):") do
        fields[#fields + 1] = part
    end
    if #fields ~= FIELD_COUNT[version] then
        return nil
    end
    local questID = parseNumber(fields[1], MAX_ID)
    local okLevel, level = parseOptional(fields[2], MAX_LEVEL)
    local okMap, mapID = parseOptional(fields[3], MAX_ID)
    local rewards, choices = parseList(fields[4]), parseList(fields[5])
    if not (questID and okLevel and okMap and rewards and choices) then
        return nil
    end
    local entry = { questID = questID, level = level, mapID = mapID, rewards = rewards, choices = choices }
    return decodeGiver(fields, entry) and entry or nil
end

function Sync.decode(message)
    if type(message) ~= "string" then
        return nil, "type"
    elseif #message > Sync.MAX_LENGTH then
        return nil, "length"
    end
    local versionText, body = message:match("^(%d+)|(.*)$")
    local version = versionText and parseNumber(versionText, MAX_ID)
    if not version then
        return nil, "format"
    elseif version > Sync.VERSION then
        return nil, "version", version
    elseif body == "" then
        return nil, "format"
    end
    local texts = {}
    for part in (body .. ";"):gmatch("([^;]*);") do
        texts[#texts + 1] = part
    end
    if #texts > Sync.MAX_ENTRIES then
        return nil, "count"
    end
    local entries = {}
    for i, text in ipairs(texts) do
        entries[i] = decodeEntry(text, version)
        if not entries[i] then
            return nil, "format"
        end
    end
    return entries
end

function Sync.newSeen(limit)
    return { keys = {}, order = {}, first = 1, last = 0, limit = limit or Sync.MAX_SEEN }
end

function Sync.fresh(seen, entry)
    local key = encodeEntry(entry)
    if seen.keys[key] then
        return false
    end
    seen.keys[key] = true
    seen.last = seen.last + 1
    seen.order[seen.last] = key
    if seen.last - seen.first + 1 > seen.limit then
        seen.keys[seen.order[seen.first]] = nil
        seen.order[seen.first] = nil
        seen.first = seen.first + 1
    end
    return true
end

function Sync.dedup(entries, seen)
    local out = {}
    for _, entry in ipairs(entries) do
        if Sync.fresh(seen, entry) then
            out[#out + 1] = entry
        end
    end
    return out
end
