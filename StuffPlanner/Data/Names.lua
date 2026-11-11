-- CONTRAT
-- Noms affichables, lus dans le client : la base n'en stocke aucun. Charger après Compat.lua.
--   ns.Names.quest(id), item(id), npc(id), zone(mapID), spell(id), instance(id) -> string ;
--     quête et objet : client > base (Data.baseName, langue du client) > repli « Quest #id » (ns.L)
--   ns.Names.itemIcon(id, icon?) -> icon de la base, sinon celle du client, si ce n'est pas le point
--     d'interrogation (objet masqué pas encore reçu) | nil
--   ns.Names.profession(skillLine) -> nom du métier (sort d'apprenti) ; repli « Profession #id »
--   ns.Names.onReady(kind, id, fn) -> fn(name) dès que le nom est connu, tout de suite s'il l'est ;
--     kind : "quest" | "item" | "npc" | "zone" | "spell" | "instance" ; chaque rappel est appelé une fois
--   ns.Names.isKnown(kind, id) -> bool : nom connu du client ou appris (pas la base ni le repli) ;
--     onReady attend ce nom-là (il apporte aussi l'icône)
--   ns.Names.learn(kind, id, name) -> nom appris hors client ; PNJ : gardé dans
--     StuffPlannerDB.npcNames[GetLocale()], appris au dialogue de quête et au ciblage d'une créature
-- PNJ : nom appris > client (info-bulle) > base (Data.npcName).
-- Seuls les vrais noms vont en cache. Quête et objet inconnus : demande au client via Compat,
-- réponse par QUEST_DATA_LOAD_RESULT ou GET_ITEM_INFO_RECEIVED. Un rappel en erreur n'arrête pas les autres.

local _, ns = ...

local L = ns.L
local Compat = ns.Compat

local Names = ns:NewModule("Names", "AceEvent-3.0")
ns.Names = Names

local FALLBACKS = {
    quest = "NAME_QUEST", item = "NAME_ITEM", npc = "NAME_NPC", zone = "NAME_ZONE",
    spell = "NAME_SPELL", instance = "NAME_INSTANCE",
}
local LOOKUPS = {
    quest = Compat.GetQuestTitle,
    item = Compat.GetItemName,
    npc = function(id)
        local saved = ns.DB.peek("account", "npcNames", GetLocale(), id)
        return saved or Compat.GetCreatureName(id) or (ns.Data and ns.Data.npcName(id))
    end,
    zone = Compat.GetZoneName,
    spell = Compat.GetSpellName,
    instance = Compat.GetInstanceName,
}

-- SkillLine du métier -> sort d'apprenti qui porte son nom (Classic).
local PROFESSION_SPELLS = {
    [129] = 3273, [164] = 2018, [165] = 2108, [171] = 2259, [182] = 2366, [185] = 2550,
    [186] = 2575, [197] = 3908, [202] = 4036, [333] = 7411, [356] = 7620, [393] = 8613,
}
local REQUESTS = { quest = Compat.RequestQuestData, item = Compat.RequestItemData }
local BASE_NAMES = { quest = true, item = true }
local UNKNOWN_ICON = 134400

local known = { quest = {}, item = {}, npc = {}, zone = {}, spell = {}, instance = {} }
local waiting = { quest = {}, item = {}, npc = {}, zone = {}, spell = {}, instance = {} }

local function lookup(kind, id)
    local name = known[kind][id]
    if name then
        return name
    end
    local read = LOOKUPS[kind]
    name = read and read(id)
    if name and name ~= "" then
        known[kind][id] = name
        return name
    end
    return nil
end

local function baseName(kind, id)
    return BASE_NAMES[kind] and ns.Data and ns.Data.baseName and ns.Data.baseName(kind, id) or nil
end

local function nameOf(kind, id)
    return lookup(kind, id) or baseName(kind, id) or L[FALLBACKS[kind]]:format(id)
end

local function validIcon(icon)
    return icon and icon ~= UNKNOWN_ICON and icon ~= 0 and icon or nil
end

function Names.itemIcon(id, icon)
    return validIcon(icon) or validIcon(Compat.GetItemIcon(id))
end

function Names.quest(id)
    return nameOf("quest", id)
end

function Names.item(id)
    return nameOf("item", id)
end

function Names.npc(id)
    return nameOf("npc", id)
end

function Names.zone(mapID)
    return nameOf("zone", mapID)
end

function Names.spell(id)
    return nameOf("spell", id)
end

function Names.instance(id)
    return nameOf("instance", id)
end

function Names.profession(skillLine)
    local spellID = PROFESSION_SPELLS[skillLine]
    return spellID and lookup("spell", spellID) or L.NAME_PROFESSION:format(skillLine)
end

local function wake(kind, id)
    local list = waiting[kind][id]
    local name = list and lookup(kind, id)
    if not name then
        return
    end
    waiting[kind][id] = nil
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn, name)
        if not ok then
            geterrorhandler()(err)
        end
    end
end

function Names.onReady(kind, id, fn)
    local name = lookup(kind, id)
    if name then
        fn(name)
        return
    end
    local list = waiting[kind][id]
    if not list then
        list = {}
        waiting[kind][id] = list
        if REQUESTS[kind] then
            REQUESTS[kind](id)
        end
    end
    list[#list + 1] = fn
end

function Names.isKnown(kind, id)
    return lookup(kind, id) ~= nil
end

function Names.learn(kind, id, name)
    known[kind][id] = name
    if kind == "npc" and ns.DB.peek("account") then
        ns.DB.account("npcNames", GetLocale())[id] = name
    end
    wake(kind, id)
end

-- Apprend le nom d'une créature désignée par une unité ("npc", "target").
local function learnUnit(unit)
    local guid = UnitGUID(unit)
    local kind, id = (guid or ""):match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    local name = UnitName(unit)
    if (kind == "Creature" or kind == "Vehicle") and name and name ~= "" then
        id = tonumber(id)
        if known.npc[id] ~= name then
            Names.learn("npc", id, name)
        end
    end
end

for _, event in ipairs({ "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING", "GOSSIP_SHOW" }) do
    Names:RegisterEvent(event, function()
        learnUnit("npc")
    end)
end

Names:RegisterEvent("PLAYER_TARGET_CHANGED", function()
    learnUnit("target")
end)

Names:RegisterEvent("QUEST_DATA_LOAD_RESULT", function(_, questID)
    wake("quest", questID)
end)

Names:RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, itemID)
    wake("item", itemID)
end)
