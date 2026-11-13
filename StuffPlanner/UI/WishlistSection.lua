-- CONTRAT
-- Section « Liste cible » repliable (ns.Section, clé ui.gearWishlist, ouverte par défaut) en tête de la page
-- Équipement : objets épinglés (WishlistStore), état de chacun (Wishlist.status, WishlistPresenter), gain du
-- profil actif, obtenu coché ; MAX_ROWS lignes visibles puis défilement ; vide : une phrase (L.WISHLIST_EMPTY).
-- « Partager… » (à droite de l'en-tête) montre ou cache le partage : champ, Importer (fusion :
-- WishlistStore.merge, aussi par Entrée), Remplacer (deux clics : armé puis confirmé, WishlistStore.replace),
-- Exporter (SPL1, WishlistIO), statut. Cadres seulement. Charger après Wishlist.lua, WishlistStore.lua,
-- WishlistPresenter.lua, ItemRow.lua, Section.lua et MainFrame.lua, avant GearTab.lua.
--   ns.WishlistSection.create(parent) : construit la section dans parent (la page Équipement)
--   ns.WishlistSection.place(y) -> y' : en-tête à y dans parent, corps rafraîchi et placé dessous s'il est
--     ouvert ; y' = sous la section
-- Lignes ns.ItemRow : clic = source, clic droit = menu, étoile = retirer de la liste. Obtenu : porté, ou
-- Compat.GetItemCount > 0 (sacs et banque). MainFrame.show("wishlist") ouvre Équipement section dépliée.
-- Rafraîchi par ns.MainFrame.refresh sur SP_WISHLIST_CHANGED et BAG_UPDATE_DELAYED (section affichée).

local _, ns = ...

local L = ns.L

local WishlistSection = {}
ns.WishlistSection = WishlistSection

local SPEC = { key = "gearWishlist", open = true }
local ROW_HEIGHT = 24
local MAX_ROWS = 5
local BOX_HEIGHT = 20
local EMPTY_HEIGHT = 40
local SHARE_HEIGHT = BOX_HEIGHT + 18
local ROW_OPTS = { iconSize = 18, gainWidth = 56, compact = true, nameWidth = 170, check = true }

local parent, section, shareButton, body, scrollBox, scrollBar, emptyText
local share, ioBox, status, replaceButton
local sharing, armed = false, false

local askName = ns.NameAsker.new(function()
    ns.MainFrame.refresh()
end)

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

local function initRow(button, row)
    if not button.icon then
        ns.ItemRow.build(button, ROW_OPTS)
    end
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

local function smallButton(owner, text, onClick)
    local button = ns.Skin.button(owner)
    button:SetText(text)
    button:SetSize(button:GetFontString():GetStringWidth() + 20, BOX_HEIGHT)
    button:SetScript("OnClick", onClick)
    return button
end

local function createShare()
    local gap = ns.Theme.spacing.gap
    share = CreateFrame("Frame", nil, parent)
    share:SetHeight(SHARE_HEIGHT)
    status = share:CreateFontString(nil, "OVERLAY", ns.Theme.fonts.small)
    status:SetPoint("BOTTOMLEFT")
    status:SetPoint("RIGHT")
    status:SetJustifyH("LEFT")
    local export = smallButton(share, L.WISHLIST_EXPORT, onExport)
    export:SetPoint("TOPRIGHT")
    replaceButton = smallButton(share, L.WISHLIST_REPLACE_CONFIRM, onReplace)
    replaceButton:SetPoint("RIGHT", export, "LEFT", -gap, 0)
    replaceButton:HookScript("OnLeave", disarm)
    disarm()
    replaceButton:SetWidth(math.max(replaceButton:GetWidth(), replaceButton:GetFontString():GetStringWidth() + 20))
    local import = smallButton(share, L.WISHLIST_IMPORT, onImport)
    import:SetPoint("RIGHT", replaceButton, "LEFT", -gap, 0)
    ioBox = CreateFrame("EditBox", nil, share, "InputBoxTemplate")
    ioBox:SetAutoFocus(false)
    ioBox:SetHeight(BOX_HEIGHT)
    ioBox:SetPoint("TOPLEFT", 6, 0)
    ioBox:SetPoint("RIGHT", import, "LEFT", -gap, 0)
    ioBox:SetScript("OnEscapePressed", ioBox.ClearFocus)
    ioBox:SetScript("OnEnterPressed", onImport)
    ioBox:SetScript("OnTextChanged", disarm)
