-- CONTRAT
-- Paliers du parcours 1-60 : meilleur objet par emplacement et par palier. Pur : aucun appel d'API.
--   BOUNDS = {{min, max}...} : 1-10, 11-20, 21-30, 31-40, 41-50, 51-59, 60
--   indexOf(level) -> indice du palier (niveau nil ou < 1 : 1 ; > 60 : dernier)
--   build(rows, player, reference?) -> {{min, max, past?, entries = {row...}, alternatives}...}
--     rows = Planner.rank (priority, delta.slot, level) ; palier de l'objet = celui de
--     max(row.level, player.level) : rien avant le palier du joueur, paliers vides omis.
--     Par palier et emplacement : la plus forte priorité ; anneaux (11, 12) et bijoux (13, 14)
--     forment un groupe de deux. Entrées dans l'ordre de la fiche de personnage, lignes partagées.
--     Ligne sans delta.slot : ignorée ; sans level : niveau 1.
--     reference = Planner.rank en mode référence : paliers sous celui du joueur (past = true), objet
--     rangé dans le palier de son level, même choix par emplacement ; lignes des autres paliers ignorées.
--     alternatives = {[itemID d'une entrée] = {row...}} : jusqu'à ALTERNATIVES autres lignes du même
--     groupe, gain > 0, effort plus faible que l'entrée ; effort croissant, puis gain, puis itemID ;
--     vide si past. Entrée d'artisanat (source.type "craft") : quests[slot] placée en tête.
--     quests = {[slot] = row} (paliers non passés) : quête de plus fort gain du groupe hors objets choisis
--     (gain > 0, tout effort), à défaut celle d'un palier suivant (le plus proche) ; anneaux et bijoux :
--     même ligne sous les deux emplacements ; emplacement sans quête nulle part : absent.
--   current(tiers, level) -> palier de build contenant level | nil (absent, vide ou tiers nil) ;
--     un palier passé ne contient jamais le niveau du joueur

local _, ns = ...

local Tiers = {}
ns.Tiers = Tiers

Tiers.ALTERNATIVES = 3

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

local function byEffort(a, b)
    if a.effort ~= b.effort then
        return a.effort < b.effort
    end
    if a.delta.abs ~= b.delta.abs then
        return a.delta.abs > b.delta.abs
    end
    return a.itemID < b.itemID
end

local function isQuest(row)
    return row.source ~= nil and row.source.type == "quest"
end

-- Quête de plus fort gain hors des count premières lignes (choisies) | nil.
local function bestQuest(list, count)
    local best
    for i = count + 1, #list do
        local row = list[i]
        if isQuest(row) and row.delta.abs > 0 and (not best or row.delta.abs > best.delta.abs
            or (row.delta.abs == best.delta.abs and row.itemID < best.itemID)) then
            best = row
        end
    end
    return best
end

-- Lignes plus faciles que list[index], hors des count premières (choisies) ; artisanat : quête en tête.
local function easier(list, index, count, groupQuest)
    local chosen, out = list[index], {}
    local quest = chosen.source and chosen.source.type == "craft" and groupQuest or nil
    for i = count + 1, #list do
        local row = list[i]
        if row ~= quest and row.delta.abs > 0 and row.effort and chosen.effort and row.effort < chosen.effort then
            out[#out + 1] = row
        end
    end
    table.sort(out, byEffort)
    if quest then
        table.insert(out, 1, quest)
    end
    for i = #out, Tiers.ALTERNATIVES + 1, -1 do
        out[i] = nil
    end
    return out
end

local function entriesOf(slots, past, quests)
    local keys = {}
    for key in pairs(slots) do
        keys[#keys + 1] = key
    end
    table.sort(keys, bySlot)
    local entries, alternatives = {}, {}
    for _, key in ipairs(keys) do
        local list = slots[key]
        local count = math.min(#list, GROUP_SIZE[key] or 1)
        for i = 1, count do
            entries[#entries + 1] = list[i]
            local found = not past and easier(list, i, count, quests[key]) or {}
            if #found > 0 then
                alternatives[list[i].itemID] = found
            end
        end
    end
    return entries, alternatives
end

-- Quête imposée par groupe pour le palier index : la sienne hors choisies, sinon celle d'un palier suivant.
local function questsOf(buckets, index)
    local quests = {}
    for i = #Tiers.BOUNDS, index, -1 do
        for key, list in pairs(buckets[i] or {}) do
            local count = i == index and math.min(#list, GROUP_SIZE[key] or 1) or 0
            quests[key] = bestQuest(list, count) or quests[key]
        end
    end
    return quests
end

local function bySlotKey(quests)
    local out = {}
    for key, row in pairs(quests) do
        out[key] = row
    end
    for slot, key in pairs(GROUP) do
        out[slot] = quests[key]
    end
    return out
end

function Tiers.build(rows, player, reference)
    local first = Tiers.indexOf(player.level)
    local buckets = {}
    group(rows, first, false, buckets)
    group(reference or {}, first, true, buckets)
    for _, slots in pairs(buckets) do
        for _, list in pairs(slots) do
            table.sort(list, byPriority)
        end
    end
    local tiers = {}
    for index, bounds in ipairs(Tiers.BOUNDS) do
        if buckets[index] then
            tiers[#tiers + 1] = {
                min = bounds[1],
                max = bounds[2],
                past = index < first or nil,
            }
            local quests = index < first and {} or questsOf(buckets, index)
            tiers[#tiers].entries, tiers[#tiers].alternatives = entriesOf(buckets[index], index < first, quests)
            tiers[#tiers].quests = bySlotKey(quests)
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
