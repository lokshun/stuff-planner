-- CONTRAT
-- Jets de butin de groupe. Détection par fonctionnalité, à chaque appel ; sans l'API : nil, jamais d'erreur.
-- Charger après Compat.lua.
--   ns.Compat.LootRollLink(rollID) -> lien de l'objet | nil (GetLootRollItemLink)
--   ns.Compat.LootRollFrame(rollID, hiddenToo?) -> cadre du client dont le champ rollID est égal, affiché
--     (ou aussi caché si hiddenToo) | nil : GroupLootFrame1..MAX_ROLL_FRAMES, puis
--     GroupLootContainer.rollFrames (interface moderne). Ne rien écrire sur ce cadre.
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

local function matches(frame, rollID, hiddenToo)
    return type(frame) == "table" and frame.rollID == rollID and (hiddenToo or frame:IsShown()) and true or false
end

function Compat.LootRollFrame(rollID, hiddenToo)
    for index = 1, Compat.MAX_ROLL_FRAMES do
        local frame = _G["GroupLootFrame" .. index]
        if matches(frame, rollID, hiddenToo) then
            return frame
        end
    end
    local container = _G.GroupLootContainer
    local frames = type(container) == "table" and container.rollFrames
    if type(frames) == "table" then
        for _, frame in pairs(frames) do
            if matches(frame, rollID, hiddenToo) then
                return frame
            end
        end
    end
    return nil
end
