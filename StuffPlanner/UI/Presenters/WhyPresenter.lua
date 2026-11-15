-- CONTRAT
-- Détail du score d'un objet, ligne par stat, pour /splan why. Pur : aucun appel à l'API WoW.
-- Charger après Format.lua et Engine/SpellWeights.lua (ns.SpellWeights lu à l'appel, facultatif).
--   ns.WhyPresenter.lines(stats, weights, L [, locale]) -> {texte...} :
--     une ligne par stat pesée, de la plus forte part à la plus faible : L.WHY_LINE
--     (libellé L.STAT_<clé>, valeur, poids, part) ; poids relevé par SpellWeights : L.WHY_LINE_LINKED
--     (poids saisi en plus) ; puis L.WHY_UNWEIGHTED (stats sans poids, ordre alphabétique) s'il y en a ;
--     puis L.WHY_TOTAL (somme des parts, avant plafonds). stats = stats déjà complétées (withDerived).

local _, ns = ...

local WhyPresenter = {}
ns.WhyPresenter = WhyPresenter

local function effective(weights, key)
    if ns.SpellWeights then
        return ns.SpellWeights.weight(weights, key)
    end
    return weights[key]
end

local function label(L, key)
    return rawget(L, "STAT_" .. key) or key
end

local function number(value, locale)
    return ns.Format.number(value, locale, value == math.floor(value) and 0 or 2)
end

function WhyPresenter.lines(stats, weights, L, locale)
    local rows, unweighted, total = {}, {}, 0
    for key, value in pairs(stats or {}) do
        local weight = effective(weights, key)
        if weight and weight ~= 0 then
            rows[#rows + 1] = { key = key, value = value, weight = weight, part = value * weight }
            total = total + value * weight
        elseif value ~= 0 then
            unweighted[#unweighted + 1] = label(L, key)
        end
    end
    table.sort(rows, function(a, b)
        if a.part ~= b.part then
            return a.part > b.part
        end
        return a.key < b.key
    end)
    local lines = {}
    for _, row in ipairs(rows) do
        local value, weight, part = number(row.value, locale), number(row.weight, locale), number(row.part, locale)
        local own = weights[row.key]
        if own ~= row.weight then
            lines[#lines + 1] = L.WHY_LINE_LINKED:format(label(L, row.key), value, weight, part,
                number(own or 0, locale))
        else
            lines[#lines + 1] = L.WHY_LINE:format(label(L, row.key), value, weight, part)
        end
    end
    if #unweighted > 0 then
        table.sort(unweighted)
        lines[#lines + 1] = L.WHY_UNWEIGHTED:format(table.concat(unweighted, ", "))
    end
    lines[#lines + 1] = L.WHY_TOTAL:format(number(total, locale))
    return lines
end
