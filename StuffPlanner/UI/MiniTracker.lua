-- CONTRAT
-- Mini-suivi : les meilleures améliorations de la zone (TrackerPresenter), à l'écran en permanence.
-- Charger après Chat.lua, TrackerPresenter.lua et MainFrame.lua.
-- Créé à PLAYER_LOGIN (variables sauvegardées lues) ; rafraîchi sur SP_RESULTS_UPDATED
-- (Results) et à l'arrivée des noms ; jamais en combat (reporté à la sortie).
-- Déplaçable à la souris (clic gauche maintenu) ; clic sur une ligne : fiche de la quête
-- (QuestDetail, sur l'onglet Zone actuelle, ligne de l'objet encadrée et amenée en vue : RowActions.select) ;
-- tout clic sélectionne l'objet ; Maj+clic : repère vers le donneur ;
-- Ctrl+clic : essayage (Compat.DressUpItem) ; survol : info-bulle de l'objet (stats, gain), quête,
-- état (journal, niveau, prérequis), badge « non confirmé ». /splan tracker affiche ou masque.
-- Sauvegarde : StuffPlannerDB.ui.tracker = {point, relativePoint, x, y} ; réglages par ns.Options :
-- tracker.shown, tracker.lines (1-5), tracker.locked (pas de glisser), tracker.alpha (fond).
--   ns.MiniTracker.resetPosition() -> position par défaut

local _, ns = ...

local L = ns.L

local WIDTH = 240
local LINE_HEIGHT = 20
local ICON_SIZE = 16
local MAX_LINES = 5
local NAME_DELAY = 0.2
local UNKNOWN_ICON = 134400

local MiniTracker = {}
ns.MiniTracker = MiniTracker

local frame, title, emptyText, background
local buttons = {}
local asked, refreshPending, combatPending = {}, false, false

local function settings()
    return ns.DB.account("ui", "tracker")
end

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

local function startMoving()
    if not ns.Options.get("tracker.locked") then
        frame:StartMoving()
    end
end

local function stopMoving()
    frame:StopMovingOrSizing()
    local point, _, relativePoint, x, y = frame:GetPoint()
    local saved = settings()
    saved.point, saved.relativePoint, saved.x, saved.y = point, relativePoint, x, y
end

local function draggable(region)
    region:RegisterForDrag("LeftButton")
    region:SetScript("OnDragStart", startMoving)
    region:SetScript("OnDragStop", stopMoving)
end

local function showTooltip(button)
    local row = button.row
    if not row then
        return
    end
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetHyperlink("item:" .. row.itemID)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(row.sourceText, 1, 1, 1)
    if row.stateText ~= "" then
        GameTooltip:AddLine(row.stateText, row.stateColor.r, row.stateColor.g, row.stateColor.b)
    end
    if row.badge then
        GameTooltip:AddLine(row.badge, row.badgeColor.r, row.badgeColor.g, row.badgeColor.b)
    end
    GameTooltip:AddLine(L.ROW_CLICK_HINT, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function hideTooltip()
    GameTooltip:Hide()
end

local function onLineClick(button)
    local row = button.row
    if not row then
        return
    end
    if IsControlKeyDown() or IsShiftKeyDown() then
        ns.RowActions.select(row.questID, row.itemID)
        if IsControlKeyDown() then
            ns.Compat.DressUpItem(row.itemID)
        else
            ns.QuestDetail.waypoint(row.questID)
        end
        return
    end
    ns:RunOutOfCombat(function()
        ns.MainFrame.show("zone")
        ns.QuestDetail.show(row.questID)
        ns.RowActions.select(row.questID, row.itemID, true)
    end)
end

local function createLine(index)
    local theme = ns.Theme
    local button = CreateFrame("Button", nil, frame)
    button:SetHeight(LINE_HEIGHT)
    button:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -(index - 1) * LINE_HEIGHT - 2)
    button:SetPoint("RIGHT", frame, "RIGHT", -theme.spacing.gap, 0)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(ICON_SIZE, ICON_SIZE)
    button.icon:SetPoint("LEFT")
    button.gain = button:CreateFontString(nil, "OVERLAY", theme.fonts.number)
    button.gain:SetPoint("RIGHT")
    button.name = button:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    button.name:SetPoint("LEFT", button.icon, "RIGHT", theme.spacing.gap, 0)
    button.name:SetPoint("RIGHT", button.gain, "LEFT", -theme.spacing.gap, 0)
    button.name:SetJustifyH("LEFT")
    button.name:SetWordWrap(false)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)
    button:SetScript("OnClick", onLineClick)
    button:SetScript("OnEnter", showTooltip)
    button:SetScript("OnLeave", hideTooltip)
    draggable(button)
    return button
