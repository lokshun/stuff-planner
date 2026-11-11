-- CONTRAT
-- Lignes de l'onglet Équipement : objet porté, son score, meilleure amélioration de la zone,
-- à défaut celle du palier courant du Parcours.
-- Pur : aucun appel d'API. Charger après Theme.lua, Format.lua, Scoring.lua et RowPresenter.lua.
--   ns.GearPresenter.build(player, profile, data, entries?, worn?, route?, routeAlternatives?, expanded?)
--     -> {row, …} (17 emplacements,
--     ordre de la fiche de personnage, sans chemise ni tabard)
--     player = Player.snapshot() ; profile = {weights, caps} | nil ; entries = Chat.bestInZone
--     (triées par gain, delta.slot renseigné) ; worn = {[slot] = {stats, quality, icon}} lu en jeu,
--     prioritaire sur la base pour les stats ; route = entrées du palier courant (Tiers.current
--     de RouteResults : lignes de Planner.rank), utilisées pour les emplacements sans gain de zone
--     row = {slot, slotName (nom de chaîne globale, ex. "HEADSLOT"), itemID | nil,
--            name (L.GEAR_EMPTY si vide), icon, quality, nameColor,
--            scoreText ("" vide ou sans profil, "?" stats inconnues ; info-bulle), estimated (confidence 1),
--            upgrade = RowPresenter.resultRow | nil (premier gain > 0 de l'emplacement) ; hors zone :
--              RowPresenter.present de la ligne du palier + questID (source quête), itemSource, outside = true,
--            upgradeGain (delta.abs) | nil, gainLabel, gainColor (de upgrade, "" sans),
--            detailText, detailColor (nom de upgrade · son detailText, préfixé L.GEAR_ROUTE · durée
--              (Format.duration de row.seconds, upgrade.durationText) hors zone ;
--              sinon L.GEAR_ESTIMATED ou L.GEAR_NO_UPGRADE)}
--            raid = RowPresenter.present + itemSource, gain | nil : meilleur objet de raid (zone ou palier)
--              s'il fait mieux que upgrade (raids jamais en upgrade) ; raidGain, raidGainLabel, raidGainColor,
--              raidText (nom · detailText, « Raid » compris)}
--            alternatives = {RowPresenter.alternative…} | nil : autres objets de l'emplacement (gain > 0, hors
--              raid et objet proposé), MAX_ALTERNATIVES au plus : zone d'abord (L.EFFORT_NEAR, par gain),
--              puis palier courant et ses alternatives (routeAlternatives = Tiers alternatives), par effort ;
--              expandKey = slot, expanded = expanded[slot] == true ; upgrade d'artisanat : quête de plus
--              fort gain en tête
--   ns.GearPresenter.summary(rows) -> {count, total, text} (L.GEAR_SUMMARY | L.GEAR_NONE)
--   ns.GearPresenter.filter(rows, onlyUpgrades) -> lignes avec upgrade ou raid (toutes si faux), ordre gardé
--   ns.GearPresenter.sortByGain(rows) -> copie triée : plus fort gain (upgradeGain ou raidGain) d'abord,
--     lignes sans gain ensuite, ordre de la fiche à égalité
--   ns.GearPresenter.sortBySlot(rows) -> copie triée par row.slot dans l'ordre de la fiche (sans slot : à la fin),
--     ordre reçu à égalité
--   ns.GearPresenter.slotName(slot) -> nom de chaîne globale de l'emplacement ("BACKSLOT") | nil

local _, ns = ...

local L = ns.L

local GearPresenter = {}
ns.GearPresenter = GearPresenter

local ESTIMATED_ITEM = 1
local MAX_ALTERNATIVES = 3

local SLOTS = {
    { 1, "HEADSLOT" }, { 2, "NECKSLOT" }, { 3, "SHOULDERSLOT" }, { 15, "BACKSLOT" },
    { 5, "CHESTSLOT" }, { 9, "WRISTSLOT" }, { 10, "HANDSSLOT" }, { 6, "WAISTSLOT" },
    { 7, "LEGSSLOT" }, { 8, "FEETSLOT" }, { 11, "FINGER0SLOT" }, { 12, "FINGER1SLOT" },
    { 13, "TRINKET0SLOT" }, { 14, "TRINKET1SLOT" }, { 16, "MAINHANDSLOT" },
    { 17, "SECONDARYHANDSLOT" }, { 18, "RANGEDSLOT" },
}

