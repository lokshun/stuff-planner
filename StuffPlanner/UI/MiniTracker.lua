-- CONTRAT
-- Mode « zone » du cadre flottant (ns.Hud) : les meilleures améliorations de la zone (TrackerPresenter).
-- Charger après Hud.lua, Chat.lua, TrackerPresenter.lua et MainFrame.lua.
-- Disponible si tracker.shown est vrai (priorité la plus basse) ; hud.lines lignes (1-5). Rafraîchi sur
-- SP_RESULTS_UPDATED, SP_OPTION_CHANGED (tracker.*, hud.lines) et à l'arrivée des noms.
-- Clic sur une ligne : fiche de la quête (QuestDetail, sur la page Maintenant, ligne de l'objet encadrée et
-- amenée en vue : RowActions.select) ; tout clic sélectionne l'objet ; Maj+clic : repère vers le donneur ;
-- Ctrl+clic : essayage (Compat.DressUpItem) ; survol : info-bulle de l'objet (stats, gain), quête,
-- état (journal, niveau, prérequis), badge « non confirmé ». /splan tracker active ou coupe le mode.

local _, ns = ...

local L = ns.L

local LINE_HEIGHT = 20
local ICON_SIZE = 16
local MAX_LINES = 5
local UNKNOWN_ICON = 134400

local MiniTracker = {}
ns.MiniTracker = MiniTracker

local emptyText
local buttons = {}

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
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
        ns.QuestDetail.show(row.questID, row.itemID)
        ns.RowActions.select(row.questID, row.itemID, true)
    end)
end

local function createLine(parent, index)
    local theme = ns.Theme
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(LINE_HEIGHT)
    button:SetPoint("TOPLEFT", 0, -(index - 1) * LINE_HEIGHT)
    button:SetPoint("RIGHT")
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
    ns.Hud.draggable(button)
    return button
end

local function create(parent)
    local theme = ns.Theme
    local frame = CreateFrame("Frame", nil, parent)
    for index = 1, MAX_LINES do
        buttons[index] = createLine(frame, index)
    end
    emptyText = frame:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    emptyText:SetPoint("TOPLEFT", 0, -2)
    emptyText:SetPoint("RIGHT")
    emptyText:SetJustifyH("LEFT")
    setColor(emptyText, theme.colors.muted)
    return frame
end

local askName = ns.NameAsker.new(function()
    ns.Hud.refresh()
end)

local function render()
    local results, mapID = ns.Chat.currentZone()
    local message = not results and mapID or nil
    local view = ns.TrackerPresenter.build(results, ns.Data, message, ns.Options.get("hud.lines"))
    local shown = 0
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
            shown = index
        end
        button:SetShown(row ~= nil)
    end
    emptyText:SetText(view.empty or "")
    local height = shown > 0 and shown * LINE_HEIGHT or emptyText:GetStringHeight() + 4
    return L.TRACKER_TITLE, height
end

ns.Hud.addMode("zone", {
    order = 3,
    available = function()
        return ns.Options.get("tracker.shown")
    end,
    create = create,
    render = render,
})

function MiniTracker.resetPosition()
    ns.Hud.resetPosition()
end

ns:RegisterCommand("tracker", function()
    ns.Options.toggle("tracker.shown")
end, "TRACKER_COMMAND_HELP")

ns:On("SP_OPTION_CHANGED", function(key)
    if key:match("^tracker%.") or key == "hud.lines" then
        ns.Hud.refresh()
    end
end)

ns:On("SP_RESULTS_UPDATED", ns.Hud.refresh)
