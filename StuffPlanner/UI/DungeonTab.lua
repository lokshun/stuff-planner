-- CONTRAT
-- Page « Donjons » (clé dungeon) : préparation hors instance. Liste des instances qui améliorent le
-- personnage (InstanceListPresenter.list, gain espéré du passage, raids compris), clic = détail : boss dans
-- l'ordre et leurs objets utiles (DungeonPresenter.build, boss tués de DungeonRun), bouton retour.
-- Instance courante (CompatInstance.current) en tête de liste et ouverte d'office à l'entrée.
-- Charger après MainFrame.lua, ItemRow.lua, DungeonPresenter.lua, InstanceListPresenter.lua, DungeonRun.lua.
-- S'inscrit par ns.MainFrame.addTab("dungeon", …) ; rafraîchi sur SP_RESULTS_UPDATED et SP_DUNGEON_CHANGED.
-- Lignes ns.ItemRow : instance (icône clé / dragon), en-tête de boss (« · Boss » doré, « · Rare » argenté, sans
-- icône ; clic = boss tué / pas tué, DungeonRun.toggle), objet (clic = fiche de la source, RowActions.click ;
-- clic droit = menu : fiche, épingler, essayer).

local _, ns = ...

local L = ns.L

local DUNGEON_ICON = "Interface\\Icons\\INV_Misc_Key_03"
local RAID_ICON = "Interface\\Icons\\INV_Misc_Head_Dragon_01"

local header, back, scrollBox, emptyText
local openID, lastCurrent

local askName = ns.NameAsker.new(function()
    ns.MainFrame.refresh()
end)

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

local function onRowClick(button)
    local row = button.row
    if row and row.instanceID then
        openID = row.instanceID
        ns.MainFrame.refresh()
    elseif row and row.header then
        if row.npcID then
            ns.DungeonRun.toggle(row.npcID)
        end
    elseif row and row.itemID then
        ns.RowActions.click(nil, row.itemID, row.itemSource)
    end
end

local ROW_OPTS = { onClick = onRowClick }

local function initRow(button, row)
    if not button.icon then
        ns.ItemRow.build(button, ROW_OPTS)
    end
    local theme = ns.Theme
    if row.header then
        ns.ItemRow.set(button, { row = row, name = row.text, gain = row.gain, gainColor = theme.colors.muted,
            nameColor = row.killed and theme.colors.muted or row.rare and theme.colors.neutral or theme.colors.title })
    elseif row.instanceID then
        ns.ItemRow.set(button, { row = row, icon = row.raid and RAID_ICON or DUNGEON_ICON, name = row.name,
            nameColor = row.current and theme.colors.gain or theme.colors.text, detail = row.detail,
            gain = row.gain, gainColor = row.gainColor, dimmed = row.dimmed })
    else
        ns.ItemRow.set(button, { row = row, itemID = row.itemID, itemSource = row.itemSource, icon = row.icon,
            name = row.name,
            nameColor = row.nameColor, detail = row.detail, gain = row.gain, gainColor = row.gainColor })
    end
    button.icon:SetShown(not row.header)
end

local function detailRows(instanceID)
    local view = ns.DungeonPresenter.build(instanceID, ns.Data, ns.Results.delta, ns.DungeonRun.killed())
    for _, boss in ipairs(view.bosses) do
        askName("npc", boss.npcID)
    end
    local rows = ns.InstanceListPresenter.detail(view, ns.Data)
    for _, row in ipairs(rows) do
        if row.itemID then
            askName("item", row.itemID)
        end
    end
    return rows, L.DUNGEON_EXPECTED:format("+" .. ns.Format.number(view.expected, nil, 1))
end

local function refresh()
    if not ns.Data.ready() then
        header:SetText(L.BEST_NOT_READY)
        back:Hide()
        scrollBox:SetDataProvider(CreateDataProvider({}))
        emptyText:SetText("")
        return
    end
    local current = ns.CompatInstance.current()
    if current ~= lastCurrent then
        lastCurrent = current
        openID = current or openID
    end
    local rows, title
    if openID then
        local summary
        rows, summary = detailRows(openID)
        title = ns.Names.instance(openID) .. " · " .. summary
    else
        local player = ns.Results.player()
        rows = ns.InstanceListPresenter.list(ns.Data, ns.Results.delta, current, player and player.level)
        title = L.DUNGEON_PAGE_HINT
    end
    back:SetShown(openID ~= nil)
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", openID and back or header:GetParent(), openID and "TOPRIGHT" or "TOPLEFT",
        openID and ns.Theme.spacing.gap or 0, 0)
    header:SetPoint("RIGHT")
    header:SetText(title)
    scrollBox:SetDataProvider(CreateDataProvider(rows))
    emptyText:SetText(#rows == 0 and L.DUNGEON_NONE or "")
end

local function create(parent)
    local theme = ns.Theme
    local panel = CreateFrame("Frame", nil, parent)
    back = ns.Skin.button(panel)
    back:SetText(L.DUNGEON_BACK)
    back:SetSize(back:GetFontString():GetStringWidth() + 20, 20)
    back:SetPoint("TOPLEFT")
    back:SetScript("OnClick", function()
        openID = nil
        ns.MainFrame.refresh()
    end)
    header = panel:CreateFontString(nil, "OVERLAY", theme.fonts.header)
    header:SetHeight(20)
    header:SetJustifyH("LEFT")
    header:SetWordWrap(false)
    scrollBox = CreateFrame("Frame", nil, panel, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", 0, -20 - theme.spacing.gap)
    scrollBox:SetPoint("BOTTOMRIGHT", -20, 0)
    local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(theme.spacing.rowHeight)
    view:SetElementInitializer("Button", initRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    emptyText = panel:CreateFontString(nil, "OVERLAY", theme.fonts.body)
    emptyText:SetPoint("CENTER", scrollBox, "CENTER")
    setColor(emptyText, theme.colors.muted)
    return panel
end

ns.MainFrame.addTab("dungeon", {
    create = create, refresh = refresh, order = 2.5, label = L.TAB_DUNGEON, icon = DUNGEON_ICON,
})

ns:On("SP_DUNGEON_CHANGED", ns.MainFrame.refresh)

ns:On("SP_SELECTION_CHANGED", function()
    if scrollBox then
        scrollBox:ForEachFrame(function(button)
            ns.RowActions.mark(button, button.questID, button.itemID)
        end)
    end
end)
