-- CONTRAT
-- Score d'objet et gain par rapport à l'équipement porté. Pur : aucun appel à l'API WoW.
-- Charger après Engine/Proficiency.lua.
--   score(stats, weights, ctx) -> number ; somme de stats[clé] * weights[clé] ;
--     ctx.caps = {[clé]=plafond}, ctx.base = {[clé]=total sans l'objet} : seule la part
--     sous le plafond compte (score marginal)
--   delta(itemID, player, profile, data) -> {abs, pct, slot} | nil
--     player = Player.snapshot(), plus equippedStats = {[slot]=stats} facultatif pour les
--     objets portés absents de la base (sinon comptés vides) ; profile = {weights, caps} ;
--     data = façade DataProvider. pct = abs / score retiré * 100, nil si ce score vaut 0.
--     nil : objet inconnu, sans emplacement, non équipable (Proficiency, classMask).
--     Anneaux, bijoux : emplacement vide d'abord, sinon le plus faible. Deux-mains : comparée
--     à main droite + main gauche ; arme ou main gauche face à une deux-mains : comparée à elle.
--     Une main : main droite, ou main gauche si la classe a la double arme, le meilleur gain.
--     Totaux de plafond : HIT = player.meleeHit, SPELL_HIT = player.spellHit, moins les objets
--     retirés. Résultat en cache par (itemID, empreinte de weights et caps) : table partagée,
--     à ne pas modifier. Le cache se vide quand player n'est plus la même table.
--   invalidate() -> vide le cache (instantané modifié sur place).
--   dependsOn(itemID, data) -> {slot...} : emplacements portés dont dépend delta (anneaux,
--     bijoux : les deux ; armes, boucliers, mains gauches : 16 et 17) ; {} si inconnu.
--   hasClass(classMask, class) -> bool ; classMask nil = toute classe.
--   hasRace(raceMask, raceID, faction) -> bool ; raceMask nil = toute race. Bit de la race (Skyborne
--     95, 96 aux bits 32, 33) ; race inconnue : vrai si le masque a une race de `faction`, ou sans faction.
--   allows(quest, player) -> bool : hasClass et hasRace de la quête pour player (class, raceID, faction).

local _, ns = ...

local Scoring = {}
ns.Scoring = Scoring

local MAIN_HAND_SLOT, OFF_HAND_SLOT = 16, 17

-- InventoryType -> emplacements candidats.
local SLOTS = {
    [1] = { 1 }, [2] = { 2 }, [3] = { 3 }, [4] = { 4 }, [5] = { 5 }, [20] = { 5 },
    [6] = { 6 }, [7] = { 7 }, [8] = { 8 }, [9] = { 9 }, [10] = { 10 },
    [11] = { 11, 12 }, [12] = { 13, 14 }, [16] = { 15 },
    [13] = { MAIN_HAND_SLOT }, [17] = { MAIN_HAND_SLOT }, [21] = { MAIN_HAND_SLOT },
    [14] = { OFF_HAND_SLOT }, [22] = { OFF_HAND_SLOT }, [23] = { OFF_HAND_SLOT },
    [15] = { 18 }, [25] = { 18 }, [26] = { 18 }, [28] = { 18 },
    [19] = { 19 },
}
local ONE_HAND, TWO_HAND = 13, 17
local PAIRED = { [11] = true, [12] = true }

-- Classe -> niveau d'apprentissage de la double arme (Classic).
local DUAL_WIELD = { ROGUE = 10, WARRIOR = 20, HUNTER = 20 }

-- Identifiants de classe du client (bit du classMask = 2^(id-1)).
local CLASS_IDS = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
    SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
}

-- Totaux du joueur connus par l'instantané, pour les plafonds.
local PLAYER_TOTALS = { HIT = "meleeHit", SPELL_HIT = "spellHit" }

local cache, cachedPlayer = {}, nil

function Scoring.score(stats, weights, ctx)
    local caps = ctx and ctx.caps or {}
    local base = ctx and ctx.base or {}
    local total = 0
    for key, value in pairs(stats or {}) do
        local weight = weights[key]
        if weight then
            local cap = caps[key]
            if cap then
                value = math.min(value, math.max(0, cap - (base[key] or 0)))
            end
            total = total + value * weight
        end
    end
    return total
end

