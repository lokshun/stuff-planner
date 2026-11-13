-- CONTRAT
-- Bandeau d'astuce de la fenêtre principale : au premier passage sur une page, une phrase « comment s'en
-- servir » (PageTipPresenter.tip), l'icône de la page et un bouton Compris ; les pages passent sous le bandeau.
-- Charger après Theme.lua, Skin.lua et PageTipPresenter.lua, avant MainFrame.lua.
--   ns.PageTip.new(parent, content, left, top) -> tip : content = cadre des pages, ancré par l'appelant en
--     TOPLEFT (left, -top) de parent ; tip.show(key, icon) : bandeau de la page, ou caché si déjà vue
--   ns.PageTip.reset() -> toutes les astuces réaffichées (appelé par /splan welcome)
-- Sauvegarde : StuffPlannerDB.ui.tipsSeen = {[clé] = true} au clic sur Compris.

local _, ns = ...

local L = ns.L

local PageTip = {}
ns.PageTip = PageTip

local HEIGHT, ICON, PAD = 44, 20, 8
local BUTTON_WIDTH, BUTTON_HEIGHT = 80, 22
local TINT = 0.08

local function seen()
    local ui = ns.DB.account("ui")
    ui.tipsSeen = ui.tipsSeen or {}
    return ui.tipsSeen
end

function PageTip.reset()
    ns.DB.account("ui").tipsSeen = nil
end

function PageTip.new(parent, content, left, top)
    local theme = ns.Theme
    local banner = CreateFrame("Frame", nil, parent)
    banner:SetPoint("TOPLEFT", left, -top)
    banner:SetPoint("RIGHT", -left, 0)
    banner:SetHeight(HEIGHT)
    local accent = theme.colors.title
    local back = banner:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(accent.r, accent.g, accent.b, TINT)
    local icon = banner:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON, ICON)
    icon:SetPoint("LEFT", PAD, 0)
    local button = ns.Skin.button(banner)
    button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    button:SetPoint("RIGHT", -PAD, 0)
    button:SetText(L.PAGE_TIP_OK)
    local text = banner:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    text:SetPoint("LEFT", icon, "RIGHT", PAD, 0)
    text:SetPoint("RIGHT", button, "LEFT", -PAD, 0)
    text:SetHeight(HEIGHT - 4)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(true)

    local tip, current = {}, nil
    local function place(shown)
        banner:SetShown(shown)
        content:SetPoint("TOPLEFT", left, -(top + (shown and HEIGHT + theme.spacing.gap or 0)))
    end

    function tip.show(key, iconTexture)
        current = key
        local message = ns.PageTipPresenter.tip(key, seen())
        if message then
            icon:SetTexture(iconTexture)
            text:SetText(message)
        end
        place(message ~= nil)
    end

    button:SetScript("OnClick", function()
        if current then
            seen()[current] = true
        end
        place(false)
    end)
    place(false)
    return tip
end
