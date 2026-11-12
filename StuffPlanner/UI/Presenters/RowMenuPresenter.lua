-- CONTRAT
-- Entrées du menu clic droit d'une ligne (pur, aucune API WoW). Charger après les Locales.
--   ns.RowMenuPresenter.entries(ctx) -> {{key, label}...}
--     ctx = {questID?, itemID?, itemSource?, following = questID suivi | nil, pinned = bool, chain = bool}
--     ordre : details (quête, ou objet et source), quête : follow (suite de quêtes, ctx.chain) ou waypoint
--     (quête simple), unfollow si elle est suivie,
--     pin / unpin et dressup (objet)
--   ns.RowMenuPresenter.profileEntries(ctx) -> {{key, label}...}
--     ctx = {active = profil actif, secondary = profil comparé} : use, compare / uncompare ; rien si actif

local _, ns = ...

local L = ns.L

local RowMenuPresenter = {}
ns.RowMenuPresenter = RowMenuPresenter

local function add(entries, key, label)
    entries[#entries + 1] = { key = key, label = label }
end

function RowMenuPresenter.entries(ctx)
    local entries = {}
    local questID, itemID = ctx.questID, ctx.itemID
    if questID or (itemID and ctx.itemSource) then
        add(entries, "details", L.MENU_DETAILS)
    end
    if questID then
        if ctx.following == questID then
            add(entries, "unfollow", L.DETAIL_UNFOLLOW)
        elseif ctx.chain then
            add(entries, "follow", L.DETAIL_FOLLOW)
        else
            add(entries, "waypoint", L.DETAIL_WAYPOINT)
        end
    end
    if itemID then
        if ctx.pinned then
            add(entries, "unpin", L.WISHLIST_UNPIN)
        else
            add(entries, "pin", L.WISHLIST_PIN)
        end
        add(entries, "dressup", L.MENU_DRESSUP)
    end
    return entries
end

function RowMenuPresenter.profileEntries(ctx)
    local entries = {}
    if ctx.active then
        return entries
    end
    add(entries, "use", L.MENU_PROFILE_USE)
    if ctx.secondary then
        add(entries, "uncompare", L.MENU_UNCOMPARE)
    else
        add(entries, "compare", L.MENU_COMPARE)
    end
    return entries
end
