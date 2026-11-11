-- CONTRAT
-- Panneau de donjon (FloatingFrame) : boss de l'instance courante dans l'ordre, objets utiles de chacun
-- (gain, taux), espérance restante du passage (DungeonPresenter, boss tués de DungeonRun exclus).
-- Charger après FloatingFrame.lua, DungeonRun.lua, DungeonPresenter.lua, BadgePresenter.lua et NameAsker.lua.
-- Affiché dans une instance connue de la base, avec un profil actif, si dungeon.panel est vrai ; rafraîchi sur
-- SP_DUNGEON_CHANGED, SP_RESULTS_UPDATED, SP_OPTION_CHANGED (dungeon.*) et à l'arrivée des noms ; jamais en
-- combat (reporté à la sortie). Boss tué : coché, grisé, objets repliés.
-- Titre : clic = replier / déplier, clic droit = DungeonRun.reset, clic gauche maintenu = déplacer.
-- Clic sur un boss : DungeonRun.toggle ; survol d'un objet : info-bulle de l'objet.
-- Au plus MAX_ITEMS objets par boss et MAX_LINES lignes. Sauvegarde : StuffPlannerDB.ui.dungeon =
-- {point, relativePoint, x, y, collapsed}.
--   ns.DungeonPanel.resetPosition() -> position par défaut

local _, ns = ...

local L = ns.L
local hint, hideTooltip = ns.FloatingFrame.hint, ns.FloatingFrame.hideHint

local WIDTH = 260
local HEADER_HEIGHT = 20
local LINE_HEIGHT = 16
local ICON_SIZE = 14
local INDENT = 14
local MAX_LINES = 18
local MAX_ITEMS = 3
local CHECK_ICON = "Interface\\Buttons\\UI-CheckBox-Check"

local DungeonPanel = {}
ns.DungeonPanel = DungeonPanel

local frame, header, titleText, summary
local buttons = {}
local combatPending = false
local refresh

local function settings()
    return ns.DB.account("ui", "dungeon")
end

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

local function points(value)
    return "+" .. ns.Format.number(value, nil, value < 1 and 2 or 1)
end

local function onLineEnter(button)
    local line = button.line
    if line and line.itemID then
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetHyperlink("item:" .. line.itemID)
        GameTooltip:Show()
    elseif line and line.npcID then
        hint(button, L.DUNGEON_BOSS_HINT)
    end
end

local function onLineClick(button)
    local line = button.line
    if line and line.npcID and not line.itemID then
        ns.DungeonRun.toggle(line.npcID)
    end
end

local function createLine(index)
    local theme = ns.Theme
    local button = CreateFrame("Button", nil, frame)
    button:SetHeight(LINE_HEIGHT)
    button:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -(index - 1) * LINE_HEIGHT - 2)
    button:SetPoint("RIGHT", frame, "RIGHT", -theme.spacing.gap, 0)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(ICON_SIZE, ICON_SIZE)
    button.gain = button:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    button.gain:SetPoint("RIGHT")
    button.text = button:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    button.text:SetPoint("RIGHT", button.gain, "LEFT", -4, 0)
    button.text:SetJustifyH("LEFT")
    button.text:SetWordWrap(false)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)
    button:RegisterForClicks("LeftButtonUp")
    button:SetScript("OnClick", onLineClick)
    button:SetScript("OnEnter", onLineEnter)
    button:SetScript("OnLeave", hideTooltip)
    frame.draggable(button)
    return button
end

local function onHeaderClick(_, mouseButton)
    if mouseButton == "RightButton" then
        ns.DungeonRun.reset()
        return
    end
    local saved = settings()
    saved.collapsed = not saved.collapsed or nil
    refresh()
end

local function create()
    local theme = ns.Theme
    local pad = theme.spacing.gap
    frame = ns.FloatingFrame.new({ width = WIDTH, saved = settings, alpha = 0.75,
        default = { point = "LEFT", x = 40, y = 60 } })
    header = CreateFrame("Button", nil, frame)
    header:SetHeight(HEADER_HEIGHT)
    header:SetPoint("TOPLEFT", pad, -pad / 2)
    header:SetPoint("RIGHT", frame, "RIGHT", -pad, 0)
    header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    header:SetScript("OnClick", onHeaderClick)
    header:SetScript("OnEnter", function(button)
        hint(button, L.DUNGEON_TITLE_HINT)
    end)
    header:SetScript("OnLeave", hideTooltip)
    frame.draggable(header)
    titleText = header:CreateFontString(nil, "OVERLAY", theme.fonts.header)
    titleText:SetAllPoints()
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(false)
    setColor(titleText, theme.colors.title)
    summary = frame:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    summary:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    summary:SetPoint("RIGHT", frame, "RIGHT", -pad, 0)
    summary:SetJustifyH("LEFT")
    for index = 1, MAX_LINES do
        buttons[index] = createLine(index)
    end
    frame:Hide()
