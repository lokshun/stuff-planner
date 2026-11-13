-- CONTRAT
-- Confirme en jeu la répartition fixes / au choix des quêtes devinées (Data.quest confidence 2), lue hors
-- journal (docs/API_NOTES.md, T17.0). Charger après CompatQuest.lua, Data/Collector.lua, Data/Loader.lua.
--   ns.QuestProbe.RATE -> 2 demandes par seconde ; READ_DELAY -> 3 s entre une demande et sa lecture de
--     secours ; MAX_TRIES -> 2 demandes par quête au plus
--   ns.QuestProbe.progress() -> quêtes restant à demander | nil tant que la liste n'est pas faite
--   ns.QuestProbe.step() -> une étape (minuterie ou tests) ; true quand il n'y a plus rien à demander
-- SP_DATA_READY : liste des quêtes confidence 2 (tranches Loader.SLICE_MS), puis une demande
--   Compat.RequestQuestData toutes les 1/RATE s ; lecture Compat.QuestRewardsByID à
--   QUEST_DATA_LOAD_RESULT(questID, ok) ou READ_DELAY s après la demande. Lecture refusée : nouvelle
--   demande, MAX_TRIES au plus, puis abandon pour la session ; ok faux : abandon.
-- Garde-fou : accepté seulement si choices ∪ rewards = l'ensemble d'objets de la base (jamais de liste
--   vide ou partielle, objet hors cache compris) ; quête confirmée entre-temps : plus lue.
-- Accepté : ns.Collector.addLog (sauvegarde, Data.observe, SP_QUEST_OBSERVED, partage) ; aucune
--   sauvegarde propre : une quête confirmée n'est plus confidence 2 aux sessions suivantes.
-- Rien en combat : étape et lecture repoussées. Sans l'API (RequestQuestData faux) : rien demandé.

local _, ns = ...

local Compat = ns.Compat

local QuestProbe = ns:NewModule("QuestProbe", "AceEvent-3.0")
ns.QuestProbe = QuestProbe

QuestProbe.RATE = 2
QuestProbe.READ_DELAY = 3
QuestProbe.MAX_TRIES = 2

local GUESSED = 2

local queue, position, tries, scanner, sliceStart

function QuestProbe.progress()
    return queue and (#queue - position + 1) or nil
end

local function itemSet(first, second)
    local set, count = {}, 0
    for _, list in ipairs({ first or {}, second or {} }) do
        for _, itemID in ipairs(list) do
            if not set[itemID] then
                set[itemID], count = true, count + 1
            end
        end
    end
    return set, count
end

local function sameItems(quest, choices, rewards)
    local known, total = itemSet(quest.choices, quest.rewards)
    local seen, count = itemSet(choices, rewards)
    if count == 0 or count ~= total then
        return false
    end
    for itemID in pairs(seen) do
        if not known[itemID] then
            return false
        end
    end
    return true
end

-- true : quête réglée (gardée, ou plus rien à lire) ; false : lecture refusée.
local function read(questID)
    local quest = ns.Data.quest(questID)
    if not (quest and quest.confidence == GUESSED) then
        return true
    end
    local choices, rewards = Compat.QuestRewardsByID(questID)
    if not (choices and sameItems(quest, choices, rewards)) then
        return false
    end
    ns.Collector.addLog(questID, choices, rewards)
    return true
end

local request

local function later(questID)
    if not tries[questID] then
        return
    end
    if InCombatLockdown() then
        C_Timer.After(QuestProbe.READ_DELAY, function() later(questID) end)
    elseif read(questID) or tries[questID] >= QuestProbe.MAX_TRIES or not request(questID) then
        tries[questID] = nil
    end
end

request = function(questID)
    if not Compat.RequestQuestData(questID) then
        return false
    end
    tries[questID] = (tries[questID] or 0) + 1
    C_Timer.After(QuestProbe.READ_DELAY, function() later(questID) end)
    return true
end

local function tick()
    if ns.Loader.clock() - sliceStart >= ns.Loader.SLICE_MS then
        coroutine.yield()
    end
end

local function scan()
    local list = {}
    for _, questID in ipairs(ns.Data.questIDs()) do
        local quest = ns.Data.quest(questID)
        if quest and quest.confidence == GUESSED then
            list[#list + 1] = questID
        end
        tick()
    end
    queue, position = list, 1
end

function QuestProbe.step()
    if scanner then
        sliceStart = ns.Loader.clock()
        local ok, err = coroutine.resume(scanner)
        if not ok then
            scanner = nil
            geterrorhandler()(err)
            return true
        end
        if coroutine.status(scanner) == "dead" then
            scanner = nil
        end
        return false
    end
    local questID = queue and queue[position]
    if not questID then
        return true
    end
    position = position + 1
    if not request(questID) then
        position = #queue + 1
        return true
    end
    return false
end

local function schedule()
    local delay = scanner and 0 or 1 / QuestProbe.RATE
    C_Timer.After(delay, function()
        if InCombatLockdown() or not QuestProbe.step() then
            schedule()
        end
    end)
end

function QuestProbe.start()
    queue, position, tries = nil, 1, {}
    scanner = coroutine.create(scan)
    schedule()
end

QuestProbe:RegisterEvent("QUEST_DATA_LOAD_RESULT", function(_, questID, ok)
    if not (tries and tries[questID]) or InCombatLockdown() then
        return
    end
    if ok == false or read(questID) then
        tries[questID] = nil
    end
end)

ns:On("SP_DATA_READY", QuestProbe.start)
