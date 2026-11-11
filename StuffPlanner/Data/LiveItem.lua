-- CONTRAT
-- Champs de score d'un objet lus en jeu par son lien : butin de monde absent de la base, ou objet à
-- suffixe aléatoire (« … du Singe ») dont la base ne connaît que les stats sans suffixe.
-- Charger après CompatItem.lua, Engine/StatParser.lua et Engine/ItemLink.lua.
--   ns.LiveItem.fields(link) -> {key = link, id, slot, itemClass, itemSubClass, stats, live = true} | nil
--     slot = InventoryType (ItemLink.inventoryType) ; stats = StatParser.merge(fromApi(Compat.GetItemStats),
--     fromLines(lignes d'info-bulle)) ; nil : lien absent, objet non équipable, ou aucune stat (objet
--     pas encore en cache : rien n'est gardé, le survol suivant relit). Résultat gardé par lien
--     (au plus MAX_CACHED liens, puis tout est oublié).
--   ns.LiveItem.needed(itemID, link, data) -> bool : lien présent et (objet hors base ou suffixe ≠ 0)

local _, ns = ...

local LiveItem = {}
ns.LiveItem = LiveItem

local MAX_CACHED = 200

local cache, cached = {}, 0
local patterns

local function read(link)
    local info = ns.Compat.GetItemInfoInstant(link)
    local slot = info and ns.ItemLink.inventoryType(info.equipLoc)
    if not slot then
        return nil
    end
    local StatParser = ns.StatParser
    patterns = patterns or StatParser.buildPatterns(ns.Compat.GlobalString)
    local stats = StatParser.merge(StatParser.fromApi(ns.Compat.GetItemStats(link)),
        StatParser.fromLines(ns.Compat.GetTooltipLines(link), patterns))
    if next(stats) == nil then
        return nil
    end
    return {
        key = link,
        id = ns.ItemLink.itemID(link),
        slot = slot,
        itemClass = info.classID,
        itemSubClass = info.subclassID,
        stats = stats,
        live = true,
    }
end

function LiveItem.fields(link)
    if type(link) ~= "string" then
        return nil
    end
    local fields = cache[link]
    if fields then
        return fields
    end
    fields = read(link)
    if fields then
        if cached >= MAX_CACHED then
            cache, cached = {}, 0
        end
        cache[link] = fields
        cached = cached + 1
    end
    return fields
end

function LiveItem.needed(itemID, link, data)
    if type(link) ~= "string" then
        return false
    end
    return data.item(itemID) == nil or ns.ItemLink.suffix(link) ~= 0
end
