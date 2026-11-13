-- CONTRAT
-- Fenêtre principale et combat. Charger après MainFrame.lua, QuestDetail.lua, SourceDetail.lua et
-- CombatReopen.lua.
--   ns.WindowCombat.request(tab?) : ouverture demandée en combat (MainFrame.show, toggle) : la fenêtre s'ouvrira
--     à la sortie, sur tab ou la page mémorisée ; avis L.WINDOW_AFTER_COMBAT une fois par combat
--   ns.WindowCombat.after(fn) : fn tout de suite hors combat ; en combat, avis puis fn à la sortie, après la
--     réouverture (ouverture d'une page + fiche : mini-suivi, fenêtre des étapes, toast de zone)
-- PLAYER_REGEN_DISABLED : fenêtre ouverte cachée, page et fiche mémorisées (ns.CombatReopen) ;
-- PLAYER_REGEN_ENABLED : rouverte (MainFrame.show, QuestDetail/SourceDetail.reopen). Fermée à la main avant le
-- combat : pas de réouverture.

local _, ns = ...

local L = ns.L

local WindowCombat = {}
ns.WindowCombat = WindowCombat

local state = ns.CombatReopen.new()
local deferred = {}

function WindowCombat.request(tab)
    if state:request(tab) then
        print(L.WINDOW_AFTER_COMBAT)
    end
end

function WindowCombat.after(fn)
    if InCombatLockdown() then
        WindowCombat.request(nil)
        deferred[#deferred + 1] = fn
    else
        fn()
    end
end

local function openDetail()
    if ns.QuestDetail.isShown() then
        return "quest"
    elseif ns.SourceDetail.isShown() then
        return "source"
    end
    return nil
end

local DETAILS = { quest = "QuestDetail", source = "SourceDetail" }

local function leave()
    local plan = state:leave()
    if plan then
        ns.MainFrame.show(plan.tab)
        local detail = plan.detail and ns[DETAILS[plan.detail]]
        if detail then
            detail.reopen()
        end
    end
    local queue = deferred
    deferred = {}
    for _, fn in ipairs(queue) do
        fn()
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        leave()
    elseif state:enter(ns.MainFrame.isShown(), ns.MainFrame.page(), openDetail()) then
        ns.MainFrame.hide()
    end
end)
