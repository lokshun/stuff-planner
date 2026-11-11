-- CONTRAT
-- Panneau de réglages dans Échap > Options > AddOns (ns.Compat.RegisterOptionsPanel).
-- Charger après OptionsWidgets.lua, MainFrame.lua, MiniTracker.lua, FollowWindow.lua, Arrow.lua et
-- Onboarding.lua.
--   ns.OptionsPanel.open() -> ouvre le panneau (hors combat ; fenêtre principale cachée)
-- Contenu construit au premier affichage, dans un cadre défilant ; contrôles relus à chaque affichage
-- et sur SP_OPTION_CHANGED (commandes /splan pris en compte). Sections : fenêtre, info-bulles,
-- mini-suivi, carte, flèche et repère, suivi de suite de quêtes. Commandes : /splan options, /splan config.

local _, ns = ...

local L = ns.L

local OptionsPanel = {}
ns.OptionsPanel = OptionsPanel

local PAD = 16

local panel = CreateFrame("Frame")
local handle
local widgets = {}

local function percent(value)
    return L.OPTIONS_PERCENT:format(ns.Format.number(value * 100))
end

local function decimal(value)
    return ns.Format.number(value, nil, 2)
end

local function integer(value)
    return ns.Format.number(value)
end

local function yards(value)
    return L.ARROW_DISTANCE:format(ns.Format.number(value))
end

local function labelOf(key)
    return L["OPTION_" .. key:gsub("%.", "_"):upper()]
end

local function resetPositions()
    ns.MainFrame.resetPosition()
    ns.MiniTracker.resetPosition()
    ns.Arrow.resetPosition()
    ns.FollowWindow.resetPosition()
end

local function welcome()
    ns:RunOutOfCombat(ns.Onboarding.show)
end

local function layout()
    local W = ns.OptionsWidgets
    return {
        W.header(nil, L.OPTIONS_SECTION_WINDOW),
        W.slider(nil, "window.scale", labelOf("window.scale"), decimal),
        W.slider(nil, "window.alpha", labelOf("window.alpha"), percent),
        W.checkbox(nil, "minimap.shown", labelOf("minimap.shown")),
        W.button(nil, L.OPTIONS_RESET_POSITIONS, resetPositions),
        W.button(nil, L.OPTIONS_WELCOME, welcome),
        W.header(nil, L.OPTIONS_SECTION_TOOLTIP),
        W.checkbox(nil, "tooltip.enabled", labelOf("tooltip.enabled")),
        W.checkbox(nil, "questHint.enabled", labelOf("questHint.enabled")),
        W.header(nil, L.OPTIONS_SECTION_BADGES),
        W.checkbox(nil, "badges.bags", labelOf("badges.bags")),
        W.checkbox(nil, "badges.merchant", labelOf("badges.merchant")),
        W.header(nil, L.OPTIONS_SECTION_TRACKER),
        W.checkbox(nil, "tracker.shown", labelOf("tracker.shown")),
        W.checkbox(nil, "tracker.locked", labelOf("tracker.locked")),
        W.slider(nil, "tracker.lines", labelOf("tracker.lines"), integer),
        W.slider(nil, "tracker.alpha", labelOf("tracker.alpha"), percent),
        W.header(nil, L.OPTIONS_SECTION_MAP),
        W.checkbox(nil, "pins.world", labelOf("pins.world")),
        W.checkbox(nil, "pins.minimap", labelOf("pins.minimap")),
        W.slider(nil, "pins.worldScale", labelOf("pins.worldScale"), percent),
        W.slider(nil, "pins.minimapScale", labelOf("pins.minimapScale"), percent),
        W.header(nil, L.OPTIONS_SECTION_ARROW),
        W.checkbox(nil, "arrow.enabled", labelOf("arrow.enabled")),
        W.checkbox(nil, "arrow.locked", labelOf("arrow.locked")),
        W.checkbox(nil, "waypoint.preferTomTom", labelOf("waypoint.preferTomTom")),
        W.slider(nil, "arrow.scale", labelOf("arrow.scale"), decimal),
        W.slider(nil, "arrow.arrival", labelOf("arrow.arrival"), yards),
        W.choice(nil, "arrow.color", labelOf("arrow.color"), {
            { "direction", L.OPTIONS_COLOR_DIRECTION },
            { "gold", L.OPTIONS_COLOR_GOLD },
        }),
        W.header(nil, L.OPTIONS_SECTION_FOLLOW),
        W.checkbox(nil, "follow.window", labelOf("follow.window")),
        W.checkbox(nil, "follow.locked", labelOf("follow.locked")),
        W.header(nil, L.OPTIONS_SECTION_PLANNER),
        W.checkbox(nil, "planner.calibrate", labelOf("planner.calibrate")),
    }
end

local function build()
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", PAD, -PAD)
    scroll:SetPoint("BOTTOMRIGHT", -PAD - 24, PAD)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(540)
    scroll:SetScrollChild(content)
    local title = content:CreateFontString(nil, "OVERLAY", ns.Theme.fonts.title)
    title:SetPoint("TOPLEFT")
    title:SetText(L.WINDOW_TITLE)
    local y = -32
    for _, widget in ipairs(layout()) do
        widget:SetParent(content)
        widget:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        y = y - widget.height
        widgets[#widgets + 1] = widget
    end
    content:SetHeight(-y + PAD)
end

local function refreshAll()
    for _, widget in ipairs(widgets) do
        widget.refresh()
    end
end

panel:SetScript("OnShow", function()
    if #widgets == 0 then
        build()
    end
    refreshAll()
end)

handle = ns.Compat.RegisterOptionsPanel(panel, L.WINDOW_TITLE)

function OptionsPanel.open()
    ns:RunOutOfCombat(function()
        ns.MainFrame.hide()
        if not ns.Compat.OpenOptionsPanel(handle) then
            print(L.OPTIONS_UNAVAILABLE)
        end
    end)
end

ns:On("SP_OPTION_CHANGED", function()
    if panel:IsShown() then
        refreshAll()
    end
end)

ns:RegisterCommand("options", OptionsPanel.open, "OPTIONS_COMMAND_HELP")
ns:RegisterCommand("config", OptionsPanel.open, "OPTIONS_COMMAND_HELP")
