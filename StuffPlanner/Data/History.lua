-- CONTRAT
-- Journal de progression du personnage : score porté (Totals.equipped, profil actif) relevé à chaque niveau
-- gagné et à chaque amélioration équipée. Sauvegarde StuffPlannerCharDB.history = {entries, last}.
-- Charger après DB.lua, Player.lua, Profiles/Manager.lua, Engine/Totals.lua.
--   ns.History.MAX = 500 : au-delà, les entrées les plus anciennes sont retirées
--   ns.History.entries() -> {entry...} du plus ancien au plus récent (table de la sauvegarde : lecture seule)
--     entry = {at (time()), level, score, profileID, kind = "start" | "level" | "upgrade",
--              itemID, slot, gain (upgrade seulement)}
--   ns.History.observe(snapshot, profileID, score, at) -> entry ajoutée | nil ; comparé au relevé précédent :
--     aucun ou autre profil -> "start" ; niveau plus haut -> "level" ; score plus haut avec un objet
--     porté changé -> "upgrade" (premier emplacement changé, gain = écart de score) ; sinon rien.
--     Le relevé précédent (last) est remplacé dans tous les cas (objet moins bon : nouvelle référence).
--   ns.History.record() : instantané, profil actif, score ; rien sans profil, sans Data prête ou en combat.
-- SP_HISTORY_CHANGED (sans argument) après chaque entrée ajoutée.
-- Relevé sur SP_PLAYER_CHANGED, SP_PROFILE_CHANGED et SP_DATA_READY.

local _, ns = ...

local History = {}
ns.History = History

History.MAX = 500

local EPSILON = 1e-6

local function store()
    return ns.DB.char("history")
end

function History.entries()
    return ns.DB.char("history", "entries")
end

local function copy(map)
    local result = {}
    for key, value in pairs(map or {}) do
        result[key] = value
    end
    return result
end

local function changedSlot(before, after)
    local slots = {}
    for slot, itemID in pairs(after) do
        if before[slot] ~= itemID then
            slots[#slots + 1] = slot
        end
    end
    table.sort(slots)
    return slots[1]
end

local function entryFor(last, snapshot, profileID, score, at)
    local entry = { at = at, level = snapshot.level, score = score, profileID = profileID }
    if not last or last.profileID ~= profileID then
        entry.kind = "start"
    elseif (snapshot.level or 0) > (last.level or 0) then
        entry.kind = "level"
    elseif score > last.score + EPSILON then
        local slot = changedSlot(last.equipped or {}, snapshot.equipped or {})
        if not slot then
            return nil
        end
        entry.kind, entry.slot, entry.itemID = "upgrade", slot, snapshot.equipped[slot]
        entry.gain = score - last.score
    else
        return nil
    end
    return entry
end

function History.observe(snapshot, profileID, score, at)
    local root = store()
    local entry = entryFor(root.last, snapshot, profileID, score, at)
    root.last = { level = snapshot.level, score = score, profileID = profileID, equipped = copy(snapshot.equipped) }
    if not entry then
        return nil
    end
    local entries = History.entries()
    entries[#entries + 1] = entry
    while #entries > History.MAX do
        table.remove(entries, 1)
    end
    ns:Send("SP_HISTORY_CHANGED")
    return entry
end

function History.record()
    if InCombatLockdown() or not (ns.Data and ns.Data.ready()) then
        return
    end
    local profile = ns.Profiles.active()
    if not profile then
        return
    end
    local player = ns.Player.snapshot()
    local score = ns.Totals.equipped(player, profile, ns.Data)
    History.observe(player, ns.Profiles.activeID(), score, time())
end

ns:On("SP_PLAYER_CHANGED", History.record)
ns:On("SP_PROFILE_CHANGED", History.record)
ns:On("SP_DATA_READY", History.record)
