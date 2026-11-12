-- CONTRAT
-- Vue du journal de progression (History.entries). Pur : aucun appel d'API. Charger après Theme.lua, Format.lua.
--   ns.HistoryPresenter.MAX_RECENT = 6
--   ns.HistoryPresenter.build(entries, profileID, data) -> {empty, summary, bars, minLevel, maxLevel, maxScore,
--     recent} ; seules les entrées de profileID comptent (scores d'un autre profil non comparables).
--     empty = L.JOURNAL_EMPTY | nil ; summary = L.JOURNAL_SUMMARY (premier score, dernier, niveaux, améliorations)
--     bars = {{level, score, ratio (score / plus haut score, 0-1), label = L.JOURNAL_BAR}} : une par niveau
--       relevé, meilleur score du niveau, par niveau croissant ; maxScore : texte du plus haut score
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

local function barsOf(kept)
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
    local bars = {}
    for index, level in ipairs(levels) do
        bars[index] = { level = level, score = best[level], ratio = top > 0 and best[level] / top or 0,
            label = L.JOURNAL_BAR:format(level, number(best[level])) }
    end
    return bars, levels, top
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
        return { empty = L.JOURNAL_EMPTY, bars = {}, recent = {} }
    end
    local bars, levels, top = barsOf(kept)
    return {
        summary = L.JOURNAL_SUMMARY:format(number(kept[1].score), number(kept[#kept].score), #levels, upgrades),
        bars = bars, minLevel = levels[1], maxLevel = levels[#levels], maxScore = number(top),
        recent = recentOf(kept, data),
    }
end
