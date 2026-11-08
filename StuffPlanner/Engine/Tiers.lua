-- CONTRAT
-- Paliers du parcours 1-60 : meilleur objet par emplacement et par palier. Pur : aucun appel d'API.
--   BOUNDS = {{min, max}...} : 1-10, 11-20, 21-30, 31-40, 41-50, 51-59, 60
--   indexOf(level) -> indice du palier (niveau nil ou < 1 : 1 ; > 60 : dernier)
--   build(rows, player, reference?) -> {{min, max, past?, entries = {row...}}...}
--     rows = Planner.rank (priority, delta.slot, level) ; palier de l'objet = celui de
--     max(row.level, player.level) : rien avant le palier du joueur, paliers vides omis.
--     Par palier et emplacement : la plus forte priorité ; anneaux (11, 12) et bijoux (13, 14)
--     forment un groupe de deux. Entrées dans l'ordre de la fiche de personnage, lignes partagées.
--     Ligne sans delta.slot : ignorée ; sans level : niveau 1.
--     reference = Planner.rank en mode référence : paliers sous celui du joueur (past = true), objet
--     rangé dans le palier de son level, même choix par emplacement ; lignes des autres paliers ignorées.
--   current(tiers, level) -> palier de build contenant level | nil (absent, vide ou tiers nil) ;
--     un palier passé ne contient jamais le niveau du joueur

local _, ns = ...

local Tiers = {}
ns.Tiers = Tiers

Tiers.BOUNDS = { { 1, 10 }, { 11, 20 }, { 21, 30 }, { 31, 40 }, { 41, 50 }, { 51, 59 }, { 60, 60 } }

-- Emplacement -> groupe (premier emplacement), taille du groupe.
local GROUP = { [12] = 11, [14] = 13 }
local GROUP_SIZE = { [11] = 2, [13] = 2 }

-- Ordre de la fiche de personnage (groupes seulement).
local SLOT_ORDER = { 1, 2, 3, 15, 5, 4, 19, 9, 10, 6, 7, 8, 11, 13, 16, 17, 18 }
local RANK = {}
for position, slot in ipairs(SLOT_ORDER) do
    RANK[slot] = position
end

function Tiers.indexOf(level)
    level = level or 1
    for index, bounds in ipairs(Tiers.BOUNDS) do
        if level <= bounds[2] then
            return index
        end
    end
    return #Tiers.BOUNDS
end

local function byPriority(a, b)
    if a.priority ~= b.priority then
        return a.priority > b.priority
    end
    return a.itemID < b.itemID
end

local function bySlot(a, b)
    local rankA, rankB = RANK[a] or (100 + a), RANK[b] or (100 + b)
    return rankA < rankB
end

-- Regroupe les lignes : {[indice de palier] = {[groupe] = {row...}}}. Sans past : paliers >= first,
-- objets plus anciens repliés dans first ; avec past : paliers < first seulement.
local function group(rows, first, past, buckets)
    for _, row in ipairs(rows) do
        local slot = row.delta and row.delta.slot
        local own = Tiers.indexOf(row.level)
        if slot and (not past or own < first) then
            local index = past and own or math.max(first, own)
            local key = GROUP[slot] or slot
            buckets[index] = buckets[index] or {}
            local list = buckets[index][key] or {}
            buckets[index][key] = list
            list[#list + 1] = row
        end
    end
end

local function entriesOf(slots)
    local keys = {}
    for key in pairs(slots) do
        keys[#keys + 1] = key
    end
    table.sort(keys, bySlot)
    local entries = {}
    for _, key in ipairs(keys) do
        local list = slots[key]
        table.sort(list, byPriority)
        for i = 1, math.min(#list, GROUP_SIZE[key] or 1) do
            entries[#entries + 1] = list[i]
        end
    end
    return entries
end

function Tiers.build(rows, player, reference)
    local first = Tiers.indexOf(player.level)
    local buckets = {}
    group(rows, first, false, buckets)
    group(reference or {}, first, true, buckets)
    local tiers = {}
    for index, bounds in ipairs(Tiers.BOUNDS) do
        if buckets[index] then
            tiers[#tiers + 1] = {
                min = bounds[1],
                max = bounds[2],
                past = index < first or nil,
                entries = entriesOf(buckets[index]),
            }
        end
    end
    return tiers
end

function Tiers.current(tiers, level)
    level = level or 1
    for _, tier in ipairs(tiers or {}) do
        if tier.min <= level and level <= tier.max then
            return tier
        end
    end
    return nil
end
