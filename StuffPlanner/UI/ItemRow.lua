-- CONTRAT
-- Ligne d'objet commune : icône, nom, détail, gain à droite, coche facultative, grisé, cadre de sélection
-- (RowActions.mark), info-bulle de l'objet, clics. Charger après Theme.lua et RowActions.lua.
--   ns.ItemRow.build(button, opts?) : décore un bouton existant (ligne de ScrollBox ou ItemRow.new) ;
--     une fois par bouton ; crée button.icon, name, detail, gain (si gainWidth > 0), check, highlight.
--     opts = {
--       iconSize, gainWidth (0 : pas de gain), nameFont,
--       compact = détail à droite du nom sur une ligne (nameWidth = largeur du nom), sinon sous le nom,
--       top = icône centrée dans les rowHeight premiers pixels (ligne qui grandit vers le bas),
--       check = coche à gauche de l'icône, markHeight = hauteur du cadre de sélection,
--       onClick(button, mouseButton) : remplace RowActions.click(questID, itemID, itemSource), appelé
--         même sans ligne ; onRightClick(button) : remplace le menu RowActions.menu ;
--         tooltip(button, row) : lignes sous l'objet }
--   ns.ItemRow.new(parent, opts?) -> bouton construit (hauteur Theme.spacing.rowHeight, ou opts.height)
--   ns.ItemRow.set(button, view) : view = {row?, questID, itemID, itemSource, link, icon, muted, name,
--     nameColor, detail, detailColor, gain, gainColor, gain2, gain2Color, dimmed, checked, hint} ; champs
--     absents = vides ; gain2 (profil comparé) : ItemRow.setGains ;
--   ns.ItemRow.setGains(button, gain, gainColor, gain2?, gain2Color?) : gain à droite ; gain2 sous gain (les deux
--     centrés ensemble en hauteur), ou à sa droite sur une ligne compacte ; rien sans colonne de gain ;
--     button.view = view, button.row = view.row or view, button.questID, button.itemID
-- Info-bulle : view.link (sinon item:<itemID>, sinon button.link) puis opts.tooltip, puis view.hint en gris
-- et L.ROW_MENU_HINT (menu clic droit, si la ligne a une quête ou un objet et pas d'onRightClick).
-- muted : icône désaturée et pâlie (couleurs du texte au choix de l'appelant) ; dimmed : ligne pâlie.

local _, ns = ...

local ItemRow = {}
ns.ItemRow = ItemRow

local GAIN_WIDTH = 70
local COMPACT_GAIN2_WIDTH = 40
local DIMMED_ALPHA = 0.5
local MUTED_ICON_ALPHA = 0.6
local CHECK_SIZE = 16
local UNKNOWN_ICON = 134400 -- INV_Misc_QuestionMark
local CHECK_ICON = "Interface\\Buttons\\UI-CheckBox-Check"

local function setColor(region, color)
    if color then
        region:SetTextColor(color.r, color.g, color.b)
    end
end

local function onClick(button, mouseButton)
    local opts, view = button.itemRowOpts, button.view
    if mouseButton == "RightButton" then
        if opts.onRightClick then
            if view then
                opts.onRightClick(button)
            end
        elseif view and (view.questID or view.itemID) then
            ns.RowActions.menu(view.questID, view.itemID, view.itemSource)
        end
    elseif opts.onClick then
        opts.onClick(button, mouseButton)
    elseif view then
        ns.RowActions.click(view.questID, view.itemID, view.itemSource)
    end
end

local function linkOf(button)
    local view = button.view
    if view and view.link then
        return view.link
    elseif view and view.itemID then
        return "item:" .. view.itemID
    end
    return button.link
end

-- Info-bulle du côté où l'écran a le plus de place : les comparaisons (deux pour un anneau ou un bijou)
-- s'y étalent sans repousser l'info-bulle sur la fenêtre.
local function anchorSide(button)
    local scale = button:GetEffectiveScale()
    local screen = UIParent:GetRight() * UIParent:GetEffectiveScale()
    local left = (button:GetLeft() or 0) * scale
    local right = screen - (button:GetRight() or 0) * scale
    return right >= left and "ANCHOR_RIGHT" or "ANCHOR_LEFT"
end

local function onEnter(button)
    local link = linkOf(button)
    if not link then
        return
    end
    GameTooltip:SetOwner(button, anchorSide(button))
    GameTooltip:SetHyperlink(link)
    if button.itemRowOpts.tooltip and button.row then
        button.itemRowOpts.tooltip(button, button.row)
    end
    local view = button.view
    if view and view.hint then
        GameTooltip:AddLine(view.hint, 0.6, 0.6, 0.6)
    end
    if view and (view.questID or view.itemID) and not button.itemRowOpts.onRightClick then
        GameTooltip:AddLine(ns.L.ROW_MENU_HINT, 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local function onLeave()
    GameTooltip:Hide()
end

local function fontString(button, font)
    local text = button:CreateFontString(nil, "OVERLAY", font)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    return text
end

local function buildTexts(button, opts, left)
    local theme = ns.Theme
    local gap = theme.spacing.gap
    local right = button.gain or button
    local rightPoint = button.gain and "LEFT" or "RIGHT"
    local rightGap = button.gain and -gap or 0
    if opts.compact then
        button.name = fontString(button, opts.nameFont or theme.fonts.small)
        button.name:SetPoint("LEFT", left, "RIGHT", gap, 0)
        button.name:SetWidth(opts.nameWidth or 170)
        button.detail = fontString(button, theme.fonts.small)
        button.detail:SetPoint("LEFT", button.name, "RIGHT", gap, 0)
        button.detail:SetPoint("RIGHT", right, rightPoint, rightGap, 0)
        return
    end
    button.name = fontString(button, opts.nameFont or theme.fonts.body)
    button.name:SetPoint("TOPLEFT", left, "TOPRIGHT", gap, 1)
    button.name:SetPoint("RIGHT", right, rightPoint, rightGap, 0)
    button.detail = fontString(button, theme.fonts.small)
    button.detail:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT", gap, -1)
    button.detail:SetPoint("RIGHT", right, rightPoint, rightGap, 0)
end

-- Ancrage à gauche, centré sur la ligne ou dans ses rowHeight premiers pixels (opts.top).
local function placeLeft(region, opts, x, size)
    if opts.top then
        region:SetPoint("TOPLEFT", x, -(ns.Theme.spacing.rowHeight - size) / 2)
    else
        region:SetPoint("LEFT", x, 0)
    end
end

function ItemRow.build(button, opts)
    opts = opts or {}
    local theme = ns.Theme
    button.itemRowOpts = opts
    local x = 2
    if opts.check then
        button.check = button:CreateTexture(nil, "OVERLAY")
        button.check:SetSize(CHECK_SIZE, CHECK_SIZE)
        placeLeft(button.check, opts, x, CHECK_SIZE)
        button.check:SetTexture(CHECK_ICON)
        x = x + CHECK_SIZE + 2
    end
    local size = opts.iconSize or theme.spacing.iconSize
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(size, size)
    placeLeft(button.icon, opts, x, size)
    local gainWidth = opts.gainWidth or GAIN_WIDTH
    if gainWidth > 0 then
        button.gain = button:CreateFontString(nil, "OVERLAY", theme.fonts.number)
        button.gain:SetPoint("RIGHT", -4, 0)
        button.gain:SetWidth(gainWidth)
        button.gain:SetJustifyH("RIGHT")
        button.gain2 = button:CreateFontString(nil, "OVERLAY", theme.fonts.number)
        if opts.compact then
            button.gain2:SetPoint("RIGHT", -4, 0)
        else
            button.gain2:SetPoint("TOPRIGHT", button, "RIGHT", -4, -1)
        end
        button.gain2:SetWidth(opts.compact and COMPACT_GAIN2_WIDTH or gainWidth)
        button.gain2:SetJustifyH("RIGHT")
    end
    buildTexts(button, opts, button.icon)
    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetAllPoints()
    button.highlight:SetColorTexture(1, 1, 1, 0.08)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", onEnter)
    button:SetScript("OnLeave", onLeave)
    return button
end

function ItemRow.new(parent, opts)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(opts and opts.height or ns.Theme.spacing.rowHeight)
    return ItemRow.build(button, opts)
end

function ItemRow.set(button, view)
    button.view, button.row = view, view.row or view
    button.questID, button.itemID = view.questID, view.itemID
    ns.RowActions.mark(button, view.questID, view.itemID, button.itemRowOpts.markHeight)
    button:SetAlpha(view.dimmed and DIMMED_ALPHA or 1)
    if button.check then
        button.check:SetShown(view.checked == true)
    end
    button.icon:SetTexture(view.icon or UNKNOWN_ICON)
    button.icon:SetDesaturated(view.muted == true)
    button.icon:SetAlpha(view.muted and MUTED_ICON_ALPHA or 1)
    button.name:SetText(view.name or "")
    setColor(button.name, view.nameColor)
    button.detail:SetText(view.detail or "")
    setColor(button.detail, view.detailColor or ns.Theme.colors.muted)
    ItemRow.setGains(button, view.gain, view.gainColor, view.gain2, view.gain2Color)
end

function ItemRow.setGains(button, gain, gainColor, gain2, gain2Color)
    if not button.gain then
        return
    end
    local second = gain2 ~= nil and gain2 ~= ""
    button.gain:SetText(gain or "")
    setColor(button.gain, gainColor)
    button.gain:ClearAllPoints()
    if second and button.itemRowOpts.compact then
        button.gain:SetPoint("RIGHT", button.gain2, "LEFT", -4, 0)
    elseif second then
        button.gain:SetPoint("BOTTOMRIGHT", button, "RIGHT", -4, 1)
    else
        button.gain:SetPoint("RIGHT", -4, 0)
    end
    button.gain2:SetShown(second)
    button.gain2:SetText(gain2 or "")
    setColor(button.gain2, gain2Color)
end
