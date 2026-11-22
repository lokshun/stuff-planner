-- CONTRAT
-- Butins voulus : objets de la liste cible ou améliorations du donjon courant parmi ceux qui tombent (fenêtre de
-- butin, jet de groupe). Pur : aucun appel d'API (ns.L et ns.Format lus à l'appel).
--   ns.LootAlertPresenter.match(itemIDs, ctx) -> {{itemID, reason, gain, gainText}...} dans l'ordre reçu (ipairs),
--     un objet au plus une fois ; ctx = {has(itemID) -> bool (WishlistStore.has), dungeonSet = {[itemID] = true}
--     | nil (hors instance), delta(itemID) -> {abs} | nil (Results.delta)} ;
--     reason "wishlist" (épinglé, même sans gain : prioritaire) | "dungeon" (dans dungeonSet et abs > 0) ;
--     gain = abs > 0 | nil, gainText = Format.points(gain) | nil
--   ns.LootAlertPresenter.dungeonSet(view) -> {[itemID] = true} des objets de DungeonPresenter.build (boss et
--     butin hors boss : même règle que le cadre donjon) | nil sans vue
--   ns.LootAlertPresenter.text(match, name) -> L.LOOT_ALERT_WISHLIST | LOOT_ALERT_UPGRADE (nom), suivi du gain
--   ns.LootAlertPresenter.fresh(seen, itemID, now) -> vrai si l'objet n'a pas été signalé depuis
--     REPEAT_SECONDS (alors noté dans seen = {[itemID] = instant}) ; fenêtre rouverte, jet puis butin
--   ns.LootAlertPresenter.REPEAT_SECONDS = 60

local _, ns = ...

local LootAlertPresenter = {}
ns.LootAlertPresenter = LootAlertPresenter

LootAlertPresenter.REPEAT_SECONDS = 60

local function gainOf(ctx, itemID)
    local delta = ctx.delta and ctx.delta(itemID)
    local abs = delta and delta.abs
    return abs and abs > 0 and abs or nil
end

local function reasonOf(ctx, itemID, gain)
    if ctx.has and ctx.has(itemID) then
        return "wishlist"
    elseif ctx.dungeonSet and ctx.dungeonSet[itemID] and gain then
        return "dungeon"
    end
end

function LootAlertPresenter.match(itemIDs, ctx)
    local found, done = {}, {}
    for _, itemID in ipairs(itemIDs or {}) do
        if not done[itemID] then
            done[itemID] = true
            local gain = gainOf(ctx, itemID)
            local reason = reasonOf(ctx, itemID, gain)
            if reason then
                found[#found + 1] = { itemID = itemID, reason = reason, gain = gain,
                    gainText = gain and ns.Format.points(gain) or nil }
            end
        end
    end
    return found
end

local function addItems(result, items)
    for _, item in ipairs(items or {}) do
        result[item.itemID] = true
    end
end

function LootAlertPresenter.dungeonSet(view)
    if not view then
        return nil
    end
    local result = {}
    for _, boss in ipairs(view.bosses or {}) do
        addItems(result, boss.items)
    end
    addItems(result, view.trash and view.trash.items)
    return result
end

function LootAlertPresenter.text(match, name)
    local L = ns.L
    local format = match.reason == "wishlist" and L.LOOT_ALERT_WISHLIST or L.LOOT_ALERT_UPGRADE
    local text = format:format(name or "")
    return match.gainText and (text .. " " .. match.gainText) or text
end

function LootAlertPresenter.fresh(seen, itemID, now)
    local last = seen[itemID]
    if last and now - last < LootAlertPresenter.REPEAT_SECONDS then
        return false
    end
    seen[itemID] = now
    return true
end
