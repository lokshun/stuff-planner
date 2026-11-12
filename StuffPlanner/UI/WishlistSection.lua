-- CONTRAT
-- Section « Liste cible » en tête de l'onglet Équipement : objets épinglés (WishlistStore), état de chacun
-- (Wishlist.status, WishlistPresenter), obtenu coché ; import / export SPL1 (WishlistIO). Cadres seulement.
-- Charger après Wishlist.lua, WishlistStore.lua, WishlistPresenter.lua, RowActions.lua et MainFrame.lua.
--   ns.WishlistSection.create(parent) -> frame (ancré par l'appelant en haut à gauche, largeur du parent)
--   ns.WishlistSection.render() -> hauteur (pixels) : titre repliable (StuffPlannerDB.ui.wishlistCollapsed),
--     MAX_ROWS lignes au plus (clic : RowActions.click ; clic droit : retirée ; survol : info-bulle de l'objet),
--     invitation si vide ; dépliée : champ, boutons Importer / Exporter, statut.
-- Obtenu : porté, ou Compat.GetItemCount > 0 (sacs et banque). Rafraîchi par ns.MainFrame.refresh sur
-- SP_WISHLIST_CHANGED et BAG_UPDATE_DELAYED (onglet affiché seulement).

local _, ns = ...

local L = ns.L

local WishlistSection = {}
ns.WishlistSection = WishlistSection

local MAX_ROWS = 8
local ROW_HEIGHT = 22
local HEADER_HEIGHT = 18
local BOX_HEIGHT = 20
local CHECK_ICON = "Interface\\Buttons\\UI-CheckBox-Check"

local frame, header, empty, ioBox, importButton, exportButton, status
local rows = {}

local function ui()
    return ns.DB.account("ui")
end

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

local askName = ns.NameAsker.new(function()
    ns.MainFrame.refresh()
end)

local function onRowClick(button, mouseButton)
    local row = button.row
    if not row then
        return
    end
    if mouseButton == "RightButton" then
        ns.WishlistStore.remove(row.itemID)
    else
        ns.RowActions.click(row.questID, row.itemID, row.itemSource)
    end
end

local function onRowEnter(button)
    if button.row then
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. button.row.itemID)
        GameTooltip:AddLine(L.WISHLIST_ROW_HINT, 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end
end

local function newRow(index)
    local theme = ns.Theme
    local button = CreateFrame("Button", nil, frame)
    button:SetHeight(ROW_HEIGHT)
    button:SetPoint("TOPLEFT", 0, -HEADER_HEIGHT - (index - 1) * ROW_HEIGHT)
    button:SetPoint("RIGHT")
    button.check = button:CreateTexture(nil, "OVERLAY")
    button.check:SetSize(16, 16)
    button.check:SetPoint("LEFT")
    button.check:SetTexture(CHECK_ICON)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(18, 18)
    button.icon:SetPoint("LEFT", 18, 0)
    button.name = button:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    button.name:SetPoint("LEFT", button.icon, "RIGHT", theme.spacing.gap, 0)
    button.name:SetWidth(170)
    button.name:SetJustifyH("LEFT")
    button.name:SetWordWrap(false)
    button.detail = button:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    button.detail:SetPoint("LEFT", button.name, "RIGHT", theme.spacing.gap, 0)
    button.detail:SetPoint("RIGHT")
    button.detail:SetJustifyH("LEFT")
    button.detail:SetWordWrap(false)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", onRowClick)
    button:SetScript("OnEnter", onRowEnter)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
    frame:SetHeight(HEADER_HEIGHT)
    header = CreateFrame("Button", nil, frame)
    header:SetPoint("TOPLEFT")
    header:SetPoint("RIGHT")
    header:SetHeight(HEADER_HEIGHT)
    header.text = header:CreateFontString(nil, "OVERLAY", theme.fonts.header)
    header.text:SetAllPoints()
    header.text:SetJustifyH("LEFT")
    setColor(header.text, theme.colors.title)
    header:SetScript("OnClick", function()
        ui().wishlistCollapsed = not ui().wishlistCollapsed or nil
        ns.MainFrame.refresh()
    end)
    empty = frame:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    empty:SetPoint("TOPLEFT", 0, -HEADER_HEIGHT)
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
    button.row = row
    if not row then
        button:Hide()
        return
    end
    askName("item", row.itemID)
    button.check:SetShown(row.checked)
    button.icon:SetTexture(row.icon)
    button.name:SetText(row.name)
    setColor(button.name, row.nameColor)
    button.detail:SetText(row.detail)
    setColor(button.detail, row.detailColor)
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
    local collapsed = ui().wishlistCollapsed == true
    header.text:SetText((collapsed and "+ " or "- ") .. view.title)
    local shown = collapsed and 0 or math.min(#view.rows, MAX_ROWS)
    for index = 1, math.max(MAX_ROWS, #rows) do
        renderRow(index, index <= shown and view.rows[index] or nil)
    end
    empty:SetText(view.empty or "")
    empty:SetShown(not collapsed and view.empty ~= nil)
    for _, region in ipairs({ ioBox, importButton, exportButton, status }) do
        region:SetShown(not collapsed)
    end
    local y = -HEADER_HEIGHT - shown * ROW_HEIGHT
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
