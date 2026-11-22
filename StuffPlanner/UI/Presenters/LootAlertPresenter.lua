-- CONTRAT
-- Butins voulus : objets de la liste cible ou améliorations parmi ceux qui tombent (fenêtre de butin, jet de
-- groupe : boss, trash, monde) ou qu'offre une quête rendue. Pur : aucun appel d'API (ns.L, ns.Format lus à l'appel).
--   ns.LootAlertPresenter.match(items, ctx) -> {{itemID, link, reason, gain, gainText}...}
--     items = {{itemID, link?}...} ; ctx = {has(itemID) -> bool (WishlistStore.has),
--       gainOf(item) -> gain en points | nil (BadgePresenter.build sur le lien : objet hors base lu en jeu),
--       minGain = seuil en points | nil (réglage loot.minGain ; 0 ou nil : tout gain > 0)} ;
--     reason "wishlist" (épinglé, même sans gain ni seuil) | "upgrade" (gain > 0 et ≥ minGain) ;
--     gainText = Format.points | nil ;
--     un objet au plus une fois ; liste cible d'abord, puis gain décroissant, ordre reçu à égalité
--   ns.LootAlertPresenter.text(match, name, quest?) -> L.LOOT_ALERT_WISHLIST | LOOT_ALERT_UPGRADE
--     (LOOT_ALERT_QUEST si quest) avec le nom, suivi du gain
--   ns.LootAlertPresenter.fresh(seen, itemID, now) -> vrai si l'objet n'a pas été signalé depuis
--     REPEAT_SECONDS (alors noté dans seen = {[itemID] = instant}) ; fenêtre rouverte, jet puis butin
--   ns.LootAlertPresenter.REPEAT_SECONDS = 60

local _, ns = ...

local LootAlertPresenter = {}
ns.LootAlertPresenter = LootAlertPresenter

LootAlertPresenter.REPEAT_SECONDS = 60

local function gainOf(ctx, item)
    local gain = ctx.gainOf and ctx.gainOf(item)
    return gain and gain > 0 and gain or nil
end

local function ranked(found, order)
    table.sort(found, function(a, b)
        local wa, wb = a.reason == "wishlist", b.reason == "wishlist"
        if wa ~= wb then
            return wa
        end
        local ga, gb = a.gain or 0, b.gain or 0
        if ga ~= gb then
            return ga > gb
        end
        return order[a] < order[b]
    end)
    return found
end

function LootAlertPresenter.match(items, ctx)
    local found, done, order = {}, {}, {}
    for _, item in ipairs(items or {}) do
        local itemID = item.itemID
        if itemID and not done[itemID] then
            done[itemID] = true
            local gain = gainOf(ctx, item)
            local reason = (ctx.has and ctx.has(itemID)) and "wishlist"
                or (gain and gain >= (ctx.minGain or 0) and "upgrade") or nil
            if reason then
                local match = { itemID = itemID, link = item.link, reason = reason, gain = gain,
                    gainText = gain and ns.Format.points(gain) or nil }
                found[#found + 1] = match
                order[match] = #found
            end
        end
    end
    return ranked(found, order)
end

function LootAlertPresenter.text(match, name, quest)
    local L = ns.L
    local format = L.LOOT_ALERT_UPGRADE
    if match.reason == "wishlist" then
        format = L.LOOT_ALERT_WISHLIST
    elseif quest then
        format = L.LOOT_ALERT_QUEST
    end
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
