-- CONTRAT
-- Passage en cours dans un donjon ou un raid : instance courante et boss tués. Charger après DB.lua,
-- CompatInstance.lua, Data/InstanceIndex.lua et Data/Names.lua.
--   ns.DungeonRun.current() -> instanceID | nil : instance où se trouve le joueur, connue de ns.Data
--   ns.DungeonRun.killed() -> {[npcID] = true} du dernier passage (table partagée, ne pas modifier)
--   ns.DungeonRun.toggle(npcID) : boss marqué tué / pas tué ; ns.DungeonRun.reset() : aucun boss tué
--   ns.DungeonRun.refresh() : relit l'instance (PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA)
--   ns.DungeonRun.onEncounter(name) : rencontre réussie (CompatInstance.encounterEnd) ; boss de l'instance
--     dont le nom (Names.npc, sans casse, espaces ni ponctuation) est égal : marqué tué ; sinon rien
-- Sauvegarde : StuffPlannerCharDB.dungeon = {instanceID, killed = {[npcID] = true}} : gardée en sortant et en
--   rentrant dans la même instance (mort, /reload) ; une autre instance repart de zéro.
-- Message SP_DUNGEON_CHANGED (sans argument) : entrée ou sortie d'instance, boss tués changés. Aucun cadre
-- touché : sans risque en combat.

local _, ns = ...

local DungeonRun = {}
ns.DungeonRun = DungeonRun

local current

local function saved()
    return ns.DB.char("dungeon")
end

local function killedTable()
    return ns.DB.char("dungeon", "killed")
end

local function normalize(name)
    return (name:lower():gsub("[%s%p]", ""))
end

function DungeonRun.current()
    return current
end

function DungeonRun.killed()
    return killedTable()
end

function DungeonRun.toggle(npcID)
    local killed = killedTable()
    killed[npcID] = not killed[npcID] or nil
    ns:Send("SP_DUNGEON_CHANGED")
end

function DungeonRun.reset()
    saved().killed = {}
    ns:Send("SP_DUNGEON_CHANGED")
end

function DungeonRun.refresh()
    local instanceID = ns.CompatInstance.current()
    if instanceID and not ns.Data.instance(instanceID) then
        instanceID = nil
    end
    local state = saved()
    if instanceID and state.instanceID ~= instanceID then
        state.instanceID = instanceID
        state.killed = {}
    end
    if instanceID ~= current then
        current = instanceID
        ns:Send("SP_DUNGEON_CHANGED")
    end
end

function DungeonRun.onEncounter(name)
    if not (current and name) then
        return
    end
    local wanted = normalize(name)
    local killed = killedTable()
    for _, npcID in ipairs(ns.Data.instanceBosses(current)) do
        if not killed[npcID] and normalize(ns.Names.npc(npcID)) == wanted then
            killed[npcID] = true
            ns:Send("SP_DUNGEON_CHANGED")
            return
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ns.CompatInstance.watchEncounters(events)
events:SetScript("OnEvent", function(_, event, ...)
    if event == ns.CompatInstance.ENCOUNTER_EVENT then
        DungeonRun.onEncounter(ns.CompatInstance.encounterEnd(...))
    elseif ns.Data.ready() then
        DungeonRun.refresh()
    end
end)

ns:On("SP_DATA_READY", function()
    DungeonRun.refresh()
end)
