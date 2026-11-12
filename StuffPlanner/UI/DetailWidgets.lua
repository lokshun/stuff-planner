-- CONTRAT
-- Briques des fiches accolées à la fenêtre principale (QuestDetail, SourceDetail).
-- Charger après MainFrame.lua et Theme.lua, avant les fiches. Cadres seulement (vérifiés en jeu).
--   ns.DetailWidgets.WIDTH (largeur du panneau), BUTTON_HEIGHT, UNKNOWN_ICON
--   newPanel() -> panel, content : panneau accolé à droite de la fenêtre principale (fond, croix,
--     caché avec elle) ; content = enfant d'un ScrollFrame (UIPanelScrollFrameTemplate, barre cachée
--     quand tout tient, molette) ; tout s'ajoute dans content.
--   fontString(content, font, color?) -> FontString à gauche, largeur du contenu
--   hoverRow(content) -> Button : icon, name (ligne 1), tag (ligne 2), gain (à droite) ; survol :
--     info-bulle de row.link (« item:N », « spell:N »), rien sans lien ; Alt+clic sur un objet :
--     RowActions.togglePin
--   button(content, text) -> bouton du jeu à la taille de son texte
--   stacker(content) -> place(region, height?, gapBefore?), finish() : empile de haut en bas,
--     finish fixe la hauteur du contenu et remonte en haut si le contenu a changé de taille
--   nameAsker(refresh) -> ns.NameAsker.new(refresh) (UI/NameAsker.lua)
--   openMap(mapID, target?) -> Compat.OpenWorldMap puis fenêtre principale cachée, message en cas d'échec ;
--     target ({mapID, x, y, title, giver}, view.waypoint) : ping au donneur (MapPins.focus)
--   setColor(region, color)

local _, ns = ...

local L = ns.L

local DetailWidgets = {}
ns.DetailWidgets = DetailWidgets

DetailWidgets.WIDTH = 300
DetailWidgets.BUTTON_HEIGHT = 22
DetailWidgets.UNKNOWN_ICON = 134400

local SCROLLBAR_SPACE = 24
local TOP_SPACE = 24 -- sous la croix de fermeture

local function contentWidth()
    return DetailWidgets.WIDTH - 2 * ns.Theme.spacing.padding - SCROLLBAR_SPACE
end

function DetailWidgets.setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

function DetailWidgets.newPanel()
    local theme = ns.Theme
    local pad = theme.spacing.padding
    local parent = ns.MainFrame.frame()
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, 0)
    panel:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 0, 0)
    panel:SetWidth(DetailWidgets.WIDTH)
    panel:EnableMouse(true)
    parent:HookScript("OnHide", function()
        panel:Hide()
    end)
    local background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    local bg = theme.colors.background
    background:SetColorTexture(bg.r, bg.g, bg.b, 0.92)
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", pad, -TOP_SPACE)
    scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR_SPACE, pad)
    scroll.scrollBarHideable = true
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(contentWidth(), 1)
    scroll:SetScrollChild(content)
    content.scroll = scroll
    return panel, content
end

function DetailWidgets.fontString(content, font, color)
    local text = content:CreateFontString(nil, "OVERLAY", font)
    text:SetJustifyH("LEFT")
    text:SetWidth(contentWidth())
    DetailWidgets.setColor(text, color or ns.Theme.colors.text)
    return text
end

local function showTooltip(row)
    if not row.link then
        return
    end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(row.link)
    GameTooltip:Show()
end

local function hideTooltip()
    GameTooltip:Hide()
end

function DetailWidgets.hoverRow(content)
    local theme = ns.Theme
    local row = CreateFrame("Button", nil, content)
    row:SetSize(contentWidth(), theme.spacing.rowHeight)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(theme.spacing.iconSize, theme.spacing.iconSize)
    row.icon:SetPoint("LEFT")
    row.gain = row:CreateFontString(nil, "OVERLAY", theme.fonts.number)
    row.gain:SetPoint("RIGHT")
    row.gain:SetJustifyH("RIGHT")
    row.name = row:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", theme.spacing.gap, 0)
    row.name:SetPoint("RIGHT", row.gain, "LEFT", -theme.spacing.gap, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.tag = row:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    row.tag:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", theme.spacing.gap, 0)
    row.tag:SetPoint("RIGHT", row.gain, "LEFT", -theme.spacing.gap, 0)
    row.tag:SetJustifyH("LEFT")
    row.tag:SetWordWrap(false)
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)
    row:SetScript("OnEnter", showTooltip)
    row:SetScript("OnLeave", hideTooltip)
    row:SetScript("OnClick", function(self)
        local itemID = IsAltKeyDown() and self.link and tonumber(self.link:match("^item:(%d+)"))
        if itemID then
            ns.RowActions.togglePin(itemID)
        end
    end)
    return row
end

function DetailWidgets.button(content, text)
    local result = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    result:SetText(text)
    result:SetSize(result:GetFontString():GetStringWidth() + 24, DetailWidgets.BUTTON_HEIGHT)
    return result
end

function DetailWidgets.stacker(content)
    local y = 0
    local function place(region, height, gapBefore)
        y = y - (gapBefore or 0)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        region:Show()
        y = y - (height or region:GetStringHeight())
    end
    local function finish()
        local height = math.max(1, -y)
        if math.abs(content:GetHeight() - height) > 0.5 then
            content:SetHeight(height)
            content.scroll:SetVerticalScroll(0)
        end
    end
    return place, finish
end

function DetailWidgets.nameAsker(refresh)
    return ns.NameAsker.new(refresh)
end

function DetailWidgets.openMap(mapID, target)
    if not mapID then
        return
    end
    if ns.Compat.OpenWorldMap(mapID) then
        ns.MainFrame.hide()
        if target and target.mapID == mapID and ns.MapPins then
            ns.MapPins.focus(target)
        end
    else
        print(L.DETAIL_MAP_FAILED)
    end
end
