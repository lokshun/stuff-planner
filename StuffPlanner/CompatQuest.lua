-- CONTRAT
-- Suite de ns.Compat : boutons de récompense des fenêtres de quête. Charger après Compat.lua.
-- Détection par fonctionnalité ; sans les cadres du client : liste vide, jamais d'erreur.
--   QuestChoiceButtons(source) -> {{button, icon, index, itemID}...} : choix visibles ;
--     source = "npc" (défaut, fenêtre d'un PNJ) | "log" (détail du journal de quêtes) ;
--     icon = texture de l'icône | nil ; itemID nil si l'objet n'est pas en cache
--   HookQuestLog(fn) -> fn() après chaque affichage du détail d'une quête du journal
--   IsOnQuest(id) -> bool : quête dans le journal (C_QuestLog.IsOnQuest, sinon GetQuestLogIndexByID)
--   QuestLogIDs() -> {[questID]=true} : quêtes du journal, en-têtes exclus (C_QuestLog.GetInfo,
--     sinon GetQuestLogTitle, 8e retour) ; vide sans l'API
--   QuestLogRewards(questID) -> choices, rewards ({itemID...} triés) | nil (hors journal, objet pas
--     en cache, API absente) ; sélectionne la quête (C_QuestLog.SetSelectedQuest, sinon
--     SelectQuestLogEntry), lit GetQuestLogItemLink, puis rend la sélection précédente
--   DressUpItem(itemID) -> essayage dans la cabine du client (DressUpItemLink) ; sans effet sans elle
-- PNJ : QuestInfoRewardsFrame.RewardButtons (repli QuestInfoRewardsFrameQuestInfoItemN),
--   liens GetQuestItemLink. Journal : Classic Era QuestLogItem1..10 (QuestLog_UpdateQuestDetails),
--   Forever QuestInfoFrame.rewardsFrame (QuestInfo_Display, questLog vrai) ; liens GetQuestLogItemLink.

local _, ns = ...

local Compat = ns.Compat

local MAX_BUTTONS = 10

local function named(prefix)
    local buttons = {}
    for i = 1, MAX_BUTTONS do
        buttons[i] = _G[prefix .. i]
    end
    return buttons
end

local function npcButtons()
    local frame = QuestInfoRewardsFrame
    if frame and frame.RewardButtons then
        return frame.RewardButtons
    end
    return named("QuestInfoRewardsFrameQuestInfoItem")
end

local function logButtons()
    if _G.QuestLogItem1 then
        return named("QuestLogItem")
    end
    local frame = QuestInfoFrame and QuestInfoFrame.rewardsFrame
    return frame and frame.RewardButtons or {}
end

function Compat.QuestChoiceButtons(source)
    local isLog = source == "log"
    local buttons = isLog and logButtons() or npcButtons()
    local getLink = isLog and GetQuestLogItemLink or GetQuestItemLink
    local choices = {}
    for _, button in pairs(buttons) do
        if button.type == "choice" and button:IsShown() then
            local index = button:GetID()
            local link = getLink and getLink("choice", index)
            local name = button.GetName and button:GetName()
            choices[#choices + 1] = {
                button = button,
                icon = button.Icon or (name and _G[name .. "IconTexture"]),
                index = index,
                itemID = link and tonumber(link:match("item:(%d+)")),
            }
        end
    end
    return choices
end

function Compat.HookQuestLog(fn)
    if not hooksecurefunc then
        return
    end
    if QuestLog_UpdateQuestDetails then
        hooksecurefunc("QuestLog_UpdateQuestDetails", function()
            fn()
        end)
    end
    if QuestInfo_Display then
        hooksecurefunc("QuestInfo_Display", function()
            if QuestInfoFrame and QuestInfoFrame.questLog then
                fn()
            end
        end)
    end
end

function Compat.IsOnQuest(id)
    if C_QuestLog and C_QuestLog.IsOnQuest then
        return C_QuestLog.IsOnQuest(id) == true
    end
    if GetQuestLogIndexByID then
        local index = GetQuestLogIndexByID(id)
        return index ~= nil and index > 0
    end
    return false
end

function Compat.DressUpItem(itemID)
    if DressUpItemLink then
        DressUpItemLink("item:" .. itemID)
    end
end

function Compat.QuestLogIDs()
    local ids = {}
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        for index = 1, C_QuestLog.GetNumQuestLogEntries() or 0 do
            local info = C_QuestLog.GetInfo(index)
            if info and not info.isHeader and info.questID and info.questID > 0 then
                ids[info.questID] = true
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        for index = 1, GetNumQuestLogEntries() or 0 do
            local _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(index)
            if not isHeader and questID and questID > 0 then
                ids[questID] = true
            end
        end
    end
    return ids
end

local function readLogItems(kind, count, questID)
    local items = {}
    for index = 1, count or 0 do
        local link = GetQuestLogItemLink(kind, index, questID)
        local id = link and link:match("item:(%d+)")
        if not id then
            return nil
        end
        items[index] = tonumber(id)
    end
    table.sort(items)
    return items
end

local function readSelected(questID)
    local choices = readLogItems("choice", GetNumQuestLogChoices(questID), questID)
    local rewards = readLogItems("reward", GetNumQuestLogRewards(questID), questID)
    if choices and rewards then
        return choices, rewards
    end
    return nil
end

local function logIndexOf(questID)
    for index = 1, GetNumQuestLogEntries() or 0 do
        local _, _, _, isHeader, _, _, _, id = GetQuestLogTitle(index)
        if not isHeader and id == questID then
            return index
        end
    end
    return nil
end

function Compat.QuestLogRewards(questID)
    if not (GetQuestLogItemLink and GetNumQuestLogChoices and GetNumQuestLogRewards) then
        return nil
    end
    if C_QuestLog and C_QuestLog.SetSelectedQuest and C_QuestLog.GetLogIndexForQuestID then
        if not C_QuestLog.GetLogIndexForQuestID(questID) then
            return nil
        end
        local previous = C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()
        C_QuestLog.SetSelectedQuest(questID)
        local choices, rewards = readSelected(questID)
        if previous then
            C_QuestLog.SetSelectedQuest(previous)
        end
        return choices, rewards
    end
    if not (GetNumQuestLogEntries and GetQuestLogTitle and SelectQuestLogEntry) then
        return nil
    end
    local index = logIndexOf(questID)
    if not index then
        return nil
    end
    local previous = GetQuestLogSelection and GetQuestLogSelection()
    SelectQuestLogEntry(index)
    local choices, rewards = readSelected(questID)
    if previous then
        SelectQuestLogEntry(previous)
    end
    return choices, rewards
end
