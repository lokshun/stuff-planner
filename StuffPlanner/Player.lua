-- CONTRAT
-- Instantané du personnage et signal de changement. Charger après Core.lua, Compat.lua, CompatQuest.lua.
--   ns.Player.snapshot() -> {class, race, raceID, faction, level, mapID, equipped={[slot]=itemID},
--     spellHit, meleeHit, professions={[id]=skill}} ; class et race en jetons anglais, raceID du client ;
--     mapID nil si carte inconnue ; toucher en points de pourcentage
--   equippedStats={[slot]={[StatKey]=value}} : objets portés absents de la base (Data prête),
--     stats lues par Compat.GetItemStats + StatParser.fromApi ; vide avant Data prête
-- Table neuve à chaque appel : la modifier n'affecte ni l'état ni les autres instantanés.
-- Message SP_PLAYER_CHANGED, sans argument, regroupé sur niveau, zone et équipement,
-- jamais émis en combat. Les changements de métier n'émettent rien.
-- Message SP_QUEST_LOG_CHANGED, sans argument : quêtes du journal changées (Compat.QuestLogIDs,
-- relu sur QUEST_LOG_UPDATE regroupé sur 1 s : prise, abandon, quête rendue ; pas les objectifs),
-- jamais émis en combat.
-- Classic Era : professions reste vide (voir Compat.GetSkillRanks).

local _, ns = ...

local Compat = ns.Compat

local Player = ns:NewModule("Player", "AceBucket-3.0")
ns.Player = Player

local BUCKET_INTERVAL = 0.5
local QUEST_LOG_INTERVAL = 1
local FIRST_EQUIPPED_SLOT = 1
local LAST_EQUIPPED_SLOT = 19

local EVENTS = {
    "PLAYER_LEVEL_UP",
    "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA",
}

local PROFESSION_SKILLS = {
    [129] = true, -- Secourisme
    [164] = true, -- Forge
    [165] = true, -- Travail du cuir
    [171] = true, -- Alchimie
    [182] = true, -- Herboristerie
    [185] = true, -- Cuisine
    [186] = true, -- Minage
    [197] = true, -- Couture
    [202] = true, -- Ingénierie
    [333] = true, -- Enchantement
    [356] = true, -- Pêche
    [393] = true, -- Dépeçage
}

local function readEquipped()
    local equipped = {}
    for slot = FIRST_EQUIPPED_SLOT, LAST_EQUIPPED_SLOT do
        equipped[slot] = GetInventoryItemID("player", slot)
    end
    return equipped
end

-- Stats des objets portés que la base ne connaît pas (butin de monde, objets masqués).
local function readEquippedStats(equipped)
    local result = {}
    local data = ns.Data
    if not (data and data.ready() and ns.StatParser) then
        return result
    end
    for slot, itemID in pairs(equipped) do
        local link = not data.item(itemID) and GetInventoryItemLink("player", slot)
        if link then
            local stats = ns.StatParser.fromApi(Compat.GetItemStats(link))
            if next(stats) then
                result[slot] = stats
            end
        end
    end
    return result
end

local function readProfessions()
    local professions = {}
    for id, rank in pairs(Compat.GetSkillRanks()) do
        if PROFESSION_SKILLS[id] then
            professions[id] = rank
        end
    end
    return professions
end

function Player.snapshot()
    local _, class = UnitClass("player")
    local _, race, raceID = UnitRace("player")
    local faction = UnitFactionGroup("player")
    local mapID = Compat.PlayerMapPosition()
    local meleeHit, spellHit = Compat.GetHitModifiers()
    local equipped = readEquipped()
    return {
        class = class,
        race = race,
        raceID = raceID,
        faction = faction,
        level = UnitLevel("player"),
        mapID = mapID,
        equipped = equipped,
        equippedStats = readEquippedStats(equipped),
        spellHit = spellHit,
        meleeHit = meleeHit,
        professions = readProfessions(),
    }
end

local waiting = {}

-- Envoie message hors combat, une seule fois même s'il est demandé plusieurs fois en combat.
local function notifier(message)
    return function()
        if waiting[message] then
            return
        end
        waiting[message] = true
        ns:RunOutOfCombat(function()
            waiting[message] = nil
            ns:Send(message)
        end)
    end
end

Player:RegisterBucketEvent(EVENTS, BUCKET_INTERVAL, notifier("SP_PLAYER_CHANGED"))
local notifyLog = notifier("SP_QUEST_LOG_CHANGED")
local lastLog

local function questLogUpdated()
    local ids = {}
    for id in pairs(Compat.QuestLogIDs()) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    local key = table.concat(ids, ",")
    if key ~= lastLog then
        lastLog = key
        notifyLog()
    end
end

Player:RegisterBucketEvent({ "QUEST_LOG_UPDATE" }, QUEST_LOG_INTERVAL, questLogUpdated)
