-- CONTRAT
-- Clic sur une ligne d'objet, partagé par les onglets Zone, Parcours, Équipement et le mini-suivi.
-- Modules lus à l'appel (QuestDetail, SourceDetail peuvent se charger après).
--   ns.RowActions.click(questID, itemID, itemSource) : info-bulle fermée d'abord (la fiche demande noms
--     et objets au client, leur arrivée reconstruirait l'info-bulle ouverte) ; objet sélectionné (select) ;
--     Alt : épinglé / retiré de la liste cible (togglePin) ;
--     Ctrl : essayage de itemID (Compat.DressUpItem) ; quête : Maj = repère (QuestDetail.waypoint), sinon
--     fiche (QuestDetail.show) ; sans quête : fiche de la source (SourceDetail.show) si itemID et
--     itemSource sont connus.
--   togglePin(itemID) : WishlistStore.toggle, message dans la discussion (épinglé, retiré, liste pleine)
--   select(questID, itemID, reveal?) : sélection courante (une seule, gardée jusqu'au prochain clic),
--     émet SP_SELECTION_CHANGED(reveal) ; rien sans itemID. reveal : les listes font défiler jusqu'à elle.
--   isSelected(questID, itemID) -> bool : même objet et même quête (nil = sans quête)
--   menu(questID, itemID, itemSource) : menu clic droit (RowMenuPresenter.entries, RowMenu.open) : fiche,
--     repère (quête simple) ou suivre (suite de quêtes) / ne plus suivre (Follow), épingler / désépingler,
--     essayer ; objet sélectionné
--   mark(button, questID, itemID, height?) : cadre de sélection (créé au premier appel) affiché si
--     isSelected ; height : cadre limité au haut du bouton (ligne dépliée : sans ses sous-lignes)

local _, ns = ...

local RowActions = {}
ns.RowActions = RowActions

local EDGE = 2
local FILL_ALPHA = 0.12

local selected -- {questID, itemID}

function RowActions.select(questID, itemID, reveal)
    if not itemID then
        return
    end
    selected = { questID = questID, itemID = itemID }
    ns:Send("SP_SELECTION_CHANGED", reveal == true)
end

function RowActions.isSelected(questID, itemID)
    return selected ~= nil and itemID ~= nil and selected.itemID == itemID and selected.questID == questID
end

local function edge(frame, color, a, b, width, height)
    local texture = frame:CreateTexture(nil, "OVERLAY")
    texture:SetColorTexture(color.r, color.g, color.b, 1)
    texture:SetPoint(a)
    texture:SetPoint(b)
    if width then
        texture:SetWidth(width)
    else
        texture:SetHeight(height)
    end
end

local function selectionFrame(button)
    local color = ns.Theme.colors.title
    local frame = CreateFrame("Frame", nil, button)
    frame:SetAllPoints()
    local fill = frame:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(color.r, color.g, color.b, FILL_ALPHA)
    edge(frame, color, "TOPLEFT", "TOPRIGHT", nil, EDGE)
    edge(frame, color, "BOTTOMLEFT", "BOTTOMRIGHT", nil, EDGE)
    edge(frame, color, "TOPLEFT", "BOTTOMLEFT", EDGE)
    edge(frame, color, "TOPRIGHT", "BOTTOMRIGHT", EDGE)
    return frame
end

function RowActions.mark(button, questID, itemID, height)
    local shown = RowActions.isSelected(questID, itemID)
    if shown and not button.selection then
        button.selection = selectionFrame(button)
    end
    local frame = button.selection
    if frame then
        frame:ClearAllPoints()
        if height then
            frame:SetPoint("TOPLEFT")
            frame:SetPoint("TOPRIGHT")
            frame:SetHeight(height)
        else
            frame:SetAllPoints()
        end
        frame:SetShown(shown)
    end
end

function RowActions.togglePin(itemID)
    if not itemID then
        return
    end
    local L = ns.L
    local pinned = ns.WishlistStore.toggle(itemID)
    local name = ns.Names.item(itemID)
    if pinned == nil then
        print(L.WISHLIST_FULL)
    else
        print((pinned and L.WISHLIST_PINNED or L.WISHLIST_UNPINNED):format(name))
    end
end

function RowActions.click(questID, itemID, itemSource)
    GameTooltip:Hide()
    if IsAltKeyDown() then
        RowActions.togglePin(itemID)
        return
    end
    RowActions.select(questID, itemID)
    if IsControlKeyDown() then
        if itemID then
            ns.Compat.DressUpItem(itemID)
        end
    elseif questID then
        if IsShiftKeyDown() then
            ns.QuestDetail.waypoint(questID)
        else
            ns.QuestDetail.show(questID)
        end
    elseif itemID and itemSource then
        ns.SourceDetail.show(itemID, itemSource)
    end
end

local function showDetails(questID, itemID, itemSource)
    if questID then
        ns.QuestDetail.show(questID)
    elseif itemID and itemSource then
        ns.SourceDetail.show(itemID, itemSource)
    end
end

local MENU_ACTIONS = {
    details = showDetails,
    waypoint = function(questID)
        ns.QuestDetail.waypoint(questID)
    end,
    follow = function(questID)
        ns.Follow.start(questID)
    end,
    unfollow = function()
        ns.Follow.stop()
    end,
    pin = function(_, itemID)
        RowActions.togglePin(itemID)
    end,
    dressup = function(_, itemID)
        ns.Compat.DressUpItem(itemID)
    end,
}
MENU_ACTIONS.unpin = MENU_ACTIONS.pin

function RowActions.menu(questID, itemID, itemSource)
    GameTooltip:Hide()
    local entries = ns.RowMenuPresenter.entries({
        questID = questID, itemID = itemID, itemSource = itemSource,
        following = ns.Follow.current(), pinned = itemID ~= nil and ns.WishlistStore.has(itemID),
        chain = questID ~= nil and ns.RowPresenter.isChain(ns.Data.quest(questID)),
    })
    if #entries == 0 then
        return
    end
    RowActions.select(questID, itemID)
    ns.RowMenu.open(entries, function(key)
        MENU_ACTIONS[key](questID, itemID, itemSource)
    end)
end

