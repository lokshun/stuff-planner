-- CONTRAT
-- Mode du cadre flottant unique (UI/Hud.lua). Pur : aucun appel d'API, aucune dépendance.
--   available = {key...} : modes disponibles, par priorité (donjon, suivi, zone : ordre des fournisseurs)
--   ns.HudPresenter.resolve(available, state) -> key | nil
--     state = {forced = key choisi par le joueur | nil, signature} (modifié) : forced oublié dès que la liste
--     des modes disponibles change (entrée en instance, suivi lancé…) ; forced s'il est disponible, sinon le
--     premier mode disponible
--   ns.HudPresenter.nextMode(available, current) -> mode qui suit current, en boucle (premier si current absent)
--   ns.HudPresenter.position(available, current) -> « 2/3 » | "" (un seul mode)

local _, ns = ...

local HudPresenter = {}
ns.HudPresenter = HudPresenter

local function indexOf(list, value)
    for index, item in ipairs(list) do
        if item == value then
            return index
        end
    end
    return nil
end

function HudPresenter.resolve(available, state)
    local signature = table.concat(available, ",")
    if state.signature ~= signature then
        state.signature, state.forced = signature, nil
    end
    if state.forced and indexOf(available, state.forced) then
        return state.forced
    end
    return available[1]
end

function HudPresenter.nextMode(available, current)
    local index = indexOf(available, current)
    if not index then
        return available[1]
    end
    return available[index % #available + 1]
end

function HudPresenter.position(available, current)
    local index = indexOf(available, current)
    if #available < 2 or not index then
        return ""
    end
    return index .. "/" .. #available
end
