-- CONTRAT
-- Suite de ns.Compat : carte du monde. Charger après Compat.lua.
-- Le repère du jeu n'est pas utilisé (voir Integrations/TomTom.lua).
-- Détection par fonctionnalité ; API absente : false ou rien, jamais d'erreur.
--   OpenWorldMap(mapID) -> bool : WorldMapFrame affichée (ToggleWorldMap, repli ShowUIPanel) puis
--     placée sur mapID ; false sans carte
--   HookWorldMap(fn) -> fn() à l'affichage de la carte et à chaque changement de carte
--   PlayerFacing() -> radians (antihoraire depuis le nord) | nil sans l'API ou si le client la refuse
--     (instances sur les clients récents)
--   CircleTexture(frame, layer) -> texture, round : texture de frame découpée en disque par un masque
--     (CreateMaskTexture + AddMaskTexture, masque calé sur la texture) ; round = false sans l'API (carrée)

local _, ns = ...

local Compat = ns.Compat

local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

function Compat.OpenWorldMap(mapID)
    local map = WorldMapFrame
    if not map then
        return false
    end
    if not map:IsShown() then
        if ToggleWorldMap then
            ToggleWorldMap()
        elseif ShowUIPanel then
            ShowUIPanel(map)
        end
    end
    if map.SetMapID then
        map:SetMapID(mapID)
    end
    return map:IsShown() == true
end

-- fn() après chaque affichage de la carte du monde ou changement de carte ; rien sans carte.
function Compat.HookWorldMap(fn)
    local map = WorldMapFrame
    if not map then
        return
    end
    map:HookScript("OnShow", fn)
    if map.OnMapChanged then
        hooksecurefunc(map, "OnMapChanged", fn)
    end
end

function Compat.PlayerFacing()
    if type(GetPlayerFacing) ~= "function" then
        return nil
    end
    return GetPlayerFacing()
end

function Compat.CircleTexture(frame, layer)
    local texture = frame:CreateTexture(nil, layer)
    if not (frame.CreateMaskTexture and texture.AddMaskTexture) then
        return texture, false
    end
    local mask = frame:CreateMaskTexture()
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(texture)
    texture:AddMaskTexture(mask)
    return texture, true
end
