-- CONTRAT
-- Gain d'un objet pour le profil secondaire (T12.1), commun aux info-bulles, lignes et pastilles. Aucun appel
-- d'API : ns.Profiles, ns.Results, ns.Scoring et ns.ProfilePresenter lus à l'appel (absents : rien).
--   ns.SecondaryGain.lookup(itemID, live?, player?, data?) -> delta, name | nil
--     sans profil secondaire : nil ; live (LiveItem.fields) : Scoring.deltaFields(live, player, profil, data,
--     live.key) ; sinon Results.secondaryDelta(itemID) ; name = ProfilePresenter.shortName(profil)
--   ns.SecondaryGain.text(delta, name) -> « +3,1 (Soin) » (points) | nil si gain ≤ 0
--   ns.SecondaryGain.value(delta) -> « +3,1 » (Format.points)
--   ns.SecondaryGain.keep(delta, name) -> L.KEEP_FOR (nom) | nil si gain ≤ 0

local _, ns = ...

local SecondaryGain = {}
ns.SecondaryGain = SecondaryGain

local EPSILON = 1e-6

function SecondaryGain.lookup(itemID, live, player, data)
    local profile = ns.Profiles and ns.Profiles.secondary and ns.Profiles.secondary()
    if not profile then
        return nil
    end
    local delta
    if live then
        delta = player and ns.Scoring.deltaFields(live, player, profile, data, live.key)
    elseif ns.Results and ns.Results.secondaryDelta then
        delta = ns.Results.secondaryDelta(itemID)
    end
    if not delta then
        return nil
    end
    return delta, ns.ProfilePresenter.shortName(profile)
end

local function improves(delta)
    return delta and delta.abs > EPSILON
end

function SecondaryGain.text(delta, name)
    if not improves(delta) then
        return nil
    end
    return ns.L.SECONDARY_GAIN:format(SecondaryGain.value(delta), name)
end

function SecondaryGain.value(delta)
    return ns.Format.points(delta.abs)
end

function SecondaryGain.keep(delta, name)
    if not improves(delta) then
        return nil
    end
    return ns.L.KEEP_FOR:format(name)
end
