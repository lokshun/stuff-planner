-- CONTRAT
-- Halo doré sur la meilleure récompense au choix : fenêtre de quête d'un PNJ et détail du
-- journal de quêtes (TooltipPresenter.bestChoice, boutons par Compat.QuestChoiceButtons).
-- Charger après CompatQuest.lua, TooltipPresenter.lua, Scoring.lua et Manager.lua.
-- PNJ : QUEST_DETAIL, QUEST_COMPLETE, calcul à l'image suivante (le client remplit les boutons
-- après l'événement) ; QUEST_FINISHED : halo retiré. Journal : à chaque affichage du détail
-- (Compat.HookQuestLog). Un halo par source. Rien en combat, avant SP_DATA_READY, sans profil ni si
-- le réglage questHint.enabled est coupé.

local _, ns = ...

local HALO_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local HALO_SCALE = 1.8
local DEFAULT_ICON_SIZE = 36

local halos = {}

local function create()
    local holder = CreateFrame("Frame", nil, UIParent)
    local texture = holder:CreateTexture(nil, "OVERLAY")
    texture:SetTexture(HALO_TEXTURE)
    texture:SetBlendMode("ADD")
    local gold = ns.Theme.colors.title
    texture:SetVertexColor(gold.r, gold.g, gold.b)
    holder:Hide()
    return { holder = holder, texture = texture }
end

local function hide(source)
    if halos[source] then
        halos[source].holder:Hide()
    end
end

local function showOn(source, choice)
    halos[source] = halos[source] or create()
    local holder, texture = halos[source].holder, halos[source].texture
    local anchor = choice.icon or choice.button
    local size = anchor.GetHeight and anchor:GetHeight() or 0
    if size <= 0 then
        size = DEFAULT_ICON_SIZE
    end
    holder:SetParent(choice.button)
    holder:SetFrameLevel(choice.button:GetFrameLevel() + 2)
    holder:ClearAllPoints()
    holder:SetAllPoints(anchor)
    texture:ClearAllPoints()
    texture:SetPoint("CENTER", anchor, "CENTER")
    texture:SetSize(size * HALO_SCALE, size * HALO_SCALE)
    holder:Show()
end

local function update(source)
    hide(source)
    if InCombatLockdown() or not ns.Data.ready() or not ns.Options.get("questHint.enabled") then
        return
    end
    local profile = ns.Profiles.active()
    if not profile then
        return
    end
    local choices = ns.Compat.QuestChoiceButtons(source)
    if #choices == 0 then
        return
    end
    local itemIDs = {}
    for i, choice in ipairs(choices) do
        itemIDs[i] = choice.itemID or false
    end
    local best = ns.TooltipPresenter.bestChoice(itemIDs, ns.Player.snapshot(), profile, ns.Data)
    if best then
        showOn(source, choices[best])
    end
end

local function updateNpc()
    update("npc")
end

ns.Compat.HookQuestLog(function()
    update("log")
end)

local events = CreateFrame("Frame")
events:RegisterEvent("QUEST_DETAIL")
events:RegisterEvent("QUEST_COMPLETE")
events:RegisterEvent("QUEST_FINISHED")
events:SetScript("OnEvent", function(_, event)
    if event == "QUEST_FINISHED" then
        hide("npc")
    else
        C_Timer.After(0, updateNpc)
    end
end)
