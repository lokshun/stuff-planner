-- CONTRAT
-- Toast d'entrée de carte : « Forêt d'Elwynn : 4 améliorations, la meilleure +12 % » (ZoneToastPresenter),
-- 5 s en haut de l'écran ; clic : onglet Zone de la fenêtre principale. Charger après Chat.lua,
-- ZoneToastPresenter.lua et MainFrame.lua.
-- Vérifié à chaque SP_RESULTS_UPDATED (gains de la carte calculés, Results.busy() faux) : une fois par
-- carte (mapID de l'instantané, une sous-zone ne change rien) et par session ; carte marquée vue dès
-- que son classement est lisible, même vide (aucun toast sans amélioration).
-- Jamais en combat : vérification reportée à la sortie (ns:RunOutOfCombat). Option toast.zone coupée :
-- plus de vérification, toast affiché masqué.
--   ns.ZoneToast.check() : vérification immédiate (tests)
--   ns.ZoneToast.display(text) : affiche le toast (remplaçable dans les tests)

local _, ns = ...

local ZoneToast = {}
ns.ZoneToast = ZoneToast

local OPTION = "toast.zone"
local DURATION = 5
local OFFSET_Y = -140
local HEIGHT = 34
local MAX_ENTRIES = 999

local seen = {}
local deferred = false
local frame, label
local shownAt = 0

local function hide()
    if frame then
        frame:Hide()
    end
end

local function openZone()
    hide()
    ns:RunOutOfCombat(function()
        ns.MainFrame.show("zone")
    end)
end

local function create()
    local theme = ns.Theme
    frame = CreateFrame("Button", nil, UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetHeight(HEIGHT)
    frame:SetPoint("TOP", UIParent, "TOP", 0, OFFSET_Y)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    local bg = theme.colors.background
    background:SetColorTexture(bg.r, bg.g, bg.b, 0.85)
    local edge = theme.colors.border
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" } }) do
        local line = frame:CreateTexture(nil, "BORDER")
        line:SetColorTexture(edge.r, edge.g, edge.b, 0.8)
        line:SetHeight(theme.spacing.border)
        line:SetPoint(side[1])
        line:SetPoint(side[2])
    end
    label = frame:CreateFontString(nil, "OVERLAY", theme.fonts.header)
    label:SetPoint("CENTER")
    frame:RegisterForClicks("LeftButtonUp")
    frame:SetScript("OnClick", openZone)
    frame:Hide()
end

function ZoneToast.display(text)
    if not frame then
        create()
    end
    label:SetText(text)
    frame:SetWidth(label:GetStringWidth() + 2 * ns.Theme.spacing.padding)
    frame:Show()
    shownAt = shownAt + 1
    local token = shownAt
    C_Timer.After(DURATION, function()
        if token == shownAt then
            hide()
        end
    end)
end

function ZoneToast.check()
    if not ns.Options.get(OPTION) or ns.Results.busy() then
        return
    end
    if InCombatLockdown() then
        if not deferred then
            deferred = true
            ns:RunOutOfCombat(function()
                deferred = false
                ZoneToast.check()
            end)
        end
        return
    end
    local player = ns.Results.player()
    local mapID = player and player.mapID
    if not mapID or seen[mapID] then
        return
    end
    local results = ns.Chat.currentZone(MAX_ENTRIES, true)
    if not results then
        return
    end
    seen[mapID] = true
    local text = ns.ZoneToastPresenter.build(results, ns.Names.zone(mapID))
    if text then
        ZoneToast.display(text)
    end
end

ns:On("SP_RESULTS_UPDATED", function()
    ZoneToast.check()
end)

ns:On("SP_OPTION_CHANGED", function(key, value)
    if key == OPTION and not value then
        hide()
    end
end)
