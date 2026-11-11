-- CONTRAT
-- Seul fichier autorisé à appeler les API qui diffèrent entre Forever et Classic Era.
-- Détection par fonctionnalité, à chaque appel. Sans l'API : réponse vide, jamais d'erreur.
--   ns.Compat.client() -> "forever" | "vanilla"
--   Objets et info-bulles d'objet : CompatItem.lua.
--   GetQuestTitle(id), GetItemName(id), GetZoneName(mapID) -> string | nil
--   GetSpellName(id), GetInstanceName(instanceID), GetCreatureName(npcID) -> string | nil
--   GetItemIcon(id) -> FileDataID | nil ; GetInventorySlotTexture(slotName) -> texture d'emplacement vide | nil
--     (PNJ : info-bulle d'un lien unit:Creature, nom connu seulement s'il est en cache)
--   RequestQuestData(id), RequestItemData(id) -> demande au client ; réponse par
--     QUEST_DATA_LOAD_RESULT(questID, ok), GET_ITEM_INFO_RECEIVED(itemID, ok)
--   IsQuestCompleted(id) -> bool
--   PlayerMapPosition() -> mapID, x, y ; x et y nil si position inconnue ; nil si carte inconnue
--   Repères et carte du monde : CompatMap.lua.
--   GlobalString(name) -> chaîne globale du client | nil
--   LoadAddOn(name) -> bool ; AddOnMemory(names) -> {[nom]=Ko} | nil sans l'API
--   GetQuestLevel(id) -> number | nil ; nil sur Classic Era
--   GetLootSlots() -> {{itemID, sourceGUID}...} ; emplacements sans objet ignorés, sourceGUID nil possible
--   GetHitModifiers() -> melee, spell ; 0 si inconnu
--   GetSkillRanks() -> {[skillID]=rank} ; vide sur Classic Era, qui ne donne pas d'identifiant
--   SetFrameTitle(frame, text), SetFramePortrait(frame, texture) -> cadre PortraitFrameTemplate

local _, ns = ...

local Compat = {}
ns.Compat = Compat

function Compat.client()
    if C_Item and C_Item.GetItemStats then
        return "forever"
    end
    return "vanilla"
end

-- Premier texte non vide rendu par l'une des fonctions présentes : sur Forever, une fonction peut
-- exister et ne rien rendre alors qu'une autre connaît le nom.
local function firstName(id, ...)
    for i = 1, select("#", ...) do
        local fn = select(i, ...)
        local name = fn and fn(id)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end
    return nil
end

function Compat.GetQuestTitle(id)
    local log = C_QuestLog or {}
    return firstName(id, log.GetTitleForQuestID, log.GetQuestInfo)
end

function Compat.GetItemName(id)
    local item = C_Item or {}
    return firstName(id, item.GetItemNameByID, item.GetItemInfo, GetItemInfo)
end

function Compat.RequestQuestData(id)
    if C_QuestLog and C_QuestLog.RequestLoadQuestByID then
        C_QuestLog.RequestLoadQuestByID(id)
    end
end

function Compat.RequestItemData(id)
    if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(id)
    end
end

function Compat.GetZoneName(mapID)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return info and info.name or nil
end

function Compat.GetItemIcon(id)
    if C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(id)
    elseif GetItemIcon then
        return GetItemIcon(id)
    end
    return nil
end

function Compat.GetSpellName(id)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(id)
    elseif GetSpellInfo then
        return (GetSpellInfo(id))
    end
    return nil
end

function Compat.GetInstanceName(instanceID)
    local name = GetRealZoneText and GetRealZoneText(instanceID)
    return name ~= "" and name or nil
end

function Compat.GetCreatureName(npcID)
    local ok, lines = pcall(Compat.GetTooltipLines, ("unit:Creature-0-0-0-0-%d-0000000000"):format(npcID))
    local name = ok and lines[1]
    return name ~= "" and name or nil
end

function Compat.IsQuestCompleted(id)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(id) == true
    end
    return false
end

function Compat.PlayerMapPosition()
    if not C_Map then
        return nil
    end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        return nil
    end
    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then
        return mapID
    end
    local x, y = position:GetXY()
    return mapID, x, y
end

function Compat.GlobalString(name)
    local value = _G[name]
    if type(value) == "string" then
        return value
    end
    return nil
end

function Compat.GetInventorySlotTexture(slotName)
    if not GetInventorySlotInfo then
        return nil
    end
    local ok, _, texture = pcall(GetInventorySlotInfo, slotName)
    return ok and texture or nil
end

function Compat.LoadAddOn(name)
    if C_AddOns and C_AddOns.LoadAddOn then
        return C_AddOns.LoadAddOn(name) and true or false
    end
    return false
end

function Compat.AddOnMemory(names)
    local get = (C_AddOns and C_AddOns.GetAddOnMemoryUsage) or GetAddOnMemoryUsage
    if not (UpdateAddOnMemoryUsage and get) then return nil end
    UpdateAddOnMemoryUsage()
    local usage = {}
    for _, name in ipairs(names) do
        usage[name] = get(name) or 0
    end
    return usage
end

function Compat.GetQuestLevel(id)
    if C_QuestLog and C_QuestLog.GetQuestDifficultyLevel then
        return C_QuestLog.GetQuestDifficultyLevel(id)
    end
    return nil
end

function Compat.GetLootSlots()
    local slots = {}
    if not (GetNumLootItems and GetLootSlotLink) then
        return slots
    end
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        local id = link and link:match("item:(%d+)")
        if id then
            slots[#slots + 1] = {
                itemID = tonumber(id),
                sourceGUID = GetLootSourceInfo and GetLootSourceInfo(slot) or nil,
            }
        end
    end
    return slots
end

function Compat.GetHitModifiers()
    local melee = GetHitModifier and GetHitModifier()
    local spell = GetSpellHitModifier and GetSpellHitModifier()
    return melee or 0, spell or 0
end

function Compat.GetSkillRanks()
    local ranks = {}
    if not (C_SkillInfo and C_SkillInfo.GetNumSkillLines and C_SkillInfo.GetSkillLineInfo) then
        return ranks
    end
    for index = 1, C_SkillInfo.GetNumSkillLines() do
        local line = C_SkillInfo.GetSkillLineInfo(index)
        if line and not line.isHeader then
            ranks[line.skillID] = line.rank
        end
    end
    return ranks
end

-- Forever : méthodes de PortraitFrameMixin ; Classic Era : TitleText et portrait du modèle.
function Compat.SetFrameTitle(frame, text)
    if frame.SetTitle then
        frame:SetTitle(text)
    elseif frame.TitleText then
        frame.TitleText:SetText(text)
    end
end

function Compat.SetFramePortrait(frame, texture)
    if frame.SetPortraitToAsset then
        frame:SetPortraitToAsset(texture)
    elseif frame.portrait and SetPortraitToTexture then
        SetPortraitToTexture(frame.portrait, texture)
    end
end
