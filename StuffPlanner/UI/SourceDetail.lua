-- CONTRAT
-- Fiche d'une source d'objet hors quête (SourcePresenter.build) : panneau accolé à droite de la
-- fenêtre principale, à la place de la fiche de quête (une seule des deux ouverte), contenu défilant.
-- Charger après DetailWidgets.lua, QuestDetail.lua et SourcePresenter.lua.
--   ns.SourceDetail.show(itemID, source) -> ouvre la fenêtre principale puis la fiche ; hors combat
--   ns.SourceDetail.hide(), isShown(), refresh()
-- Contenu : objet (survol : info-bulle de l'objet), titre (instance ou recette), sous-titre,
--   lignes « libellé : valeur », recette (survol : info-bulle du sort), composants (icône
--   Compat.GetItemIcon, « 2 × nom », survol : info-bulle de l'objet), autres sources,
--   bouton Carte (zone d'entrée, Compat.OpenWorldMap) ; sous l'objet : Épingler / Retirer et Essayer
--   (DetailWidgets.itemButtons).
-- Rafraîchie sur SP_PLAYER_CHANGED, SP_PROFILE_CHANGED et à l'arrivée des noms.

local _, ns = ...

local L = ns.L
local W = ns.DetailWidgets

local SourceDetail = {}
ns.SourceDetail = SourceDetail

local panel, content, texts, itemRow, recipeRow, mapButton, itemButtons
local lineTexts, reagentRows = {}, {}
local currentItem, currentSource, currentView
local askName = W.nameAsker(function()
    SourceDetail.refresh()
end)

local function lineText(index)
    lineTexts[index] = lineTexts[index] or W.fontString(content, ns.Theme.fonts.small)
    return lineTexts[index]
end

local function create()
    local theme = ns.Theme
    panel, content = W.newPanel()
    local function text(font, color)
        return W.fontString(content, font, color)
    end
    texts = {
        title = text(theme.fonts.title, theme.colors.title),
        subtitle = text(theme.fonts.small, theme.colors.muted),
        itemHeader = text(theme.fonts.header, theme.colors.title),
        recipeHeader = text(theme.fonts.header, theme.colors.title),
        reagentsHeader = text(theme.fonts.header, theme.colors.title),
        othersHeader = text(theme.fonts.header, theme.colors.title),
        others = text(theme.fonts.small),
    }
    texts.itemHeader:SetText(L.SOURCE_DETAIL_ITEM)
    texts.recipeHeader:SetText(L.SOURCE_DETAIL_RECIPE)
    texts.reagentsHeader:SetText(L.SOURCE_DETAIL_REAGENTS)
    texts.othersHeader:SetText(L.SOURCE_DETAIL_OTHERS)
    itemRow = W.hoverRow(content)
    recipeRow = W.hoverRow(content)
    mapButton = W.button(content, L.DETAIL_MAP)
    mapButton:SetScript("OnClick", function()
        W.openMap(currentView and currentView.mapID)
    end)
    itemButtons = W.itemButtons(content)
end

local function fillItem(view)
    local item = view.item
    itemRow.link = "item:" .. view.itemID
    itemRow.icon:SetTexture(item.icon or W.UNKNOWN_ICON)
    itemRow.name:SetText(item.name)
    W.setColor(itemRow.name, item.nameColor)
    itemRow.tag:SetText(item.badge and ns.Theme.colorize(item.badge, item.badgeColor) or "")
    ns.ItemRow.setGains(itemRow, item.gainLabel, item.gainColor, item.secondaryLabel, item.secondaryColor)
end

local function fillRecipe(view)
    recipeRow.link = "spell:" .. view.spellID
    recipeRow.icon:SetTexture(view.item.icon or W.UNKNOWN_ICON)
    recipeRow.name:SetText(view.title)
    W.setColor(recipeRow.name, ns.Theme.colors.text)
    recipeRow.tag:SetText("")
    ns.ItemRow.setGains(recipeRow, "")
end

local function placeReagents(place, view)
    local reagents = view.reagents or {}
    texts.reagentsHeader:SetShown(#reagents > 0)
    if #reagents > 0 then
        place(texts.reagentsHeader, nil, ns.Theme.spacing.padding)
    end
    for i, reagent in ipairs(reagents) do
        local row = reagentRows[i] or W.hoverRow(content)
        reagentRows[i] = row
        row.link = "item:" .. reagent.itemID
        row.icon:SetTexture(ns.Compat.GetItemIcon(reagent.itemID) or W.UNKNOWN_ICON)
        row.name:SetText(reagent.text)
        W.setColor(row.name, ns.Theme.colors.text)
        row.tag:SetText("")
        row.gain:SetText("")
        place(row, ns.Theme.spacing.rowHeight, 2)
        askName("item", reagent.itemID)
    end
    for index = #reagents + 1, #reagentRows do
        reagentRows[index]:Hide()
    end
end

local function placeLines(place, view)
    local muted = ns.Theme.hex(ns.Theme.colors.muted)
    for i, line in ipairs(view.lines) do
        local text = lineText(i)
        text:SetText("|c" .. muted .. line.label .. " :|r " .. line.text)
        place(text, nil, 2)
    end
    for index = #view.lines + 1, #lineTexts do
        lineTexts[index]:Hide()
    end
end

local function render(view)
    local theme = ns.Theme
    local pad = theme.spacing.padding
    local place, finish = W.stacker(content)
    texts.title:SetText(view.title)
    place(texts.title)
    texts.subtitle:SetText(view.subtitle)
    place(texts.subtitle, nil, 2)
    placeLines(place, view)
    local isCraft = view.spellID ~= nil
    mapButton:SetShown(not isCraft)
    if not isCraft then
        mapButton:SetEnabled(view.mapID ~= nil)
        place(mapButton, W.BUTTON_HEIGHT, theme.spacing.gap)
    end
    place(texts.itemHeader, nil, pad)
    fillItem(view)
    place(itemRow, theme.spacing.rowHeight, 2)
    itemButtons.place(place, view.itemID, 2)
    texts.recipeHeader:SetShown(isCraft)
    recipeRow:SetShown(isCraft)
    if isCraft then
        place(texts.recipeHeader, nil, pad)
        fillRecipe(view)
        place(recipeRow, theme.spacing.rowHeight, 2)
    end
    placeReagents(place, view)
    local hasOthers = #view.others > 0
    texts.othersHeader:SetShown(hasOthers)
    texts.others:SetShown(hasOthers)
    if hasOthers then
        place(texts.othersHeader, nil, pad)
        texts.others:SetText(table.concat(view.others, "\n"))
        place(texts.others, nil, 2)
    end
    finish()
    askName("item", view.itemID)
end

function SourceDetail.isShown()
    return panel ~= nil and panel:IsShown()
end

function SourceDetail.hide()
    if panel then
        panel:Hide()
    end
end

function SourceDetail.refresh()
    if not SourceDetail.isShown() or InCombatLockdown() then
        return
    end
    local data = ns.Data
    currentView = data.ready() and ns.SourcePresenter.build(currentItem, currentSource, ns.Player.snapshot(),
        ns.Profiles.active(), data, ns.RouteResults.secondsOf(currentSource)) or nil
    if not currentView then
        panel:Hide()
        return
    end
    render(currentView)
end

function SourceDetail.show(itemID, source)
    if InCombatLockdown() or not itemID or not source then
        return
    end
    if not ns.MainFrame.isShown() then
        ns.MainFrame.show()
    end
    if not panel then
        create()
    end
    ns.QuestDetail.hide()
    currentItem, currentSource = itemID, source
    panel:Show()
    SourceDetail.refresh()
end

ns:On("SP_PLAYER_CHANGED", SourceDetail.refresh)
ns:On("SP_PROFILE_CHANGED", SourceDetail.refresh)
ns:On("SP_WISHLIST_CHANGED", SourceDetail.refresh)
