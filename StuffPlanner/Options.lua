-- CONTRAT
-- Réglages de l'addon : catalogue unique, lecture et écriture dans StuffPlannerDB. Aucune API WoW.
-- Charger après Core.lua.
--   ns.Options.get(key) -> valeur (défaut si rien n'est sauvegardé) | nil pour une clé inconnue
--   ns.Options.set(key, value) -> bool : nombre borné et arrondi au pas, booléen forcé, choix hors
--     liste refusé ; message SP_OPTION_CHANGED(key, value) seulement si la valeur change
--   ns.Options.toggle(key) -> nouvelle valeur d'un booléen ; ns.Options.reset(key)
--   ns.Options.keys() -> clés dans l'ordre du catalogue ; ns.Options.spec(key) -> description
--     {key, kind = "boolean" | "number" | "choice", default, min, max, step, values}
-- Sauvegarde au format des modules d'origine (aucune migration) : `path` dans StuffPlannerDB ;
-- `invert` : le drapeau sauvegardé est l'inverse (hidden, disabled). Valeur par défaut : rien écrit.
-- Migration DB 2 (T14.10) : ui.tracker {point, relativePoint, x, y, lines, alpha, locked} et ui.follow.locked
-- passent à ui.hud (hud.lines, hud.alpha, hud.locked) ; valeur déjà présente dans ui.hud gardée.

local _, ns = ...

local Options = {}
ns.Options = Options

local CATALOG = {
    { key = "window.scale", default = 1, min = 0.6, max = 1.5, step = 0.05, path = { "ui", "scale" } },
    { key = "window.alpha", default = 1, min = 0.3, max = 1, step = 0.05, path = { "ui", "alpha" } },
    { key = "window.skin", default = "notebook", values = { "notebook", "blizzard" }, path = { "ui", "skin" } },
    { key = "minimap.shown", default = true, invert = true, path = { "ui", "minimap", "hide" } },
    { key = "tooltip.enabled", default = true, invert = true, path = { "ui", "tooltipDisabled" } },
    { key = "tooltip.alts", default = true, invert = true, path = { "ui", "tooltipAltsHidden" } },
    { key = "questHint.enabled", default = true, invert = true, path = { "ui", "questHintDisabled" } },
    { key = "badges.bags", default = true, invert = true, path = { "ui", "badges", "bagsHidden" } },
    { key = "badges.merchant", default = true, invert = true, path = { "ui", "badges", "merchantHidden" } },
    { key = "badges.auction", default = true, invert = true, path = { "ui", "badges", "auctionHidden" } },
    { key = "toast.zone", default = true, invert = true, path = { "ui", "toast", "zoneHidden" } },
    { key = "dungeon.panel", default = true, invert = true, path = { "ui", "dungeon", "hidden" } },
    { key = "roll.hint", default = true, invert = true, path = { "ui", "rollHintHidden" } },
    { key = "share.enabled", default = false, path = { "share", "enabled" } },
    { key = "tracker.shown", default = true, invert = true, path = { "ui", "tracker", "hidden" } },
    { key = "hud.lines", default = 3, min = 1, max = 5, step = 1, path = { "ui", "hud", "lines" } },
    { key = "hud.locked", default = false, path = { "ui", "hud", "locked" } },
    { key = "hud.alpha", default = 0.75, min = 0, max = 1, step = 0.05, path = { "ui", "hud", "alpha" } },
    { key = "pins.world", default = true, invert = true, path = { "ui", "pinsHidden" } },
    { key = "pins.minimap", default = true, invert = true, path = { "ui", "pinsMinimapHidden" } },
    { key = "pins.worldScale", default = 1, min = 0.5, max = 2, step = 0.05, path = { "ui", "pinsWorldScale" } },
    { key = "pins.minimapScale", default = 1, min = 0.5, max = 2, step = 0.05, path = { "ui", "pinsMinimapScale" } },
    { key = "arrow.enabled", default = true, invert = true, path = { "ui", "arrow", "disabled" } },
    { key = "arrow.scale", default = 1, min = 0.5, max = 2, step = 0.05, path = { "ui", "arrow", "scale" } },
    { key = "arrow.arrival", default = 10, min = 5, max = 30, step = 1, path = { "ui", "arrow", "arrival" } },
    { key = "arrow.color", default = "direction", values = { "direction", "gold" }, path = { "ui", "arrow", "color" } },
    { key = "arrow.locked", default = false, path = { "ui", "arrow", "locked" } },
    { key = "follow.window", default = true, invert = true, path = { "ui", "follow", "hidden" } },
    { key = "waypoint.preferTomTom", default = true, invert = true, path = { "ui", "waypointNoTomTom" } },
    { key = "planner.calibrate", default = true, invert = true, path = { "planner", "calibrateDisabled" } },
}

local byKey, keys = {}, {}
for _, spec in ipairs(CATALOG) do
    if spec.values then
        spec.kind = "choice"
    else
        spec.kind = type(spec.default)
    end
    byKey[spec.key] = spec
    keys[#keys + 1] = spec.key
end

local function readPath(path)
    return ns.DB.peek("account", unpack(path))
end

local function writePath(path, value)
    ns.DB.account(unpack(path, 1, #path - 1))[path[#path]] = value
end

local function normalize(spec, value)
    if spec.kind == "boolean" then
        return value and true or false
    elseif spec.kind == "number" then
        value = tonumber(value)
        if not value then
            return nil
        end
        value = math.min(spec.max, math.max(spec.min, value))
        value = spec.min + math.floor((value - spec.min) / spec.step + 0.5) * spec.step
        return tonumber(string.format("%.4f", math.min(spec.max, value)))
    end
    for _, allowed in ipairs(spec.values) do
        if allowed == value then
            return value
        end
    end
    return nil
end

function Options.spec(key)
    return byKey[key]
end

function Options.keys()
    return keys
end

function Options.get(key)
    local spec = byKey[key]
    if not spec then
        return nil
    end
    local saved = readPath(spec.path)
    if spec.invert then
        return not saved
    end
    local value = saved ~= nil and normalize(spec, saved)
    if value == nil or value == false and spec.kind ~= "boolean" then
        return spec.default
    end
    return value
end

function Options.set(key, value)
    local spec = byKey[key]
    value = spec and normalize(spec, value)
    if value == nil then
        return false
    end
    if Options.get(key) == value then
        return true
    end
    local stored
    if spec.invert then
        stored = (not value) or nil
    elseif value ~= spec.default then
        stored = value
    end
    writePath(spec.path, stored)
    if ns.Send then
        ns:Send("SP_OPTION_CHANGED", key, value)
    end
    return true
end

function Options.toggle(key)
    Options.set(key, not Options.get(key))
    return Options.get(key)
end

function Options.reset(key)
    local spec = byKey[key]
    if spec then
        Options.set(key, spec.default)
    end
end

local HUD_FIELDS = { "point", "relativePoint", "x", "y", "lines", "alpha", "locked" }

ns.DB.MIGRATIONS.account[2] = function(root)
    local ui = type(root.ui) == "table" and root.ui or nil
    if not ui then
        return
    end
    local tracker = type(ui.tracker) == "table" and ui.tracker or {}
    local follow = type(ui.follow) == "table" and ui.follow or {}
    local hud = type(ui.hud) == "table" and ui.hud or {}
    for _, field in ipairs(HUD_FIELDS) do
        if hud[field] == nil then
            hud[field] = tracker[field]
        end
        tracker[field] = nil
    end
    if hud.locked == nil then
        hud.locked = follow.locked
    end
    follow.locked = nil
    if next(hud) then
        ui.hud = hud
    end
end