end

local function currentView()
    local player = ns.Results.player() or ns.Player.snapshot()
    local state = ns.Wishlist.status(ns.WishlistStore.list(), player, ns.Data, {
        isDone = ns.Compat.IsQuestCompleted,
        owned = function(itemID)
            return ns.Compat.GetItemCount(itemID) > 0
        end,
    })
    local profile = ns.Profiles.active()
    local gainOf = profile and function(itemID)
        return ns.Scoring.delta(itemID, player, profile, ns.Data)
    end
    return ns.WishlistPresenter.build(state, ns.Data, gainOf)
end

-- Corps ouvert : lignes (ou phrase si vide) puis partage ; renvoie sa hauteur.
local function renderBody()
    disarm()
    local rows = {}
    if ns.Data.ready() then
        local view = currentView()
        section.setTitle(view.title)
        rows = view.rows
        for _, row in ipairs(rows) do
            askName("item", row.itemID)
        end
        emptyText:SetText(view.empty or "")
    else
        section.setTitle(L.TAB_WISHLIST)
        emptyText:SetText(L.BEST_NOT_READY)
    end
    local listHeight = #rows > 0 and math.min(#rows, MAX_ROWS) * ROW_HEIGHT or EMPTY_HEIGHT
    scrollBox:SetShown(#rows > 0)
    scrollBar:SetShown(#rows > MAX_ROWS)
    emptyText:SetShown(#rows == 0)
    body:SetHeight(listHeight)
    scrollBox:SetDataProvider(CreateDataProvider(rows))
    return listHeight
end

function WishlistSection.place(y)
    local gap = ns.Theme.spacing.gap
    local open
    open, y = section.place(y)
    shareButton:SetShown(open)
    body:SetShown(open)
    share:SetShown(open and sharing)
    if not open then
        section.setTitle(L.TAB_WISHLIST)
        return y
    end
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y - gap / 2)
    body:SetPoint("RIGHT", parent, "RIGHT")
    y = y - gap / 2 - renderBody()
    if sharing then
        share:ClearAllPoints()
        share:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y - gap)
        share:SetPoint("RIGHT", parent, "RIGHT")
        y = y - gap - SHARE_HEIGHT
    end
    return y
end

function WishlistSection.create(owner)
    local theme = ns.Theme
    parent = owner
    SPEC.title = L.TAB_WISHLIST
    section = ns.Section.new(parent, SPEC, ns.MainFrame.refresh)
    shareButton = smallButton(parent, L.WISHLIST_SHARE, function()
        sharing = not sharing
        ns.MainFrame.refresh()
    end)
    shareButton:SetFrameLevel(section.header:GetFrameLevel() + 2)
    shareButton:SetPoint("RIGHT", section.header, "RIGHT")
    body = CreateFrame("Frame", nil, parent)
    scrollBox = CreateFrame("Frame", nil, body, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT")
    scrollBox:SetPoint("BOTTOMRIGHT", -20, 0)
    scrollBar = CreateFrame("EventFrame", nil, body, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer("Button", initRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    emptyText = body:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    emptyText:SetPoint("TOPLEFT", 16, -4)
    emptyText:SetPoint("BOTTOMRIGHT", -4, 0)
    emptyText:SetJustifyH("LEFT")
    emptyText:SetJustifyV("TOP")
    emptyText:SetWordWrap(true)
    setColor(emptyText, theme.colors.muted)
    createShare()
end

ns.MainFrame.onReveal("wishlist", function()
    ns.Section.setOpen(SPEC, true)
    ns.MainFrame.refresh()
end)

ns:On("SP_WISHLIST_CHANGED", ns.MainFrame.refresh)

local events = CreateFrame("Frame")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:SetScript("OnEvent", function()
    if body and body:IsVisible() then
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
