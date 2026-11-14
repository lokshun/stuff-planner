-- CONTRAT
-- Conseil au jet de butin de groupe : « Besoin : +12 % » (amélioration, BadgePresenter) ou « Cupidité ».
-- Affichage seul : aucun jet n'est jamais fait par l'addon. Charger après BadgePresenter.lua, LiveItem.lua,
-- Manager.lua, Results.lua et CompatLoot.lua.
--   ns.RollHint.text(link) -> L.ROLL_NEED (gain en points) | L.ROLL_GREED
--     (suivi de « · » view.keep si l'objet ne sert qu'au profil secondaire) ;
--     nil sans lien, base pas prête ou sans profil actif ; nil, true : objet pas encore lisible (à relire)
--   ns.RollHint.show(rollID) : lien Compat.LootRollLink ; texte posé au-dessus du cadre de jet affiché
--     (Compat.LootRollFrame ; un texte par cadre, réutilisé, rangé ici dans une table à clés faibles : rien
--     n'est écrit sur le cadre du client), sinon une ligne L.ROLL_CHAT dans la discussion ; sans conseil :
--     texte du cadre masqué. Option roll.hint coupée : rien.
-- Cadre pas encore ouvert (interface moderne : animation, file d'attente) : show relancé toutes les
-- RETRY_DELAY s, au plus RETRY_MAX fois, avant le repli dans la discussion.
-- START_LOOT_ROLL(rollID) : show une image plus tard (le client ouvre d'abord son cadre), en combat aussi
-- (exception à la règle, voir DECISIONS : un seul objet, cadre non protégé, jet souvent lancé en combat).
-- Objet pas encore lisible : jet gardé en attente, show relancé à GET_ITEM_INFO_RECEIVED.
-- CANCEL_LOOT_ROLL : attente oubliée, texte du cadre de ce jet masqué, même si le cadre l'est déjà (un
-- cadre réutilisé pour un autre jet ne garde pas l'ancien conseil).

local _, ns = ...

local L = ns.L

local RollHint = {}
ns.RollHint = RollHint

local OPTION = "roll.hint"
local OFFSET_Y = 2
local RETRY_DELAY = 0.1
local RETRY_MAX = 10

local labels = setmetatable({}, { __mode = "k" })
local waiting = {} -- rollID -> true : objet pas encore lisible
local tries = {} -- rollID -> relances faites faute de cadre

function RollHint.text(link)
    if not link or not ns.Data.ready() then
        return nil
    end
    local profile, player = ns.Profiles.active(), ns.Results.player()
    if not (profile and player) then
        return nil
    end
    local view, retry = ns.BadgePresenter.build(link, player, profile, ns.Data, ns.LiveItem.fields)
    if retry then
        return nil, true
    end
    if not view then
        return L.ROLL_GREED
    end
    if view.keep then
        return L.ROLL_GREED .. " · " .. view.keep
    end
    return L.ROLL_NEED:format(view.text)
end

local function label(frame)
    local text = labels[frame]
    if not text then
        text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("BOTTOM", frame, "TOP", 0, OFFSET_Y)
        labels[frame] = text
    end
    return text
end

local function hideLabel(frame)
    if frame and labels[frame] then
        labels[frame]:Hide()
    end
end

function RollHint.show(rollID)
    if not ns.Options.get(OPTION) then
        return
    end
    local link = ns.Compat.LootRollLink(rollID)
    local text, retry = RollHint.text(link)
    waiting[rollID] = retry or nil
    local frame = ns.Compat.LootRollFrame(rollID)
    if not text then
        hideLabel(frame)
        return
    end
    if not frame then
        local done = tries[rollID] or 0
        if done < RETRY_MAX then
            tries[rollID] = done + 1
            C_Timer.After(RETRY_DELAY, function()
                if tries[rollID] then
                    RollHint.show(rollID)
                end
            end)
            return
        end
        tries[rollID] = nil
        print(L.ROLL_CHAT:format(link, text))
        return
    end
    tries[rollID] = nil
    local region = label(frame)
    local color = text == L.ROLL_GREED and ns.Theme.colors.muted or ns.Theme.colors.gain
    region:SetText(text)
    region:SetTextColor(color.r, color.g, color.b)
    region:Show()
end

local function cancel(rollID)
    waiting[rollID] = nil
    tries[rollID] = nil
    hideLabel(ns.Compat.LootRollFrame(rollID, true))
end

local events = CreateFrame("Frame")
events:RegisterEvent("START_LOOT_ROLL")
events:RegisterEvent("CANCEL_LOOT_ROLL")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:SetScript("OnEvent", function(_, event, rollID)
    if event == "CANCEL_LOOT_ROLL" then
        cancel(rollID)
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        for pending in pairs(waiting) do
            RollHint.show(pending)
        end
    else
        C_Timer.After(0, function()
            RollHint.show(rollID)
        end)
    end
end)
