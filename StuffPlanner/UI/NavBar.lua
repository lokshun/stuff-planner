-- CONTRAT
-- Barre de navigation : colonne d'onglets collée hors du bord gauche de la fenêtre principale ; onglet = icône
-- et libellé court dessous, page active sur fond teinté, libellé doré. Charger après Theme.lua, avant MainFrame.lua.
--   ns.NavBar.order(tabs) -> {{key, icon, label, short, order}...} : tabs = {[key] = tab}, triés par tab.order
--     (sans ordre : après, par clé) ; short = tab.short sinon tab.label ; pur
--   ns.NavBar.pick(tabs, key?, saved?) -> clé ouverte : key si inscrite, sinon saved, sinon la première ; nil
--     sans page ; pur
--   ns.NavBar.new(parent, onSelect) -> bar ; bar.frame (largeur NavBar.WIDTH, à ancrer par
--     l'appelant hors de la fenêtre, TOPRIGHT sur son TOPLEFT) ;
--     bar.render(pages) : un onglet par page (NavBar.order), clic = onSelect(key) ; bar.setActive(key)
--   ns.NavBar.WIDTH, ns.NavBar.BUTTON (hauteur d'un onglet)
-- Survol : libellé complet (page.label) en info-bulle.

local _, ns = ...

local NavBar = {}
ns.NavBar = NavBar

NavBar.WIDTH = 60
NavBar.BUTTON = 48

local ICON = 28
local GAP = 4
local PAD = 4
local UNKNOWN_ICON = 134400
local HIGHLIGHT_TEXTURE = "Interface\\Buttons\\ButtonHilight-Square"
local BACK_ALPHA, ACTIVE_ALPHA, INACTIVE_ICON_ALPHA = 0.75, 0.22, 0.75

function NavBar.order(tabs)
    local pages = {}
    for key, tab in pairs(tabs) do
        pages[#pages + 1] = { key = key, icon = tab.icon, label = tab.label, short = tab.short or tab.label,
            order = tab.order }
    end
    table.sort(pages, function(a, b)
        local oa, ob = a.order or math.huge, b.order or math.huge
        if oa ~= ob then
            return oa < ob
        end
        return a.key < b.key
    end)
    return pages
end

function NavBar.pick(tabs, key, saved)
    if key and tabs[key] then
        return key
    elseif saved and tabs[saved] then
        return saved
    end
    local first = NavBar.order(tabs)[1]
    return first and first.key
end

local function showLabel(button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText(button.label or "")
    GameTooltip:Show()
end

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

local function newButton(bar, onSelect)
    local theme = ns.Theme
    local button = CreateFrame("Button", nil, bar.frame)
    button:SetSize(NavBar.WIDTH - 2, NavBar.BUTTON)
    local accent = theme.colors.title
    button.active = button:CreateTexture(nil, "BACKGROUND")
    button.active:SetAllPoints()
    button.active:SetColorTexture(accent.r, accent.g, accent.b, ACTIVE_ALPHA)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(ICON, ICON)
    button.icon:SetPoint("TOP", 0, -PAD)
    button.text = button:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    button.text:SetPoint("TOPLEFT", 1, -(PAD + ICON + 2))
    button.text:SetPoint("TOPRIGHT", -1, -(PAD + ICON + 2))
    button.text:SetJustifyH("CENTER")
    button.text:SetWordWrap(false)
    button:SetHighlightTexture(HIGHLIGHT_TEXTURE, "ADD")
    button:SetScript("OnClick", function(self)
        onSelect(self.key)
    end)
    button:SetScript("OnEnter", showLabel)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

function NavBar.new(parent, onSelect)
    local bar = { frame = CreateFrame("Frame", nil, parent), buttons = {} }
    bar.frame:SetWidth(NavBar.WIDTH)
    local back = bar.frame:CreateTexture(nil, "BACKGROUND")
    back:SetPoint("TOPLEFT")
    back:SetPoint("TOPRIGHT")
    back:SetColorTexture(0, 0, 0, BACK_ALPHA)
    function bar.render(pages)
        for index, page in ipairs(pages) do
            local button = bar.buttons[index] or newButton(bar, onSelect)
            bar.buttons[index] = button
            button.key, button.label = page.key, page.label
            button.icon:SetTexture(page.icon or UNKNOWN_ICON)
            button.text:SetText(page.short or page.label or "")
            button:ClearAllPoints()
            button:SetPoint("TOP", bar.frame, "TOP", 0, -(PAD + (index - 1) * (NavBar.BUTTON + GAP)))
            button:Show()
        end
        for index = #pages + 1, #bar.buttons do
            bar.buttons[index]:Hide()
        end
        back:SetHeight(PAD * 2 + #pages * NavBar.BUTTON + math.max(0, #pages - 1) * GAP)
    end
    function bar.setActive(key)
        local theme = ns.Theme
        for _, button in ipairs(bar.buttons) do
            local active = button:IsShown() and button.key == key
            button.active:SetShown(active)
            setColor(button.text, active and theme.colors.title or theme.colors.muted)
            button.icon:SetAlpha(active and 1 or INACTIVE_ICON_ALPHA)
        end
    end
    return bar
end
