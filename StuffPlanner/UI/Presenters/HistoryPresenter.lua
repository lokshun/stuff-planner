-- CONTRAT
-- Vue du journal de progression (History.entries). Pur : aucun appel d'API. Charger après Theme.lua, Format.lua.
--   ns.HistoryPresenter.MAX_RECENT = 6
--   ns.HistoryPresenter.build(entries, profileID, data) -> {empty, tiles, points, ticks, maxScore, hint, recent} ;
--     seules les entrées de profileID comptent (scores d'un autre profil non comparables).
--     empty = L.JOURNAL_EMPTY | nil ; tiles = {{label, value}} × 3 : score actuel (dernier relevé), gain depuis le
--       premier relevé (L.JOURNAL_TILE_SINCE, niveau de départ ; signé), nombre d'améliorations
--     points = {{level, score, x, y, label = L.JOURNAL_BAR}} : un par niveau relevé (meilleur score du niveau),
--       niveau croissant ; x = place sur l'axe 1 → max(60, plus haut niveau) (0-1), y = score / plus haut score
--     ticks = {{level, x}} : 1, 10, 20 … 60 ; maxScore : texte du plus haut score ;
--     hint = L.JOURNAL_ONE_POINT si un seul niveau est relevé (la courbe viendra), sinon nil
--     recent = {{itemID, name, icon, nameColor (qualité), text}} : améliorations, plus récente d'abord ;
--       text = L.JOURNAL_UPGRADE (gain, % du score d'avant, niveau), L.JOURNAL_UPGRADE_FLAT si score d'avant nul

local _, ns = ...

local L = ns.L

local HistoryPresenter = {}
ns.HistoryPresenter = HistoryPresenter

HistoryPresenter.MAX_RECENT = 6

local function number(value)
    return ns.Format.number(value, nil, 1)
end

local function upgradeText(entry)
    local before = entry.score - entry.gain
    if before > 0 then
        return L.JOURNAL_UPGRADE:format(number(entry.gain), ns.Format.percent(entry.gain / before), entry.level)
    end
    return L.JOURNAL_UPGRADE_FLAT:format(number(entry.gain), entry.level)
end

local function recentOf(kept, data)
    local recent = {}
    for index = #kept, 1, -1 do
        local entry = kept[index]
        if entry.kind == "upgrade" and #recent < HistoryPresenter.MAX_RECENT then
            local fields = data.item(entry.itemID)
            recent[#recent + 1] = {
                itemID = entry.itemID, name = ns.Names.item(entry.itemID), icon = ns.Names.itemIcon(entry.itemID),
                nameColor = ns.Theme.quality(fields and fields.quality), text = upgradeText(entry),
            }
        end
    end
    return recent
end

local MAX_LEVEL = 60
local TICK_STEP = 10

local function axisX(level, axisMax)
    return math.max(0, math.min(1, (level - 1) / (axisMax - 1)))
end

local function ticksOf(axisMax)
    local ticks = { { level = 1, x = 0 } }
    for level = TICK_STEP, axisMax, TICK_STEP do
        ticks[#ticks + 1] = { level = level, x = axisX(level, axisMax) }
    end
    return ticks
end

local function signed(value)
    return (value >= 0 and "+" or "") .. number(value)
end

local function pointsOf(kept)
    local best, levels, top = {}, {}, 0
    for _, entry in ipairs(kept) do
        local level = entry.level or 0
        if not best[level] then
            levels[#levels + 1] = level
        end
        best[level] = math.max(best[level] or entry.score, entry.score)
        top = math.max(top, entry.score)
    end
    table.sort(levels)
    local axisMax = math.max(MAX_LEVEL, levels[#levels])
    local points = {}
    for index, level in ipairs(levels) do
        points[index] = { level = level, score = best[level], x = axisX(level, axisMax),
            y = top > 0 and best[level] / top or 0, label = L.JOURNAL_BAR:format(level, number(best[level])) }
    end
    return points, top, axisMax
end

function HistoryPresenter.build(entries, profileID, data)
    local kept, upgrades = {}, 0
    for _, entry in ipairs(entries) do
        if entry.profileID == profileID then
            kept[#kept + 1] = entry
            upgrades = upgrades + (entry.kind == "upgrade" and 1 or 0)
        end
    end
    if #kept == 0 then
        return { empty = L.JOURNAL_EMPTY, tiles = {}, points = {}, ticks = {}, recent = {} }
    end
    local points, top, axisMax = pointsOf(kept)
    local first, last = kept[1], kept[#kept]
    return {
        tiles = {
            { label = L.JOURNAL_TILE_SCORE, value = number(last.score) },
            { label = L.JOURNAL_TILE_SINCE:format(first.level or 0), value = signed(last.score - first.score) },
            { label = L.JOURNAL_TILE_UPGRADES, value = tostring(upgrades) },
        },
        points = points, ticks = ticksOf(axisMax), maxScore = number(top),
        hint = #points == 1 and L.JOURNAL_ONE_POINT or nil,
        recent = recentOf(kept, data),
    }
end
