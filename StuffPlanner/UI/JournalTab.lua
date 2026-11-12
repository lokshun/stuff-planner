-- CONTRAT
-- Page « Journal » (clé journal) : section « Progression » (ns.HistoryChart : score par niveau, dernières
-- améliorations), section « Autres personnages » (AltListPresenter : personnages du royaume et objets
-- échangeables des sacs qui leur iraient, liste défilante). Sections repliables (ns.Section, clés ui.journalProgress
-- et ui.journalAlts, ouvertes par défaut). Charger après MainFrame.lua, Section.lua, ItemRow.lua,
-- HistoryChart.lua, AltListPresenter.lua, Alts.lua, LiveItem.lua.
-- S'inscrit par ns.MainFrame.addTab("journal", …) ; /splan journal ouvre la page (bascule si déjà affichée).
-- Affichage de la page : History.record() ; rafraîchie sur SP_HISTORY_CHANGED, SP_PROFILE_CHANGED et
-- BAG_UPDATE_DELAYED (page affichée). Objets : clic = source, clic droit = menu.

local _, ns = ...

local L = ns.L

local PROGRESS = { key = "journalProgress", open = true }
local ALTS = { key = "journalAlts", open = true }
local ROW_HEIGHT = 24
local NOTE_HEIGHT = 30
local TRADEABLE = { [0] = true, [2] = true }

local panel, progress, alts, chart, scrollBox, scrollBar, note

local askName = ns.NameAsker.new(function()
    ns.MainFrame.refresh()
end)

local function className(token)
    local names = _G.LOCALIZED_CLASS_NAMES_MALE
    return names and names[token] or token or ""
end

local function classColor(token)
    local colors = _G.RAID_CLASS_COLORS
    return colors and colors[token] or ns.Theme.colors.title
end

local ROW_OPTS = { iconSize = 18, compact = true, nameWidth = 200, gainWidth = 90 }

local function initRow(button, row)
    if not button.icon then
        ns.ItemRow.build(button, ROW_OPTS)
    end
    if row.alt then
        ns.ItemRow.set(button, { row = row, name = row.name, nameColor = classColor(row.class),
            detail = row.detail, detailColor = ns.Theme.colors.muted, gain = row.gain,
            gainColor = ns.Theme.colors.muted })
    else
        ns.ItemRow.set(button, row)
    end
    button.icon:SetShown(not row.alt)
end

local function bagItems()
    local items = {}
    ns.Compat.EachBagItem(function(link, bag, slot)
        local itemID = tonumber(link:match("item:(%d+)"))
        if itemID and TRADEABLE[ns.Compat.GetBindType(link) or -1]
            and not ns.Compat.IsContainerItemBound(bag, slot) then
            local live = ns.LiveItem.needed(itemID, link, ns.Data) and ns.LiveItem.fields(link) or nil
            local fields = live or ns.Data.item(itemID)
            if fields then
                items[#items + 1] = { itemID = itemID, fields = fields }
            end
        end
    end)
    return items
end

local function altRows()
    local view = ns.AltListPresenter.build(ns.Alts.others(), bagItems(), ns.Data, time(), className)
    for _, row in ipairs(view.rows) do
        if row.itemID then
            askName("item", row.itemID)
        end
    end
    return view.rows, view.empty or view.note
end

local function layout()
    local y = 0
    local open
    open, y = progress.place(y)
    chart:SetShown(open)
    if open then
        chart:ClearAllPoints()
        chart:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
        chart:SetPoint("RIGHT", panel, "RIGHT")
        y = y - ns.HistoryChart.refresh() - ns.Theme.spacing.gap
    end
    open, y = alts.place(y)
    scrollBox:SetShown(open)
    scrollBar:SetShown(open)
    note:SetShown(open)
    if open then
        scrollBox:ClearAllPoints()
        scrollBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
        scrollBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -20, NOTE_HEIGHT)
    end
end

local function refresh()
    if not ns.Data.ready() then
        return
    end
    layout()
    if scrollBox:IsShown() then
        local rows, message = altRows()
        scrollBox:SetDataProvider(CreateDataProvider(rows))
        note:SetText(message or "")
    end
end

local function create(parent)
    local theme = ns.Theme
    panel = CreateFrame("Frame", nil, parent)
    PROGRESS.title = L.JOURNAL_PROGRESS
    ALTS.title = L.ALTS_TITLE
    progress = ns.Section.new(panel, PROGRESS, ns.MainFrame.refresh)
    alts = ns.Section.new(panel, ALTS, ns.MainFrame.refresh)
    chart = ns.HistoryChart.create(panel)
    scrollBox = CreateFrame("Frame", nil, panel, "WowScrollBoxList")
    scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer("Button", initRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    note = panel:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    note:SetPoint("BOTTOMLEFT")
    note:SetPoint("RIGHT")
    note:SetHeight(NOTE_HEIGHT)
    note:SetJustifyH("LEFT")
    note:SetTextColor(theme.colors.muted.r, theme.colors.muted.g, theme.colors.muted.b)
    panel:SetScript("OnShow", function()
        ns.History.record()
    end)
    ns.History.record()
    return panel
end

ns.MainFrame.addTab("journal", {
    create = create, refresh = refresh, order = 5, label = L.TAB_JOURNAL,
    icon = "Interface\\Icons\\INV_Misc_Book_11",
})

ns:On("SP_HISTORY_CHANGED", ns.MainFrame.refresh)
ns:On("SP_PROFILE_CHANGED", ns.MainFrame.refresh)

local events = CreateFrame("Frame")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:SetScript("OnEvent", function()
    if panel and panel:IsVisible() then
        ns.MainFrame.refresh()
    end
end)

ns:RegisterCommand("journal", function()
    if InCombatLockdown() then
        return
    end
    if ns.MainFrame.isShown() and panel and panel:IsVisible() then
        ns.MainFrame.hide()
    else
        ns.MainFrame.show("journal")
    end
end, "JOURNAL_COMMAND_HELP")

ns:On("SP_SELECTION_CHANGED", function()
    if scrollBox then
        scrollBox:ForEachFrame(function(button)
            ns.RowActions.mark(button, button.questID, button.itemID)
        end)
    end
end)
