-- CONTRAT
-- Liste cible : objets épinglés par le joueur, quel que soit leur gain. Pur : aucun appel à l'API WoW.
-- Charger après Engine/Planner.lua et Engine/Chains.lua (ns.Feasible lu à l'appel : étapes impossibles écartées).
--   ns.Wishlist.status(itemIDs, player, data, opts?) -> view
--     opts = {isDone(questID), owned(itemID) -> bool (sacs, banque), travel, tuning} (comme Planner.rank) ;
--     view = {entries = {entry...} (ordre de itemIDs, doublons retirés), progress = {done, total},
--             nextIndex = indice de l'entrée non obtenue la plus rapide (puis la première) | nil}
--     entry = {itemID, obtained (porté : player.equipped, ou opts.owned), blocked (aucune source possible),
--              source (la plus rapide de data.sourcesOf, Planner.effort, raids compris) | nil, seconds | nil,
--              steps = {questID...} (quêtes restantes, prérequis d'abord : Chains.remaining) | nil hors quête}
--     Objet obtenu : ni source ni étapes.

local _, ns = ...

local Wishlist = {}
ns.Wishlist = Wishlist

local function equipped(player, itemID)
    for _, id in pairs(player.equipped or {}) do
        if id == itemID then
            return true
        end
    end
    return false
end

local function questSteps(source, player, data, opts)
    return ns.Chains.remaining(source.id, data, opts.isDone, function(id)
        local step = data.quest(id)
        return not step or ns.Feasible.allows(step, player, opts.isDone)
    end)
end

local function bestSource(itemID, player, data, effortOpts)
    local best, bestSeconds
    for _, source in ipairs(data.sourcesOf(itemID) or {}) do
        local seconds = ns.Planner.effort(source, player, data, effortOpts)
        if seconds and (not bestSeconds or seconds < bestSeconds) then
            best, bestSeconds = source, seconds
        end
    end
    return best, bestSeconds
end

local function entryOf(itemID, player, data, opts, effortOpts)
    local owned = equipped(player, itemID) or (opts.owned ~= nil and opts.owned(itemID) == true)
    local entry = { itemID = itemID, obtained = owned, blocked = false }
    if owned then
        return entry
    end
    entry.source, entry.seconds = bestSource(itemID, player, data, effortOpts)
    entry.blocked = entry.source == nil
    if entry.source and entry.source.type == "quest" then
        entry.steps = questSteps(entry.source, player, data, opts)
    end
    return entry
end

function Wishlist.status(itemIDs, player, data, opts)
    opts = opts or {}
    local effortOpts = { isDone = opts.isDone, includeRaids = true, travel = opts.travel, tuning = opts.tuning }
    local view = { entries = {}, progress = { done = 0, total = 0 } }
    local seen, fastest = {}, nil
    for _, itemID in ipairs(itemIDs) do
        if not seen[itemID] then
            seen[itemID] = true
            local entry = entryOf(itemID, player, data, opts, effortOpts)
            view.entries[#view.entries + 1] = entry
            local index = #view.entries
            view.progress.total = index
            if entry.obtained then
                view.progress.done = view.progress.done + 1
            elseif entry.seconds and (not fastest or entry.seconds < fastest) then
                view.nextIndex, fastest = index, entry.seconds
            end
        end
    end
    return view
end
