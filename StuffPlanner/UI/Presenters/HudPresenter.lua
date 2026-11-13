-- CONTRAT
-- Mode, pastilles et menu du cadre flottant unique (UI/Hud.lua). Pur : aucun appel d'API.
--   available = {key...} : modes disponibles, par priorité (donjon, suivi, zone : ordre des fournisseurs)
--   ns.HudPresenter.resolve(available, state) -> key | nil
--     state = {forced = key choisi par le joueur | nil, signature} (modifié) : forced oublié dès que la liste
--     des modes disponibles change (entrée en instance, suivi lancé…) ; forced s'il est disponible, sinon le
--     premier mode disponible
--   ns.HudPresenter.pills(available, current) -> {{key, active}...} : une par mode disponible, dans l'ordre ;
--     {} s'il y a moins de deux modes
--   ns.HudPresenter.menuEntries(opts) -> entrées ns.RowMenu ; opts = {collapsed, locked, canHide} :
--     collapse (Replier | Déplier), lock (case, L.HUD_MENU_LOCK), hide (si canHide), filet, open (fenêtre),
--     options (L.OPTIONS_OPEN)

local _, ns = ...

local L = ns.L

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

function HudPresenter.pills(available, current)
    local pills = {}
    if #available < 2 then
        return pills
    end
    for index, key in ipairs(available) do
        pills[index] = { key = key, active = key == current }
    end
    return pills
end

function HudPresenter.menuEntries(opts)
    local entries = {
        { key = "collapse", label = opts.collapsed and L.HUD_MENU_EXPAND or L.HUD_MENU_COLLAPSE },
        { key = "lock", label = L.HUD_MENU_LOCK, checked = opts.locked == true },
    }
    if opts.canHide then
        entries[#entries + 1] = { key = "hide", label = L.HUD_MENU_HIDE }
    end
    entries[#entries + 1] = { separator = true }
    entries[#entries + 1] = { key = "open", label = L.HUD_MENU_OPEN }
    entries[#entries + 1] = { key = "options", label = L.OPTIONS_OPEN }
    return entries
end
