-- CONTRAT
-- Façade de lecture de StuffPlanner_Data. Aucun appel d'API : Loader la remplit.
-- Schéma 11 : chaînes décodées par ns.Codec (charger Codec.lua avant) ; `forever` (1 | nil) : absent de Classic Era ;
-- quest.starter, quest.ender = npcID | nil ; instance = instanceID | nil ; objMap, objX, objY = lieu d'objectif | nil ;
-- instance.bosses = {npcID...} dans l'ordre du donjon | nil.
--   ns.Data.ready() -> bool
--   quest(id), item(id), instance(id) -> table aux champs nommés de tools/schema.py, `id` compris | nil ;
--     la base n'a que les objets ayant une origine : item(id) d'un objet porté peut valoir nil
--   npc(id) -> {id, mapID, x, y} (x, y en 0–1) | nil ; base = donneurs et PNJ de rendu, position observée d'abord
--   npcName(id) -> nom du PNJ dans la langue du client (ns.NpcNames de la base) | nil ;
--     baseName("npc"|"quest"|"item", id) -> nom de la base (NpcNames, QuestNames, ItemNames) | nil
--   recipe(itemID) -> {spellID, skillLine} | nil, première recette de l'objet
--   sourcesOf(itemID) -> {{type="quest"|"dungeon"|"raid"|"craft", id, chance, npcID, skillLine}...} ;
--     id = questID, instance ou spellID ; vide si inconnu ; artisanat : yellow, grey (seuils de
--     compétence, nil si inconnus), reagents = {{itemID, count}...}
--   itemIDs() -> {itemID...} trié, objets masqués compris (item(id) nil) ;
--   questsInMap(mapID) -> {questID...} trié ; neighbors(mapID) -> {mapID...}, vide sans ns.Neighbors
-- Tables renvoyées en cache et partagées : ne pas les modifier. Cache à valeurs faibles : une table
--   que personne ne garde est rendue au ramasse-miettes et décodée de nouveau au besoin.
-- Couches : base < db.Overlay ({quests={[id]={champ=valeur}}, items={...}}) < observations du
--   collecteur (quêtes connues de la base : level s'il est connu, mapID, rewards, choices ; la dernière
--   observation detail ou complete l'emporte ; "log", lue dans le journal, n'apporte que rewards et
--   choices et ne remplace pas un dialogue). Quête confidence 2 dont une couche (Overlay ou
--   observation) fixe rewards et choices : confidence 3 (confirmée). Observations : ns.Observations
--   (Data/Observations.lua, charger avant).
-- observeItem(id, stats) : stats lues en jeu (ItemProbe), au-dessus de l'Overlay, effet immédiat ;
--   objet confidence 1 dont une couche fixe stats : confidence 3.
-- observe(record) : Loader au chargement, puis Collector ; effet immédiat sur quest(id) et npc(id),
--   questsInMap garde la carte du chargement.
-- Réservé à Loader : attach(db [, opts]) -> bool (false si schéma différent), indexQuest(id), finish().
--   db = ns de l'addon de données (Schema, Quests, Items, EraItems sur Vanilla, Origins, Instances, Npcs).
--   opts.hideForever : quest, item -> nil pour `forever`, absents de questsInMap et de sourcesOf.
--   opts.era : item(id) prend quality, ilvl, reqLevel, stats de db.EraItems[id] (Classic Era, couche juste
--     au-dessus de la base) et confidence 1 (ItemSparse, sans effets « Équipé ») : ItemProbe les confirme.
--   opts.external = QuestieAdapter (quest, npc, npcName) : champs EXTERNAL des quêtes de la base
--     remplacés (couche entre base et Overlay ; mapID et récompenses restent les nôtres) ;
--     npc : observé < externe < base ; npcName : externe puis base.

local _, ns = ...

local Data = {}
ns.Data = Data

local SCHEMA_VERSION = 11
local EMPTY = {}
local WEAK = { __mode = "v" }
local EXTERNAL = { "level", "reqLevel", "prereq", "classMask", "raceMask", "starter", "ender" }
local GUESSED, CONFIRMED, ESTIMATED = 2, 3, 1

local db, overlay, kinds, hideForever, external, eraItems
local cache, byMap, itemList
local isReady = false
local Observations = ns.Observations

local function reset()
    db, overlay, kinds, hideForever, external, eraItems = nil, nil, nil, false, nil, nil
    cache = {}
    for _, name in ipairs({ "quests", "items", "instances", "npcs", "sources" }) do
        cache[name] = setmetatable({}, WEAK)
    end
    byMap, itemList = {}, nil
    Observations.reset()
    isReady = false
end
reset()

function Data.attach(database, opts)
    reset()
    if not database.Schema or database.Schema.version ~= SCHEMA_VERSION then
        return false
    end
    db = database
    overlay = database.Overlay or EMPTY
    hideForever = (opts and opts.hideForever) == true
    external = opts and opts.external
    eraItems = opts and opts.era == true and database.EraItems or nil
    kinds = {}
    for name, code in pairs(database.Schema.originKinds) do
        kinds[code] = name
    end
    return true
end

function Data.observe(record)
    if not db then
        return
    end
    local id = record.questID
    if Observations.add(record, id ~= nil and db.Quests[id] ~= nil) then
        cache.quests[id] = nil
    end
end

function Data.observeItem(id, stats)
    Observations.setItem(id, stats)
    cache.items[id] = nil
end

