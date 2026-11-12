-- CONTRAT
-- Index des instances de StuffPlanner_Data : par carte d'entrée et par objet de leur butin.
-- Complète ns.Data ; charger juste après DataProvider.lua (enveloppe Data.attach et Data.finish).
--   ns.Data.instancesInMap(mapID) -> {instanceID...} trié, instances dont l'entrée est sur la carte
--     (champ mapID de l'instance) ; instance sans entrée connue : absente
--   ns.Data.instanceItems(instanceID) -> {itemID...} trié, une fois chacun : objets ayant une
--     origine donjon ou raid de cette instance (objets masqués compris, Data.item(id) nil)
--   ns.Data.instanceIDs() -> {instanceID...} trié : instances ayant au moins un objet en butin
--   ns.Data.instanceBosses(instanceID) -> {npcID...} dans l'ordre du donjon (champ bosses) ; vide si
--     inconnu
-- Réservé à Loader : indexInstance(id) pour chaque db.Instances, indexOrigin(itemID) pour chaque
--   db.Origins, avant Data.finish (qui trie). Data.attach efface l'index.
-- Tables renvoyées partagées : ne pas les modifier. Aucun appel d'API.

local _, ns = ...

local Data = ns.Data

local EMPTY = {}

local db, kinds, byMap, byInstance, ids

local function reset(database)
    db, kinds, byMap, byInstance, ids = database, {}, {}, {}, {}
    local codes = database and database.Schema and database.Schema.originKinds or EMPTY
    for _, name in ipairs({ "dungeon", "raid" }) do
        if codes[name] then
            kinds[codes[name]] = true
        end
    end
end
reset(nil)

local attach, finish = Data.attach, Data.finish

function Data.attach(database, opts)
    local ok = attach(database, opts)
    reset(ok and database or nil)
    return ok
end

function Data.finish()
    for _, lists in ipairs({ byMap, byInstance }) do
        for _, list in pairs(lists) do
            table.sort(list)
        end
    end
    for instanceID in pairs(byInstance) do
        ids[#ids + 1] = instanceID
    end
    table.sort(ids)
    return finish()
end

local function append(index, key, value)
    local list = index[key] or {}
    index[key] = list
    list[#list + 1] = value
end

function Data.indexInstance(id)
    local instance = db and Data.instance(id)
    if instance and instance.mapID then
        append(byMap, instance.mapID, id)
    end
end

function Data.indexOrigin(itemID)
    local text = db and db.Origins[itemID]
    if not text then
        return
    end
    local added = {}
    for _, entry in ipairs(ns.Codec.decode(text)[db.Schema.origins.entries]) do
        local instanceID = entry[2]
        if kinds[entry[1]] and not added[instanceID] then
            added[instanceID] = true
            append(byInstance, instanceID, itemID)
        end
    end
end

function Data.instancesInMap(mapID)
    return byMap[mapID] or EMPTY
end

function Data.instanceItems(instanceID)
    return byInstance[instanceID] or EMPTY
end

function Data.instanceIDs()
    return ids
end

function Data.instanceBosses(instanceID)
    local instance = Data.instance(instanceID)
    return instance and instance.bosses or EMPTY
end
