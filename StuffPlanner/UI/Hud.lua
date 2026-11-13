-- CONTRAT
-- Cadre flottant unique (FloatingFrame) : un mode à la fois, choisi par HudPresenter (donjon > suivi > zone).
-- Charger après FloatingFrame.lua, HudPresenter.lua, RowMenu.lua et Options.lua, avant MiniTracker,
-- FollowWindow, DungeonPanel (fournisseurs).
--   ns.Hud.addMode(key, provider) ; provider = {
--     order (petit = prioritaire), available() -> bool, create(body) -> frame (une fois, enfant de body),
--     render(frame) -> title, height (contenu à jour, hauteur du corps),
--     label, icon (pastille du mode), option (clé ns.Options booléenne qui active le mode : « Masquer ce mode »),
--     action = {icon, hint, onClick} (bouton en haut à droite, facultatif) }
--   ns.Hud.refresh() : mode recalculé et rendu ; regroupé à l'image suivante, reporté après le combat
--   ns.Hud.draggable(region) : glisser region déplace le cadre (sauf hud.locked)
--   ns.Hud.resetPosition() ; ns.Hud.current() -> mode affiché | nil
-- En-tête : titre, pastilles des modes disponibles (HudPresenter.pills ; clic = ce mode, gardé tant que les
-- modes disponibles ne changent pas ; survol = nom), flèche replier / déplier. Clic droit sur l'en-tête :
-- menu (HudPresenter.menuEntries : Replier, Verrouiller, Masquer ce mode, Ouvrir la fenêtre, Réglages).
-- Aucun mode disponible : cadre caché.
-- Sauvegarde : StuffPlannerDB.ui.hud = {point, relativePoint, x, y, collapsed} ; options hud.alpha (fond),
-- hud.locked, hud.lines (lignes du mode zone, lu par MiniTracker). Créé à PLAYER_LOGIN.

local _, ns = ...

local L = ns.L

local Hud = {}
ns.Hud = Hud

local WIDTH = 260
local HEADER_HEIGHT = 20
local ACTION_SIZE = 20
local PILL_SIZE = 14
local PILL_GAP = 3
local ARROW_SIZE = 12
local INACTIVE_ALPHA = 0.45
local BLACK = { r = 0, g = 0, b = 0 }
local ARROW_TEXTURE = "Interface\\ChatFrame\\ChatFrameExpandArrow"
local HIGHLIGHT_TEXTURE = "Interface\\Buttons\\ButtonHilight-Square"

local frame, header, titleText, pillBar, arrow, action, body, background
local pills = {}
local modes, ordered = {}, {}
local state = {}
local currentKey
local pending = false

local function settings()
    return ns.DB.account("ui", "hud")
end

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

local function hint(owner, text)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddLine(text, 1, 1, 1)
    GameTooltip:Show()
end

