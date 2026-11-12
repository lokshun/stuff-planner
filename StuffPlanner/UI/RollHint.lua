-- CONTRAT
-- Conseil au jet de butin de groupe : « Besoin : +12 % » (amélioration, BadgePresenter) ou « Cupidité ».
-- Affichage seul : aucun jet n'est jamais fait par l'addon. Charger après BadgePresenter.lua, LiveItem.lua,
-- Manager.lua et Results.lua.
--   ns.RollHint.text(link) -> L.ROLL_NEED (pourcentage) | L.ROLL_NEED_EMPTY (emplacement vide) | L.ROLL_GREED ;
--     nil sans lien, base pas prête ou sans profil actif
--   ns.RollHint.show(rollID) : lien GetLootRollItemLink(rollID) ; texte posé au-dessus du cadre de jet affiché
--     GroupLootFrame1..MAX_FRAMES dont rollID est égal (un texte par cadre, réutilisé), sinon une ligne
--     L.ROLL_CHAT dans la discussion ; sans conseil : texte du cadre masqué. Option roll.hint coupée : rien.
-- START_LOOT_ROLL(rollID) : show une image plus tard (le client ouvre d'abord son cadre), hors combat
-- (ns:RunOutOfCombat). CANCEL_LOOT_ROLL : texte du cadre de ce jet masqué, même si le cadre l'est déjà (un
-- cadre réutilisé pour un autre jet ne garde pas l'ancien conseil).

local _, ns = ...

local L = ns.L

local RollHint = {}
ns.RollHint = RollHint

local OPTION = "roll.hint"
local MAX_FRAMES = 4
local OFFSET_Y = 2

function RollHint.text(link)
    if not link or not ns.Data.ready() then
        return nil
    end
    local profile, player = ns.Profiles.active(), ns.Results.player()
    if not (profile and player) then
        return nil
    end
    local view = ns.BadgePresenter.build(link, player, profile, ns.Data, ns.LiveItem.fields)
    if not view then
        return L.ROLL_GREED
    end
    if view.text == "" then
        return L.ROLL_NEED_EMPTY
    end
    return L.ROLL_NEED:format(view.text)
end

local function frameFor(rollID, hiddenToo)
    for index = 1, MAX_FRAMES do
        local frame = _G["GroupLootFrame" .. index]
        if frame and frame.rollID == rollID and (hiddenToo or frame:IsShown()) then
            return frame
        end
    end
    return nil
end

local function label(frame)
    local text = frame.stuffPlannerRoll
    if not text then
        text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("BOTTOM", frame, "TOP", 0, OFFSET_Y)
        frame.stuffPlannerRoll = text
    end
    return text
end

function RollHint.show(rollID)
    if not ns.Options.get(OPTION) then
        return
    end
    local getLink = _G.GetLootRollItemLink
    local link = getLink and getLink(rollID)
    local text = RollHint.text(link)
    local frame = frameFor(rollID)
    if not text then
        if frame and frame.stuffPlannerRoll then
            frame.stuffPlannerRoll:Hide()
        end
        return
    end
    if not frame then
        print(L.ROLL_CHAT:format(link, text))
        return
    end
    local region = label(frame)
    local color = text == L.ROLL_GREED and ns.Theme.colors.muted or ns.Theme.colors.gain
    region:SetText(text)
    region:SetTextColor(color.r, color.g, color.b)
    region:Show()
end

local function cancel(rollID)
    local frame = frameFor(rollID, true)
    if frame and frame.stuffPlannerRoll then
        frame.stuffPlannerRoll:Hide()
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("START_LOOT_ROLL")
events:RegisterEvent("CANCEL_LOOT_ROLL")
events:SetScript("OnEvent", function(_, event, rollID)
    if event == "CANCEL_LOOT_ROLL" then
        cancel(rollID)
        return
    end
    C_Timer.After(0, function()
        ns:RunOutOfCombat(function()
            RollHint.show(rollID)
        end)
    end)
end)
