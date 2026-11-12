-- CONTRAT
-- Section « Liste cible » en tête de l'onglet Équipement : objets épinglés (WishlistStore), état de chacun
-- (Wishlist.status, WishlistPresenter), obtenu coché ; import / export SPL1 (WishlistIO). Cadres seulement.
-- Charger après Wishlist.lua, WishlistStore.lua, WishlistPresenter.lua, RowActions.lua et MainFrame.lua.
--   ns.WishlistSection.create(parent) -> frame (ancré par l'appelant en haut à gauche, largeur du parent)
--   ns.WishlistSection.render() -> hauteur (pixels) : ns.Section repliable (StuffPlannerDB.ui.wishlistCollapsed),
--     MAX_ROWS lignes ns.ItemRow au plus (clic : RowActions.click ; clic droit : retirée ; survol : objet),
--     invitation si vide ; dépliée : champ, boutons Importer / Exporter, statut.
-- Obtenu : porté, ou Compat.GetItemCount > 0 (sacs et banque). Rafraîchi par ns.MainFrame.refresh sur
-- SP_WISHLIST_CHANGED et BAG_UPDATE_DELAYED (onglet affiché seulement).

local _, ns = ...

local L = ns.L

local WishlistSection = {}
ns.WishlistSection = WishlistSection

local MAX_ROWS = 8
local ROW_HEIGHT = 22
local BOX_HEIGHT = 20
local SECTION = { key = "wishlistCollapsed", open = true, invert = true }

local frame, section, empty, ioBox, importButton, exportButton, status
local rows = {}
local rowTop = -ns.Section.HEIGHT

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

local askName = ns.NameAsker.new(function()
    ns.MainFrame.refresh()
end)

local ROW_OPTS = {
    height = ROW_HEIGHT, iconSize = 18, gainWidth = 0, compact = true, nameWidth = 170, check = true,
    onRightClick = function(button)
        ns.WishlistStore.remove(button.row.itemID)
    end,
}

local function newRow(index)
    local button = ns.ItemRow.new(frame, ROW_OPTS)
    button:SetPoint("TOPLEFT", 0, rowTop - (index - 1) * ROW_HEIGHT)
    button:SetPoint("RIGHT")
    rows[index] = button
    return button
end

local function setStatus(text, color)
    status:SetText(text or "")
    if color then
        setColor(status, color)
    end
end

local function onImport()
    local ids, code = ns.WishlistIO.decode(ioBox:GetText())
    if not ids then
        setStatus(code == "TOO_MANY" and L.WISHLIST_FULL or L.WISHLIST_ERR, ns.Theme.colors.loss)
        return
    end
    ns.WishlistStore.replace(ids)
    ioBox:ClearFocus()
    setStatus(L.WISHLIST_IMPORTED:format(#ids), ns.Theme.colors.gain)
end

local function onExport()
    ioBox:SetText(ns.WishlistIO.encode(ns.WishlistStore.list()))
    ioBox:SetFocus()
    ioBox:HighlightText()
    setStatus("")
end

local function smallButton(text, onClick)
    local button = ns.Skin.button(frame)
    button:SetText(text)
    button:SetSize(button:GetFontString():GetStringWidth() + 20, BOX_HEIGHT)
    button:SetScript("OnClick", onClick)
    return button
end

function WishlistSection.create(parent)
    local theme = ns.Theme
    frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(ns.Section.HEIGHT)
    section = ns.Section.new(frame, SECTION, function()
        ns.MainFrame.refresh()
    end)
    empty = frame:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    empty:SetPoint("TOPLEFT", 0, rowTop)
    empty:SetPoint("RIGHT")
    empty:SetJustifyH("LEFT")
    setColor(empty, theme.colors.muted)
    ioBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    ioBox:SetAutoFocus(false)
    ioBox:SetHeight(BOX_HEIGHT)
    ioBox:SetScript("OnEscapePressed", ioBox.ClearFocus)
    importButton = smallButton(L.WISHLIST_IMPORT, onImport)
    exportButton = smallButton(L.WISHLIST_EXPORT, onExport)
    status = frame:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    status:SetJustifyH("LEFT")
    return frame
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

local function renderRow(index, row)
    local button = rows[index] or newRow(index)
    if not row then
        button.row, button.view = nil, nil
        button:Hide()
        return
    end
    askName("item", row.itemID)
    row.hint = L.WISHLIST_ROW_HINT
    ns.ItemRow.set(button, row)
    button:Show()
end

local function placeIO(y)
    local gap = ns.Theme.spacing.gap
    ioBox:ClearAllPoints()
    ioBox:SetPoint("TOPLEFT", 6, y)
    ioBox:SetPoint("RIGHT", importButton, "LEFT", -gap, 0)
    exportButton:ClearAllPoints()
    exportButton:SetPoint("TOPRIGHT", 0, y)
    importButton:ClearAllPoints()
    importButton:SetPoint("RIGHT", exportButton, "LEFT", -gap, 0)
    status:ClearAllPoints()
    status:SetPoint("TOPLEFT", 0, y - BOX_HEIGHT - 2)
    status:SetPoint("RIGHT")
    return y - BOX_HEIGHT - 2 - (status:GetText() ~= "" and 14 or 0)
end

function WishlistSection.render()
    if not frame or not ns.Data.ready() then
        return 0
    end
    local view = currentView()
    section.setTitle(view.title)
    local open = section.place(0)
    local collapsed = not open
    local shown = collapsed and 0 or math.min(#view.rows, MAX_ROWS)
    for index = 1, math.max(MAX_ROWS, #rows) do
        renderRow(index, index <= shown and view.rows[index] or nil)
    end
    empty:SetText(view.empty or "")
    empty:SetShown(not collapsed and view.empty ~= nil)
    for _, region in ipairs({ ioBox, importButton, exportButton, status }) do
        region:SetShown(not collapsed)
    end
    local y = rowTop - shown * ROW_HEIGHT
    if not collapsed then
        if view.empty then
            y = y - 16
        end
        y = placeIO(y - 4)
    end
    frame:SetHeight(-y)
    return -y
end

ns:On("SP_WISHLIST_CHANGED", function()
    ns.MainFrame.refresh()
end)

local events = CreateFrame("Frame")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:SetScript("OnEvent", function()
    if frame and frame:IsVisible() then
        ns.MainFrame.refresh()
    end
end)
