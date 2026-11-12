-- CONTRAT
-- Lignes de la section Liste cible (onglet Équipement). Pur : aucun appel d'API. Charger après RowPresenter.lua.
--   ns.WishlistPresenter.build(view, data) -> {title, empty, rows}
--     view = Wishlist.status ; title = L.WISHLIST_TITLE (obtenus, total) ; empty = L.WISHLIST_EMPTY | nil ;
--     row = {itemID, name, icon, nameColor, checked (obtenu), detail, detailColor, isNext,
--            questID (première quête restante) | nil, itemSource (source hors quête) | nil}
--     detail : L.WISHLIST_OBTAINED, L.WISHLIST_BLOCKED, sinon source (RowPresenter), L.EFFORT_CHAIN si plusieurs
--       quêtes restantes, durée (Format.duration), séparés par « · » ; couleur : gain (obtenu), loss
--       (bloqué), title (suivant : view.nextIndex), muted sinon.

local _, ns = ...

local L = ns.L

local WishlistPresenter = {}
ns.WishlistPresenter = WishlistPresenter

local SEPARATOR = " · "

local function detailOf(entry, base)
    if entry.obtained then
        return L.WISHLIST_OBTAINED
    elseif entry.blocked then
        return L.WISHLIST_BLOCKED
    end
    local parts = { base.sourceText }
    if entry.steps and #entry.steps > 1 then
        parts[#parts + 1] = L.EFFORT_CHAIN:format(#entry.steps)
    end
    parts[#parts + 1] = ns.Format.duration(entry.seconds)
    return table.concat(parts, SEPARATOR)
end

local function colorOf(entry, isNext)
    local colors = ns.Theme.colors
    if entry.obtained then
        return colors.gain
    elseif entry.blocked then
        return colors.loss
    end
    return isNext and colors.title or colors.muted
end

function WishlistPresenter.build(view, data)
    local rows = {}
    for index, entry in ipairs(view.entries) do
        local base = ns.RowPresenter.present({ itemID = entry.itemID, source = entry.source }, data)
        local isNext = index == view.nextIndex
        local quest = entry.source and entry.source.type == "quest"
        rows[index] = {
            itemID = entry.itemID, name = base.name, icon = base.icon, nameColor = base.nameColor,
            checked = entry.obtained, isNext = isNext,
            detail = detailOf(entry, base), detailColor = colorOf(entry, isNext),
            questID = quest and entry.steps and entry.steps[1] or nil,
            itemSource = not quest and entry.source or nil,
        }
    end
    return {
        title = L.WISHLIST_TITLE:format(view.progress.done, view.progress.total),
        empty = #rows == 0 and L.WISHLIST_EMPTY or nil,
        rows = rows,
    }
end
