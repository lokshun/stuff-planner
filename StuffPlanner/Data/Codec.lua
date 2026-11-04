-- CONTRAT
-- Décode les enregistrements de StuffPlanner_Data (schéma 5), émis par tools/emit_lua.py
-- (record_string) : une chaîne par enregistrement, une table Lua par enregistrement coûtant trop.
--   ns.Codec.decode(text) -> table ; erreur si la chaîne est mal formée
-- Grammaire : valeur = nombre | true | false | vide (nil) | { [valeur|clé=valeur] {, ...} } ;
-- clé = identifiant. Aucune chaîne dans les valeurs. Pur : aucun appel d'API.

local _, ns = ...

local Codec = {}
ns.Codec = Codec

local OPEN, CLOSE = 123, 125 -- "{", "}"
local LITERALS = { ["true"] = true, ["false"] = false }

local parseValue

local function parseTable(text, pos)
    local result, count = {}, 0
    if text:byte(pos) == CLOSE then
        return result, pos + 1
    end
    while true do
        local key, after = text:match("^([%a_][%w_]*)=()", pos)
        local value
        if key then
            value, pos = parseValue(text, after)
            result[key] = value
        else
            count = count + 1
            value, pos = parseValue(text, pos)
            result[count] = value
        end
        local separator = text:byte(pos)
        if separator == CLOSE then
            return result, pos + 1
        elseif separator ~= 44 then -- ","
            error("Codec : séparateur attendu en " .. pos .. " dans " .. text)
        end
        pos = pos + 1
    end
end

function parseValue(text, pos)
    if text:byte(pos) == OPEN then
        return parseTable(text, pos + 1)
    end
    local token, after = text:match("^([^,}]*)()", pos)
    if token == "" then
        return nil, after
    end
    local literal = LITERALS[token]
    if literal ~= nil then
        return literal, after
    end
    local number = tonumber(token)
    if number == nil then
        error("Codec : valeur illisible « " .. token .. " » dans " .. text)
    end
    return number, after
end

function Codec.decode(text)
    local value, pos = parseValue(text, 1)
    if type(value) ~= "table" or pos ~= #text + 1 then
        error("Codec : enregistrement mal formé : " .. text)
    end
    return value
end
