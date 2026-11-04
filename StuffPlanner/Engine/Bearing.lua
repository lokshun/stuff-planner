-- CONTRAT
-- Direction d'une flèche vers un repère. Pur : aucune API WoW.
-- Angles en radians, sens antihoraire depuis le nord, comme GetPlayerFacing et HereBeDragons:GetWorldVector.
--   ns.Bearing.rotation(angle, facing) -> angle relatif dans [0, 2π) ; 0 = droit devant,
--     π/2 = à gauche (valeur pour Texture:SetRotation, elle aussi antihoraire)
--   ns.Bearing.compute(angle, distance, facing [, arrival]) -> {rotation, distance, arrived} | nil si une
--     valeur manque ; arrival : seuil d'arrivée (ARRIVAL_YARDS par défaut)
--   ns.Bearing.arrived(distance, arrival, wasArrived) -> bool : sous arrival (ARRIVAL_YARDS par défaut) ;
--     déjà arrivé : le reste jusqu'à arrival + REAPPEAR_YARDS (pas de clignotement à la limite) ; nil -> faux
--   ns.Bearing.frame(rotation, count) -> image 0..count-1 la plus proche (image k : rotation k·2π/count)
--   ns.Bearing.texCoords(index, cols, rows) -> left, right, top, bottom (planche lue ligne par ligne)
--   ns.Bearing.color(rotation) -> r, g, b : vert devant, jaune de côté, rouge derrière
--   ns.Bearing.ARRIVAL_YARDS : distance (en mètres du jeu, « yards ») à partir de laquelle on est arrivé
--   ns.Bearing.REAPPEAR_YARDS : marge au-delà de l'arrivée avant de repartir

local _, ns = ...

local TWO_PI = 2 * math.pi

local Bearing = {}
ns.Bearing = Bearing

Bearing.ARRIVAL_YARDS = 10
Bearing.REAPPEAR_YARDS = 2

function Bearing.rotation(angle, facing)
    return (angle - facing) % TWO_PI
end

function Bearing.compute(angle, distance, facing, arrival)
    if angle == nil or distance == nil or facing == nil then
        return nil
    end
    return {
        rotation = Bearing.rotation(angle, facing),
        distance = distance,
        arrived = distance <= (arrival or Bearing.ARRIVAL_YARDS),
    }
end

function Bearing.arrived(distance, arrival, wasArrived)
    if distance == nil then
        return false
    end
    local limit = arrival or Bearing.ARRIVAL_YARDS
    return distance <= (wasArrived and limit + Bearing.REAPPEAR_YARDS or limit)
end

function Bearing.frame(rotation, count)
    return math.floor((rotation % TWO_PI) / TWO_PI * count + 0.5) % count
end

function Bearing.texCoords(index, cols, rows)
    local col, row = index % cols, math.floor(index / cols)
    return col / cols, (col + 1) / cols, row / rows, (row + 1) / rows
end

function Bearing.color(rotation)
    local r = rotation % TWO_PI
    local off = math.min(r, TWO_PI - r) / math.pi -- 0 devant, 1 derrière
    if off <= 0.5 then
        return off * 2, 1, 0
    end
    return 1, 2 - off * 2, 0
end