local SLOT_NAMES, SLOT_ORDER = {}, {}
for i, slot in ipairs(SLOTS) do
    SLOT_NAMES[slot[1]] = slot[2]
    SLOT_ORDER[slot[1]] = i
end

function GearPresenter.slotName(slot)
    return SLOT_NAMES[slot]
end

local function isRaid(entry)
    return entry.source ~= nil and entry.source.type == "raid"
end

local function bestUpgrades(entries, data)
    local best = {}
    for _, entry in ipairs(entries or {}) do
        local slot = entry.delta and entry.delta.slot
        if slot and not best[slot] and entry.delta.abs > 0 and not isRaid(entry) then
            best[slot] = ns.RowPresenter.resultRow(entry, data)
            best[slot].gain = entry.delta.abs
        end
    end
    return best
end

local function routeUpgrades(best, route, data)
    for _, entry in ipairs(route or {}) do
        local slot = entry.delta and entry.delta.slot
        if slot and not best[slot] and entry.delta.abs > 0 and not isRaid(entry) then
            local row = ns.RowPresenter.present(entry, data)
            row.questID = entry.source and entry.source.type == "quest" and entry.source.id or nil
            row.outside, row.itemSource, row.gain = true, entry.source, entry.delta.abs
            row.durationText = ns.Format.duration(entry.seconds)
            best[slot] = row
        end
    end
end

-- Plus gros gain de raid par emplacement, dans la zone et le palier courant.
local function raidUpgrades(entries, route, data)
    local best = {}
    for _, list in ipairs({ entries or {}, route or {} }) do
        for _, entry in ipairs(list) do
            local slot = entry.delta and entry.delta.slot
            if slot and isRaid(entry) and entry.delta.abs > 0
                and (not best[slot] or entry.delta.abs > best[slot].gain) then
                local row = ns.RowPresenter.present(entry, data)
                row.itemSource, row.gain = entry.source, entry.delta.abs
                best[slot] = row
            end
        end
    end
    return best
end

local function usable(entry, slot, seen)
    return entry.delta and entry.delta.slot == slot and entry.delta.abs > 0 and not isRaid(entry)
        and not seen[entry.itemID]
end

local function byEase(a, b)
    if a.ease ~= b.ease then
        return a.ease < b.ease
    end
    if a.gain ~= b.gain then
        return a.gain > b.gain
    end
    return a.itemID < b.itemID
end

