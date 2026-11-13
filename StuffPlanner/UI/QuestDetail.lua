-- CONTRAT
-- Fiche d'une quête (DetailPresenter.build) : panneau accolé à droite de la fenêtre principale,
-- contenu défilant (DetailWidgets). Charger après DetailWidgets.lua, DetailPresenter.lua et
-- Integrations/TomTom.lua, QuestTooltip.lua, WaypointButton.lua.
--   ns.QuestDetail.show(questID, itemID?) -> ouvre la fenêtre principale (onglet gardé) puis la fiche ;
--     hors combat ; itemID (objet cliqué) : Épingler / Retirer et Essayer sous Repère et Carte
--   ns.QuestDetail.hide(), isShown(), refresh()
--   ns.QuestDetail.reopen() : réaffiche la dernière fiche (sortie du combat, MainFrame) ; rien sans fiche
--   ns.QuestDetail.waypoint(questID) -> bool : repère vers le donneur (ns.Waypoint, clé questID) ou, si une
--     suite de quêtes reste à faire, vers celui de sa première quête disponible (clé = cette quête) ;
--     false sans position
-- Survol d'une quête de la suite ou des prérequis : ns.QuestTooltip (détails de cette quête).
-- Contenu : titre, niveau, état (journal, niveau requis, prérequis), condition, zone, badge, donneur, bouton
--   Repère ou Suivre pour une suite de quêtes (UI/WaypointButton.lua), bouton Carte
--   (Compat.OpenWorldMap, puis fenêtre principale cachée), récompenses, choix (meilleur signalé),
--   suite de quêtes restante (sinon prérequis faits) ; ligne « Commence par » sous le donneur.
--   Survol d'un objet : info-bulle du client.
-- Enfant de la fenêtre principale : cachée, déplacée et mise à l'échelle avec elle (Échap compris).
-- Rafraîchie sur SP_PLAYER_CHANGED, SP_PROFILE_CHANGED, SP_DATA_READY, SP_QUEST_OBSERVED,
-- SP_QUEST_LOG_CHANGED, SP_WISHLIST_CHANGED et à l'arrivée des noms ; bouton Repère suivi sur
-- SP_WAYPOINT_CHANGED, SP_FOLLOW_CHANGED.

local _, ns = ...

local L = ns.L
local W = ns.DetailWidgets

local QuestDetail = {}
ns.QuestDetail = QuestDetail

local panel, content, texts, waypointButton, mapButton, itemButtons
local itemRows, prereqLines = {}, {}
local currentID, currentItem, currentView
local buildView
local askName = W.nameAsker(function()
    QuestDetail.refresh()
end)

local function itemRow(index)
    itemRows[index] = itemRows[index] or W.hoverRow(content)
    return itemRows[index]
end