local function sortedPairs(map)
    local keys = {}
    for key in pairs(map or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    local parts = {}
    for _, key in ipairs(keys) do
        parts[#parts + 1] = key .. "=" .. tostring(map[key])
    end
    return table.concat(parts, ",")
end

local function fingerprint(profile)
    return sortedPairs(profile.weights) .. "|" .. sortedPairs(profile.caps)
end

function Scoring.hasClass(classMask, class)
    if not classMask then
        return true
    end
    local id = CLASS_IDS[class]
    if not id then
        return false
    end
    local bitValue = 2 ^ (id - 1)
    return classMask % (bitValue * 2) >= bitValue
end

-- Identifiants de race du client -> bit du raceMask (au-delà de 32 bits : arithmétique, pas `bit`).
local RACE_BITS = {
    [1] = 2 ^ 0, [2] = 2 ^ 1, [3] = 2 ^ 2, [4] = 2 ^ 3, [5] = 2 ^ 4, [6] = 2 ^ 5, [7] = 2 ^ 6, [8] = 2 ^ 7,
    [95] = 2 ^ 32, [96] = 2 ^ 33,
}
local FACTION_RACES = { Alliance = { 1, 3, 4, 7, 95 }, Horde = { 2, 5, 6, 8, 96 } }

local function hasBit(mask, bitValue)
    return mask % (bitValue * 2) >= bitValue
end

function Scoring.hasRace(raceMask, raceID, faction)
    if not raceMask then
        return true
    end
    local bitValue = RACE_BITS[raceID]
    if bitValue then
        return hasBit(raceMask, bitValue)
    end
    local races = FACTION_RACES[faction]
    if not races then
        return true
    end
    for _, id in ipairs(races) do
        if hasBit(raceMask, RACE_BITS[id]) then
            return true
        end
    end
    return false
end

function Scoring.allows(quest, player)
    return Scoring.hasClass(quest.classMask, player.class)
        and Scoring.hasRace(quest.raceMask, player.raceID, player.faction)
end

local function equippedStats(slot, player, data)
    local stats = player.equippedStats and player.equippedStats[slot]
    if stats then
        return stats
    end
    local itemID = player.equipped[slot]
    local fields = itemID and data.item(itemID)
    return fields and fields.stats or {}
end

local function sum(list)
    local total = {}
    for _, stats in ipairs(list) do
        for key, value in pairs(stats) do
            total[key] = (total[key] or 0) + value
        end
    end
    return total
end

-- Compare l'objet aux emplacements retirés ; renvoie abs, score retiré.
local function compare(stats, removedSlots, player, profile, data)
    local removed = {}
    for _, slot in ipairs(removedSlots) do
        removed[#removed + 1] = equippedStats(slot, player, data)
    end
    local removedStats = sum(removed)
    local base = {}
    for key, field in pairs(PLAYER_TOTALS) do
        base[key] = (player[field] or 0) - (removedStats[key] or 0)
    end
    local ctx = { caps = profile.caps, base = base }
    local before = Scoring.score(removedStats, profile.weights, ctx)
    return Scoring.score(stats, profile.weights, ctx) - before, before
end

local function result(abs, before, slot)
    return { abs = abs, pct = before ~= 0 and abs / before * 100 or nil, slot = slot }
end

local function bestOf(options, stats, player, profile, data)
    local best
    for _, option in ipairs(options) do
        local abs, before = compare(stats, option.removed, player, profile, data)
        if not best or abs > best.abs then
            best = result(abs, before, option.slot)
        end
    end
    return best
end

local function pairedOptions(itemID, slots, player)
    local free, others = {}, {}
    for _, slot in ipairs(slots) do
        local worn = player.equipped[slot]
        if not worn then
            free[#free + 1] = slot
        elseif worn ~= itemID then
            others[#others + 1] = slot
        end
    end
    local candidates = #free > 0 and { free[1] } or others
    if #candidates == 0 then
        candidates = { slots[1] }
    end
    -- Le plus faible porté donne le plus grand gain : bestOf le retient.
    local options = {}
    for _, slot in ipairs(candidates) do
        options[#options + 1] = { slot = slot, removed = { slot } }
    end
    return options
end

local function wearsTwoHand(player, data)
    local itemID = player.equipped[MAIN_HAND_SLOT]
    local fields = itemID and data.item(itemID)
    return fields ~= nil and fields.slot == TWO_HAND
end

local function weaponOptions(fields, slots, player, data)
    local slot = slots[1]
    if fields.slot == TWO_HAND then
        return { { slot = MAIN_HAND_SLOT, removed = { MAIN_HAND_SLOT, OFF_HAND_SLOT } } }
    end
    if wearsTwoHand(player, data) then
        return { { slot = slot, removed = { MAIN_HAND_SLOT } } }
    end
    local options = { { slot = slot, removed = { slot } } }
    local dualLevel = DUAL_WIELD[player.class]
    if fields.slot == ONE_HAND and dualLevel and (player.level or 0) >= dualLevel then
        options[#options + 1] = { slot = OFF_HAND_SLOT, removed = { OFF_HAND_SLOT } }
    end
    return options
end

local function canUse(fields, player)
    local proficiency = ns.Proficiency
    return proficiency.canEquip(player.class, player.level, fields.itemClass, fields.itemSubClass)
        and Scoring.hasClass(fields.classMask, player.class)
end

local function compute(itemID, player, profile, data)
    local fields = data.item(itemID)
    local slots = fields and SLOTS[fields.slot]
    if not slots or not canUse(fields, player) then
        return nil
    end
    local options
    if PAIRED[fields.slot] then
        options = pairedOptions(itemID, slots, player)
    elseif slots[1] == MAIN_HAND_SLOT or slots[1] == OFF_HAND_SLOT then
        options = weaponOptions(fields, slots, player, data)
    else
        options = { { slot = slots[1], removed = { slots[1] } } }
    end
    return bestOf(options, fields.stats, player, profile, data)
end

function Scoring.delta(itemID, player, profile, data)
    if player ~= cachedPlayer then
        cache, cachedPlayer = {}, player
    end
    local key = itemID .. "|" .. fingerprint(profile)
    local cached = cache[key]
    if cached == nil then
        cached = compute(itemID, player, profile, data) or false
        cache[key] = cached
    end
    return cached or nil
end

function Scoring.invalidate()
    cache = {}
end

function Scoring.dependsOn(itemID, data)
    local fields = data.item(itemID)
    local slots = fields and SLOTS[fields.slot]
    if not slots then
        return {}
    end
    if slots[1] == MAIN_HAND_SLOT or slots[1] == OFF_HAND_SLOT then
        return { MAIN_HAND_SLOT, OFF_HAND_SLOT }
    end
    local copy = {}
    for i, slot in ipairs(slots) do
        copy[i] = slot
    end
    return copy
end
