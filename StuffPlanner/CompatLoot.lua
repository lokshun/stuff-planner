-- CONTRAT
-- Butin : jets de groupe, fenêtre de butin, récompenses de l'écran de rendu de quête, son d'alerte.
-- Détection par fonctionnalité, à chaque appel ; sans l'API : nil ou liste vide, jamais d'erreur.
-- Charger après Compat.lua.
--   ns.Compat.LootSlotLinks() -> {{itemID, link}...} : emplacements de la fenêtre de butin ouverte (GetNumLootItems,
--     GetLootSlotLink) ; argent et emplacements vides ignorés
--   ns.Compat.QuestDialogRewardLinks() -> {{itemID, link}...} : récompenses fixes puis au choix du dialogue de quête
--     affiché (GetNumQuestRewards, GetNumQuestChoices, GetQuestItemLink) ; objet pas en cache : absent
--   ns.Compat.PlayAlertSound() : son d'avertissement de raid du client (SOUNDKIT.RAID_WARNING, repli 8959), canal
--     Master ; sans PlaySound : rien
--   ns.Compat.LootRollLink(rollID) -> lien de l'objet | nil (GetLootRollItemLink)
--   ns.Compat.LootRollFrame(rollID, hiddenToo?) -> cadre du client dont le champ rollID est égal, affiché
--     (ou aussi caché si hiddenToo) | nil : GroupLootFrame1..MAX_ROLL_FRAMES, puis
--     GroupLootContainer.rollFrames (interface moderne). Ne rien écrire sur ce cadre.
--   ns.Compat.MAX_ROLL_FRAMES = 4

local _, ns = ...

local Compat = ns.Compat

Compat.MAX_ROLL_FRAMES = 4

function Compat.LootRollLink(rollID)
    local getLink = _G.GetLootRollItemLink
    if type(getLink) ~= "function" then
        return nil
    end
    local ok, link = pcall(getLink, rollID)
    return ok and link or nil
end

local function matches(frame, rollID, hiddenToo)
    return type(frame) == "table" and frame.rollID == rollID and (hiddenToo or frame:IsShown()) and true or false
end

function Compat.LootRollFrame(rollID, hiddenToo)
    for index = 1, Compat.MAX_ROLL_FRAMES do
        local frame = _G["GroupLootFrame" .. index]
        if matches(frame, rollID, hiddenToo) then
            return frame
        end
    end
    local container = _G.GroupLootContainer
    local frames = type(container) == "table" and container.rollFrames
    if type(frames) == "table" then
        for _, frame in pairs(frames) do
            if matches(frame, rollID, hiddenToo) then
                return frame
            end
        end
    end
    return nil
end

local function entry(link)
    local id = type(link) == "string" and link:match("item:(%d+)")
    return id and { itemID = tonumber(id), link = link } or nil
end

function Compat.LootSlotLinks()
    local items = {}
    if not (GetNumLootItems and GetLootSlotLink) then
        return items
    end
    for slot = 1, GetNumLootItems() or 0 do
        items[#items + 1] = entry(GetLootSlotLink(slot))
    end
    return items
end

local function addQuestLinks(items, kind, count)
    for index = 1, count or 0 do
        items[#items + 1] = entry(GetQuestItemLink(kind, index))
    end
end

function Compat.QuestDialogRewardLinks()
    local items = {}
    if not GetQuestItemLink then
        return items
    end
    addQuestLinks(items, "reward", GetNumQuestRewards and GetNumQuestRewards())
    addQuestLinks(items, "choice", GetNumQuestChoices and GetNumQuestChoices())
    return items
end

local RAID_WARNING = 8959

function Compat.PlayAlertSound()
    if not PlaySound then
        return
    end
    local kit = _G.SOUNDKIT
    pcall(PlaySound, (type(kit) == "table" and kit.RAID_WARNING) or RAID_WARNING, "Master")
end
