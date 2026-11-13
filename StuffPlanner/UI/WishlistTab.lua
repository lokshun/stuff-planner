-- CONTRAT
-- Page « Liste cible » (clé wishlist) : objets épinglés (WishlistStore), état de chacun (Wishlist.status,
-- WishlistPresenter), obtenu coché, liste défilante sans limite ; pied : champ, Importer (fusion :
-- WishlistStore.merge, aussi par Entrée), Remplacer (deux clics : armé puis confirmé, WishlistStore.replace),
-- Exporter (SPL1, WishlistIO), statut. Cadres seulement. Charger après Wishlist.lua, WishlistStore.lua,
-- WishlistPresenter.lua, ItemRow.lua et MainFrame.lua.
-- S'inscrit par ns.MainFrame.addTab("wishlist", …). Lignes ns.ItemRow : clic = RowActions.click (source),
-- clic droit = menu (Désépingler) ; vide : titre et explication (rôle de la page, ajout, import).
-- Obtenu : porté, ou Compat.GetItemCount > 0 (sacs et banque). Rafraîchi par ns.MainFrame.refresh sur
-- SP_WISHLIST_CHANGED et BAG_UPDATE_DELAYED (page affichée).

local _, ns = ...

local L = ns.L

local ROW_HEIGHT = 24
local BOX_HEIGHT = 20
local FOOTER_HEIGHT = BOX_HEIGHT + 18

local panel, header, scrollBox, emptyTitle, emptyBody, ioBox, status, replaceButton
local armed = false -- Remplacer attend la confirmation

local askName = ns.NameAsker.new(function()
    ns.MainFrame.refresh()
end)

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

local ROW_OPTS = { iconSize = 18, gainWidth = 0, compact = true, nameWidth = 180, check = true }

local function initRow(button, row)
    if not button.icon then
        ns.ItemRow.build(button, ROW_OPTS)
    end
    row.hint = L.WISHLIST_ROW_HINT
    ns.ItemRow.set(button, row)
end

local function setStatus(text, color)
    status:SetText(text or "")
    if color then
        setColor(status, color)
    end
end

local function disarm()
    armed = false
    if replaceButton then
        replaceButton:SetText(L.WISHLIST_REPLACE)
    end
end

local function decoded()
    local ids, code = ns.WishlistIO.decode(ioBox:GetText())
    if not ids then
        setStatus(code == "TOO_MANY" and L.WISHLIST_FULL or L.WISHLIST_ERR, ns.Theme.colors.loss)
    end
    return ids
end

local function onImport()
    disarm()
    local ids = decoded()
    if not ids then
        return
    end
    local added, present, full = ns.WishlistStore.merge(ids)
    ioBox:ClearFocus()
    local text = L.WISHLIST_MERGED:format(added, present)
    setStatus(full and text .. " " .. L.WISHLIST_FULL or text, full and ns.Theme.colors.loss or ns.Theme.colors.gain)
end