-- Une couche qui fixe ce qui était deviné (récompenses et choix d'une quête, stats d'un objet)
-- le rend sûr.
local function confirm(tableName, record, layer)
    if tableName == "quests" and record.confidence == GUESSED and layer.rewards ~= nil
        and layer.choices ~= nil then
        record.confidence = CONFIRMED
    elseif tableName == "items" and record.confidence == ESTIMATED and layer.stats ~= nil then
        record.confidence = CONFIRMED
    end
end

local function rowOf(rowsName, id)
    local text = db and db[rowsName][id]
    return text and ns.Codec.decode(text)
end

local function hidden(tableName, row)
    local position = db.Schema[tableName].forever
    return hideForever and position ~= nil and row[position] ~= nil
end

local function decode(tableName, rowsName, id)
    local row = rowOf(rowsName, id)
    if not row or hidden(tableName, row) then
        return nil
    end
    local decoded = { id = id }
    for field, position in pairs(db.Schema[tableName]) do
        decoded[field] = row[position]
    end
    local eraRow = eraItems and tableName == "items" and eraItems[id] and ns.Codec.decode(eraItems[id])
    for field, position in pairs(eraRow and db.Schema.eraItems or EMPTY) do
        decoded[field], decoded.confidence = eraRow[position], ESTIMATED
    end
    local fromExternal = external and tableName == "quests" and external.quest(id)
    for _, field in ipairs(fromExternal and EXTERNAL or EMPTY) do
        decoded[field] = fromExternal[field]
    end
    local corrected = (overlay[tableName] or EMPTY)[id] or EMPTY
    for field, value in pairs(corrected) do
        decoded[field] = value
    end
    confirm(tableName, decoded, corrected)
    return decoded
end

local function cached(tableName, rowsName, id, layer)
    local entry = cache[tableName][id]
    if entry == nil then
        entry = decode(tableName, rowsName, id) or false
        if entry and layer then
            layer(entry)
        end
        cache[tableName][id] = entry
    end
    return entry or nil
end

local function applyObservation(quest)
    local record = Observations.applyQuest(quest)
    if record then
        confirm("quests", quest, record)
    end
end

function Data.quest(id)
    return cached("quests", "Quests", id, applyObservation)
end

local function applyItemObservation(item)
    if Observations.applyItem(item) then
        confirm("items", item, item)
    end
end

function Data.item(id)
    return cached("items", "Items", id, applyItemObservation)
end

function Data.instance(id)
    return cached("instances", "Instances", id)
end

function Data.npc(id)
    return Observations.npc(id) or (external and external.npc(id)) or cached("npcs", "Npcs", id)
end

function Data.npcName(id)
    return (external and external.npcName(id)) or Data.baseName("npc", id)
end

local NAME_TABLES = { npc = "NpcNames", quest = "QuestNames", item = "ItemNames" }
function Data.baseName(kind, id)
    local names = db and NAME_TABLES[kind] and db[NAME_TABLES[kind]]
    return names and names[id] or nil
end

local function mapOf(id)
    local seen = Observations.mapID(id)
    if seen then
        return seen
    end
    local corrected = (overlay.quests or EMPTY)[id]
    if corrected and corrected.mapID then
        return corrected.mapID
    end
    local row = rowOf("Quests", id)
    if hidden("quests", row) then
        return nil
    end
    return row[db.Schema.quests.mapID]
end

function Data.indexQuest(id)
    local mapID = db and db.Quests[id] and mapOf(id)
    if mapID then
        local list = byMap[mapID] or {}
        byMap[mapID] = list
        list[#list + 1] = id
    end
end

function Data.finish()
    if not db then
        return
    end
    for _, list in pairs(byMap) do
        table.sort(list)
    end
    isReady = true
end

function Data.ready()
    return isReady
end

local function sourceOf(entry)
    local kind = kinds[entry[1]]
    if kind == "craft" then
        local reagents, flat = {}, entry[7] or EMPTY
        for i = 1, #flat - 1, 2 do
            reagents[#reagents + 1] = { itemID = flat[i], count = flat[i + 1] }
        end
        return { type = kind, id = entry[2], skillLine = entry[4], yellow = entry[5], grey = entry[6],
            reagents = reagents }
    elseif kind == "quest" then
        return { type = kind, id = entry[2] }
    end
    return { type = kind, id = entry[2], chance = entry[3], npcID = entry[4] }
end

function Data.sourcesOf(itemID)
    local list = cache.sources[itemID]
    if list then
        return list
    end
    local row = rowOf("Origins", itemID)
    if not row or (hideForever and not Data.item(itemID)) then
        return EMPTY
    end
    list = {}
    for _, entry in ipairs(row[db.Schema.origins.entries]) do
        local source = sourceOf(entry)
        if not (hideForever and source.type == "quest" and not Data.quest(source.id)) then
            list[#list + 1] = source
        end
    end
    cache.sources[itemID] = list
    return list
end

function Data.recipe(itemID)
    for _, source in ipairs(Data.sourcesOf(itemID)) do
        if source.type == "craft" then
            return { spellID = source.id, skillLine = source.skillLine }
        end
    end
    return nil
end

function Data.itemIDs()
    if not itemList then
        itemList = {}
        for id in pairs(db and db.Items or EMPTY) do
            itemList[#itemList + 1] = id
        end
        table.sort(itemList)
    end
    return itemList
end

function Data.questsInMap(mapID)
    return byMap[mapID] or EMPTY
end

function Data.neighbors(mapID)
    return db and db.Neighbors and db.Neighbors[mapID] or EMPTY
end
