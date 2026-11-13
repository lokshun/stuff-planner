-- CONTRAT
-- Étoile d'épingle d'une ligne d'objet (ns.ItemRow). Charger avant ItemRow.lua.
--   ns.PinStar.attach(button) : crée button.star (bouton 14 px, cachée) ; à placer par l'appelant
--   ns.PinStar.update(button) : pleine si button.view.itemID est dans la liste cible (WishlistStore.has),
--     contour pâle si la ligne ou l'étoile est survolée, cachée sinon ou sans objet
-- Clic = RowActions.togglePin ; survol : Épingler / Désépingler. Toutes les étoiles relues sur
-- SP_WISHLIST_CHANGED.

local _, ns = ...

local PinStar = {}
ns.PinStar = PinStar

local STAR_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"
local STAR_SIZE = 14
local STAR_HOVER_ALPHA = 0.45

local starred = setmetatable({}, { __mode = "k" }) -- boutons à étoile

function PinStar.update(button)
    local star = button.star
    if not star then
        return
    end
    local itemID = button.view and button.view.itemID
    local pinned = itemID ~= nil and ns.WishlistStore.has(itemID)
    local hover = itemID ~= nil and (button:IsMouseOver() or star:IsMouseOver())
    star:SetShown(pinned or hover)
    star.texture:SetDesaturated(not pinned)
    star.texture:SetAlpha(pinned and 1 or STAR_HOVER_ALPHA)
end

local function onStarClick(star)
    local view = star:GetParent().view
    ns.RowActions.togglePin(view and view.itemID)
end

local function onStarEnter(star)
    local button = star:GetParent()
    local itemID = button.view and button.view.itemID
    PinStar.update(button)
    if itemID then
        GameTooltip:SetOwner(star, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.WishlistStore.has(itemID) and ns.L.WISHLIST_UNPIN or ns.L.WISHLIST_PIN)
        GameTooltip:Show()
    end
end

local function onStarLeave(star)
    GameTooltip:Hide()
    PinStar.update(star:GetParent())
end

function PinStar.attach(button)
    local star = CreateFrame("Button", nil, button)
    star:SetSize(STAR_SIZE, STAR_SIZE)
    star.texture = star:CreateTexture(nil, "OVERLAY")
    star.texture:SetAllPoints()
    star.texture:SetTexture(STAR_ICON)
    star:SetScript("OnClick", onStarClick)
    star:SetScript("OnEnter", onStarEnter)
    star:SetScript("OnLeave", onStarLeave)
    star:Hide()
    button.star = star
    starred[button] = true
end

ns:On("SP_WISHLIST_CHANGED", function()
    for button in pairs(starred) do
        PinStar.update(button)
    end
end)
