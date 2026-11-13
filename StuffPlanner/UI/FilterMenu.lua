-- CONTRAT
-- Bouton « Filtres (n) » / « Tri » d'une page, qui ouvre ns.RowMenu sous lui (filtres à cocher, tri), menu
-- gardé ouvert entre deux choix. Charger après Skin.lua, Chips.lua, RowMenu.lua et FilterMenuPresenter.lua.
--   ns.FilterMenu.new(parent) -> menu ; menu.button à placer par l'appelant (hauteur Chips.HEIGHT)
--   menu:update(label, build, onPick) : texte du bouton (largeur ajustée) ; build() -> entrées
--     (FilterMenuPresenter.entries), relu à l'ouverture et après chaque choix ; onPick(kind, value)
--     (FilterMenuPresenter.parse) ; menu:SetShown(on)

local _, ns = ...

local FilterMenu = {}
ns.FilterMenu = FilterMenu

local Menu = {}
Menu.__index = Menu

function FilterMenu.new(parent)
    local self = setmetatable({}, Menu)
    local button = ns.Skin.button(parent)
    button:SetHeight(ns.Chips.HEIGHT)
    button:SetScript("OnClick", function()
        self:open()
    end)
    self.button = button
    return self
end

function Menu:open()
    if not self.build then
        return
    end
    ns.RowMenu.open(self.build(), function(key)
        local kind, value = ns.FilterMenuPresenter.parse(key)
        if kind then
            self.onPick(kind, value)
        end
        return self.build()
    end, { anchor = self.button, keepOpen = true })
end

function Menu:update(label, build, onPick)
    self.build, self.onPick = build, onPick
    self.button:SetText(label)
    self.button:SetWidth(self.button:GetFontString():GetStringWidth() + 24)
end

function Menu:SetShown(on)
    self.button:SetShown(on)
end
