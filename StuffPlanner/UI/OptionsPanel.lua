-- CONTRAT
-- Panneau de réglages dans Échap > Options > AddOns (ns.Compat.RegisterOptionsPanel).
-- Charger après OptionsWidgets.lua, MainFrame.lua, Hud.lua, Arrow.lua et Onboarding.lua.
--   ns.OptionsPanel.open() -> ouvre le panneau (hors combat) ; la fenêtre principale reste ouverte, passée
--     sous le panneau du client (MainFrame.setBehind) jusqu'à sa fermeture (Compat.OnOptionsClosed)
-- Contenu construit au premier affichage, dans un cadre défilant ; contrôles relus à chaque affichage
-- et sur SP_OPTION_CHANGED (commandes /splan pris en compte). Habillage (window.skin) : appliqué au
-- rechargement, bouton « Recharger l'interface ». Sections : Fenêtre, Cadre flottant (modes, note), Sur
-- les objets (info-bulles, pastilles, halo, jet), Carte et flèche, Parcours, Partage (note).
-- « Réinitialiser les positions » : fenêtre, cadre flottant, flèche. Commandes : /splan options, /splan config.

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
    ns.Hud.resetPosition()
    ns.Arrow.resetPosition()
end

local function reload()
    if not InCombatLockdown() then
        ReloadUI()
    end
end

local function welcome()
    ns:RunOutOfCombat(ns.Onboarding.show)
end

local function windowSection(W)
    return {
        W.header(nil, L.OPTIONS_SECTION_WINDOW),
        W.slider(nil, "window.scale", labelOf("window.scale"), decimal),
        W.slider(nil, "window.alpha", labelOf("window.alpha"), percent),
        W.choice(nil, "window.skin", labelOf("window.skin"), {
            { "notebook", L.OPTIONS_SKIN_NOTEBOOK },
            { "blizzard", L.OPTIONS_SKIN_BLIZZARD },
        }),
        W.button(nil, L.OPTIONS_RELOAD, reload),
        W.checkbox(nil, "minimap.shown", labelOf("minimap.shown")),
        W.button(nil, L.OPTIONS_RESET_POSITIONS, resetPositions),
        W.button(nil, L.OPTIONS_WELCOME, welcome),
    }
end

local function hudSection(W)
    return {
        W.header(nil, L.OPTIONS_SECTION_TRACKER),
        W.note(nil, L.OPTIONS_HUD_NOTE),
        W.checkbox(nil, "dungeon.panel", labelOf("dungeon.panel")),
        W.checkbox(nil, "follow.window", labelOf("follow.window")),
        W.checkbox(nil, "tracker.shown", labelOf("tracker.shown")),
        W.slider(nil, "hud.lines", labelOf("hud.lines"), integer),
        W.slider(nil, "hud.alpha", labelOf("hud.alpha"), percent),
        W.checkbox(nil, "hud.locked", labelOf("hud.locked")),
        W.checkbox(nil, "toast.zone", labelOf("toast.zone")),
    }
end

local function itemsSection(W)
    return {
        W.header(nil, L.OPTIONS_SECTION_ITEMS),
        W.checkbox(nil, "tooltip.enabled", labelOf("tooltip.enabled")),
        W.checkbox(nil, "tooltip.alts", labelOf("tooltip.alts")),
        W.checkbox(nil, "badges.bags", labelOf("badges.bags")),
        W.checkbox(nil, "badges.merchant", labelOf("badges.merchant")),
        W.checkbox(nil, "badges.auction", labelOf("badges.auction")),
        W.checkbox(nil, "questHint.enabled", labelOf("questHint.enabled")),
        W.checkbox(nil, "roll.hint", labelOf("roll.hint")),
    }
end

local function mapSection(W)
    return {
        W.header(nil, L.OPTIONS_SECTION_MAP),
        W.checkbox(nil, "pins.world", labelOf("pins.world")),
        W.checkbox(nil, "pins.minimap", labelOf("pins.minimap")),
        W.slider(nil, "pins.worldScale", labelOf("pins.worldScale"), percent),
        W.slider(nil, "pins.minimapScale", labelOf("pins.minimapScale"), percent),
        W.checkbox(nil, "arrow.enabled", labelOf("arrow.enabled")),
        W.checkbox(nil, "arrow.locked", labelOf("arrow.locked")),
        W.checkbox(nil, "waypoint.preferTomTom", labelOf("waypoint.preferTomTom")),
        W.slider(nil, "arrow.scale", labelOf("arrow.scale"), decimal),
        W.slider(nil, "arrow.arrival", labelOf("arrow.arrival"), yards),
        W.choice(nil, "arrow.color", labelOf("arrow.color"), {
            { "direction", L.OPTIONS_COLOR_DIRECTION },
            { "gold", L.OPTIONS_COLOR_GOLD },
        }),
    }
end

local function layout()
    local W = ns.OptionsWidgets
    local list = {}
    local sections = { windowSection(W), hudSection(W), itemsSection(W), mapSection(W), {
        W.header(nil, L.OPTIONS_SECTION_PLANNER),
        W.checkbox(nil, "planner.calibrate", labelOf("planner.calibrate")),
        W.header(nil, L.OPTIONS_SECTION_SHARE),
        W.note(nil, L.OPTIONS_SHARE_NOTE),
        W.checkbox(nil, "share.enabled", labelOf("share.enabled")),
    } }
    for _, section in ipairs(sections) do
        for _, widget in ipairs(section) do
            list[#list + 1] = widget
        end
    end
    return list
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
    ns.MainFrame.setBehind(true)
end)

handle = ns.Compat.RegisterOptionsPanel(panel, L.WINDOW_TITLE)
ns.Compat.OnOptionsClosed(handle, function()
    ns.MainFrame.setBehind(false)
end)

function OptionsPanel.open()
    ns:RunOutOfCombat(function()
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
