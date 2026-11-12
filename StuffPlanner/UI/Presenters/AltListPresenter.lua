-- CONTRAT
-- Section « Autres personnages » du journal : chaque autre personnage du royaume (Alts.others) et les objets
-- des sacs qui lui iraient le mieux (AltGain.best : un objet va au personnage qui y gagne le plus). Pur : aucun
-- appel d'API. Charger après Theme.lua et AltGain.lua ; lit ns.Names, ns.SecondaryGain, ns.AltGain à l'appel.
--   ns.AltListPresenter.build(alts, items, data, now, className) -> {empty?, note?, rows}
--     alts = Alts.others() ; items = {{itemID, fields}} (objets échangeables des sacs, fields = LiveItem.fields
--     ou data.item) ; now = time() ; className(token) -> nom affiché de la classe
--     empty = L.ALTS_EMPTY sans autre personnage ; note = L.ALTS_NO_ITEM si aucun objet ne sert
--     rows : par personnage (ordre d'alts) un en-tête {alt = true, name, class, detail (L.ALT_DETAIL · relevé),
--       gain (L.ALT_ITEMS | "")}, puis ses objets {itemID, icon, name, nameColor (qualité), gain
--       (SecondaryGain.value), gainColor}, meilleur pourcentage d'abord (emplacement vide avant tout)
--     relevé : L.ALT_SEEN_TODAY le jour même, sinon L.ALT_SEEN_DAYS (jours entiers depuis record.at)

local _, ns = ...

local AltListPresenter = {}
ns.AltListPresenter = AltListPresenter

local DAY = 86400

local function seen(at, now)
    local days = math.floor((now - (at or now)) / DAY)
    return days < 1 and ns.L.ALT_SEEN_TODAY or ns.L.ALT_SEEN_DAYS:format(days)
end

local function better(a, b)
    local pa, pb = a.delta.pct or math.huge, b.delta.pct or math.huge
    if pa ~= pb then
        return pa > pb
    end
    if a.delta.abs ~= b.delta.abs then
        return a.delta.abs > b.delta.abs
    end
    return a.itemID < b.itemID
end

local function assign(alts, items, data)
    local byName, done = {}, {}
    for _, item in ipairs(items) do
        if not done[item.itemID] then
            done[item.itemID] = true
            local best = ns.AltGain.best(item.fields, alts, data)
            if best then
                byName[best.name] = byName[best.name] or {}
                table.insert(byName[best.name], { itemID = item.itemID, delta = best.delta })
            end
        end
    end
    return byName
end

local function itemRow(entry, data)
    local record = data.item and data.item(entry.itemID)
    return {
        itemID = entry.itemID, icon = ns.Names.itemIcon(entry.itemID), name = ns.Names.item(entry.itemID),
        nameColor = ns.Theme.quality(record and record.quality), gain = ns.SecondaryGain.value(entry.delta),
        gainColor = ns.Theme.colors.gain,
    }
end

function AltListPresenter.build(alts, items, data, now, className)
    local L = ns.L
    local rows = {}
    if #alts == 0 then
        return { empty = L.ALTS_EMPTY, rows = rows }
    end
    local byName, any = assign(alts, items, data), false
    for _, alt in ipairs(alts) do
        local list = byName[alt.name] or {}
        table.sort(list, better)
        rows[#rows + 1] = {
            alt = true, name = alt.name, class = alt.class,
            detail = L.ALT_DETAIL:format(alt.level or 0, className(alt.class)) .. " · " .. seen(alt.at, now),
            gain = #list > 0 and L.ALT_ITEMS:format(#list) or "",
        }
        for _, entry in ipairs(list) do
            rows[#rows + 1] = itemRow(entry, data)
            any = true
        end
    end
    return { rows = rows, note = not any and L.ALTS_NO_ITEM or nil }
end
