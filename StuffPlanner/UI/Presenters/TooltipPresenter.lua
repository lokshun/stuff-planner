-- CONTRAT
-- Texte ajouté aux info-bulles d'objet et choix de la meilleure récompense de quête.
-- Pur : aucun appel d'API. Charger après RowPresenter.lua et SecondaryGain.lua (ns.Scoring lu à l'appel).
--   ns.TooltipPresenter.build(itemID, player, profile, data [, live [, price]]) -> view | nil
--     live = LiveItem.fields(link) : objet lu en jeu, remplace la base (Scoring.deltaFields, ses stats,
--       jamais d'avertissement) ; price = prix d'hôtel des ventes en cuivre (Prices.get) | nil ;
--     nil si Scoring.delta ne donne rien (objet inconnu, non équipable…) ;
--     view = {gain = L.TOOLTIP_GAIN (points signés, Format.points ; sans flèche, absente de la
--               police des info-bulles ; avec profil secondaire : suivi du nom court du profil (spé connue)),
--               gainColor, upgrade = gain > 0 ici,
--             second = L.TOOLTIP_GAIN (SecondaryGain.text : points et nom) | nil sans profil secondaire,
--               secondColor (SecondaryGain.color) : ligne sous gain, même format,
--             details = {L.TOOLTIP_STAT...} : 3 stats au plus dont valeur * poids pèse le plus
--               (valeur absolue décroissante, puis clé), plafonds ignorés,
--             warning = L.TOOLTIP_UNCONFIRMED | nil (objet confidence 1 hors lecture en cours), warningColor,
--             keep = L.KEEP_FOR | nil (gain ≤ 0 ici, > 0 pour le profil secondaire), keepColor,
--             perGold = L.TOOLTIP_PER_GOLD (points ÷ prix en pièces d'or, Format.points) |
--               nil (sans prix ou gain ≤ 0)}
--   ns.TooltipPresenter.bestChoice(itemIDs, player, profile, data) -> index | nil
--     itemIDs = {itemID | false...} ; indice du plus grand gain > 0, le premier si égalité

local _, ns = ...

local L = ns.L

local TooltipPresenter = {}
ns.TooltipPresenter = TooltipPresenter

local MAX_DETAILS = 3
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

local COPPER_PER_GOLD = 10000

local function perGold(delta, price)
    if not (price and price > 0 and delta.abs > 0) then
        return nil
    end
    return L.TOOLTIP_PER_GOLD:format(ns.Format.points(delta.abs / (price / COPPER_PER_GOLD)))
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
    local second, name = ns.SecondaryGain.lookup(itemID, live, player, data)
    local value = ns.Format.points(delta.abs)
    if second and profile.spec then
        value = L.SECONDARY_GAIN:format(value, ns.ProfilePresenter.shortName(profile))
    end
    local view = {
        gain = L.TOOLTIP_GAIN:format(value),
        gainColor = color,
        upgrade = delta.abs > 0,
        details = details(item.stats, profile.weights or {}),
        perGold = perGold(delta, price),
    }
    if second then
        view.second = L.TOOLTIP_GAIN:format(L.SECONDARY_GAIN:format(ns.SecondaryGain.value(second), name))
        view.secondColor = ns.SecondaryGain.color(second)
    end
    if delta.abs <= 0 and second then
        view.keep, view.keepColor = ns.SecondaryGain.keep(second, name), ns.Theme.colors.instance
    end
    if ns.RowPresenter.estimated(itemID, item) then
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
