-- CONTRAT
-- Profils personnalisés du personnage, rangés dans la table de sauvegarde reçue par chaque fonction
-- (StuffPlannerCharDB.profiles, fournie par Profiles/Manager.lua) : customs = {nextID, list = {entrée…}}.
-- Pur : aucun appel d'API. Charger avant Profiles/Manager.lua.
--   ns.Customs.MAX = 10 ; NAME_MAX = 32 (octets, coupé sur un caractère entier)
--   isCustom(id) -> bool (« CUSTOM_<n> »)
--   migrate(saved) : ancien profil unique `custom` -> première entrée (sans nom), manual "CUSTOM" -> son id ;
--     ancien profil illisible : effacé, manual "CUSTOM" oublié ; sans effet une fois fait
--   list(saved) -> entrées valides {id, name?, weights, caps, order?}, ordre de création ; find(saved, id)
--   cleanName(text) -> nom rogné et coupé | nil (vide)
--   save(saved, id | nil, name?, profile) -> id | nil, code : copie weights et caps (nombres), order (clés
--     texte, sinon absent) dans une nouvelle table ; id nil = nouvelle entrée (FULL au-delà de MAX) ;
--     id inconnu : UNKNOWN ; name nil garde le nom existant
--   rename(saved, id, text) -> true | false, code (NAME : vide, UNKNOWN) ; remove(saved, id) -> bool
-- Les ids ne sont jamais réutilisés (nextID croissant).

local _, ns = ...

local Customs = {}
ns.Customs = Customs

Customs.MAX = 10
Customs.NAME_MAX = 32

local LEGACY_ID = "CUSTOM"
local PREFIX = "CUSTOM_"

function Customs.isCustom(id)
    return type(id) == "string" and id:match("^CUSTOM_%d+$") ~= nil
end

local function copyNumbers(values)
    local result = {}
    for key, value in pairs(type(values) == "table" and values or {}) do
        if type(value) == "number" then
            result[key] = value
        end
    end
    return result
end

local function copyOrder(order)
    if type(order) ~= "table" then
        return nil
    end
    local result = {}
    for i, key in ipairs(order) do
        if type(key) ~= "string" then
            return nil
        end
        result[i] = key
    end
    return #result > 0 and result or nil
end

local function valid(entry)
    return type(entry) == "table" and Customs.isCustom(entry.id) and type(entry.weights) == "table"
end

local function store(saved)
    local customs = saved.customs
    if type(customs) ~= "table" or type(customs.list) ~= "table" then
        customs = { nextID = 1, list = {} }
        saved.customs = customs
    end
    customs.nextID = tonumber(customs.nextID) or (#customs.list + 1)
    return customs
end

local function indexOf(saved, id)
    for index, entry in ipairs(store(saved).list) do
        if valid(entry) and entry.id == id then
            return index, entry
        end
    end
    return nil
end

function Customs.list(saved)
    local result = {}
    for _, entry in ipairs(store(saved).list) do
        if valid(entry) then
            result[#result + 1] = entry
        end
    end
    return result
end

function Customs.find(saved, id)
    local _, entry = indexOf(saved, id)
    return entry
end

function Customs.cleanName(text)
    local name = type(text) == "string" and text:match("^%s*(.-)%s*$") or ""
    if #name > Customs.NAME_MAX then
        local cut = Customs.NAME_MAX
        -- Octet de suite UTF-8 (10xxxxxx) juste après la coupe : reculer au début du caractère.
        while cut > 0 and (name:byte(cut + 1) or 0) >= 0x80 and name:byte(cut + 1) < 0xC0 do
            cut = cut - 1
        end
        name = name:sub(1, cut):match("^(.-)%s*$")
    end
    return name ~= "" and name or nil
end

local function entry(id, name, profile)
    return {
        id = id,
        name = name,
        weights = copyNumbers(profile.weights),
        caps = copyNumbers(profile.caps),
        order = copyOrder(profile.order),
    }
end

function Customs.save(saved, id, name, profile)
    local customs = store(saved)
    if id == nil then
        if #Customs.list(saved) >= Customs.MAX then
            return nil, "FULL"
        end
        id = PREFIX .. customs.nextID
        customs.nextID = customs.nextID + 1
        customs.list[#customs.list + 1] = entry(id, Customs.cleanName(name), profile)
        return id
    end
    local index, current = indexOf(saved, id)
    if not index then
        return nil, "UNKNOWN"
    end
    local keptName = name == nil and current.name or Customs.cleanName(name)
    customs.list[index] = entry(id, keptName, profile)
    return id
end

function Customs.rename(saved, id, text)
    local _, current = indexOf(saved, id)
    if not current then
        return false, "UNKNOWN"
    end
    local name = Customs.cleanName(text)
    if not name then
        return false, "NAME"
    end
    current.name = name
    return true
end

function Customs.remove(saved, id)
    local index = indexOf(saved, id)
    if not index then
        return false
    end
    table.remove(store(saved).list, index)
    return true
end

function Customs.migrate(saved)
    local legacy = saved.custom
    if legacy == nil then
        if saved.manual == LEGACY_ID then
            saved.manual = nil
        end
        return
    end
    saved.custom = nil
    local id
    if type(legacy) == "table" and type(legacy.weights) == "table" then
        id = Customs.save(saved, nil, nil, legacy)
    end
    if saved.manual == LEGACY_ID then
        saved.manual = id
    end
end
