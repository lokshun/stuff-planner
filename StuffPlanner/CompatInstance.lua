-- CONTRAT
-- Instance courante et fin de rencontre, Forever et Classic Era. Détection par fonctionnalité ; sans l'API :
-- réponse vide, jamais d'erreur. Charger après Compat.lua.
--   ns.CompatInstance.current() -> instanceID, "party" | "raid" | nil (hors donjon et raid : champ de bataille,
--     arène, monde) ; instanceID = 8e retour de GetInstanceInfo (identifiant de carte d'instance)
--   ns.CompatInstance.ENCOUNTER_EVENT = "ENCOUNTER_END"
--   ns.CompatInstance.watchEncounters(frame) -> bool : frame inscrit à ENCOUNTER_END ; faux si le client ne
--     connaît pas l'événement (RegisterEvent protégé)
--   ns.CompatInstance.encounterEnd(...) -> name | nil : arguments d'ENCOUNTER_END (encounterID, encounterName,
--     difficultyID, groupSize, success) ; nom seulement si la rencontre est réussie (success 1 ou true) et que
--     le nom est une chaîne lisible (Forever : valeurs secrètes possibles, refusées)

local _, ns = ...

local CompatInstance = {}
ns.CompatInstance = CompatInstance

local KINDS = { party = true, raid = true }
local INSTANCE_ID = 8

CompatInstance.ENCOUNTER_EVENT = "ENCOUNTER_END"

function CompatInstance.current()
    if not (IsInInstance and GetInstanceInfo) then
        return nil
    end
    local inInstance, kind = IsInInstance()
    if not inInstance or not KINDS[kind] then
        return nil
    end
    local instanceID = select(INSTANCE_ID, GetInstanceInfo())
    if type(instanceID) ~= "number" then
        return nil
    end
    return instanceID, kind
end

function CompatInstance.watchEncounters(frame)
    return (pcall(frame.RegisterEvent, frame, CompatInstance.ENCOUNTER_EVENT))
end

local function readable(name)
    local ok, length = pcall(function()
        return type(name) == "string" and #name or 0
    end)
    return ok and length > 0
end

function CompatInstance.encounterEnd(_, name, _, _, success)
    if (success == 1 or success == true) and readable(name) then
        return name
    end
    return nil
end
