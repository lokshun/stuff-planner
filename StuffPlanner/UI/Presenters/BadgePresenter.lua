-- CONTRAT
-- Pastille de gain posée sur un bouton d'objet (sacs, marchand, hôtel des ventes). Pur : aucun appel
-- d'API. Charger après Theme.lua, Format.lua, ItemLink.lua et LiveItem.lua (ns.Scoring lu à l'appel).
--   ns.BadgePresenter.build(link, player, profile, data, readLive) -> view | nil
--     readLive(link) -> champs LiveItem.fields | nil ; appelé seulement si LiveItem.needed (objet hors
--       base ou à suffixe aléatoire), le calcul passe alors par Scoring.deltaFields (clé = lien) ;
--     view = {abs = gain en points, color = Theme.colors.gain, text = Format.points(abs) (« +2,5 »)}
--     nil : lien illisible, objet non lisible ou non équipable, gain nul ou négatif (ici et pour le profil
--     secondaire). Gain ≤ 0 ici mais > 0 pour le profil secondaire (SecondaryGain) : view du secondaire,
--     color = Theme.colors.instance (bleu), keep = L.KEEP_FOR (nom du profil).

local _, ns = ...

local BadgePresenter = {}
ns.BadgePresenter = BadgePresenter

local EPSILON = 1e-6

local function delta(link, player, profile, data, readLive)
    local itemID = ns.ItemLink.itemID(link)
    if not itemID then
        return nil
    end
    if ns.LiveItem.needed(itemID, link, data) then
        local live = readLive(link)
        if not live then
            return nil
        end
        return ns.Scoring.deltaFields(live, player, profile, data, live.key), itemID, live
    end
    return ns.Scoring.delta(itemID, player, profile, data), itemID
end

function BadgePresenter.build(link, player, profile, data, readLive)
    local result, itemID, live = delta(link, player, profile, data, readLive)
    if not result then
        return nil
    end
    if result.abs > EPSILON then
        return { abs = result.abs, color = ns.Theme.colors.gain, text = ns.Format.points(result.abs) }
    end
    local second, name = ns.SecondaryGain.lookup(itemID, live, player, data)
    local keep = second and ns.SecondaryGain.keep(second, name)
    if not keep then
        return nil
    end
    return { abs = second.abs, color = ns.Theme.colors.instance, text = ns.Format.points(second.abs),
             keep = keep }
end
