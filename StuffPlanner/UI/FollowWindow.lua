-- CONTRAT
-- Mode « suivi » du cadre flottant (ns.Hud) : étapes de la suite suivie (ns.Follow), contenu par
-- FollowPresenter. Charger après Hud.lua, Follow.lua, FollowPresenter.lua, QuestDetail.lua et MainFrame.lua.
-- Disponible tant qu'une suite est suivie et que follow.window est vrai (priorité 2) ; rafraîchi sur
-- SP_FOLLOW_CHANGED, SP_FOLLOW_UPDATED, SP_OPTION_CHANGED (follow.*) et à l'arrivée des noms.
-- Bouton du cadre : croix = Follow.stop. Clic sur une étape placée : Follow.aim + carte du monde sur sa zone ;
-- clic sur une quête : fiche de la quête (QuestDetail). Lignes à partir de la quête de l'étape courante.
--   ns.FollowWindow.resetPosition() -> position du cadre flottant par défaut

local _, ns = ...

local L = ns.L
local hint, hideTooltip = ns.FloatingFrame.hint, ns.FloatingFrame.hideHint

local LINE_HEIGHT = 16
local ICON_SIZE = 14
local INDENT = 12
local MAX_LINES = 14
local CLOSE_ICON = "Interface\\Buttons\\UI-StopButton"

local FollowWindow = {}
ns.FollowWindow = FollowWindow

local target
local lines = {}

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

local function createLine(parent, index)
    local theme = ns.Theme
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(LINE_HEIGHT)
    button:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 0, -(index - 1) * LINE_HEIGHT - 2)
    button:SetPoint("RIGHT", parent, "RIGHT")
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
    ns.Hud.draggable(button)
    return button
end

local function create(parent)
    local theme = ns.Theme
    local frame = CreateFrame("Frame", nil, parent)
    target = frame:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    target:SetPoint("TOPLEFT")
    target:SetPoint("RIGHT")
    target:SetJustifyH("LEFT")
    target:SetWordWrap(false)
    for index = 1, MAX_LINES do
        lines[index] = createLine(frame, index)
    end
    return frame
end

local askName = ns.NameAsker.new(function()
    ns.Hud.refresh()
end)

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

local function render()
    local ctx = { mapID = ns.Compat.PlayerMapPosition(), objective = ns.Follow.objective,
        player = ns.Results.player(), profile = ns.Profiles.active() }
    local out = ns.FollowPresenter.build(ns.Follow.view(), ns.Data, ctx)
    askName("quest", ns.Follow.current())
    target:SetText(targetText(out.target))
    local shown = 0
    for index, button in ipairs(lines) do
        local line = out.lines[out.first + index - 1]
        renderLine(button, line)
        shown = line and index or shown
    end
    return out.title, target:GetStringHeight() + shown * LINE_HEIGHT + 2
end

ns.Hud.addMode("follow", {
    order = 2,
    available = function()
        return ns.Follow.view() ~= nil and ns.Options.get("follow.window")
    end,
    create = create,
    render = render,
    action = { icon = CLOSE_ICON, hint = L.FOLLOW_CLOSE_HINT, onClick = function() ns.Follow.stop() end },
})

function FollowWindow.resetPosition()
    ns.Hud.resetPosition()
end

ns:On("SP_FOLLOW_CHANGED", ns.Hud.refresh)
ns:On("SP_FOLLOW_UPDATED", ns.Hud.refresh)
ns:On("SP_OPTION_CHANGED", function(key)
    if key:match("^follow%.") then
        ns.Hud.refresh()
    end
end)
