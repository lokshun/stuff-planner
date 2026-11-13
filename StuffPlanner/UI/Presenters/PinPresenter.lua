-- CONTRAT
-- Aspect des épingles de carte et de minicarte (UI/MapPins.lua). Pur : aucun appel d'API.
--   ns.PinPresenter.layout(kind, style, scale) -> {size, x, y, round}
--     kind = "world" | "minimap" ; style = pins.style : "corner" (défaut, aussi pour une valeur inconnue) |
--     "center" ; scale = pins.worldScale | pins.minimapScale
--     corner : pastille ronde de CORNER[kind] × scale px, centre décalé de (x, y) > 0 vers le haut à droite du
--       point du donneur, pour laisser lisible le « ! » / « ? » (GLYPH[kind] = demi-taille du marqueur du jeu)
--     center : ancien aspect, icône carrée de CENTER[kind] × scale px centrée sur le donneur
--   Tailles arrondies au pixel, au moins 1.

local _, ns = ...

local PinPresenter = {}
ns.PinPresenter = PinPresenter

local CORNER = { world = 12, minimap = 9 }
local CENTER = { world = 20, minimap = 14 }
local GLYPH = { world = 8, minimap = 5 }

local function round(value)
    return math.max(1, math.floor(value + 0.5))
end

function PinPresenter.layout(kind, style, scale)
    scale = scale or 1
    if style == "center" then
        return { size = round(CENTER[kind] * scale), x = 0, y = 0, round = false }
    end
    local size = round(CORNER[kind] * scale)
    local offset = math.max(GLYPH[kind], math.ceil(size / 2)) + math.floor(size / 4)
    return { size = size, x = offset, y = offset, round = true }
end
