-- CONTRAT
-- Liste cible du personnage (objets épinglés), dans StuffPlannerCharDB.wishlist.items. Charger après DB.lua et
-- Profiles/WishlistIO.lua. Aucune API WoW.
--   ns.WishlistStore.list() -> {itemID...} dans l'ordre d'épinglage (copie)
--   ns.WishlistStore.has(itemID) -> bool
--   ns.WishlistStore.toggle(itemID) -> true (épinglé), false (retiré) | nil, "FULL" (WishlistIO.MAX atteint)
--   ns.WishlistStore.remove(itemID) -> bool ; ns.WishlistStore.replace(itemIDs) : liste remplacée (import ;
--     doublons retirés, coupée à WishlistIO.MAX)
--   ns.WishlistStore.merge(itemIDs) -> added, present, full : absents ajoutés à la fin (import par défaut),
--     doublons de l'entrée ignorés ; full = au moins un objet refusé (WishlistIO.MAX atteint)
-- SP_WISHLIST_CHANGED (sans argument) après chaque changement réel.

local _, ns = ...

local WishlistStore = {}
ns.WishlistStore = WishlistStore

local function items()
    return ns.DB.char("wishlist", "items")
end

local function indexOf(itemID)
    for index, id in ipairs(items()) do
        if id == itemID then
            return index
        end
    end
    return nil
end

function WishlistStore.list()
    local copy = {}
    for index, id in ipairs(items()) do
        copy[index] = id
    end
    return copy
end

function WishlistStore.has(itemID)
    return indexOf(itemID) ~= nil
end

function WishlistStore.remove(itemID)
    local index = indexOf(itemID)
    if not index then
        return false
    end
    table.remove(items(), index)
    ns:Send("SP_WISHLIST_CHANGED")
    return true
end

function WishlistStore.toggle(itemID)
    if WishlistStore.remove(itemID) then
        return false
    end
    local list = items()
    if #list >= ns.WishlistIO.MAX then
        return nil, "FULL"
    end
    list[#list + 1] = itemID
    ns:Send("SP_WISHLIST_CHANGED")
    return true
end

function WishlistStore.merge(itemIDs)
    local list = items()
    local had, seen = {}, {}
    for _, id in ipairs(list) do
        had[id] = true
    end
    local added, present, full = 0, 0, false
    for _, id in ipairs(itemIDs) do
        if seen[id] then -- luacheck: ignore 542
        elseif had[id] then
            present = present + 1
        elseif #list >= ns.WishlistIO.MAX then
            full = true
        else
            list[#list + 1] = id
            added = added + 1
        end
        seen[id] = true
    end
    if added > 0 then
        ns:Send("SP_WISHLIST_CHANGED")
    end
    return added, present, full
end

function WishlistStore.replace(itemIDs)
    local list, seen = {}, {}
    for _, id in ipairs(itemIDs) do
        if not seen[id] and #list < ns.WishlistIO.MAX then
            seen[id] = true
            list[#list + 1] = id
        end
    end
    ns.DB.char("wishlist").items = list
    ns:Send("SP_WISHLIST_CHANGED")
end
