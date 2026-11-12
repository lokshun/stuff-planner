-- CONTRAT
-- Jets de butin de groupe. Détection par fonctionnalité, à chaque appel ; sans l'API : nil, jamais d'erreur.
-- Charger après Compat.lua.
--   ns.Compat.LootRollLink(rollID) -> lien de l'objet | nil (GetLootRollItemLink)
--   ns.Compat.LootRollFrame(rollID, hiddenToo?) -> cadre du client GroupLootFrame1..MAX_ROLL_FRAMES dont le
--     champ rollID est égal, affiché (ou aussi caché si hiddenToo) | nil. Ne rien écrire sur ce cadre.
--   ns.Compat.MAX_ROLL_FRAMES = 4

local _, ns = ...

local Compat = ns.Compat

Compat.MAX_ROLL_FRAMES = 4

function Compat.LootRollLink(rollID)
    local getLink = _G.GetLootRollItemLink
    if type(getLink) ~= "function" then
        return nil
    end
    local ok, link = pcall(getLink, rollID)
    return ok and link or nil
end

function Compat.LootRollFrame(rollID, hiddenToo)
    for index = 1, Compat.MAX_ROLL_FRAMES do
        local frame = _G["GroupLootFrame" .. index]
        if type(frame) == "table" and frame.rollID == rollID and (hiddenToo or frame:IsShown()) then
            return frame
        end
    end
    return nil
end
