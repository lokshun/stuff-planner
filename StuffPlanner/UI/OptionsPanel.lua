-- CONTRAT
-- Panneau de réglages dans Échap > Options > AddOns (ns.Compat.RegisterOptionsPanel).
-- Charger après OptionsWidgets.lua, OptionsLayout.lua, MainFrame.lua, Hud.lua, Arrow.lua et Onboarding.lua.
--   ns.OptionsPanel.open() -> ouvre le panneau (hors combat) ; la fenêtre principale reste ouverte, passée
--     sous le panneau du client (MainFrame.setBehind) jusqu'à sa fermeture (Compat.OnOptionsClosed)
-- Contenu construit au premier affichage d'après ns.OptionsLayout (sections, info-bulles), dans un cadre
-- défilant ; contrôles relus et lignes replacées à chaque affichage et sur SP_OPTION_CHANGED (commandes
-- /splan prises en compte). « Recharger l'interface » montré seulement si ns.Skin.pending().
-- « Réinitialiser les positions » : fenêtre, cadre flottant, flèche. « Valeurs par défaut » (en bas) : deux
-- clics (armé, puis Options.reset de chaque Options.keys()) ; désarmé en quittant le bouton.
-- Commandes : /splan options, /splan config.

local _, ns = ...

local L = ns.L

local OptionsPanel = {}
ns.OptionsPanel = OptionsPanel

local PAD = 16

local panel = CreateFrame("Frame")
local handle, content
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

local FORMATS = { percent = percent, decimal = decimal, integer = integer, yards = yards }
local CONDITIONS = {
    skinPending = function()
        return ns.Skin.pending()
    end,
}
local SECTION_GAP = 8

local function resetPositions()
    ns.MainFrame.resetPosition()
    ns.Hud.resetPosition()
    ns.Arrow.resetPosition()
end

local defaultsButton
local armed = false

local function disarm()
    armed = false
    if defaultsButton then
        defaultsButton:SetText(L.OPTIONS_DEFAULTS)
    end
end

local function resetDefaults()
    if not armed then
        armed = true
        defaultsButton:SetText(L.OPTIONS_DEFAULTS_CONFIRM)
        return
    end
    disarm()
    for _, key in ipairs(ns.Options.keys()) do
        ns.Options.reset(key)
    end
end

local ACTIONS = {
    reload = function()
        if not InCombatLockdown() then
            ReloadUI()
        end
    end,
    resetPositions = resetPositions,
    welcome = function()
        ns:RunOutOfCombat(ns.Onboarding.show)
    end,
    defaults = resetDefaults,
}

local function widgetFor(W, row)
    local layout = ns.OptionsLayout
    if row.kind == "checkbox" then
        return W.checkbox(nil, row.key, layout.label(row.key), layout.tip(row.key))
    elseif row.kind == "slider" then
        return W.slider(nil, row.key, layout.label(row.key), FORMATS[row.format], layout.tip(row.key))
    elseif row.kind == "choice" then
        return W.choice(nil, row.key, layout.label(row.key), row.values, layout.tip(row.key))
    elseif row.kind == "note" then
        return W.note(nil, row.text)
    end
    local button = W.button(nil, row.label, ACTIONS[row.action])
    if row.action == "defaults" then
        defaultsButton = button
        button:HookScript("OnLeave", disarm)
        button.gap = SECTION_GAP * 2
    end
    return button
end

local function build()
    local W = ns.OptionsWidgets
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", PAD, -PAD)
    scroll:SetPoint("BOTTOMRIGHT", -PAD - 24, PAD)
    content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(540)
    scroll:SetScrollChild(content)
    local title = content:CreateFontString(nil, "OVERLAY", ns.Theme.fonts.title)
    title:SetPoint("TOPLEFT")
    title:SetText(L.WINDOW_TITLE)
    for index, section in ipairs(ns.OptionsLayout.sections()) do
        local header = W.header(nil, section.title)
        header.gap = index > 1 and SECTION_GAP or 0
        widgets[#widgets + 1] = header
        for _, row in ipairs(section.rows) do
            local widget = widgetFor(W, row)
            widget.when = row.when and CONDITIONS[row.when]
            widgets[#widgets + 1] = widget
        end
    end
    for _, widget in ipairs(widgets) do
        widget:SetParent(content)
    end
end

-- Lignes empilées ; une ligne à condition fausse est cachée et ne prend pas de place.
local function place()
    local y = -32
    for _, widget in ipairs(widgets) do
        local shown = not widget.when or widget.when()
        widget:SetShown(shown)
        if shown then
            y = y - (widget.gap or 0)
            widget:ClearAllPoints()
            widget:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            y = y - widget.height
        end
    end
    content:SetHeight(-y + PAD)
end

local function refreshAll()
    for _, widget in ipairs(widgets) do
        widget.refresh()
    end
    place()
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
