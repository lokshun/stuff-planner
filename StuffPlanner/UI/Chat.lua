-- CONTRAT
-- Sorties texte dans la fenêtre de discussion. Charger après Scoring.lua, Chains.lua, Names.lua, Manager.lua.
--   ns.Chat.bestInZone(player, profile, data, opts) -> {{itemID, questID, delta, questState}...}
--     récompenses et choix des quêtes de player.mapID (data.questsInMap), gain abs > 0, triées par
--     gain décroissant puis itemID ; un objet n'apparaît qu'une fois (première quête par id) ;
--     quêtes exclues : opts.isDone(questID) vrai, reqLevel > player.level + 3 ;
--     opts.limit (5 par défaut) ; opts.delta(itemID) remplace Scoring.delta (Results).
--     opts.fallback : ensuite, par emplacement (anneaux, bijoux : un groupe) sans gain > 0, l'entrée de plus
--     fort delta.fallback (profil personnalisé, Scoring) copiée avec delta = Scoring.fallbackOf, gain décroissant.
--     questState = Chains.questState(quest, player.level, opts) (opts.isInLog, opts.isDone).
--     opts.instances : aussi le butin des instances dont l'entrée est sur la carte
--     (data.instancesInMap, instanceItems), après les quêtes (un objet de quête garde sa quête) ;
--     entrée {itemID, source = {type, id, chance, npcID}, delta, questState}, sans questID ;
--     source = celle de data.sourcesOf pour cette instance au meilleur taux, sinon {type, id} ;
--     instances exclues : minLevel > player.level + INSTANCE_WINDOW (10) ; questState "level" si
--     minLevel > player.level. Pur : aucun appel d'API.
--   ns.Chat.currentZone(limit, instances, fallback?) -> résultats de bestInZone pour la zone et le profil actuels,
--     mapID ; entrées de repli (delta.fallback) seulement si fallback ;
--     isDone = Compat.IsQuestCompleted, isInLog = Compat.IsOnQuest, opts.instances = instances ;
--     instantané et gains partagés de ns.Results ;
--     nil, message (L.BEST_NOT_READY | BEST_NO_PROFILE | BEST_NO_ZONE) si impossible.
--     Un seul classement (sans limite, instances comprises) gardé pour l'instantané et le profil, oublié sur
--     SP_RESULTS_UPDATED et SP_QUEST_LOG_CHANGED ; chaque appel en reçoit une liste neuve, sans les entrées
--     d'instance si instances est faux, tronquée à limit (DEFAULT_LIMIT) ; entrées partagées, à ne pas modifier.
-- Commande /splan best : top 5 de la zone actuelle pour le profil actif ; gain en points de score
--   (même échelle que le tri, 2 décimales sous 1) ; « estimé » si l'objet a confidence 1.
--   Noms demandés au client (Names.onReady) : affichage dès qu'ils sont tous connus, au plus 2 s.
-- /splan best : quêtes seulement.

local _, ns = ...

local L = ns.L

local Chat = {}
ns.Chat = Chat

local DEFAULT_LIMIT = 5
local LEVEL_WINDOW = 3
local INSTANCE_WINDOW = 10
local LOW_CONFIDENCE = 1
local NAME_TIMEOUT = 2

local function questAllowed(quest, player, isDone)
    if not quest or (isDone and isDone(quest.id)) then
        return false
    end
    return not (quest.reqLevel and player.level and quest.reqLevel > player.level + LEVEL_WINDOW)
end

