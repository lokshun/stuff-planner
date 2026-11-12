-- CONTRAT
-- Chaîne de liste cible à copier-coller : identifiants d'objets seuls, aucun nom. Pur : aucun appel à l'API WoW.
--   ns.WishlistIO.MAX -> 50 objets au plus
--   ns.WishlistIO.encode(itemIDs) -> "SPL1;19019,17076" (ordre gardé)
--   ns.WishlistIO.decode(text) -> {itemID...} (ordre gardé, doublons retirés) | nil, code
--     espaces et retours à la ligne ignorés ; codes : EMPTY (rien, ou aucun objet), TOO_LONG, PREFIX, FORMAT,
--     VALUE (identifiant non entier ou ≤ 0), TOO_MANY

local _, ns = ...

local WishlistIO = {}
ns.WishlistIO = WishlistIO

local PREFIX = "SPL1"
WishlistIO.MAX = 50
local MAX_LENGTH = 1000
local MAX_ID = 2147483647

function WishlistIO.encode(itemIDs)
    local parts = {}
    for index, itemID in ipairs(itemIDs) do
        parts[index] = tostring(itemID)
    end
    return PREFIX .. ";" .. table.concat(parts, ",")
end

function WishlistIO.decode(text)
    if type(text) ~= "string" then
        return nil, "EMPTY"
    end
    text = text:gsub("%s+", "")
    if text == "" then
        return nil, "EMPTY"
    elseif #text > MAX_LENGTH then
        return nil, "TOO_LONG"
    end
    local prefix, list = text:match("^([^;]*);(.*)$")
    if prefix ~= PREFIX then
        return nil, "PREFIX"
    elseif list:find(";", 1, true) then
        return nil, "FORMAT"
    elseif list == "" then
        return nil, "EMPTY"
    end
    local ids, seen = {}, {}
    for raw in (list .. ","):gmatch("([^,]*),") do
        local id = raw:match("^%d+$") and tonumber(raw)
        if not id or id < 1 or id > MAX_ID then
            return nil, "VALUE"
        end
        if not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    if #ids > WishlistIO.MAX then
        return nil, "TOO_MANY"
    end
    return ids
end
