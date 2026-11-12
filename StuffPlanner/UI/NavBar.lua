-- CONTRAT
-- Barre de navigation : onglets latéraux à la Blizzard (grimoire, métiers), collés hors du bord gauche de la
-- fenêtre principale ; libellé au survol, page active surlignée. Charger après Theme.lua, avant MainFrame.lua.
--   ns.NavBar.order(tabs) -> {{key, icon, label, order}...} : tabs = {[key] = tab}, triés par tab.order
--     (sans ordre : après, par clé) ; pur
--   ns.NavBar.pick(tabs, key?, saved?) -> clé ouverte : key si inscrite, sinon saved, sinon la première ; nil
--     sans page ; pur
--   ns.NavBar.new(parent, onSelect) -> bar ; bar.frame (largeur NavBar.WIDTH, à ancrer par
--     l'appelant hors de la fenêtre, TOPRIGHT sur son TOPLEFT) ;
--     bar.render(pages) : un bouton par page (NavBar.order), clic = onSelect(key) ; bar.setActive(key)
--   ns.NavBar.WIDTH, ns.NavBar.BUTTON

local _, ns = ...

local NavBar = {}
ns.NavBar = NavBar

NavBar.BUTTON = 32
NavBar.WIDTH = NavBar.BUTTON + 4

local GAP = 14
local UNKNOWN_ICON = 134400
local TAB_TEXTURE = "Interface\\SpellBook\\SpellBook-SkillLineTab"
local HIGHLIGHT_TEXTURE = "Interface\\Buttons\\ButtonHilight-Square"
local CHECKED_TEXTURE = "Interface\\Buttons\\CheckButtonHilight"
local TAB_ART, TAB_ART_X, TAB_ART_Y = 64, 3, 11

function NavBar.order(tabs)
    local pages = {}
    for key, tab in pairs(tabs) do
        pages[#pages + 1] = { key = key, icon = tab.icon, label = tab.label, order = tab.order }
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

local function hideLabel()
    GameTooltip:Hide()
end

-- Onglet de grimoire Blizzard retourné : l'attache plate de la texture vient contre le bord gauche de la fenêtre.
local function newButton(bar, onSelect)
    local button = CreateFrame("Button", nil, bar.frame)
    button:SetSize(NavBar.BUTTON, NavBar.BUTTON)
    local back = button:CreateTexture(nil, "BACKGROUND")
    back:SetTexture(TAB_TEXTURE)
    back:SetTexCoord(1, 0, 0, 1)
    back:SetSize(TAB_ART, TAB_ART)
    back:SetPoint("TOPRIGHT", TAB_ART_X, TAB_ART_Y)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button:SetHighlightTexture(HIGHLIGHT_TEXTURE, "ADD")
    button.active = button:CreateTexture(nil, "OVERLAY")
    button.active:SetTexture(CHECKED_TEXTURE)
    button.active:SetBlendMode("ADD")
    button.active:SetAllPoints()
    button:SetScript("OnClick", function(self)
        onSelect(self.key)
    end)
    button:SetScript("OnEnter", showLabel)
    button:SetScript("OnLeave", hideLabel)
    return button
end

function NavBar.new(parent, onSelect)
    local bar = { frame = CreateFrame("Frame", nil, parent), buttons = {} }
    bar.frame:SetWidth(NavBar.WIDTH)
    function bar.render(pages)
        for index, page in ipairs(pages) do
            local button = bar.buttons[index] or newButton(bar, onSelect)
            bar.buttons[index] = button
            button.key, button.label = page.key, page.label
            button.icon:SetTexture(page.icon or UNKNOWN_ICON)
            button:ClearAllPoints()
            button:SetPoint("TOP", bar.frame, "TOP", 0, -(index - 1) * (NavBar.BUTTON + GAP))
            button:Show()
        end
        for index = #pages + 1, #bar.buttons do
            bar.buttons[index]:Hide()
        end
    end
    function bar.setActive(key)
        for _, button in ipairs(bar.buttons) do
            local active = button:IsShown() and button.key == key
            button.active:SetShown(active)
        end
    end
    return bar
end