end

local function border(color)
    local size = ns.Theme.spacing.border
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" } }) do
        local line = frame:CreateTexture(nil, "BORDER")
        line:SetColorTexture(color.r, color.g, color.b, 0.8)
        line:SetHeight(size)
        line:SetPoint(side[1])
        line:SetPoint(side[2])
    end
end

local function restorePosition()
    local saved = settings()
    frame:ClearAllPoints()
    if saved.point then
        frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
    else
        frame:SetPoint("RIGHT", UIParent, "RIGHT", -80, 120)
    end
end

local function applyOptions()
    local bg = ns.Theme.colors.background
    background:SetColorTexture(bg.r, bg.g, bg.b, ns.Options.get("tracker.alpha"))
    frame:SetHeight(2 * ns.Theme.spacing.gap + 16 + ns.Options.get("tracker.lines") * LINE_HEIGHT)
    frame:SetShown(ns.Options.get("tracker.shown"))
end

local function create()
    local theme = ns.Theme
    local pad = theme.spacing.gap
    frame = CreateFrame("Frame", nil, UIParent)
    frame:SetWidth(WIDTH)
    frame:SetFrameStrata("LOW")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    draggable(frame)
    background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    border(theme.colors.border)
    title = frame:CreateFontString(nil, "OVERLAY", theme.fonts.header)
    title:SetPoint("TOPLEFT", pad, -pad)
    title:SetText(L.TRACKER_TITLE)
    setColor(title, theme.colors.title)
    for index = 1, MAX_LINES do
        buttons[index] = createLine(index)
    end
    emptyText = frame:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    emptyText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    emptyText:SetPoint("RIGHT", frame, "RIGHT", -pad, 0)
    emptyText:SetJustifyH("LEFT")
    setColor(emptyText, theme.colors.muted)
    restorePosition()
    applyOptions()
end

local refresh

local function scheduleRefresh()
    if refreshPending then
        return
    end
    refreshPending = true
    C_Timer.After(NAME_DELAY, function()
        refreshPending = false
        refresh()
    end)
end

local function askName(kind, id)
    local key = kind .. id
    if not asked[key] then
        asked[key] = true
        ns.Names.onReady(kind, id, scheduleRefresh)
    end
end

local function render(view)
    for index, button in ipairs(buttons) do
        local row = view.lines[index]
        button.row = row
        if row then
            askName("item", row.itemID)
            askName("quest", row.questID)
            button.icon:SetTexture(row.icon or UNKNOWN_ICON)
            button.name:SetText(row.name)
            setColor(button.name, row.nameColor)
            button.gain:SetText(row.gainLabel)
            setColor(button.gain, row.gainColor)
            button:SetAlpha(row.dimmed and 0.5 or 1)
        end
        button:SetShown(row ~= nil)
    end
    emptyText:SetText(view.empty or "")
end

refresh = function()
    if not frame or not frame:IsShown() then
        return
    end
    if InCombatLockdown() then
        if not combatPending then
            combatPending = true
            ns:RunOutOfCombat(function()
                combatPending = false
                refresh()
            end)
        end
        return
    end
    local results, mapID = ns.Chat.currentZone()
    local message = not results and mapID or nil
    render(ns.TrackerPresenter.build(results, ns.Data, message, ns.Options.get("tracker.lines")))
end

local function toggle()
    ns.Options.toggle("tracker.shown")
end

function MiniTracker.resetPosition()
    local saved = settings()
    saved.point, saved.relativePoint, saved.x, saved.y = nil, nil, nil, nil
    if frame then
        restorePosition()
    end
end

ns:On("SP_OPTION_CHANGED", function(key)
    if frame and key:match("^tracker%.") then
        applyOptions()
        refresh()
    end
end)

ns:RegisterCommand("tracker", toggle, "TRACKER_COMMAND_HELP")

ns:On("SP_RESULTS_UPDATED", function()
    refresh()
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
    create()
    refresh()
end)