end

local askName = ns.NameAsker.new(function()
    refresh()
end)

local function itemLine(item, npcID)
    askName("item", item.itemID)
    local gain = item.pct and ns.BadgePresenter.percentText(item.pct) or points(item.abs)
    local chance = item.chance and ns.Format.percent(item.chance / 100, nil, item.chance < 1 and 1 or 0)
        or L.DUNGEON_CHANCE_UNKNOWN
    return { itemID = item.itemID, npcID = npcID, indent = INDENT, icon = ns.Names.itemIcon(item.itemID),
        text = ns.Names.item(item.itemID), gain = gain .. " · " .. chance, color = ns.Theme.colors.text,
        gainColor = ns.Theme.colors.gain }
end

local function addItems(lines, boss)
    for index = 1, math.min(#boss.items, MAX_ITEMS) do
        lines[#lines + 1] = itemLine(boss.items[index], boss.npcID)
    end
end

local function buildLines(view)
    local theme, lines = ns.Theme, {}
    for _, boss in ipairs(view.bosses) do
        askName("npc", boss.npcID)
        lines[#lines + 1] = { npcID = boss.npcID, indent = 0, icon = boss.killed and CHECK_ICON or nil,
            text = ns.Names.npc(boss.npcID), color = boss.killed and theme.colors.muted or theme.colors.title,
            gain = #boss.items > 0 and points(boss.expected) or "", gainColor = theme.colors.muted }
        if not boss.killed then
            addItems(lines, boss)
        end
    end
    if #view.trash.items > 0 then
        lines[#lines + 1] = { indent = 0, text = L.DUNGEON_TRASH, color = theme.colors.title, gain = "",
            gainColor = theme.colors.muted }
        addItems(lines, view.trash)
    end
    return lines
end

local function renderLine(button, line)
    button.line = line
    if not line then
        button:Hide()
        return
    end
    button.icon:SetPoint("LEFT", line.indent, 0)
    button.icon:SetTexture(line.icon)
    button.icon:SetShown(line.icon ~= nil)
    button.text:SetPoint("LEFT", button.icon, "RIGHT", 2, 0)
    button.text:SetText(line.text)
    setColor(button.text, line.color)
    button.gain:SetText(line.gain)
    setColor(button.gain, line.gainColor)
    button:Show()
end

local function summaryText(view)
    if #view.trash.items == 0 and view.expected == 0 and view.unknownChance == 0 then
        local any = false
        for _, boss in ipairs(view.bosses) do
            any = any or #boss.items > 0
        end
        if not any then
            return L.DUNGEON_NONE
        end
    end
    local text = L.DUNGEON_EXPECTED:format(points(view.expected))
    if view.unknownChance > 0 then
        text = text .. "  " .. L.DUNGEON_UNKNOWN:format(view.unknownChance)
    end
    return text
end

local function render(instanceID, view)
    titleText:SetText(ns.Names.instance(instanceID))
    local collapsed = settings().collapsed
    summary:SetText(summaryText(view))
    summary:SetShown(not collapsed)
    local lines = collapsed and {} or buildLines(view)
    local shown = 0
    for index, button in ipairs(buttons) do
        renderLine(button, lines[index])
        shown = lines[index] and index or shown
    end
    local pad = ns.Theme.spacing.gap
    local body = collapsed and 0 or (summary:GetStringHeight() + shown * LINE_HEIGHT + pad)
    frame:SetHeight(pad + HEADER_HEIGHT + body)
end

refresh = function()
    local instanceID = ns.DungeonRun.current()
    if not instanceID or not ns.Options.get("dungeon.panel") or not ns.Results.player() then
        if frame then
            frame:Hide()
        end
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
    if not frame then
        create()
    end
    render(instanceID, ns.DungeonPresenter.build(instanceID, ns.Data, ns.Results.delta, ns.DungeonRun.killed()))
    frame:Show()
end

function DungeonPanel.resetPosition()
    if frame then
        frame.resetPosition()
    end
end

ns:On("SP_DUNGEON_CHANGED", function() refresh() end)
ns:On("SP_RESULTS_UPDATED", function() refresh() end)
ns:On("SP_OPTION_CHANGED", function(key)
    if key:match("^dungeon%.") then
        refresh()
    end
end)
