-- CONTRAT
-- Barre de navigation : colonne d'icônes à gauche de la fenêtre principale, libellé au survol, page active
-- marquée d'un cadre doré. Charger après Theme.lua, avant MainFrame.lua.
--   ns.NavBar.order(tabs) -> {{key, icon, label, order}...} : tabs = {[key] = tab}, triés par tab.order
--     (sans ordre : après, par clé) ; pur
--   ns.NavBar.pick(tabs, key?, saved?) -> clé ouverte : key si inscrite, sinon saved, sinon la première ; nil
--     sans page ; pur
--   ns.NavBar.new(parent, onSelect) -> bar ; bar.frame (largeur NavBar.WIDTH, à ancrer par l'appelant) ;
--     bar.render(pages) : un bouton par page (NavBar.order), clic = onSelect(key) ; bar.setActive(key)
--   ns.NavBar.WIDTH, ns.NavBar.BUTTON

local _, ns = ...

local NavBar = {}
ns.NavBar = NavBar

NavBar.BUTTON = 32
NavBar.WIDTH = NavBar.BUTTON + 4

local GAP = 6
local UNKNOWN_ICON = 134400

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
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(button.label or "")
    GameTooltip:Show()
end

local function hideLabel()
    GameTooltip:Hide()
end

local function activeFrame(button)
    local color = ns.Theme.colors.title
    local frame = CreateFrame("Frame", nil, button)
    frame:SetPoint("TOPLEFT", -2, 2)
    frame:SetPoint("BOTTOMRIGHT", 2, -2)
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" } }) do
        local edge = frame:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(color.r, color.g, color.b, 1)
        edge:SetHeight(2)
        edge:SetPoint(side[1])
        edge:SetPoint(side[2])
    end
    for _, side in ipairs({ { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = frame:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(color.r, color.g, color.b, 1)
        edge:SetWidth(2)
        edge:SetPoint(side[1])
        edge:SetPoint(side[2])
    end
    return frame
end

local function newButton(bar, onSelect)
    local button = CreateFrame("Button", nil, bar.frame)
    button:SetSize(NavBar.BUTTON, NavBar.BUTTON)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.15)
    button.active = activeFrame(button)
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
            button.icon:SetDesaturated(not active)
        end
    end
    return bar
end
