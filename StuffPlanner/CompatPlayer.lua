-- CONTRAT
-- Suite de ns.Compat : réputations et sorts connus du personnage (conditions de quête, Engine/Feasible).
-- Charger après Compat.lua. Détection par fonctionnalité ; sans l'API : réponse vide, jamais d'erreur.
--   GetReputations() -> {[factionID]=valeur} : valeur depuis Neutre (0 ; Amical 3000...), comme les conditions
--     de QuestieDB ; Forever C_Reputation.GetFactionDataByIndex (currentStanding), sinon GetFactionInfo
--     (barValue, factionID 14e retour) ; en-têtes sans réputation ignorés ; factions sous un en-tête replié
--     absentes (lecture des lignes visibles : inconnue = condition gardée par Feasible).
--   IsSpellKnown(spellID) -> bool | nil (sans l'API) : IsPlayerSpell, sinon C_SpellBook.IsSpellKnown, sinon
--     IsSpellKnown (première présente).

local _, ns = ...

local Compat = ns.Compat

local function modernReputations(out)
    local api = C_Reputation
    for index = 1, api.GetNumFactions() or 0 do
        local row = api.GetFactionDataByIndex(index)
        if row and row.factionID and (not row.isHeader or row.isHeaderWithRep) then
            out[row.factionID] = row.currentStanding
        end
    end
    return out
end

local function classicReputations(out)
    for index = 1, GetNumFactions() or 0 do
        local _, _, _, _, _, value, _, _, isHeader, _, hasRep, _, _, factionID = GetFactionInfo(index)
        if factionID and value and (not isHeader or hasRep) then
            out[factionID] = value
        end
    end
    return out
end

function Compat.GetReputations()
    if C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetFactionDataByIndex then
        return modernReputations({})
    elseif GetNumFactions and GetFactionInfo then
        return classicReputations({})
    end
    return {}
end

function Compat.IsSpellKnown(spellID)
    local fn = IsPlayerSpell or (C_SpellBook and C_SpellBook.IsSpellKnown) or IsSpellKnown
    if not fn then
        return nil
    end
    return fn(spellID) == true
end
