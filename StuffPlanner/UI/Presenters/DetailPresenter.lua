-- CONTRAT
-- Champs affichés de la fiche d'une quête et des épingles de carte. Charger après RowPresenter.lua.
-- Pur : noms par ns.Names, gains par ns.Scoring.delta, nombres par ns.Format.
--   ns.DetailPresenter.build(questID, player, profile, data [, opts]) -> view | nil (quête inconnue)
--     opts.isDone(questID) -> bool (prérequis faits), opts.isInLog ; profile nil : aucun gain affiché ;
--     opts.seconds (RouteResults.secondsOf) -> durationText (L.DETAIL_DURATION, Format.duration) | nil
--     view = {questID, title, levelText, zoneText, durationText, giverText, mapID,
--             waypoint = {questID, mapID, x, y, title, giver, npcID} | nil (donneur placé par data.npc(quest.starter),
--               giver = son nom ; suite à faire : donneur de sa première quête disponible, questID = elle),
--             chain = {{questID, text, color, start}...} | nil : étapes restantes (Chains.remaining, quête
--               exclue ; alternatives d'une autre race écartées si player), état de chacune ;
--               start = première sans prérequis manquant ;
--             startText = « Commence par » + quête et donneur de start | nil,
--             instanceText, instanceColor : « Donjon : nom » / « Raid : nom » | nil (quest.instance) ;
--               étapes de la suite marquées de même (RowPresenter.instanceTag),
--             rewards = {row...}, choices = {row...} (RowPresenter.present + best : meilleur choix
--               de gain > 0, toujours faux pour les récompenses),
--             prereqs = {{questIDs, text, done, color}...} (une alternative : noms joints, faite
--               si l'une l'est), badge, badgeColor (quête confidence 2),
--             questState, stateText, stateColor (Chains.questState, RowPresenter.state ;
--               niveau ignoré sans player)}
--     mapID = carte du donneur (de la première quête de la suite s'il y en a), sinon celle de la quête.
--   ns.DetailPresenter.waypointButton(view, followed, placed) -> {mode, label, enabled}
--     suite de quêtes (view.chain) ou quête suivie : mode "follow", L.DETAIL_UNFOLLOW si
--     followed == view.questID, sinon L.DETAIL_FOLLOW ; sinon mode "waypoint",
--     L.DETAIL_WAYPOINT_CLEAR si placed, grisé sans view.waypoint.
--   ns.DetailPresenter.pins(entries, data) -> {{questID, mapID, x, y, itemID, delta}...}
--     entries = Chat.bestInZone (triées) ; une épingle par quête, son premier objet ; donneur placé seul.

local _, ns = ...

local L = ns.L

local DetailPresenter = {}
ns.DetailPresenter = DetailPresenter

local GUESSED_QUEST = 2

local function coord(value)
    return ns.Format.number(value * 100, nil, 1)
end

-- Position du donneur de la quête : npc avec x et y, ou nil.
local function giverOf(quest, data)
    local npc = quest.starter and data.npc(quest.starter)
    if npc and npc.mapID and npc.x and npc.y then
        return npc
    end
    return nil
end

local function levelText(quest)
    local text = L.DETAIL_LEVEL:format(quest.level and tostring(quest.level) or "?")
    if quest.reqLevel then
        text = text .. " " .. L.DETAIL_REQUIRES:format(quest.reqLevel)
    end
    return text
end

local function rowsFor(list, quest, player, profile, data, markBest)
    local rows, best = {}, nil
    for i, itemID in ipairs(list or {}) do
        local delta = profile and ns.Scoring.delta(itemID, player, profile, data)
        local entry = { itemID = itemID, source = { type = "quest", id = quest.id } }
        if delta and delta.abs ~= 0 then
            entry.delta = delta
            if markBest and delta.abs > 0 and (not best or delta.abs > rows[best].delta) then
                best = i
            end
        end
        local row = ns.RowPresenter.present(entry, data)
        row.delta, row.best = entry.delta and entry.delta.abs, false
        rows[i] = row
    end
    if best then
        rows[best].best = true
    end
    return rows
end

local function prereqRows(quest, isDone)
    local rows = {}
    for _, element in ipairs(quest.prereq or {}) do
        local ids = type(element) == "table" and element or { element }
        local names, done = {}, false
        for i, id in ipairs(ids) do
            names[i] = ns.Names.quest(id)
            done = done or (isDone ~= nil and isDone(id))
        end
        rows[#rows + 1] = {
            questIDs = ids,
            text = table.concat(names, " " .. L.DETAIL_OR .. " "),
            done = done,
            color = done and ns.Theme.colors.gain or ns.Theme.colors.muted,
        }
    end
    return rows
end

local function waypointOf(questID, quest, data)
    local giver = quest and giverOf(quest, data)
    if not giver then
        return nil
    end
    local name = ns.Names.npc(giver.id or quest.starter)
    return { questID = questID, mapID = giver.mapID, x = giver.x, y = giver.y, title = ns.Names.quest(questID),
        giver = name, npcID = giver.id or quest.starter }, giver
end

-- Étapes restantes avant questID, dans l'ordre ; nil sans étape ou sur un cycle.
local function chainRows(questID, data, player, opts)
    local isAllowed = player and function(id)
        local step = data.quest(id)
        return not step or ns.Feasible.allows(step, player, opts.isDone, opts.isInLog)
    end
    local steps = ns.Chains.remaining(questID, data, opts.isDone, isAllowed or nil)
    if not steps or #steps < 2 then
        return nil
    end
    local colors, rows, start = ns.Theme.colors, {}, nil
    for i = 1, #steps - 1 do
        local id = steps[i]
        local quest = data.quest(id)
        local state = quest and ns.Chains.questState(quest, player and player.level, opts)
        local stateText, stateColor = ns.RowPresenter.state(state, quest)
        local text = L.DETAIL_CHAIN_STEP:format(i, ns.Names.quest(id))
        local tag = ns.RowPresenter.instanceTag(quest, data)
        text = tag and (text .. " [" .. tag .. "]") or text
        local row = { questID = id, start = false, color = state == "prereq" and colors.muted or colors.text,
            text = stateText ~= "" and (text .. " (" .. stateText .. ")") or text }
        if not start and state ~= "prereq" then
            start, row.start, row.color = row, true, state and stateColor or colors.gain
        end
        rows[i] = row
    end
    return rows, start
end

function DetailPresenter.build(questID, player, profile, data, opts)
    local quest = data.quest(questID)
    if not quest then
        return nil
    end
    opts = opts or {}
    local title = ns.Names.quest(questID)
    local waypoint, giver = waypointOf(questID, quest, data)
    local view = {
        questID = questID,
        title = title,
        levelText = levelText(quest),
        zoneText = quest.mapID and ns.Names.zone(quest.mapID) or "",
        durationText = opts.seconds and L.DETAIL_DURATION:format(ns.Format.duration(opts.seconds)) or nil,
        giverText = L.DETAIL_NO_GIVER,
        mapID = quest.mapID,
        rewards = rowsFor(quest.rewards, quest, player, profile, data, false),
        choices = rowsFor(quest.choices, quest, player, profile, data, true),
        prereqs = prereqRows(quest, opts.isDone),
        questState = ns.Chains.questState(quest, player and player.level, opts),
    }
    view.stateText, view.stateColor = ns.RowPresenter.state(view.questState, quest)
    local tag, tagColor = ns.RowPresenter.instanceTag(quest, data)
    if tag then
        view.instanceText = L.DETAIL_INSTANCE:format(tag, ns.Names.instance(quest.instance))
        view.instanceColor = tagColor
    end
    if giver then
        local giverName = ns.Names.npc(giver.id or quest.starter)
        view.giverText = L.DETAIL_GIVER:format(giverName, ns.Names.zone(giver.mapID), coord(giver.x), coord(giver.y))
        view.waypoint, view.mapID = waypoint, giver.mapID
    end
    local start
    view.chain, start = chainRows(questID, data, player, opts)
    if start then
        local startWaypoint, startGiver = waypointOf(start.questID, data.quest(start.questID), data)
        view.waypoint, view.mapID = startWaypoint, startGiver and startGiver.mapID or view.mapID
        view.startText = startGiver and L.DETAIL_CHAIN_START:format(startWaypoint.title, L.DETAIL_GIVER:format(
            startWaypoint.giver, ns.Names.zone(startGiver.mapID), coord(startGiver.x), coord(startGiver.y)))
            or L.DETAIL_CHAIN_START:format(ns.Names.quest(start.questID), L.DETAIL_NO_GIVER)
    end
    if quest.confidence == GUESSED_QUEST then
        view.badge, view.badgeColor = L.BADGE_UNCONFIRMED, ns.Theme.colors.warning
    end
    return view
end

function DetailPresenter.pins(entries, data)
    local pins, seen = {}, {}
    for _, entry in ipairs(entries or {}) do
        if not seen[entry.questID] then
            seen[entry.questID] = true
            local quest = data.quest(entry.questID)
            local giver = quest and giverOf(quest, data)
            if giver then
                pins[#pins + 1] = {
                    questID = entry.questID,
                    mapID = giver.mapID,
                    x = giver.x,
                    y = giver.y,
                    itemID = entry.itemID,
                    delta = entry.delta,
                }
            end
        end
    end
    return pins
end

function DetailPresenter.waypointButton(view, followed, placed)
    if view.chain or followed == view.questID then
        local label = followed == view.questID and L.DETAIL_UNFOLLOW or L.DETAIL_FOLLOW
        return { mode = "follow", label = label, enabled = true }
    end
    return {
        mode = "waypoint",
        label = placed and L.DETAIL_WAYPOINT_CLEAR or L.DETAIL_WAYPOINT,
        enabled = placed or view.waypoint ~= nil,
    }
end
