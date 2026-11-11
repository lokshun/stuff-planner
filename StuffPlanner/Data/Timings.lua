-- CONTRAT
-- Chronométrage local du joueur, mesures confiées à Engine/Calibration. Charger après DB.lua, CompatQuest.lua,
-- Engine/Calibration.lua, Integrations/TomTom.lua, Follow.lua et FollowTravel.lua.
--   ns.Timings.now() -> secondes de jeu actif : GetTime pendant la session, arrêté pendant l'absence (AFK,
--     PLAYER_FLAGS_CHANGED, UnitIsAFK) ; reprise après déconnexion depuis la valeur sauvée à PLAYER_LOGOUT
--     (temps hors ligne et sessions perdues écartés)
--   ns.Timings.medians() -> Calibration.medians des mesures sauvées ; ns.Timings.samples() -> {[kind] = {...}}
--   ns.Timings.MAX_PENDING -> quêtes prises gardées au plus (les plus anciennes sortent)
-- Mesures (Calibration.add, bornes et fenêtre glissante) :
--   quest : QUEST_ACCEPTED (Compat.AcceptedQuestID) → QUEST_TURNED_IN de la même quête ;
--   dungeon, raid : entrée → sortie d'instance (IsInInstance "party" | "raid", GetInstanceInfo 8e retour),
--     relue à PLAYER_ENTERING_WORLD et ZONE_CHANGED_NEW_AREA ; rechargement dans la même instance : gardée ;
--     une mort ramène parfois dehors : course coupée (trop courte, refusée par les bornes)
--   travel : étape du suivi à PNJ (SP_FOLLOW_CHANGED, ns.Follow.target) → discussion avec ce PNJ (GOSSIP_SHOW,
--     QUEST_GREETING, QUEST_DETAIL, QUEST_PROGRESS, QUEST_COMPLETE, ns.Waypoint.dialogNpc) ; valeur = durée
--     réelle / durée prévue (ns.FollowTravel.estimator au départ, MIN_PREDICTED s au moins) ; même PNJ :
--     départ gardé ; autre étape ou fin du suivi : trajet oublié. Trajet en cours non sauvé.
-- Sauvegarde StuffPlannerCharDB.timings = {clock, quests = {[questID] = début}, run = {instanceID, kind, at},
--   samples}.

local _, ns = ...

local Timings = ns:NewModule("Timings", "AceEvent-3.0")
ns.Timings = Timings

Timings.MAX_PENDING = 40
Timings.MIN_PREDICTED = 30

local RUN_KINDS = { party = "dungeon", raid = "raid" }
local DIALOGS = { "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE" }

local elapsed, anchor = 0, GetTime()
local trip

function Timings.now()
    local base = ns.DB.peek("char", "timings", "clock") or 0
    return base + elapsed + (anchor and GetTime() - anchor or 0)
end

local function store()
    return ns.DB.char("timings")
end

function Timings.samples()
    return store().samples or {}
end

function Timings.medians()
    return ns.Calibration.medians(ns.DB.peek("char", "timings", "samples"))
end

local function measure(kind, value)
    local saved = store()
    saved.samples = saved.samples or {}
    ns.Calibration.add(saved.samples, kind, value)
end

local function setAway(away)
    if away and anchor then
        elapsed, anchor = elapsed + GetTime() - anchor, nil
    elseif not away and not anchor then
        anchor = GetTime()
    end
end

Timings:RegisterEvent("PLAYER_FLAGS_CHANGED", function(_, unit)
    if unit == "player" then
        setAway(UnitIsAFK("player") and true or false)
    end
end)

Timings:RegisterEvent("PLAYER_LOGOUT", function()
    local clock = Timings.now()
    store().clock = clock
    elapsed, anchor = 0, GetTime()
end)

-- Quêtes prises : la plus ancienne sort au-delà de MAX_PENDING.
local function trimPending(quests)
    local count, oldestID, oldest = 0, nil, nil
    for questID, start in pairs(quests) do
        count = count + 1
        if not oldest or start < oldest then
            oldestID, oldest = questID, start
        end
    end
    if count > Timings.MAX_PENDING then
        quests[oldestID] = nil
        trimPending(quests)
    end
end

Timings:RegisterEvent("QUEST_ACCEPTED", function(_, ...)
    local questID = ns.Compat.AcceptedQuestID(...)
    if questID then
        local quests = ns.DB.char("timings", "quests")
        quests[questID] = Timings.now()
        trimPending(quests)
    end
end)

Timings:RegisterEvent("QUEST_TURNED_IN", function(_, questID)
    local start = ns.DB.peek("char", "timings", "quests", questID)
    if start then
        ns.DB.char("timings", "quests")[questID] = nil
        measure("quest", Timings.now() - start)
    end
end)

local function checkInstance()
    local inInstance, instanceType = IsInInstance()
    local kind = inInstance and RUN_KINDS[instanceType]
    local instanceID = kind and select(8, GetInstanceInfo())
    local saved = store()
    local run = saved.run
    if run and run.instanceID == instanceID then
        return
    end
    if run then
        measure(run.kind, Timings.now() - run.at)
    end
    saved.run = kind and { instanceID = instanceID, kind = kind, at = Timings.now() } or nil
end

Timings:RegisterEvent("PLAYER_ENTERING_WORLD", checkInstance)
Timings:RegisterEvent("ZONE_CHANGED_NEW_AREA", checkInstance)

ns:On("SP_FOLLOW_CHANGED", function()
    local step = ns.Follow and ns.Follow.target()
    if not (step and step.npcID and step.mapID and step.x and step.y) then
        trip = nil
        return
    end
    if trip and trip.npcID == step.npcID then
        return
    end
    local estimator = ns.FollowTravel and ns.FollowTravel.estimator()
    local predicted = estimator and estimator(step.mapID, step.x, step.y)
    trip = predicted and predicted >= Timings.MIN_PREDICTED
        and { npcID = step.npcID, predicted = predicted, at = Timings.now() } or nil
end)

local function onDialog()
    if trip and ns.Waypoint.dialogNpc() == trip.npcID then
        measure("travel", (Timings.now() - trip.at) / trip.predicted)
        trip = nil
    end
end

for _, event in ipairs(DIALOGS) do
    Timings:RegisterEvent(event, onDialog)
end
