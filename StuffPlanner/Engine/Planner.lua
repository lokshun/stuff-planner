-- CONTRAT
-- Priorité de parcours : (gain × durée de vie + ALPHA × XP) / minutes d'effort. Pur : aucun appel à l'API WoW.
-- Charger après Engine/Effort.lua (calcul de l'effort d'une source).
--   candidates(itemIDs, data, step?) -> {{itemID, source}...}, une entrée par source de data.sourcesOf ;
--     step() appelé après chaque objet (sourcesOf décode la base : à étaler)
--   rank(candidates, player, profile, data, opts?) -> {{itemID, source, delta, effort, seconds, xp, level, hops,
--     steps, priority}...} : un objet une fois (sa meilleure source), tri par priorité décroissante
--     puis itemID ; delta = Scoring.delta ({abs, pct, slot}), objets à gain abs <= 0 écartés, sauf
--     opts.fallback (parcours normal) : delta = Scoring.fallbackOf s'il existe (repli hors profil).
--     opts.isDone(questID) ; opts.includeRaids (raids écartés sinon) ; opts.tuning = {clé=valeur}
--     remplace les constantes de Planner.TUNING (Calibration.tuning : mesures du joueur).
--     opts.travel(mapID, x, y) -> secondes | nil : trajet du joueur jusqu'au donneur de la première étape
--     restante (data.npc, x, y en 0–1) ; nil, absent ou sans donneur : hops × TRAVEL.
--     effort = seconds (s) ; trip = part du trajet dans seconds, place = départ de la 1re étape (QuestStart.of)
--     (Session ; nil hors secondes, artisanat, place nil hors quête). opts.step() appelé après chaque candidat
--     (coroutine.yield pour étaler le calcul sur plusieurs images) ; opts.pause() appelé une fois avant
--     le tri final (yield sans condition : le tri ne partage pas son image).
--   opts.reference = true : paliers passés du Parcours, « comme si on y était ». Gain = score de l'objet
--     (Scoring.score, poids du profil), durée de vie 1, sans XP ; objets sans delta (non équipables)
--     écartés, score <= 0 écarté, level > opts.maxLevel écarté avant tout calcul d'effort ; quêtes
--     faites gardées (chaîne entière) ; lignes + done (opts.isDone de la quête), beaten (delta.abs <= 0).
-- level = niveau d'obtention : max(reqLevel de l'objet, niveau de la quête | minLevel de l'instance) ;
--   les récompenses de quête de Classic n'ont souvent pas de niveau requis (reqLevel 1).
-- Durée de vie : min(LIFESPAN, 60 - L) / LIFESPAN, L = max(niveau du joueur, level) ; 1 si L >= 60.
-- Trajet : TRAVEL × hops, hops = Distance.hops(carte du joueur, carte de la source, MAX_HOPS) ; carte de la
--   quête, entrée de l'instance (donjon, raid), carte du butin (monde, opts.travel vers x, y s'ils sont connus) ;
--   0 et hops nil si l'une est inconnue ou pour l'artisanat.
-- Effort : quête = étapes restantes (Chains.steps) × QUEST_STEP + trajet ; écartée si faite, en cycle,
--   inconnue, impossible (Feasible.check sur la quête et ses étapes : classe, race, niveau max, exclusive,
--   suivante faite...) ; + CONDITION par étape à condition atteignable (métier, réputation, sort), raison
--   de la première dans la ligne (condition, parcours normal) ; opts.isInLog (exclusives en cours) ;
--   alternative de prérequis d'une autre race écartée (Chains, isAllowed).
--   Donjon, raid = DUNGEON_RUN, RAID_RUN × 100 / chance (DEFAULT_CHANCE sans taux, MIN_CHANCE au
--   moins) + trajet ; monde = WORLD_KILL × 100 / chance + trajet ;
--   artisanat = CRAFT si player.professions[skillLine], CRAFT_UNKNOWN sinon.
-- steps : étapes restantes de la quête (nil hors quête).
--   effort(source, player, data, opts?) -> secondes, étapes (quête) | nil (source écartée) : effort d'une source
--     seule, mêmes règles que rank (opts.isDone, includeRaids, travel, tuning) ; Wishlist.
-- XP : quêtes seulement, nombre d'étapes restantes non grises ; 0 au niveau 60.

local _, ns = ...

local Planner = {}
ns.Planner = Planner

local MAX_LEVEL = 60

-- Secondes, provisoires : quête (prise, objectif, rendu sur place) 7 min, zone traversée 3 min
-- (Travel.TUNING.zoneSeconds), donjon 50 min, raid 3 h, créature du butin de monde 3 min, artisanat 2 min,
-- métier à monter 1 h, condition atteignable d'une étape (métier, réputation, sort) 1 h.
Planner.TUNING = {
    LIFESPAN = 8,
    ALPHA = 0.1,
    QUEST_STEP = 420,
    TRAVEL = 180,
    MAX_HOPS = 3,
    DUNGEON_RUN = 3000,
    RAID_RUN = 10800,
    WORLD_KILL = 180,
    DEFAULT_CHANCE = 5,
    MIN_CHANCE = 1,
    CRAFT = 120,
    CRAFT_UNKNOWN = 3600,
    CONDITION = 3600,
    UNPLACED = 300, -- départ de quête sans position exacte (zone, donjon) : après une source placée
    TRAVEL_FACTOR = 1, -- trajet réel / prévu (Calibration)
}

