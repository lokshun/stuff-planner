-- CONTRAT
-- Poids effectifs des bonus de sorts imbriqués, pour Scoring.score. Pur : aucun appel à l'API WoW.
-- Formulations des objets (codage vérifié par tools/audit_equip_stats.py) :
--   « dégâts et soins de X » = SPELL_POWER ; « dégâts des sorts de X » (toutes écoles) = SPELL_DMG ;
--   « dégâts d'Ombre de X » = SHADOW_DMG (une école) ; « soins de X et dégâts de Y » = HEALING + SPELL_DMG.
-- Un bonus qui en contient d'autres vaut au moins leur somme, quels que soient les poids saisis
-- (profil par ordre de priorité, Pawn, profil par défaut) :
--   SPELL_DMG effectif = max(SPELL_DMG, meilleur poids d'école)
--   SPELL_POWER effectif = max(SPELL_POWER, SPELL_DMG effectif + HEALING)
-- Les poids d'école ne sont jamais relevés : une école ne sert qu'aux sorts de cette école.
--   ns.SpellWeights.weight(weights, key) -> poids effectif | nil (nil si aucun poids ne s'applique)
--   ns.SpellWeights.SCHOOLS -> {"HOLY_DMG", …} (copie de référence, à ne pas modifier)

local _, ns = ...

local SpellWeights = {}
ns.SpellWeights = SpellWeights

local SCHOOLS = { "HOLY_DMG", "FIRE_DMG", "NATURE_DMG", "FROST_DMG", "SHADOW_DMG", "ARCANE_DMG" }
SpellWeights.SCHOOLS = SCHOOLS

local function positive(value)
    return type(value) == "number" and value > 0 and value or 0
end

local function damage(weights)
    local best = positive(weights.SPELL_DMG)
    for _, school in ipairs(SCHOOLS) do
        best = math.max(best, positive(weights[school]))
    end
    return best
end

local function orNil(own, derived)
    if derived > positive(own) then
        return derived
    end
    return own
end

function SpellWeights.weight(weights, key)
    if key == "SPELL_DMG" then
        return orNil(weights.SPELL_DMG, damage(weights))
    elseif key == "SPELL_POWER" then
        return orNil(weights.SPELL_POWER, damage(weights) + positive(weights.HEALING))
    end
    return weights[key]
end