-- Autres objets de l'emplacement, du plus facile au plus difficile.
local function alternativesOf(slot, chosen, entries, route, routeAlternatives, data)
    local seen, found = { [chosen.itemID] = true }, {}
    local function add(entry, ease, effortText)
        if usable(entry, slot, seen) then
            seen[entry.itemID] = true
            local row = ns.RowPresenter.alternative(entry, data, effortText)
            row.ease, row.gain = ease, entry.delta.abs
            found[#found + 1] = row
        end
    end
    for _, entry in ipairs(entries or {}) do
        add(entry, -1, L.EFFORT_NEAR)
    end
    for _, entry in ipairs(route or {}) do
        add(entry, entry.effort or math.huge)
        for _, other in ipairs(routeAlternatives and routeAlternatives[entry.itemID] or {}) do
            add(other, other.effort or math.huge)
        end
    end
    table.sort(found, byEase)
    local quest
    for i, row in ipairs(chosen.sourceKind == "craft" and found or {}) do
        if row.questID and (not quest or row.gain > found[quest].gain) then
            quest = i
        end
    end
    if quest then
        table.insert(found, 1, table.remove(found, quest))
    end
    for i = #found, MAX_ALTERNATIVES + 1, -1 do
        found[i] = nil
    end
    return #found > 0 and found or nil
end

local function scoreText(stats, profile)
    if not profile then
        return ""
    elseif not stats then
        return "?"
    end
    local score = ns.Scoring.score(stats, profile.weights)
    return ns.Format.number(score, nil, math.abs(score) < 1 and 2 or 1)
end

local function present(slot, slotName, player, profile, data, read)
    local itemID = player.equipped and player.equipped[slot]
    local row = { slot = slot, slotName = slotName, itemID = itemID, estimated = false }
    if not itemID then
        row.name, row.scoreText = L.GEAR_EMPTY, ""
        row.nameColor = ns.Theme.colors.muted
        return row
    end
    local item = data.item(itemID)
    row.name = ns.Names.item(itemID)
    row.icon = ns.Names.itemIcon(itemID, (item and item.icon) or (read and read.icon))
    row.quality = (item and item.quality) or (read and read.quality)
    row.nameColor = ns.Theme.quality(row.quality)
    row.estimated = item ~= nil and item.confidence == ESTIMATED_ITEM
    row.scoreText = scoreText((read and read.stats) or (item and item.stats), profile)
    return row
end

local SEPARATOR = " · "

local function describe(row)
    local colors, upgrade = ns.Theme.colors, row.upgrade
    if not upgrade then
        row.gainLabel, row.gainColor = "", colors.neutral
        row.detailColor = row.estimated and colors.warning or colors.muted
        row.detailText = row.estimated and L.GEAR_ESTIMATED or L.GEAR_NO_UPGRADE
        return
    end
    row.upgradeGain, row.gainLabel, row.gainColor = upgrade.gain, upgrade.gainLabel, upgrade.gainColor
    local parts = { ns.Theme.colorize(upgrade.name, upgrade.nameColor) }
    if upgrade.detailText ~= "" then
        parts[#parts + 1] = upgrade.detailText
    end
    local text = table.concat(parts, SEPARATOR)
    if upgrade.outside then
        local prefix = upgrade.durationText and (L.GEAR_ROUTE .. SEPARATOR .. upgrade.durationText) or L.GEAR_ROUTE
        text = prefix .. SEPARATOR .. text
    end
    row.detailText = text
    row.detailColor = colors.text
end

local function describeRaid(row, raid)
    if not raid or raid.gain <= (row.upgradeGain or 0) then
        return
    end
    row.raid, row.raidGain, row.raidGainLabel, row.raidGainColor = raid, raid.gain, raid.gainLabel, raid.gainColor
    local name = ns.Theme.colorize(raid.name, raid.nameColor)
    row.raidText = raid.detailText ~= "" and (name .. SEPARATOR .. raid.detailText) or name
end

function GearPresenter.build(player, profile, data, entries, worn, route, routeAlternatives, expanded)
    local upgrades = bestUpgrades(entries, data)
    routeUpgrades(upgrades, route, data)
    local raids = raidUpgrades(entries, route, data)
    local rows = {}
    for i, slot in ipairs(SLOTS) do
        local row = present(slot[1], slot[2], player, profile, data, worn and worn[slot[1]])
        row.upgrade = upgrades[slot[1]]
        if row.upgrade then
            row.alternatives = alternativesOf(slot[1], row.upgrade, entries, route, routeAlternatives, data)
            row.expandKey = slot[1]
            row.expanded = expanded ~= nil and expanded[slot[1]] == true
        end
        describe(row)
        describeRaid(row, raids[slot[1]])
        rows[i] = row
    end
    return rows
end

function GearPresenter.summary(rows)
    local count, total = 0, 0
    for _, row in ipairs(rows) do
        if row.upgradeGain then
            count, total = count + 1, total + row.upgradeGain
        end
    end
    local text = count == 0 and L.GEAR_NONE
        or L.GEAR_SUMMARY:format(count, "+" .. ns.Format.number(total, nil, total < 1 and 2 or 1))
    return { count = count, total = total, text = text }
end

function GearPresenter.filter(rows, onlyUpgrades)
    local kept = {}
    for _, row in ipairs(rows) do
        if not onlyUpgrades or row.upgrade or row.raid then
            kept[#kept + 1] = row
        end
    end
    return kept
end

function GearPresenter.sortBySlot(rows)
    local sorted, position = {}, {}
    for i, row in ipairs(rows) do
        sorted[i], position[row] = row, i
    end
    table.sort(sorted, function(a, b)
        local orderA, orderB = SLOT_ORDER[a.slot] or math.huge, SLOT_ORDER[b.slot] or math.huge
        if orderA ~= orderB then
            return orderA < orderB
        end
        return position[a] < position[b]
    end)
    return sorted
end

local function rowGain(row)
    return math.max(row.upgradeGain or 0, row.raidGain or 0)
end

function GearPresenter.sortByGain(rows)
    local sorted, position = {}, {}
    for i, row in ipairs(rows) do
        sorted[i], position[row] = row, i
    end
    table.sort(sorted, function(a, b)
        local gainA, gainB = rowGain(a), rowGain(b)
        if gainA ~= gainB then
            return gainA > gainB
        end
        return position[a] < position[b]
    end)
    return sorted
end
