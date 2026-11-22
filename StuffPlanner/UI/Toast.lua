-- CONTRAT
-- Bandeau d'avis en haut de l'écran (fond sombre, filets dorés, police du jeu), commun au toast d'entrée de zone
-- et à l'alerte de butin. Cadre créé au premier affichage. Charger après Theme.lua.
--   ns.Toast.new(opts) -> toast ; opts = {offsetY (px depuis le haut), duration (s), onClick(toast)?,
--     onEnter(frame, toast)? (survol ; info-bulle), icon (bool : place d'une icône à gauche)}
--   toast:show(text, icon?) : texte (et icône si opts.icon), largeur ajustée, masqué après duration
--     (un nouvel affichage relance le délai) ; toast:hide() ; toast.data : libre (appelant)
-- Clic gauche : opts.onClick, sinon masqué. Aucun cadre sécurisé : affichable en combat.

local _, ns = ...

local Toast = {}
ns.Toast = Toast

local HEIGHT = 34
local ICON_SIZE = 24

local function build(toast)
    local theme, opts = ns.Theme, toast.opts
    local frame = CreateFrame("Button", nil, UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetHeight(HEIGHT)
    frame:SetPoint("TOP", UIParent, "TOP", 0, opts.offsetY)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    local bg = theme.colors.background
    background:SetColorTexture(bg.r, bg.g, bg.b, 0.85)
    local edge = theme.colors.border
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" } }) do
        local line = frame:CreateTexture(nil, "BORDER")
        line:SetColorTexture(edge.r, edge.g, edge.b, 0.8)
        line:SetHeight(theme.spacing.border)
        line:SetPoint(side[1])
        line:SetPoint(side[2])
    end
    local padding = theme.spacing.padding
    toast.label = frame:CreateFontString(nil, "OVERLAY", theme.fonts.header)
    if opts.icon then
        toast.icon = frame:CreateTexture(nil, "ARTWORK")
        toast.icon:SetSize(ICON_SIZE, ICON_SIZE)
        toast.icon:SetPoint("LEFT", padding, 0)
        toast.label:SetPoint("LEFT", toast.icon, "RIGHT", theme.spacing.gap, 0)
    else
        toast.label:SetPoint("CENTER")
    end
    frame:RegisterForClicks("LeftButtonUp")
    frame:SetScript("OnClick", function()
        if opts.onClick then
            opts.onClick(toast)
        else
            toast:hide()
        end
    end)
    if opts.onEnter then
        frame:SetScript("OnEnter", function(self)
            opts.onEnter(self, toast)
        end)
        frame:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    frame:Hide()
    toast.frame = frame
end

local methods = {}

function methods:show(text, icon)
    if not self.frame then
        build(self)
    end
    local padding, width = ns.Theme.spacing.padding, 0
    self.label:SetText(text)
    if self.icon then
        self.icon:SetTexture(icon)
        self.icon:SetShown(icon ~= nil)
        width = ICON_SIZE + ns.Theme.spacing.gap
    end
    self.frame:SetWidth(self.label:GetStringWidth() + width + 2 * padding)
    self.frame:Show()
    self.shownAt = self.shownAt + 1
    local token = self.shownAt
    C_Timer.After(self.opts.duration, function()
        if token == self.shownAt then
            self:hide()
        end
    end)
end

function methods:hide()
    if self.frame then
        self.frame:Hide()
    end
end

function Toast.new(opts)
    local toast = { opts = opts, shownAt = 0 }
    for name, method in pairs(methods) do
        toast[name] = method
    end
    return toast
end
