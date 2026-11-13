-- CONTRAT
-- Instantané du personnage et signal de changement. Charger après Core.lua, Compat*.lua.
--   ns.Player.snapshot() -> {class, race, raceID, faction, level, mapID, equipped={[slot]=itemID},
--     spellHit, meleeHit, avoidCrit, professions={[id]=skill}, reputations={[factionID]=valeur}, knowsSpell}
--     (Compat.GetReputations, Compat.IsSpellKnown) ; class et race en jetons anglais, raceID du client ;
--     avoidCrit = % de critiques subis en moins (StatValue.critAvoidance, Compat.GetDefense) ;
--     mapID nil si carte inconnue ; toucher en points de pourcentage
--   equippedStats={[slot]={[StatKey]=value}} : objets portés absents de la base ou à suffixe aléatoire
--     (Data prête), stats lues par Compat.GetItemStats + StatParser.fromApi ; vide avant Data prête
--   equippedTypes={[slot]=InventoryType} : objets portés absents de la base (Compat.GetItemInfoInstant)
-- Table neuve à chaque appel : la modifier n'affecte ni l'état ni les autres instantanés.
-- ns.Player.signature() -> chaîne : niveau, carte, toucher, lien et stats connues (Compat.GetItemStats non
--   vide) de chaque objet porté ; égale tant que rien de ce qui compte pour les gains ne change.
-- Message SP_PLAYER_CHANGED, sans argument, regroupé sur niveau, zone et équipement, émis seulement si la
-- signature a changé depuis le dernier message (sous-zone sans changement de carte : rien), jamais en
-- combat (signature lue à l'envoi). Les changements de métier et de réputation n'émettent rien.
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

-- Stats des objets portés que la base ne connaît pas (butin de monde, objets masqués) ou dont le
-- suffixe aléatoire change les stats ; type d'emplacement des objets hors base.
local function readEquippedStats(equipped)
    local result, types = {}, {}
    local data = ns.Data
    if not (data and data.ready() and ns.StatParser) then
        return result, types
    end
    for slot, itemID in pairs(equipped) do
        local known = data.item(itemID) ~= nil
        local link = GetInventoryItemLink("player", slot)
        if link and (not known or ns.ItemLink.suffix(link) ~= 0) then
            local stats = ns.StatParser.fromApi(Compat.GetItemStats(link))
            if next(stats) then
                result[slot] = stats
            end
        end
        local info = link and not known and Compat.GetItemInfoInstant(link)
        local inventoryType = info and ns.ItemLink.inventoryType(info.equipLoc)
        if inventoryType then
            types[slot] = inventoryType
        end
    end
    return result, types
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
    local equippedStats, equippedTypes = readEquippedStats(equipped)
    return {
        class = class,
        race = race,
        raceID = raceID,
        faction = faction,
        level = UnitLevel("player"),
        mapID = mapID,
        equipped = equipped,
        equippedStats = equippedStats,
        equippedTypes = equippedTypes,
        spellHit = spellHit,
        meleeHit = meleeHit,
        avoidCrit = ns.StatValue.critAvoidance(Compat.GetDefense(), UnitLevel("player")),
        professions = readProfessions(),
        reputations = Compat.GetReputations(),
        knowsSpell = Compat.IsSpellKnown,
    }
end

function Player.signature()
    local melee, spell = Compat.GetHitModifiers()
    local parts = { UnitLevel("player") or 0, (Compat.PlayerMapPosition()) or 0, melee, spell }
    for slot = FIRST_EQUIPPED_SLOT, LAST_EQUIPPED_SLOT do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
        parts[#parts + 1] = link and (link .. (next(Compat.GetItemStats(link)) and "+" or "-")) or ""
    end
    return table.concat(parts, "|")
end

local waiting = {}

-- Envoie message hors combat, une seule fois même s'il est demandé plusieurs fois en combat ;
-- changed() (facultatif), appelé à l'envoi, peut l'annuler.
local function notifier(message, changed)
    return function()
        if waiting[message] then
            return
        end
        waiting[message] = true
        ns:RunOutOfCombat(function()
            waiting[message] = nil
            if not changed or changed() then
                ns:Send(message)
            end
        end)
    end
end

local lastSignature

local function playerChanged()
    local signature = Player.signature()
    if signature == lastSignature then
        return false
    end
    lastSignature = signature
    return true
end

Player:RegisterBucketEvent(EVENTS, BUCKET_INTERVAL, notifier("SP_PLAYER_CHANGED", playerChanged))
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