function Planner.candidates(itemIDs, data, step)
    local out = {}
    for _, itemID in ipairs(itemIDs) do
        for _, source in ipairs(data.sourcesOf(itemID) or {}) do
            out[#out + 1] = { itemID = itemID, source = source }
        end
        if step then
            step()
        end
    end
    return out
end

local function obtainLevel(item, source, data)
    local level = item and item.reqLevel or 1
    if source.type == "quest" then
        local quest = data.quest(source.id)
        level = math.max(level, quest and (quest.level or quest.reqLevel) or 1)
    elseif source.type == "dungeon" or source.type == "raid" then
        local instance = data.instance and data.instance(source.id)
        level = math.max(level, instance and instance.minLevel or 1)
    end
    return level
end

local function lifetime(obtained, player, tuning)
    local level = math.max(player.level or 1, obtained)
    if level >= MAX_LEVEL then
        return 1
    end
    return math.min(tuning.LIFESPAN, MAX_LEVEL - level) / tuning.LIFESPAN
end

local function tuningOf(opts)
    local tuning = {}
    for key, value in pairs(Planner.TUNING) do
        tuning[key] = value
    end
    for key, value in pairs(opts.tuning or {}) do
        tuning[key] = value
    end
    return tuning
end

local function neverDone()
    return false
end

-- Ligne d'un candidat en parcours normal ; nil si écarté.
local function evaluate(candidate, delta, player, data, opts, tuning)
    delta = (opts.fallback and delta and delta.abs <= 0) and ns.Scoring.fallbackOf(delta) or delta
    if not delta or delta.abs <= 0 then
        return nil
    end
    local effort, xp, hops, steps, trip, place, condition = ns.Effort.of(candidate.source, player, data, opts,
        tuning)
    if not effort or effort <= 0 then
        return nil
    end
    local level = obtainLevel(data.item(candidate.itemID), candidate.source, data)
    local gain = delta.abs * lifetime(level, player, tuning)
    return { effort = effort, seconds = effort, xp = xp, hops = hops, steps = steps, level = level,
        priority = (gain + tuning.ALPHA * xp) / (effort / 60), trip = trip, place = place, delta = delta,
        condition = condition }
end

-- Ligne d'un candidat en mode référence ; nil si écarté.
local function evaluateReference(candidate, delta, player, profile, data, opts, tuning)
    local item = delta and data.item(candidate.itemID)
    local level = item and obtainLevel(item, candidate.source, data)
    if not level or (opts.maxLevel and level > opts.maxLevel) then
        return nil
    end
    local score = ns.Scoring.score(item.stats, profile.weights)
    if score <= 0 then
        return nil
    end
    local effort, _, hops, steps = ns.Effort.of(candidate.source, player, data, opts.effortOpts, tuning)
    if not effort or effort <= 0 then
        return nil
    end
    local source = candidate.source
    local done = source.type == "quest" and opts.isDone ~= nil and opts.isDone(source.id) == true
    return { effort = effort, seconds = effort, xp = 0, hops = hops, steps = steps, level = level,
        priority = score / (effort / 60), done = done, beaten = delta.abs <= 0 }
end

function Planner.effort(source, player, data, opts)
    opts = opts or {}
    local seconds, _, _, steps = ns.Effort.of(source, player, data, opts, tuningOf(opts))
    if not seconds or seconds <= 0 then
        return nil
    end
    return seconds, steps
end

function Planner.rank(candidates, player, profile, data, opts)
    opts = opts or {}
    local tuning = tuningOf(opts)
    if opts.reference then
        opts.effortOpts = { isDone = neverDone, includeRaids = opts.includeRaids, travel = opts.travel,
            reference = true }
    end
    local best, deltas = {}, {}
    for _, candidate in ipairs(candidates) do
        local itemID = candidate.itemID
        if deltas[itemID] == nil then
            deltas[itemID] = ns.Scoring.delta(itemID, player, profile, data) or false
        end
        local delta = deltas[itemID]
        local row
        if opts.reference then
            row = evaluateReference(candidate, delta, player, profile, data, opts, tuning)
        else
            row = evaluate(candidate, delta, player, data, opts, tuning)
        end
        local current = best[itemID]
        if row and (not current or row.priority > current.priority) then
            row.itemID, row.source, row.delta = itemID, candidate.source, row.delta or delta
            best[itemID] = row
        end
        if opts.step then
            opts.step()
        end
    end
    if opts.pause then
        opts.pause()
    end
    local out = {}
    for _, row in pairs(best) do
        out[#out + 1] = row
    end
    table.sort(out, function(a, b)
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end
        return a.itemID < b.itemID
    end)
    return out
end