local function fillItemRow(row, data)
    row.link = "item:" .. data.itemID
    row.icon:SetTexture(data.icon or W.UNKNOWN_ICON)
    row.name:SetText(data.name)
    W.setColor(row.name, data.nameColor)
    ns.ItemRow.setGains(row, data.gainLabel, data.gainColor, data.secondaryLabel, data.secondaryColor)
    local tags = {}
    if data.best then
        tags[#tags + 1] = ns.Theme.colorize(L.DETAIL_BEST, ns.Theme.colors.gain)
    end
    if data.badge then
        tags[#tags + 1] = ns.Theme.colorize(data.badge, data.badgeColor)
    end
    row.tag:SetText(table.concat(tags, " · "))
end

local function showQuestTooltip(hover)
    local views = {}
    for _, id in ipairs(hover.questIDs or {}) do
        views[#views + 1] = buildView(id, true)
    end
    ns.QuestTooltip.show(hover, views)
end

-- Ligne de la suite ou des prérequis ; line.hover (survol) la recouvre.
local function prereqLine(index)
    local line = prereqLines[index]
    if not line then
        line = W.fontString(content, ns.Theme.fonts.small)
        line.hover = CreateFrame("Frame", nil, content)
        line.hover:SetAllPoints(line)
        line.hover:EnableMouse(true)
        line.hover:SetScript("OnEnter", showQuestTooltip)
        line.hover:SetScript("OnLeave", ns.QuestTooltip.hide)
        prereqLines[index] = line
    end
    return line
end

local function hideLine(line)
    line:Hide()
    line.hover:Hide()
end

local function updateWaypointButton()
    waypointButton:update(currentView)
end

local function create()
    local theme = ns.Theme
    panel, content = W.newPanel()
    local function text(font, color)
        return W.fontString(content, font, color)
    end
    texts = {
        title = text(theme.fonts.title, theme.colors.title),
        level = text(theme.fonts.small, theme.colors.muted),
        state = text(theme.fonts.small),
        condition = text(theme.fonts.small, theme.colors.warning),
        zone = text(theme.fonts.small, theme.colors.muted),
        duration = text(theme.fonts.small, theme.colors.muted),
        instance = text(theme.fonts.small, theme.colors.instance),
        badge = text(theme.fonts.small, theme.colors.warning),
        giverHeader = text(theme.fonts.header, theme.colors.title),
        giver = text(theme.fonts.small),
        start = text(theme.fonts.small, theme.colors.gain),
        rewards = text(theme.fonts.header, theme.colors.title),
        choices = text(theme.fonts.header, theme.colors.title),
        prereqs = text(theme.fonts.header, theme.colors.title),
        nothing = text(theme.fonts.small, theme.colors.muted),
    }
    texts.giverHeader:SetText(L.DETAIL_GIVER_HEADER)
    texts.rewards:SetText(L.DETAIL_REWARDS)
    texts.choices:SetText(L.DETAIL_CHOICES)
    texts.prereqs:SetText(L.DETAIL_PREREQS)
    texts.nothing:SetText(L.DETAIL_NOTHING)
    waypointButton = ns.WaypointButton.new(content)
    mapButton = W.button(content, L.DETAIL_MAP)
    mapButton:SetScript("OnClick", function()
        W.openMap(currentView and currentView.mapID, currentView and currentView.waypoint)
    end)
    mapButton:SetPoint("LEFT", waypointButton, "RIGHT", theme.spacing.gap, 0)
    itemButtons = W.itemButtons(content)
end

-- Place un texte s'il n'est pas vide, sinon le cache.
local function placeOptional(place, region, text, gapBefore)
    region:SetText(text or "")
    region:SetShown(text ~= nil and text ~= "")
    if text and text ~= "" then
        place(region, nil, gapBefore)
    end
end

local function placeItems(place, rows, header, firstIndex)
    if #rows == 0 then
        header:Hide()
        return firstIndex
    end
    place(header, nil, ns.Theme.spacing.padding)
    for i, data in ipairs(rows) do
        local row = itemRow(firstIndex + i - 1)
        fillItemRow(row, data)
        place(row, ns.Theme.spacing.rowHeight, 2)
        askName("item", data.itemID)
    end
    return firstIndex + #rows
end

-- Suite de quêtes restante si elle existe, sinon prérequis (tous faits).
local function placePrereqs(place, view)
    local chain = view.chain
    local lines = chain or view.prereqs
    if #lines == 0 then
        texts.prereqs:Hide()
        return 1
    end
    texts.prereqs:SetText(chain and L.DETAIL_CHAIN or L.DETAIL_PREREQS)
    place(texts.prereqs, nil, ns.Theme.spacing.padding)
    for i, entry in ipairs(lines) do
        local line = prereqLine(i)
        line:SetText(entry.done and (entry.text .. " (" .. L.DETAIL_DONE .. ")") or entry.text)
        W.setColor(line, entry.color)
        place(line, nil, 2)
        line.hover.questIDs = entry.questIDs or { entry.questID }
        line.hover:Show()
        for _, id in ipairs(line.hover.questIDs) do
            askName("quest", id)
        end
    end
    return #lines + 1
end

local function render(view)
    local pad = ns.Theme.spacing.padding
    local place, finish = W.stacker(content)
    texts.title:SetText(view.title)
    place(texts.title)
    placeOptional(place, texts.level, view.levelText, 2)
    W.setColor(texts.state, view.stateColor)
    placeOptional(place, texts.state, view.stateText, 2)
    placeOptional(place, texts.condition, view.conditionText, 2)
    placeOptional(place, texts.zone, view.zoneText, 2)
    placeOptional(place, texts.duration, view.durationText, 2)
    placeOptional(place, texts.instance, view.instanceText, 2)
    placeOptional(place, texts.badge, view.badge, 2)
    place(texts.giverHeader, nil, pad)
    texts.giver:SetText(view.giverText)
    place(texts.giver, nil, 2)
    placeOptional(place, texts.start, view.startText, 2)
    place(waypointButton, W.BUTTON_HEIGHT, ns.Theme.spacing.gap)
    updateWaypointButton()
    mapButton:SetEnabled(view.mapID ~= nil)
    itemButtons.place(place, currentItem, 2)
    local nextRow = placeItems(place, view.rewards, texts.rewards, 1)
    nextRow = placeItems(place, view.choices, texts.choices, nextRow)
    texts.nothing:SetShown(nextRow == 1)
    if nextRow == 1 then
        place(texts.nothing, nil, pad)
    end
    for index = nextRow, #itemRows do
        itemRows[index]:Hide()
    end
    for index = placePrereqs(place, view), #prereqLines do
        hideLine(prereqLines[index])
    end
    finish()
    askName("quest", view.questID)
end

function buildView(questID, withScores)
    local data = ns.Data
    if not data.ready() then
        return nil
    end
    local player = withScores and ns.Player.snapshot() or nil
    local profile = withScores and ns.Profiles.active() or nil
    return ns.DetailPresenter.build(questID, player, profile, data,
        { isDone = ns.Compat.IsQuestCompleted, isInLog = ns.Compat.IsOnQuest,
            seconds = ns.RouteResults.secondsOf({ type = "quest", id = questID }) })
end

function QuestDetail.isShown()
    return panel ~= nil and panel:IsShown()
end

function QuestDetail.refresh()
    if not QuestDetail.isShown() or InCombatLockdown() then
        return
    end
    currentView = buildView(currentID, true)
    if not currentView then
        panel:Hide()
        return
    end
    render(currentView)
end

function QuestDetail.show(questID, itemID)
    if InCombatLockdown() or not questID then
        return
    end
    if not ns.MainFrame.isShown() then
        ns.MainFrame.show()
    end
    if not panel then
        create()
    end
    if ns.SourceDetail then
        ns.SourceDetail.hide()
    end
    currentID, currentItem = questID, itemID
    panel:Show()
    QuestDetail.refresh()
end

function QuestDetail.reopen()
    if panel and currentID and not InCombatLockdown() then
        panel:Show()
        QuestDetail.refresh()
    end
end

function QuestDetail.hide()
    if panel then
        panel:Hide()
    end
end

function QuestDetail.waypoint(questID)
    local view = questID and buildView(questID, false)
    local target = view and view.waypoint
    if not target then
        return false
    end
    ns.Waypoint.set(target.mapID, target.x, target.y, target.title, target.questID, target.giver, target.npcID)
    if currentView and currentView.questID == questID then
        updateWaypointButton()
    end
    return true
end

ns:On("SP_PLAYER_CHANGED", QuestDetail.refresh)
ns:On("SP_PROFILE_CHANGED", QuestDetail.refresh)
ns:On("SP_QUEST_OBSERVED", QuestDetail.refresh)
ns:On("SP_QUEST_LOG_CHANGED", QuestDetail.refresh)
ns:On("SP_DATA_READY", QuestDetail.refresh)
ns:On("SP_WISHLIST_CHANGED", QuestDetail.refresh)
local function onWaypointChanged()
    if waypointButton and QuestDetail.isShown() then
        updateWaypointButton()
    end
end
ns:On("SP_FOLLOW_CHANGED", onWaypointChanged)
ns:On("SP_WAYPOINT_CHANGED", onWaypointChanged)
