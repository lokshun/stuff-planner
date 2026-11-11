-- CONTRAT
-- Texte ajouté aux info-bulles d'objet et choix de la meilleure récompense de quête.
-- Pur : aucun appel d'API. Charger après RowPresenter.lua (ns.Scoring lu à l'appel).
--   ns.TooltipPresenter.build(itemID, player, profile, data [, live [, price]]) -> view | nil
--     live = LiveItem.fields(link) : objet lu en jeu, remplace la base (Scoring.deltaFields, ses stats,
--       jamais d'avertissement) ; price = prix d'hôtel des ventes en cuivre (Prices.get) | nil ;
--     nil si Scoring.delta ne donne rien (objet inconnu, non équipable…) ;
--     view = {gain = L.TOOLTIP_GAIN (points et pourcentage signés ; sans flèche, absente de la
--               police des info-bulles), gainColor,
--             details = {L.TOOLTIP_STAT...} : 3 stats au plus dont valeur * poids pèse le plus
--               (valeur absolue décroissante, puis clé), plafonds ignorés,
--             warning = L.TOOLTIP_UNCONFIRMED | nil (objet confidence 1), warningColor,
--             perGold = L.TOOLTIP_PER_GOLD (pourcentage ÷ prix en pièces d'or, 2 décimales sous 1) |
--               nil (sans prix, gain ≤ 0 ou sans pourcentage)}
--   ns.TooltipPresenter.bestChoice(itemIDs, player, profile, data) -> index | nil
--     itemIDs = {itemID | false...} ; indice du plus grand gain > 0, le premier si égalité

local _, ns = ...

local L = ns.L

local TooltipPresenter = {}
ns.TooltipPresenter = TooltipPresenter

local MAX_DETAILS = 3
local ESTIMATED_ITEM = 1
local PERCENT_KEYS = {
    HIT = true, CRIT = true, SPELL_HIT = true, SPELL_CRIT = true,
    DODGE = true, PARRY = true, BLOCK = true, HASTE = true,
}

local function points(value)
    local magnitude = math.abs(value)
    local text = ns.Format.number(magnitude, nil, magnitude < 1 and 2 or 1)
    return value < 0 and "-" .. text or text
end

local function signed(text, value)
    return value > 0 and "+" .. text or text
end

local function statValue(key, value)
    if PERCENT_KEYS[key] then
        return signed(ns.Format.percent(value / 100), value)
    end
    local decimals = value == math.floor(value) and 0 or 1
    return signed(ns.Format.number(value, nil, decimals), value)
end

local function details(stats, weights)
    local parts = {}
    for key, value in pairs(stats or {}) do
        local weight = weights[key]
        if weight and weight ~= 0 and value ~= 0 then
            parts[#parts + 1] = { key = key, value = value, weight = value * weight }
        end
    end
    table.sort(parts, function(a, b)
        local wa, wb = math.abs(a.weight), math.abs(b.weight)
        if wa ~= wb then
            return wa > wb
        end
        return a.key < b.key
    end)
    local lines = {}
    for i = 1, math.min(MAX_DETAILS, #parts) do
        local part = parts[i]
        local label = L["STAT_" .. part.key] or part.key
        lines[i] = L.TOOLTIP_STAT:format(label, statValue(part.key, part.value), points(part.weight))
    end
    return lines
end

local function gainText(delta)
    local _, parts = ns.RowPresenter.gain(delta)
    if delta.pct then
        parts = parts .. " (" .. signed(ns.Format.percent(delta.pct / 100), delta.pct) .. ")"
    end
    return L.TOOLTIP_GAIN:format(parts)
end

local COPPER_PER_GOLD = 10000

local function perGold(delta, price)
    if not (price and price > 0 and delta.pct and delta.abs > 0) then
        return nil
    end
    local value = delta.pct / (price / COPPER_PER_GOLD)
    local text = ns.Format.percent(value / 100, nil, value < 1 and 2 or 1)
    return L.TOOLTIP_PER_GOLD:format("+" .. text)
end

function TooltipPresenter.build(itemID, player, profile, data, live, price)
    local delta
    if live then
        delta = ns.Scoring.deltaFields(live, player, profile, data, live.key)
    else
        delta = ns.Scoring.delta(itemID, player, profile, data)
    end
    if not delta then
        return nil
    end
    local item = live or data.item(itemID) or {}
    local _, _, color = ns.RowPresenter.gain(delta)
    local view = {
        gain = gainText(delta),
        gainColor = color,
        details = details(item.stats, profile.weights or {}),
        perGold = perGold(delta, price),
    }
    if item.confidence == ESTIMATED_ITEM then
        view.warning, view.warningColor = L.TOOLTIP_UNCONFIRMED, ns.Theme.colors.warning
    end
    return view
end

function TooltipPresenter.bestChoice(itemIDs, player, profile, data)
    local bestIndex, bestGain = nil, 0
    for index, itemID in pairs(itemIDs) do
        local delta = itemID and ns.Scoring.delta(itemID, player, profile, data)
        local gain = delta and delta.abs or 0
        if gain > bestGain or (gain == bestGain and bestIndex and index < bestIndex) then
            bestIndex, bestGain = index, gain
        end
    end
    return bestIndex
end
