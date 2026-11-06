-- CONTRAT
-- Profil de poids actif du personnage. Charger après Core.lua et Profiles/Defaults.lua.
--   ns.Profiles.active() -> profil de ns.ProfileDefaults ({weights, caps, ...}) | nil ; table partagée
--   ns.Profiles.activeID() -> profileID | nil (classe sans profil)
--   ns.Profiles.available() -> profileIDs de la classe du joueur, triés ; get(id) -> profil | nil
--   ns.Profiles.automaticID() -> profileID que donnerait le choix automatique | nil (classe sans profil)
--   ns.Profiles.manualID() -> profileID choisi à la main et encore valable | nil (automatique)
--   ns.Profiles.set(profileID | nil) -> bool ; choix manuel gardé dans StuffPlannerCharDB.profiles.manual,
--     conservé au niveau 60 et au rechargement ; nil revient au choix automatique ; false si inconnu
--     ou d'une autre classe (rien ne change)
-- Choix automatique : première spé de la classe (ordre alphabétique), phase « 60 » dès le niveau 60,
-- « leveling » avant ; l'autre phase si celle-ci manque. Manuel disparu des défauts : automatique.
--   ns.Profiles.CUSTOM = "CUSTOM" ; setCustom({weights, caps, order?}) : copie gardée dans
--     StuffPlannerCharDB.profiles.custom, activée en manuel, émet même si déjà active ; order (liste de
--     clés, priorités de stats) gardé tel quel, source « priorities », sinon source « import » ;
--     clearCustom() l'efface (retour à l'automatique s'il était actif) ; listé en dernier par available()
--   ns.Profiles.baseID() -> profil par défaut de départ : choix manuel s'il n'est pas CUSTOM, sinon
--     automatique ; nil si la classe n'en a pas
-- SP_PROFILE_CHANGED(profileID) émis une fois par changement réel (set, ou SP_PLAYER_CHANGED qui
-- franchit le niveau 60) ; le premier calcul est silencieux. Abonné : ns.Scoring.invalidate().

local _, ns = ...

local Profiles = {}
ns.Profiles = Profiles

Profiles.CUSTOM = "CUSTOM"

local MAX_LEVEL = 60
local current
local customProfile, customSource

local function store()
    StuffPlannerCharDB = StuffPlannerCharDB or {}
    StuffPlannerCharDB.profiles = StuffPlannerCharDB.profiles or {}
    return StuffPlannerCharDB.profiles
end

local function defaults()
    return ns.ProfileDefaults or {}
end

local function playerClass()
    local _, class = UnitClass("player")
    return class
end

local function copy(values)
    local result = {}
    for key, value in pairs(type(values) == "table" and values or {}) do
        if type(value) == "number" then
            result[key] = value
        end
    end
    return result
end

local function copyOrder(order)
    if type(order) ~= "table" then
        return nil
    end
    local result = {}
    for i, key in ipairs(order) do
        if type(key) ~= "string" then
            return nil
        end
        result[i] = key
    end
    return #result > 0 and result or nil
end

-- Profil importé, reconstruit seulement quand la sauvegarde change de table.
local function custom()
    local saved = store().custom
    if type(saved) ~= "table" or type(saved.weights) ~= "table" then
        return nil
    end
    if saved ~= customSource then
        customSource = saved
        local order = copyOrder(saved.order)
        customProfile = {
            spec = Profiles.CUSTOM,
            source = order and "priorities" or "import",
            weights = copy(saved.weights),
            caps = copy(saved.caps),
            order = order,
        }
    end
    customProfile.class = playerClass()
    return customProfile
end

local function lookup(id)
    if id == Profiles.CUSTOM then
        return custom()
    end
    return defaults()[id]
end

function Profiles.available()
    local class = playerClass()
    local ids = {}
    for id, profile in pairs(defaults()) do
        if profile.class == class then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)
    if custom() then
        ids[#ids + 1] = Profiles.CUSTOM
    end
    return ids
end

local function automatic(ids)
    local first = defaults()[ids[1]]
    if not first then
        return nil
    end
    local wanted = (UnitLevel("player") or 0) >= MAX_LEVEL and "60" or "leveling"
    local fallback
    for _, id in ipairs(ids) do
        local profile = defaults()[id]
        if profile.spec == first.spec then
            if profile.phase == wanted then
                return id
            end
            fallback = fallback or id
        end
    end
    return fallback
end

local function contains(ids, wanted)
    for _, id in ipairs(ids) do
        if id == wanted then
            return true
        end
    end
    return false
end

local function resolve()
    local ids = Profiles.available()
    local manual = store().manual
    if manual and contains(ids, manual) then
        return manual
    end
    return automatic(ids)
end

function Profiles.baseID()
    local ids = Profiles.available()
    local manual = store().manual
    if manual and manual ~= Profiles.CUSTOM and contains(ids, manual) then
        return manual
    end
    return automatic(ids)
end

function Profiles.automaticID()
    return automatic(Profiles.available())
end

function Profiles.get(id)
    return lookup(id)
end

function Profiles.manualID()
    local manual = store().manual
    if manual and contains(Profiles.available(), manual) then
        return manual
    end
    return nil
end

function Profiles.activeID()
    local id = resolve()
    if current == nil then
        current = id
    end
    return id
end

function Profiles.active()
    local id = Profiles.activeID()
    return id and lookup(id)
end

local function refresh()
    local known = current
    local id = resolve()
    current = id
    if known ~= nil and id ~= known then
        ns:Send("SP_PROFILE_CHANGED", id)
    end
end

function Profiles.set(profileID)
    if profileID ~= nil and not contains(Profiles.available(), profileID) then
        return false
    end
    Profiles.activeID()
    store().manual = profileID
    refresh()
    return true
end

function Profiles.setCustom(profile)
    Profiles.activeID()
    local wasActive = current == Profiles.CUSTOM
    local saved = store()
    saved.custom = {
        weights = copy(profile.weights),
        caps = copy(profile.caps),
        order = copyOrder(profile.order),
    }
    saved.manual = Profiles.CUSTOM
    refresh()
    if wasActive then
        ns:Send("SP_PROFILE_CHANGED", Profiles.CUSTOM)
    end
end

function Profiles.clearCustom()
    Profiles.activeID()
    local saved = store()
    saved.custom = nil
    if saved.manual == Profiles.CUSTOM then
        saved.manual = nil
    end
    refresh()
end

ns:On("SP_PLAYER_CHANGED", refresh)
ns:On("SP_PROFILE_CHANGED", function()
    if ns.Scoring then
        ns.Scoring.invalidate()
    end
end)
