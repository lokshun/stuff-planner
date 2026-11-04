-- CONTRAT
-- Bouton de la minicarte : lanceur LibDataBroker-1.1 affiché par LibDBIcon-1.0 (embarquées).
-- Charger après MainFrame.lua et OptionsPanel.lua.
-- Clic gauche : fenêtre principale (MainFrame.toggle) ; clic droit : réglages (OptionsPanel.open).
-- Enregistré à PLAYER_LOGIN ; position et drapeau `hide` dans StuffPlannerDB.ui.minimap (format
-- LibDBIcon, partagé avec le réglage minimap.shown) ; SP_OPTION_CHANGED : Show / Hide.
-- Sans l'une des bibliothèques : rien.

local ADDON, ns = ...

local L = ns.L

local ICON = ns.ICON -- logo de l'addon

local function libraries()
    if not LibStub then
        return nil
    end
    local broker, icon = LibStub("LibDataBroker-1.1", true), LibStub("LibDBIcon-1.0", true)
    if broker and icon then
        return broker, icon
    end
    return nil
end

local function onClick(_, button)
    if button == "RightButton" then
        ns.OptionsPanel.open()
    else
        ns:RunOutOfCombat(ns.MainFrame.toggle)
    end
end

local function onTooltip(tooltip)
    tooltip:AddLine(L.WINDOW_TITLE)
    tooltip:AddLine(L.MINIMAP_HINT, 0.8, 0.8, 0.8)
end

local function register()
    local broker, icon = libraries()
    if not broker then
        return
    end
    StuffPlannerDB = StuffPlannerDB or {}
    StuffPlannerDB.ui = StuffPlannerDB.ui or {}
    StuffPlannerDB.ui.minimap = StuffPlannerDB.ui.minimap or {}
    local launcher = broker:NewDataObject(ADDON, {
        type = "launcher",
        text = L.WINDOW_TITLE,
        icon = ICON,
        OnClick = onClick,
        OnTooltipShow = onTooltip,
    })
    icon:Register(ADDON, launcher, StuffPlannerDB.ui.minimap)
end

ns:On("SP_OPTION_CHANGED", function(key, value)
    local _, icon = libraries()
    if key ~= "minimap.shown" or not icon then
        return
    end
    if value then
        icon:Show(ADDON)
    else
        icon:Hide(ADDON)
    end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", register)
