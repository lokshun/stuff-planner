-- CONTRAT
-- Briques des fiches accolées à la fenêtre principale (QuestDetail, SourceDetail).
-- Charger après MainFrame.lua, Theme.lua et ItemRow.lua, avant les fiches. Cadres seulement (vérifiés en jeu).
--   ns.DetailWidgets.WIDTH (largeur du panneau), BUTTON_HEIGHT, UNKNOWN_ICON
--   newPanel() -> panel, content : panneau accolé à droite de la fenêtre principale (fond, croix,
--     caché avec elle) ; content = enfant d'un ScrollFrame (UIPanelScrollFrameTemplate, barre cachée
--     quand tout tient, molette) ; tout s'ajoute dans content.
--   fontString(content, font, color?) -> FontString à gauche, largeur du contenu
--   hoverRow(content) -> ns.ItemRow : icon, name (ligne 1), tag = detail (ligne 2), gain (à droite) ; survol :
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
    ns.Skin.panel(panel, { alpha = 0.92, edges = "none" })
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

local function onHoverClick(self)
    local itemID = IsAltKeyDown() and self.link and tonumber(self.link:match("^item:(%d+)"))
    if itemID then
        ns.RowActions.togglePin(itemID)
    end
end

local HOVER_OPTS = { nameFont = ns.Theme.fonts.small, onClick = onHoverClick }

function DetailWidgets.hoverRow(content)
    local row = ns.ItemRow.new(content, HOVER_OPTS)
    row:SetWidth(contentWidth())
    row.tag = row.detail
    return row
end

function DetailWidgets.button(content, text)
    local result = ns.Skin.button(content)
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