local function onReplace()
    if not armed then
        armed = true
        replaceButton:SetText(L.WISHLIST_REPLACE_CONFIRM)
        return
    end
    disarm()
    local ids = decoded()
    if not ids then
        return
    end
    ns.WishlistStore.replace(ids)
    ioBox:ClearFocus()
    setStatus(L.WISHLIST_IMPORTED:format(#ids), ns.Theme.colors.gain)
end

local function onExport()
    disarm()
    ioBox:SetText(ns.WishlistIO.encode(ns.WishlistStore.list()))
    ioBox:SetFocus()
    ioBox:HighlightText()
    setStatus("")
end

local function smallButton(text, onClick)
    local button = ns.Skin.button(panel)
    button:SetText(text)
    button:SetSize(button:GetFontString():GetStringWidth() + 20, BOX_HEIGHT)
    button:SetScript("OnClick", onClick)
    return button
end

local function currentView()
    local player = ns.Results.player() or ns.Player.snapshot()
    local state = ns.Wishlist.status(ns.WishlistStore.list(), player, ns.Data, {
        isDone = ns.Compat.IsQuestCompleted,
        owned = function(itemID)
            return ns.Compat.GetItemCount(itemID) > 0
        end,
    })
    return ns.WishlistPresenter.build(state, ns.Data)
end

local function refresh()
    disarm()
    if not ns.Data.ready() then
        header:SetText(L.BEST_NOT_READY)
        scrollBox:SetDataProvider(CreateDataProvider({}))
        emptyTitle:SetText("")
        emptyBody:SetText("")
        return
    end
    local view = currentView()
    for _, row in ipairs(view.rows) do
        askName("item", row.itemID)
    end
    header:SetText(view.title)
    scrollBox:SetDataProvider(CreateDataProvider(view.rows))
    emptyTitle:SetText(view.empty and view.empty.title or "")
    emptyBody:SetText(view.empty and view.empty.body or "")
end

local function createFooter()
    local theme = ns.Theme
    local gap = theme.spacing.gap
    status = panel:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    status:SetPoint("BOTTOMLEFT")
    status:SetPoint("RIGHT")
    status:SetJustifyH("LEFT")
    local export = smallButton(L.WISHLIST_EXPORT, onExport)
    export:SetPoint("BOTTOMRIGHT", 0, 16)
    replaceButton = smallButton(L.WISHLIST_REPLACE_CONFIRM, onReplace)
    replaceButton:SetPoint("RIGHT", export, "LEFT", -gap, 0)
    replaceButton:HookScript("OnLeave", disarm)
    disarm()
    replaceButton:SetWidth(math.max(replaceButton:GetWidth(), replaceButton:GetFontString():GetStringWidth() + 20))
    local import = smallButton(L.WISHLIST_IMPORT, onImport)
    import:SetPoint("RIGHT", replaceButton, "LEFT", -gap, 0)
    ioBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    ioBox:SetAutoFocus(false)
    ioBox:SetHeight(BOX_HEIGHT)
    ioBox:SetPoint("LEFT", panel, "BOTTOMLEFT", 6, 16 + BOX_HEIGHT / 2)
    ioBox:SetPoint("RIGHT", import, "LEFT", -gap, 0)
    ioBox:SetScript("OnEscapePressed", ioBox.ClearFocus)
    ioBox:SetScript("OnEnterPressed", onImport)
    ioBox:SetScript("OnTextChanged", disarm)
end

local function create(parent)
    local theme = ns.Theme
    panel = CreateFrame("Frame", nil, parent)
    header = panel:CreateFontString(nil, "OVERLAY", theme.fonts.header)
    header:SetPoint("TOPLEFT")
    header:SetPoint("RIGHT")
    header:SetJustifyH("LEFT")
    createFooter()
    scrollBox = CreateFrame("Frame", nil, panel, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -theme.spacing.gap)
    scrollBox:SetPoint("BOTTOMRIGHT", -20, FOOTER_HEIGHT + theme.spacing.gap)
    local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer("Button", initRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    emptyTitle = panel:CreateFontString(nil, "OVERLAY", theme.fonts.title)
    emptyTitle:SetPoint("TOPLEFT", scrollBox, "TOPLEFT", 20, -24)
    emptyTitle:SetPoint("RIGHT", scrollBox, "RIGHT", -20, 0)
    emptyTitle:SetJustifyH("LEFT")
    setColor(emptyTitle, theme.colors.title)
    emptyBody = panel:CreateFontString(nil, "OVERLAY", theme.fonts.body)
    emptyBody:SetPoint("TOPLEFT", emptyTitle, "BOTTOMLEFT", 0, -theme.spacing.padding)
    emptyBody:SetPoint("RIGHT", scrollBox, "RIGHT", -20, 0)
    emptyBody:SetJustifyH("LEFT")
    emptyBody:SetJustifyV("TOP")
    emptyBody:SetWordWrap(true)
    emptyBody:SetSpacing(3)
    setColor(emptyBody, theme.colors.text)
    return panel
end

ns.MainFrame.addTab("wishlist", {
    create = create, refresh = refresh, order = 3.5, label = L.TAB_WISHLIST,
    icon = "Interface\\Icons\\INV_Misc_Note_02",
})

ns:On("SP_WISHLIST_CHANGED", ns.MainFrame.refresh)

local events = CreateFrame("Frame")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:SetScript("OnEvent", function()
    if panel and panel:IsVisible() then
        ns.MainFrame.refresh()
    end
end)

ns:On("SP_SELECTION_CHANGED", function()
    if scrollBox then
        scrollBox:ForEachFrame(function(button)
            ns.RowActions.mark(button, button.questID, button.itemID)
        end)
    end
end)
