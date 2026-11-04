-- CONTRAT
-- Recalcul incrémental des gains (Scoring.delta). Pur : aucun appel à l'API WoW.
-- Charger après Engine/Scoring.lua.
--   changes(old, new) -> true (tout recalculer) | {slots={[slot]=true}, totals=bool}
--     true : old nil, classe, race, faction ou niveau différents ; slots : emplacements dont
--     l'objet porté ou ses stats lues en jeu (equippedStats) ont changé, ajout et retrait
--     compris ; totals : meleeHit ou spellHit changé.
--     La carte n'entre pas en compte : le gain d'un objet n'en dépend pas.
--   zoneItems(mapIDs, data) -> {itemID...} : récompenses puis choix des quêtes de ces cartes
--     (data.questsInMap), une fois chacun, dans l'ordre des cartes et des quêtes.
--   new() -> store :
--     store:apply(player, profile, data) : nouvel instantané ; profil d'une autre table ou
--       changes = true : tout est oublié ; sinon seuls les objets dont un emplacement de
--       Scoring.dependsOn a changé et, si totals, ceux dont les stats, ou celles de l'objet
--       porté en face, ont une clé plafonnée par le profil (profile.caps).
--     store:delta(itemID) -> Scoring.delta | nil ; calculé au besoin puis gardé (nil aussi)
--     store:fill(itemIDs, step?) -> nombre de calculs faits ; step() après chacun (coroutine)
--     store:keep(itemIDs) : oublie les résultats hors de cette liste (portée zone + voisines)
--     store:reset() : oublie tout ; sans apply préalable, delta et fill ne calculent rien.
-- Profil modifié sur place : appeler reset (fait par Results sur SP_PROFILE_CHANGED).

local _, ns = ...

local Recompute = {}
ns.Recompute = Recompute

local IDENTITY = { "class", "race", "faction", "level" }
local TOTALS = { "meleeHit", "spellHit" }

local function sameStats(a, b)
    a, b = a or {}, b or {}
    for key, value in pairs(a) do
        if b[key] ~= value then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end

function Recompute.changes(old, new)
    if not old then
        return true
    end
    for _, key in ipairs(IDENTITY) do
        if old[key] ~= new[key] then
            return true
        end
    end
    local slots = {}
    for slot, itemID in pairs(old.equipped) do
        if new.equipped[slot] ~= itemID then
            slots[slot] = true
        end
    end
    for slot, itemID in pairs(new.equipped) do
        if old.equipped[slot] ~= itemID then
            slots[slot] = true
        end
    end
    local oldStats, newStats = old.equippedStats or {}, new.equippedStats or {}
    for slot = 1, 19 do
        if not sameStats(oldStats[slot], newStats[slot]) then
            slots[slot] = true
        end
    end
    local totals = false
    for _, key in ipairs(TOTALS) do
        if (old[key] or 0) ~= (new[key] or 0) then
            totals = true
        end
    end
    return { slots = slots, totals = totals }
end

local function addAll(list, seen, itemIDs)
    for _, itemID in ipairs(itemIDs or {}) do
        if not seen[itemID] then
            seen[itemID] = true
            list[#list + 1] = itemID
        end
    end
end

function Recompute.zoneItems(mapIDs, data)
    local list, seen = {}, {}
    for _, mapID in ipairs(mapIDs) do
        for _, questID in ipairs(data.questsInMap(mapID)) do
            local quest = data.quest(questID)
            if quest then
                addAll(list, seen, quest.rewards)
                addAll(list, seen, quest.choices)
            end
        end
    end
    return list
end

local Store = {}
Store.__index = Store

function Recompute.new()
    return setmetatable({ results = {} }, Store)
end

local function hasCapped(stats, caps)
    for key in pairs(stats or {}) do
        if caps[key] then
            return true
        end
    end
    return false
end

-- Vrai si le gain de l'objet peut changer avec le toucher total du joueur.
local function touchesCaps(itemID, slots, player, profile, data)
    local caps = profile.caps or {}
    local fields = data.item(itemID)
    if hasCapped(fields and fields.stats, caps) then
        return true
    end
    for _, slot in ipairs(slots) do
        local worn = player.equipped[slot]
        local wornFields = worn and data.item(worn)
        if hasCapped(wornFields and wornFields.stats, caps) then
            return true
        end
    end
    return false
end

local function stale(itemID, change, player, profile, data)
    local slots = ns.Scoring.dependsOn(itemID, data)
    for _, slot in ipairs(slots) do
        if change.slots[slot] then
            return true
        end
    end
    return change.totals and touchesCaps(itemID, slots, player, profile, data)
end

function Store:apply(player, profile, data)
    local change = profile == self.profile and Recompute.changes(self.player, player) or true
    self.player, self.profile, self.data = player, profile, data
    if change == true then
        self.results = {}
        return
    end
    for itemID in pairs(self.results) do
        if stale(itemID, change, player, profile, data) then
            self.results[itemID] = nil
        end
    end
end

-- Calcule l'objet s'il manque ; vrai si un calcul a eu lieu.
function Store:compute(itemID)
    if self.results[itemID] ~= nil or not self.player then
        return false
    end
    self.results[itemID] = ns.Scoring.delta(itemID, self.player, self.profile, self.data) or false
    return true
end

function Store:delta(itemID)
    self:compute(itemID)
    return self.results[itemID] or nil
end

function Store:fill(itemIDs, step)
    local count = 0
    for _, itemID in ipairs(itemIDs) do
        if self:compute(itemID) then
            count = count + 1
            if step then
                step()
            end
        end
    end
    return count
end

function Store:keep(itemIDs)
    local wanted = {}
    for _, itemID in ipairs(itemIDs) do
        wanted[itemID] = true
    end
    for itemID in pairs(self.results) do
        if not wanted[itemID] then
            self.results[itemID] = nil
        end
    end
end

function Store:reset()
    self.results = {}
end