local function addCandidates(list, seen, quest, items, state)
    for _, itemID in ipairs(items or {}) do
        if not seen[itemID] then
            seen[itemID] = true
            list[#list + 1] = { itemID = itemID, questID = quest.id, questState = state }
        end
    end
end

-- Source de l'objet pour cette instance : meilleur taux connu, sinon le type de l'instance.
local function instanceSource(itemID, instance, data)
    local best
    for _, source in ipairs(data.sourcesOf(itemID)) do
        if source.id == instance.id and (source.type == "dungeon" or source.type == "raid")
            and (not best or (source.chance or 0) > (best.chance or 0)) then
            best = source
        end
    end
    return best or { type = instance.raid and "raid" or "dungeon", id = instance.id }
end

local function addInstances(list, seen, player, data)
    local level = player.level or 1
    for _, instanceID in ipairs(data.instancesInMap(player.mapID)) do
        local instance = data.instance(instanceID)
        local minLevel = instance and instance.minLevel or 1
        if instance and minLevel <= level + INSTANCE_WINDOW then
            local state = minLevel > level and "level" or nil
            for _, itemID in ipairs(data.instanceItems(instanceID)) do
                if not seen[itemID] then
                    seen[itemID] = true
                    list[#list + 1] = { itemID = itemID, source = instanceSource(itemID, instance, data),
                        questState = state }
                end
            end
        end
    end
end

local SLOT_GROUP = { [12] = 11, [14] = 13 }

local function byGain(a, b)
    if a.delta.abs ~= b.delta.abs then
        return a.delta.abs > b.delta.abs
    end
    return a.itemID < b.itemID
end

-- Par groupe d'emplacements sans gain > 0 : l'entrée de plus fort gain de repli, copiée.
local function fallbackEntries(considered)
    local covered, best = {}, {}
    for _, entry in ipairs(considered) do
        local delta = entry.delta
        local key = delta.slot and (SLOT_GROUP[delta.slot] or delta.slot)
        if key and delta.abs > 0 then
            covered[key] = true
        elseif key and delta.fallback and (not best[key] or delta.fallback > best[key].delta.fallback) then
            best[key] = entry
        end
    end
    local out = {}
    for key, entry in pairs(best) do
        if not covered[key] then
            out[#out + 1] = { itemID = entry.itemID, questID = entry.questID, source = entry.source,
                questState = entry.questState, delta = ns.Scoring.fallbackOf(entry.delta) }
        end
    end
    table.sort(out, byGain)
    return out
end

function Chat.bestInZone(player, profile, data, opts)
    opts = opts or {}
    local candidates, seen = {}, {}
    for _, questID in ipairs(player.mapID and data.questsInMap(player.mapID) or {}) do
        local quest = data.quest(questID)
        if questAllowed(quest, player, opts.isDone) then
            local state = ns.Chains.questState(quest, player.level, opts)
            addCandidates(candidates, seen, quest, quest.rewards, state)
            addCandidates(candidates, seen, quest, quest.choices, state)
        end
    end
    if opts.instances and player.mapID then
        addInstances(candidates, seen, player, data)
    end
    local results, considered = {}, {}
    for _, entry in ipairs(candidates) do
        local delta = opts.delta and opts.delta(entry.itemID)
            or not opts.delta and ns.Scoring.delta(entry.itemID, player, profile, data)
        if delta then
            entry.delta = delta
            considered[#considered + 1] = entry
            if delta.abs > 0 then
                results[#results + 1] = entry
            end
        end
    end
    table.sort(results, byGain)
    if opts.fallback then
        for _, entry in ipairs(fallbackEntries(considered)) do
            results[#results + 1] = entry
        end
    end
    for i = #results, (opts.limit or DEFAULT_LIMIT) + 1, -1 do
        results[i] = nil
    end
    return results
end

-- Toujours en points : le % de l'objet remplacé explose quand celui-ci n'a presque aucune stat pondérée.
local function gainText(delta)
    return "+" .. ns.Format.number(delta.abs, nil, delta.abs < 1 and 2 or 1)
end

local function lineFor(rank, entry, data)
    local text = L.BEST_LINE:format(rank, ns.Names.item(entry.itemID), gainText(entry.delta),
        ns.Names.quest(entry.questID))
    local fields = data.item(entry.itemID)
    if fields and fields.confidence == LOW_CONFIDENCE then
        text = text .. L.BEST_ESTIMATED
    end
    return text
end

-- Appelle done une fois, quand tous les noms sont connus ou après NAME_TIMEOUT secondes.
local function whenNamed(results, done)
    local pending, finished = 1, false
    local function finish()
        if not finished then
            finished = true
            done()
        end
    end
    local function settle()
        pending = pending - 1
        if pending == 0 then
            finish()
        end
    end
    for _, entry in ipairs(results) do
        pending = pending + 2
        ns.Names.onReady("item", entry.itemID, settle)
        ns.Names.onReady("quest", entry.questID, settle)
    end
    settle()
    if not finished then
        C_Timer.After(NAME_TIMEOUT, finish)
    end
end

local shared -- {player, profile, results}

local function sharedRanking(player, profile, data)
    if not (shared and shared.player == player and shared.profile == profile) then
        local opts = { isDone = ns.Compat.IsQuestCompleted, isInLog = ns.Compat.IsOnQuest, limit = math.huge,
            delta = ns.Results.delta, instances = true, fallback = true }
        shared = { player = player, profile = profile, results = Chat.bestInZone(player, profile, data, opts) }
    end
    return shared.results
end

local function forget()
    shared = nil
end

function Chat.currentZone(limit, instances, fallback)
    local data = ns.Data
    if not data.ready() then
        return nil, L.BEST_NOT_READY
    end
    local profile = ns.Profiles.active()
    if not profile then
        return nil, L.BEST_NO_PROFILE
    end
    local player = ns.Results.player()
    if not player or not player.mapID then
        return nil, L.BEST_NO_ZONE
    end
    local results, max = {}, limit or DEFAULT_LIMIT
    for _, entry in ipairs(sharedRanking(player, profile, data)) do
        if #results >= max then
            break
        end
        if (instances or entry.questID) and (fallback or not entry.delta.fallback) then
            results[#results + 1] = entry
        end
    end
    return results, player.mapID
end

local function showBest()
    local results, mapID = Chat.currentZone()
    if not results then
        print(mapID)
        return
    end
    local data = ns.Data
    local zone = ns.Names.zone(mapID)
    if #results == 0 then
        print(L.BEST_NONE:format(zone))
        return
    end
    whenNamed(results, function()
        print(L.BEST_HEADER:format(zone))
        for rank, entry in ipairs(results) do
            print(lineFor(rank, entry, data))
        end
    end)
end

ns:RegisterCommand("best", showBest, "BEST_COMMAND_HELP")
ns:On("SP_RESULTS_UPDATED", forget)
ns:On("SP_QUEST_LOG_CHANGED", forget)
