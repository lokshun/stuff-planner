-- CONTRAT
-- Chaîne de poids à copier-coller (import/export). Pur : aucun appel à l'API WoW.
-- Charger après Engine/StatKeys.lua et Profiles/PawnMap.lua.
--   ns.ProfileIO.encode({weights, caps?}) -> "SPW1;KEY=v,KEY=v;KEY=v"
--     sections : version, poids, plafonds ; clés triées ; poids nuls omis ; 4 chiffres significatifs
--   ns.ProfileIO.decode(text) -> {weights, caps, name?, ignored?} | nil, code, détail?
--     SPW1 : espaces et retours à la ligne ignorés ; section des plafonds facultative ; ni name ni ignored
--     Échelle Pawn « ( Pawn: v1: "Nom": Stat=v, … ) » (4000 caractères au plus) : name = nom de l'échelle,
--       stats converties par PawnMap.convert (ignored = stats non reprises), aucun plafond ; valeur X ou x :
--       stat ignorée ; Class, Spec : non lues ; version > 1 ou paire malformée : FORMAT
--     codes : EMPTY, TOO_LONG, PREFIX, FORMAT, STAT (détail = clé), VALUE (détail = clé),
--     DUPLICATE (détail = clé), NO_WEIGHT ; poids dans [-1000, 1000], plafonds dans [0, 1000]

local _, ns = ...

local ProfileIO = {}
ns.ProfileIO = ProfileIO

local PREFIX = "SPW1"
local MAX_LENGTH = 2000
local PAWN_MAX_LENGTH = 4000
local PAWN_VERSION = 1
local PAWN_START = "^%s*%(%s*Pawn%s*:"
local PAWN_TAG = '^%s*%(%s*Pawn%s*:%s*v(%d+)%s*:%s*"([^"]+)"%s*:%s*(.-)%s*%)%s*$'
local MAX_WEIGHT, MAX_CAP = 1000, 1000

local function formatNumber(value)
    return (string.format("%.4g", value))
end

local function encodeSection(values, skipZero)
    local keys = {}
    for key, value in pairs(values or {}) do
        if not (skipZero and value == 0) then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    local parts = {}
    for i, key in ipairs(keys) do
        parts[i] = key .. "=" .. formatNumber(values[key])
    end
    return table.concat(parts, ",")
end

function ProfileIO.encode(profile)
    return PREFIX .. ";" .. encodeSection(profile.weights, true) .. ";" .. encodeSection(profile.caps, false)
end

local function split(text, separator)
    local parts = {}
    for part in (text .. separator):gmatch("(.-)" .. separator) do
        parts[#parts + 1] = part
    end
    return parts
end

local function parseNumber(text)
    if not text:match("^%-?%d+%.?%d*$") and not text:match("^%-?%.%d+$") then
        return nil
    end
    return tonumber(text)
end

-- Renvoie la table des valeurs, ou nil, code, détail.
local function decodeSection(text, low, high)
    local values = {}
    if text == "" then
        return values
    end
    for _, pair in ipairs(split(text, ",")) do
        local key, raw = pair:match("^([^=]+)=(.+)$")
        if not key then
            return nil, "FORMAT"
        end
        if not rawget(ns.StatKeys, key) then
            return nil, "STAT", key
        end
        local value = parseNumber(raw)
        if not value or value < low or value > high then
            return nil, "VALUE", key
        end
        if values[key] then
            return nil, "DUPLICATE", key
        end
        values[key] = value
    end
    return values
end

local function pawnValues(list)
    local values = {}
    for _, pair in ipairs(split(list, ",")) do
        local stat, raw = pair:match("^%s*([%a%d]+)%s*=%s*(%S+)%s*$")
        if not stat then
            return nil, "FORMAT"
        end
        if values[stat] then
            return nil, "DUPLICATE", stat
        end
        if ns.PawnMap.SKIPPED[stat] or raw == "X" or raw == "x" then
            values[stat] = 0
        else
            local value = parseNumber(raw)
            if not value or value < -MAX_WEIGHT or value > MAX_WEIGHT then
                return nil, "VALUE", stat
            end
            values[stat] = value
        end
    end
    return values
end

local function decodePawn(text)
    if #text > PAWN_MAX_LENGTH then
        return nil, "TOO_LONG"
    end
    local version, name, list = text:match(PAWN_TAG)
    if not version or tonumber(version) > PAWN_VERSION or list == "" then
        return nil, "FORMAT"
    end
    local values, code, detail = pawnValues(list)
    if not values then
        return nil, code, detail
    end
    local weights, ignored = ns.PawnMap.convert(values)
    if next(weights) == nil then
        return nil, "NO_WEIGHT"
    end
    return { weights = weights, caps = {}, name = name, ignored = ignored }
end

function ProfileIO.decode(text)
    if type(text) ~= "string" then
        return nil, "EMPTY"
    end
    if text:match(PAWN_START) then
        return decodePawn(text)
    end
    text = text:gsub("%s+", "")
    if text == "" then
        return nil, "EMPTY"
    elseif #text > MAX_LENGTH then
        return nil, "TOO_LONG"
    end
    local sections = split(text, ";")
    if sections[1] ~= PREFIX then
        return nil, "PREFIX"
    elseif #sections > 3 then
        return nil, "FORMAT"
    end
    local weights, code, detail = decodeSection(sections[2] or "", -MAX_WEIGHT, MAX_WEIGHT)
    if not weights then
        return nil, code, detail
    end
    local caps
    caps, code, detail = decodeSection(sections[3] or "", 0, MAX_CAP)
    if not caps then
        return nil, code, detail
    end
    for key, value in pairs(weights) do
        if value == 0 then
            weights[key] = nil
        end
    end
    if next(weights) == nil then
        return nil, "NO_WEIGHT"
    end
    return { weights = weights, caps = caps }
end
