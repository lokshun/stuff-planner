-- CONTRAT
-- Petite fenêtre des étapes du suivi (ns.Follow), contenu par FollowPresenter.
-- Charger après FloatingFrame.lua, Follow.lua, FollowPresenter.lua, QuestDetail.lua et MainFrame.lua.
-- Affichée tant qu'une suite est suivie et que follow.window est vrai ; rafraîchie sur SP_FOLLOW_CHANGED,
-- SP_FOLLOW_UPDATED et à l'arrivée des noms ; jamais en combat (reporté à la sortie).
-- Barre de titre : clic = replier / déplier, clic gauche maintenu = déplacer (sauf follow.locked) ;
-- croix = Follow.stop. Clic sur une étape placée : Follow.aim + carte du monde sur sa zone ;
-- clic sur une quête : fiche de la quête (QuestDetail). Lignes à partir de la quête de l'étape courante.
-- Sauvegarde : StuffPlannerDB.ui.follow = {point, relativePoint, x, y, collapsed}.
--   ns.FollowWindow.resetPosition() -> position par défaut

local _, ns = ...

local L = ns.L
local hint, hideTooltip = ns.FloatingFrame.hint, ns.FloatingFrame.hideHint

local WIDTH = 260
local HEADER_HEIGHT = 20
local LINE_HEIGHT = 16
local ICON_SIZE = 14
local INDENT = 12
local MAX_LINES = 14
local NAME_DELAY = 0.2

local FollowWindow = {}
ns.FollowWindow = FollowWindow

local frame, header, titleText, target
local lines = {}
local asked, refreshPending, combatPending = {}, false, false

local function settings()
    StuffPlannerDB = StuffPlannerDB or {}
    StuffPlannerDB.ui = StuffPlannerDB.ui or {}
    StuffPlannerDB.ui.follow = StuffPlannerDB.ui.follow or {}
    return StuffPlannerDB.ui.follow
end

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

local function onLineEnter(button)
    local line = button.line
    if line and (line.kind == "quest" or line.clickable) then
        hint(button, line.kind == "quest" and L.FOLLOW_QUEST_HINT or L.FOLLOW_STEP_HINT)
    end
end

local function onLineClick(button)
    local line = button.line
    if not line then
        return
    end
    if line.kind == "quest" then
        ns:RunOutOfCombat(function()
            ns.MainFrame.show("zone")
            ns.QuestDetail.show(line.questID)
        end)
        return
    end
    local view = ns.Follow.view()
    local step = view and view.steps[line.step]
    if line.clickable and step and ns.Follow.aim(line.step) then
        ns:RunOutOfCombat(function()
            ns.Compat.OpenWorldMap(step.mapID)
        end)
    end
end

local function createLine(index)
    local theme = ns.Theme
    local button = CreateFrame("Button", nil, frame)
    button:SetHeight(LINE_HEIGHT)
    button:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 0, -(index - 1) * LINE_HEIGHT - 2)
    button:SetPoint("RIGHT", frame, "RIGHT", -theme.spacing.gap, 0)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(ICON_SIZE, ICON_SIZE)
    button.text = button:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    button.text:SetPoint("RIGHT")
    button.text:SetJustifyH("LEFT")
    button.text:SetWordWrap(false)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)
    button:SetScript("OnClick", onLineClick)
    button:SetScript("OnEnter", onLineEnter)
    button:SetScript("OnLeave", hideTooltip)
    frame.draggable(button)
    return button
end

local refresh

local function toggleCollapsed()
    local saved = settings()
    saved.collapsed = not saved.collapsed or nil
    refresh()
end

local function createHeader(theme, pad)
    header = CreateFrame("Button", nil, frame)
    header:SetHeight(HEADER_HEIGHT)
    header:SetPoint("TOPLEFT", pad, -pad / 2)
    header:SetPoint("RIGHT", frame, "RIGHT", -24, 0)
    header:SetScript("OnClick", toggleCollapsed)
    frame.draggable(header)
    titleText = header:CreateFontString(nil, "OVERLAY", theme.fonts.header)
    titleText:SetAllPoints()
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(false)
    setColor(titleText, theme.colors.title)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function()
        ns.Follow.stop()
    end)
    close:SetScript("OnEnter", function(button)
        hint(button, L.FOLLOW_CLOSE_HINT)
    end)
    close:SetScript("OnLeave", hideTooltip)
end

local function create()
    local theme = ns.Theme
    local pad = theme.spacing.gap
    frame = ns.FloatingFrame.new({ width = WIDTH, saved = settings, locked = "follow.locked", alpha = 0.75,
        default = { point = "RIGHT", x = -80, y = -60 } })
    createHeader(theme, pad)
    target = frame:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    target:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    target:SetPoint("RIGHT", frame, "RIGHT", -pad, 0)
    target:SetJustifyH("LEFT")
    target:SetWordWrap(false)
    for index = 1, MAX_LINES do
        lines[index] = createLine(index)
    end
    frame:Hide()
end

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
    if not id then
        return
    end
    local key = kind .. id
    if not asked[key] then
        asked[key] = true
        ns.Names.onReady(kind, id, scheduleRefresh)
    end
end

local function targetText(row)
    if not row then
        return ""
    end
    askName("item", row.itemID)
    return ns.Theme.colorize(row.name, row.nameColor) .. "  " .. ns.Theme.colorize(row.gainLabel, row.gainColor)
end

local function renderLine(button, line)
    button.line = line
    if not line then
        button:Hide()
        return
    end
    askName("quest", line.questID)
    local view = ns.Follow.view()
    local step = line.step and view and view.steps[line.step]
    if step and step.npcID then
        askName("npc", step.npcID)
    end
    local indent = line.kind == "step" and INDENT or 0
    button.icon:SetPoint("LEFT", indent, 0)
    button.icon:SetTexture(line.icon)
    button.icon:SetShown(line.icon ~= nil)
    button.text:SetPoint("LEFT", button.icon, "RIGHT", 2, 0)
    button.text:SetFontObject(line.kind == "quest" and ns.Theme.fonts.body or ns.Theme.fonts.small)
    button.text:SetText(line.text)
    setColor(button.text, line.color)
    button:Show()
end

local function render(out)
    titleText:SetText(out.title)
    askName("quest", ns.Follow.current())
    local collapsed = settings().collapsed
    target:SetText(targetText(out.target))
    target:SetShown(not collapsed)
    local shown = 0
    for index, button in ipairs(lines) do
        local line = not collapsed and out.lines[out.first + index - 1] or nil
        renderLine(button, line)
        shown = line and index or shown
    end
    local pad = ns.Theme.spacing.gap
    local body = collapsed and 0 or (target:GetStringHeight() + shown * LINE_HEIGHT + pad)
    frame:SetHeight(pad + HEADER_HEIGHT + body)
end

refresh = function()
    if not frame then
        return
    end
    local view = ns.Follow.view()
    if not view or not ns.Options.get("follow.window") then
        frame:Hide()
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
    local ctx = { mapID = ns.Compat.PlayerMapPosition(), objective = ns.Follow.objective,
        player = ns.Results.player(), profile = ns.Profiles.active() }
    render(ns.FollowPresenter.build(view, ns.Data, ctx))
    frame:Show()
end

function FollowWindow.resetPosition()
    if frame then
        frame.resetPosition()
    end
end

ns:On("SP_FOLLOW_CHANGED", function() refresh() end)
ns:On("SP_FOLLOW_UPDATED", function() refresh() end)
ns:On("SP_OPTION_CHANGED", function(key)
    if key:match("^follow%.") then
        refresh()
    end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
    create()
    refresh()
end)