local function availableModes()
    local list = {}
    for _, key in ipairs(ordered) do
        if modes[key].available() then
            list[#list + 1] = key
        end
    end
    return list
end

local function setAction(spec)
    action.spec = spec
    action:SetShown(spec ~= nil)
    if spec then
        action.icon:SetTexture(spec.icon)
    end
end

-- Flèche vers la droite (replié) ou vers le bas (déplié), comme ns.Section.
local function setArrow(collapsed)
    if collapsed then
        arrow.icon:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
    else
        arrow.icon:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
    end
end

local function newPill()
    local pill = CreateFrame("Button", nil, pillBar)
    pill:SetSize(PILL_SIZE, PILL_SIZE)
    pill.icon = pill:CreateTexture(nil, "ARTWORK")
    pill.icon:SetAllPoints()
    pill:SetHighlightTexture(HIGHLIGHT_TEXTURE, "ADD")
    pill:SetScript("OnClick", function(self)
        state.forced = self.key
        Hud.refresh()
    end)
    pill:SetScript("OnEnter", function(self)
        hint(self, modes[self.key].label or self.key)
    end)
    pill:SetScript("OnLeave", ns.FloatingFrame.hideHint)
    return pill
end

local function renderPills(available, key)
    local list = ns.HudPresenter.pills(available, key)
    for index, spec in ipairs(list) do
        local pill = pills[index] or newPill()
        pills[index] = pill
        pill.key = spec.key
        pill.icon:SetTexture(modes[spec.key].icon)
        pill.icon:SetDesaturated(not spec.active)
        pill.icon:SetAlpha(spec.active and 1 or INACTIVE_ALPHA)
        pill:ClearAllPoints()
        pill:SetPoint("LEFT", pillBar, "LEFT", (index - 1) * (PILL_SIZE + PILL_GAP), 0)
        pill:Show()
    end
    for index = #list + 1, #pills do
        pills[index]:Hide()
    end
    pillBar:SetWidth(math.max(1, #list * (PILL_SIZE + PILL_GAP)))
end

local function render()
    local available = availableModes()
    local key = ns.HudPresenter.resolve(available, state)
    for name, mode in pairs(modes) do
        if mode.frame then
            mode.frame:SetShown(name == key)
        end
    end
    currentKey = key
    if not key then
        frame:Hide()
        return
    end
    local mode = modes[key]
    if not mode.frame then
        mode.frame = mode.create(body)
        mode.frame:SetPoint("TOPLEFT")
        mode.frame:SetPoint("RIGHT")
    end
    local collapsed = settings().collapsed
    local title, height = mode.render(mode.frame)
    titleText:SetText(title or "")
    renderPills(available, key)
    setArrow(collapsed)
    setAction(mode.action)
    mode.frame:SetShown(not collapsed)
    local pad = ns.Theme.spacing.gap
    frame:SetHeight(pad + HEADER_HEIGHT + (collapsed and 0 or (height or 0) + pad))
    frame:Show()
end

function Hud.refresh()
    if not frame or pending then
        return
    end
    pending = true
    C_Timer.After(0, function()
        ns:RunOutOfCombat(function()
            pending = false
            render()
        end)
    end)
end

local function toggleCollapsed()
    local saved = settings()
    saved.collapsed = not saved.collapsed or nil
    Hud.refresh()
end

local MENU_ACTIONS = {
    collapse = toggleCollapsed,
    lock = function()
        ns.Options.set("hud.locked", not ns.Options.get("hud.locked"))
    end,
    hide = function()
        local mode = currentKey and modes[currentKey]
        if mode and mode.option then
            ns.Options.set(mode.option, false)
            Hud.refresh()
        end
    end,
    open = function()
        ns.MainFrame.show()
    end,
    options = function()
        ns.OptionsPanel.open()
    end,
}

local function openMenu()
    local mode = currentKey and modes[currentKey]
    local entries = ns.HudPresenter.menuEntries({
        collapsed = settings().collapsed == true,
        locked = ns.Options.get("hud.locked") == true,
        canHide = mode ~= nil and mode.option ~= nil,
    })
    ns.RowMenu.open(entries, function(key)
        if MENU_ACTIONS[key] then
            MENU_ACTIONS[key]()
        end
    end)
end

local function createAction()
    action = CreateFrame("Button", nil, frame)
    action:SetSize(ACTION_SIZE, ACTION_SIZE)
    action:SetPoint("TOPRIGHT", -ns.Theme.spacing.gap / 2, -ns.Theme.spacing.gap / 2)
    action.icon = action:CreateTexture(nil, "ARTWORK")
    action.icon:SetAllPoints()
    action:SetHighlightTexture(HIGHLIGHT_TEXTURE, "ADD")
    action:SetScript("OnClick", function(self)
        if self.spec then
            self.spec.onClick()
        end
    end)
    action:SetScript("OnEnter", function(self)
        if self.spec then
            hint(self, self.spec.hint)
        end
    end)
    action:SetScript("OnLeave", ns.FloatingFrame.hideHint)
end

local function createArrow(pad)
    arrow = CreateFrame("Button", nil, frame)
    arrow:SetSize(HEADER_HEIGHT, HEADER_HEIGHT)
    arrow:SetPoint("RIGHT", action, "LEFT", -pad / 2, 0)
    arrow.icon = arrow:CreateTexture(nil, "ARTWORK")
    arrow.icon:SetSize(ARROW_SIZE, ARROW_SIZE)
    arrow.icon:SetPoint("CENTER")
    arrow.icon:SetTexture(ARROW_TEXTURE)
    arrow:SetHighlightTexture(HIGHLIGHT_TEXTURE, "ADD")
    arrow:SetScript("OnClick", toggleCollapsed)
    arrow:SetScript("OnEnter", function(self)
        hint(self, L.HELP_DO_COLLAPSE)
    end)
    arrow:SetScript("OnLeave", ns.FloatingFrame.hideHint)
end

local function createHeader(theme, pad)
    createArrow(pad)
    pillBar = CreateFrame("Frame", nil, frame)
    pillBar:SetHeight(PILL_SIZE)
    pillBar:SetPoint("RIGHT", arrow, "LEFT", -pad / 2, 0)
    header = CreateFrame("Button", nil, frame)
    header:SetHeight(HEADER_HEIGHT)
    header:SetPoint("TOPLEFT", pad, -pad / 2)
    header:SetPoint("RIGHT", pillBar, "LEFT", -pad / 2, 0)
    header:RegisterForClicks("RightButtonUp")
    header:SetScript("OnClick", openMenu)
    header:SetScript("OnEnter", function(self)
        hint(self, L.HUD_TITLE_HINT)
    end)
    header:SetScript("OnLeave", ns.FloatingFrame.hideHint)
    frame.draggable(header)
    titleText = header:CreateFontString(nil, "OVERLAY", theme.fonts.header)
    titleText:SetPoint("LEFT")
    titleText:SetPoint("RIGHT")
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(false)
    setColor(titleText, theme.colors.title)
end

local function applyAlpha()
    if background then
        local bg = ns.Skin.name() == "blizzard" and BLACK or ns.Theme.colors.background
        background:SetColorTexture(bg.r, bg.g, bg.b, ns.Options.get("hud.alpha"))
    end
end

local function create()
    local theme = ns.Theme
    local pad = theme.spacing.gap
    frame = ns.FloatingFrame.new({ width = WIDTH, saved = settings, locked = "hud.locked", alpha = 0,
        default = { point = "RIGHT", x = -80, y = 120 } })
    background = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    background:SetAllPoints()
    applyAlpha()
    createAction()
    createHeader(theme, pad)
    body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    body:SetPoint("RIGHT", frame, "RIGHT", -pad, 0)
    body:SetHeight(1)
    frame:Hide()
end

function Hud.addMode(key, provider)
    modes[key] = provider
    ordered[#ordered + 1] = key
    table.sort(ordered, function(a, b) return modes[a].order < modes[b].order end)
    Hud.refresh()
end

function Hud.draggable(region)
    if frame then
        frame.draggable(region)
    end
end

function Hud.current()
    return currentKey
end

function Hud.resetPosition()
    if frame then
        frame.resetPosition()
    end
end

ns:On("SP_OPTION_CHANGED", function(key)
    if key == "hud.alpha" then
        applyAlpha()
    end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
    create()
    Hud.refresh()
end)
