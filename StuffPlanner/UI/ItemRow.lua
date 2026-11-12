-- CONTRAT
-- Ligne d'objet commune : icône, nom, détail, gain à droite, coche facultative, grisé, cadre de sélection
-- (RowActions.mark), info-bulle de l'objet, clics. Charger après Theme.lua et RowActions.lua.
--   ns.ItemRow.build(button, opts?) : décore un bouton existant (ligne de ScrollBox ou ItemRow.new) ;
--     une fois par bouton. opts = {
--       iconSize, gainWidth (0 : pas de gain),
--       compact = détail à droite du nom sur une ligne (nameWidth = largeur du nom), sinon sous le nom,
--       check = coche à gauche de l'icône,
--       onClick(button, mouseButton) : remplace RowActions.click(questID, itemID, itemSource),
--       onRightClick(button), tooltip(button, row) : lignes ajoutées sous l'objet, avant row.hint }
--   ns.ItemRow.new(parent, opts?) -> bouton construit (hauteur Theme.spacing.rowHeight, ou opts.height)
--   ns.ItemRow.set(button, row) : row = {questID, itemID, itemSource, icon, name, nameColor, detail,
--     detailColor, gain, gainColor, dimmed, checked, hint} ; button.row = row ; champs absents = vides
-- Info-bulle : lien item:<itemID> puis opts.tooltip, puis row.hint en gris ; aucune sans itemID.

local _, ns = ...

local ItemRow = {}
ns.ItemRow = ItemRow

local GAIN_WIDTH = 70
local DIMMED_ALPHA = 0.5
local CHECK_SIZE = 16
local UNKNOWN_ICON = 134400 -- INV_Misc_QuestionMark
local CHECK_ICON = "Interface\\Buttons\\UI-CheckBox-Check"

local function setColor(region, color)
    if color then
        region:SetTextColor(color.r, color.g, color.b)
    end
end

local function onClick(button, mouseButton)
    local opts, row = button.itemRowOpts, button.row
    if not row then
        return
    end
    if mouseButton == "RightButton" then
        if opts.onRightClick then
            opts.onRightClick(button)
        end
    elseif opts.onClick then
        opts.onClick(button, mouseButton)
    else
        ns.RowActions.click(row.questID, row.itemID, row.itemSource)
    end
end

local function onEnter(button)
    local row = button.row
    if not (row and row.itemID) then
        return
    end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. row.itemID)
    if button.itemRowOpts.tooltip then
        button.itemRowOpts.tooltip(button, row)
    end
    if row.hint then
        GameTooltip:AddLine(row.hint, 0.6, 0.6, 0.6)
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
        button.name = fontString(button, theme.fonts.small)
        button.name:SetPoint("LEFT", left, "RIGHT", gap, 0)
        button.name:SetWidth(opts.nameWidth or 170)
        button.detail = fontString(button, theme.fonts.small)
        button.detail:SetPoint("LEFT", button.name, "RIGHT", gap, 0)
        button.detail:SetPoint("RIGHT", right, rightPoint, rightGap, 0)
        return
    end
    button.name = fontString(button, theme.fonts.body)
    button.name:SetPoint("TOPLEFT", left, "TOPRIGHT", gap, 1)
    button.name:SetPoint("RIGHT", right, rightPoint, rightGap, 0)
    button.detail = fontString(button, theme.fonts.small)
    button.detail:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT", gap, -1)
    button.detail:SetPoint("RIGHT", right, rightPoint, rightGap, 0)
end

function ItemRow.build(button, opts)
    opts = opts or {}
    local theme = ns.Theme
    button.itemRowOpts = opts
    local x = 2
    if opts.check then
        button.check = button:CreateTexture(nil, "OVERLAY")
        button.check:SetSize(CHECK_SIZE, CHECK_SIZE)
        button.check:SetPoint("LEFT", x, 0)
        button.check:SetTexture(CHECK_ICON)
        x = x + CHECK_SIZE + 2
    end
    local size = opts.iconSize or theme.spacing.iconSize
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(size, size)
    button.icon:SetPoint("LEFT", x, 0)
    local gainWidth = opts.gainWidth or GAIN_WIDTH
    if gainWidth > 0 then
        button.gain = button:CreateFontString(nil, "OVERLAY", theme.fonts.number)
        button.gain:SetPoint("RIGHT", -4, 0)
        button.gain:SetWidth(gainWidth)
        button.gain:SetJustifyH("RIGHT")
    end
    buildTexts(button, opts, button.icon)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)
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

function ItemRow.set(button, row)
    button.row = row
    button.questID, button.itemID = row.questID, row.itemID
    ns.RowActions.mark(button, row.questID, row.itemID)
    button:SetAlpha(row.dimmed and DIMMED_ALPHA or 1)
    if button.check then
        button.check:SetShown(row.checked == true)
    end
    button.icon:SetTexture(row.icon or UNKNOWN_ICON)
    button.name:SetText(row.name or "")
    setColor(button.name, row.nameColor)
    button.detail:SetText(row.detail or "")
    setColor(button.detail, row.detailColor or ns.Theme.colors.muted)
    if button.gain then
        button.gain:SetText(row.gain or "")
        setColor(button.gain, row.gainColor)
    end
end
