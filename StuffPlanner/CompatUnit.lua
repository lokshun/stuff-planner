-- CONTRAT
-- Suite de ns.Compat : créature désignée par une unité ou un GUID. Charger après Compat.lua.
-- Forever (API 12.x) peut rendre UnitGUID / UnitName / GUID de butin « secrets » (cible prise en combat,
-- contexte protégé) : y toucher (match, comparaison) lève une erreur et tache l'exécution. Une valeur
-- secrète (issecretvalue, si le client l'a) ou illisible (pcall) donne nil, jamais d'erreur.
--   IsSecret(value) -> bool : issecretvalue(value) si le client l'a, sinon false
--   CreatureIDFromGUID(guid) -> identifiant de créature ou de véhicule | nil (joueur, objet, secret, nil)
--   UnitCreature(unit) -> id, nom | nil : créature désignée par unit ("npc", "target"), nom non vide

local _, ns = ...

local Compat = ns.Compat

local PATTERN = "^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"

function Compat.IsSecret(value)
    local test = _G.issecretvalue
    return type(test) == "function" and test(value) == true
end

local function parse(guid)
    local kind, id = guid:match(PATTERN)
    if kind == "Creature" or kind == "Vehicle" then
        return tonumber(id)
    end
    return nil
end

function Compat.CreatureIDFromGUID(guid)
    if Compat.IsSecret(guid) or type(guid) ~= "string" then
        return nil
    end
    local ok, id = pcall(parse, guid)
    return ok and id or nil
end

function Compat.UnitCreature(unit)
    local id = Compat.CreatureIDFromGUID(UnitGUID(unit))
    if not id then
        return nil
    end
    local name = UnitName(unit)
    if Compat.IsSecret(name) or type(name) ~= "string" or name == "" then
        return nil
    end
    return id, name
end
