-- CONTRAT
-- Plan du panneau de réglages (UI/OptionsPanel.lua). Pur : aucun appel d'API. Charger après Options.lua.
--   ns.OptionsLayout.sections() -> {{title, rows}...} : Fenêtre, Cadre flottant, Sur les objets, Alertes,
--     Carte et flèche, Parcours, Partage ; chaque réglage de ns.Options une fois.
--     row = {kind = "checkbox" | "slider" | "choice", key, format? (slider : percent | decimal | integer |
--       yards), values? (choice : {{valeur, libellé}...})}
--       | {kind = "note", text} | {kind = "button", action, label, when?}
--     action : reload (when = "skinPending" : montré seulement si l'habillage attend un rechargement),
--       resetPositions, welcome, defaults (dernier bouton, confirmation en deux clics)
--   ns.OptionsLayout.label(key) -> L.OPTION_<CLÉ> ; ns.OptionsLayout.tip(key) -> L.OPTION_<CLÉ>_TIP | nil
--     (réglages non évidents seulement, table TIPS)

local _, ns = ...

local L = ns.L

local OptionsLayout = {}
ns.OptionsLayout = OptionsLayout

local TIPS = {
    ["window.skin"] = true, ["tooltip.alts"] = true, ["questHint.enabled"] = true, ["hud.lines"] = true,
    ["toast.zone"] = true, ["roll.hint"] = true, ["arrow.arrival"] = true, ["waypoint.preferTomTom"] = true,
    ["planner.calibrate"] = true,
}

local function suffix(key)
    return "OPTION_" .. key:gsub("%.", "_"):upper()
end

function OptionsLayout.label(key)
    return L[suffix(key)]
end

function OptionsLayout.tip(key)
    if TIPS[key] then
        return L[suffix(key) .. "_TIP"]
    end
    return nil
end

local function check(key)
    return { kind = "checkbox", key = key }
end

local function slider(key, format)
    return { kind = "slider", key = key, format = format }
end

local function button(action, label, when)
    return { kind = "button", action = action, label = label, when = when }
end

function OptionsLayout.sections()
    return {
        { title = L.OPTIONS_SECTION_WINDOW, rows = {
            slider("window.scale", "decimal"), slider("window.alpha", "percent"),
            { kind = "choice", key = "window.skin", values = {
                { "notebook", L.OPTIONS_SKIN_NOTEBOOK }, { "blizzard", L.OPTIONS_SKIN_BLIZZARD } } },
            button("reload", L.OPTIONS_RELOAD, "skinPending"),
            check("minimap.shown"),
            button("resetPositions", L.OPTIONS_RESET_POSITIONS), button("welcome", L.OPTIONS_WELCOME),
        } },
        { title = L.OPTIONS_SECTION_TRACKER, rows = {
            { kind = "note", text = L.OPTIONS_HUD_NOTE },
            check("dungeon.panel"), check("follow.window"), check("tracker.shown"),
            slider("hud.lines", "integer"), slider("hud.alpha", "percent"), check("hud.locked"),
        } },
        { title = L.OPTIONS_SECTION_ITEMS, rows = {
            check("tooltip.enabled"), check("tooltip.alts"), check("badges.bags"), check("badges.merchant"),
            check("badges.auction"), check("questHint.enabled"),
        } },
        { title = L.OPTIONS_SECTION_ALERTS, rows = { check("toast.zone"), check("roll.hint") } },
        { title = L.OPTIONS_SECTION_MAP, rows = {
            check("pins.world"), check("pins.minimap"), slider("pins.worldScale", "percent"),
            slider("pins.minimapScale", "percent"), check("arrow.enabled"), check("arrow.locked"),
            check("waypoint.preferTomTom"), slider("arrow.scale", "decimal"), slider("arrow.arrival", "yards"),
            { kind = "choice", key = "arrow.color", values = {
                { "direction", L.OPTIONS_COLOR_DIRECTION }, { "gold", L.OPTIONS_COLOR_GOLD } } },
        } },
        { title = L.OPTIONS_SECTION_PLANNER, rows = { check("planner.calibrate") } },
        { title = L.OPTIONS_SECTION_SHARE, rows = {
            { kind = "note", text = L.OPTIONS_SHARE_NOTE }, check("share.enabled"),
            button("defaults", L.OPTIONS_DEFAULTS),
        } },
    }
end
