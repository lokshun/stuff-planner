-- CONTRAT
-- Alerte de butin voulu : son et bandeau (ns.Toast) quand tombe un objet de la liste cible ou une amélioration
-- (fenêtre de butin : boss, trash, monde ; jet de groupe) ou qu'une quête rendue en offre une (écran de rendu).
-- Charger après Toast.lua, LootAlertPresenter.lua, BadgePresenter.lua, LiveItem.lua, WishlistStore.lua,
-- Results.lua et CompatLoot.lua.
-- Événements : LOOT_OPENED (Compat.LootSlotLinks), START_LOOT_ROLL(rollID) (Compat.LootRollLink, une image plus
-- tard), QUEST_COMPLETE (Compat.QuestDialogRewardLinks, une image plus tard). Gain : BadgePresenter.build sur le
-- lien (objet hors base lu en jeu) ; objet pas encore lisible : relu une fois RETRY_SECONDS plus tard.
-- Seuil : réglage loot.minGain (points ; la liste cible l'ignore). Un objet signalé une fois par
-- LootAlertPresenter.REPEAT_SECONDS. Affichée en combat aussi (son, cadre non sécurisé ; comme RollHint).
-- Bandeau : meilleur objet trouvé (icône, « Liste cible : nom +2,5 »), 8 s ; survol = info-bulle de l'objet ;
-- clic : masqué (Maj+clic : lien dans la discussion). Réglages loot.alert (bandeau) et loot.sound (son) ;
-- les deux coupés : rien n'est lu.
--   ns.LootAlert.check(items, quest?) : items = {{itemID, link}...} ; vérification immédiate

local _, ns = ...

local LootAlert = {}
ns.LootAlert = LootAlert

local OFFSET_Y = -180
local DURATION = 8
local RETRY_SECONDS = 1

local seen = {}
local toast

local function onEnter(frame, current)
    local link = current.data and current.data.link
    if link then
        GameTooltip:SetOwner(frame, "ANCHOR_BOTTOM")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end
end

local function onClick(current)
    local match = current.data
    if IsShiftKeyDown() and match then
        ns.Compat.InsertChatLink(match.itemID)
        return
    end
    current:hide()
end

local function displayName(match)
    local link = match.link
    local name = link and link:match("%[(.-)%]") or ns.Names.item(match.itemID)
    local color = link and link:match("^(|c%x%x%x%x%x%x%x%x)")
    return color and (color .. name .. "|r") or name
end

local function show(match, quest)
    if ns.Options.get("loot.sound") then
        ns.Compat.PlayAlertSound()
    end
    if ns.Options.get("loot.alert") then
        toast = toast or ns.Toast.new({ offsetY = OFFSET_Y, duration = DURATION, icon = true,
            onClick = onClick, onEnter = onEnter })
        toast.data = match
        toast:show(ns.LootAlertPresenter.text(match, displayName(match), quest), ns.Names.itemIcon(match.itemID))
    end
end

-- Gain en points d'après le lien ; retry vrai si l'objet n'est pas encore lisible.
local function gainReader(state)
    local profile, player = ns.Profiles.active(), ns.Results.player()
    return function(item)
        if not (profile and player) then
            return nil
        end
        local view, retry = ns.BadgePresenter.build(item.link or ("item:" .. item.itemID), player, profile,
            ns.Data, ns.LiveItem.fields)
        state.retry = state.retry or retry
        return view and view.abs
    end
end

local function enabled()
    return ns.Options.get("loot.alert") or ns.Options.get("loot.sound")
end

local function run(items, quest, again)
    if not (enabled() and ns.Data.ready()) or #items == 0 then
        return
    end
    local state = {}
    local found = ns.LootAlertPresenter.match(items, {
        has = ns.WishlistStore.has, gainOf = gainReader(state), minGain = ns.Options.get("loot.minGain"),
    })
    local now = GetTime()
    for _, match in ipairs(found) do
        if ns.LootAlertPresenter.fresh(seen, match.itemID, now) then
            show(match, quest)
            return
        end
    end
    if state.retry and not again then
        C_Timer.After(RETRY_SECONDS, function()
            run(items, quest, true)
        end)
    end
end

function LootAlert.check(items, quest)
    run(items or {}, quest, false)
end

local function nextFrame(fn)
    C_Timer.After(0, fn)
end

local events = CreateFrame("Frame")
events:RegisterEvent("LOOT_OPENED")
events:RegisterEvent("START_LOOT_ROLL")
events:RegisterEvent("QUEST_COMPLETE")
events:SetScript("OnEvent", function(_, event, rollID)
    if not enabled() then
        return
    elseif event == "LOOT_OPENED" then
        LootAlert.check(ns.Compat.LootSlotLinks())
    elseif event == "START_LOOT_ROLL" then
        nextFrame(function()
            local link = ns.Compat.LootRollLink(rollID)
            local id = link and link:match("item:(%d+)")
            if id then
                LootAlert.check({ { itemID = tonumber(id), link = link } })
            end
        end)
    else
        nextFrame(function()
            LootAlert.check(ns.Compat.QuestDialogRewardLinks(), true)
        end)
    end
end)

ns:On("SP_OPTION_CHANGED", function(key, value)
    if key == "loot.alert" and not value and toast then
        toast:hide()
    end
end)
