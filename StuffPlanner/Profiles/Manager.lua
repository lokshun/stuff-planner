-- CONTRAT
-- Profil de poids actif du personnage. Charger après Core.lua, Profiles/Defaults.lua et Profiles/Customs.lua.
--   ns.Profiles.active() -> profil ({weights, caps, ...}) | nil ; table partagée, ne pas modifier
--   ns.Profiles.activeID() -> profileID | nil (classe sans profil)
--   ns.Profiles.available() -> profileIDs de la classe du joueur, triés, puis profils personnalisés dans
--     leur ordre de création ; get(id) -> profil | nil
--   ns.Profiles.automaticID() -> profileID que donnerait le choix automatique | nil (classe sans profil)
--   ns.Profiles.manualID() -> profileID choisi à la main et encore valable | nil (automatique)
--   ns.Profiles.set(profileID | nil) -> bool ; choix manuel gardé dans StuffPlannerCharDB.profiles.manual,
--     conservé au niveau 60 et au rechargement ; nil revient au choix automatique ; false si inconnu
--     ou d'une autre classe (rien ne change)
-- Choix automatique : première spé de la classe (ordre alphabétique), phase « 60 » dès le niveau 60,
-- « leveling » avant ; l'autre phase si celle-ci manque. Manuel disparu : automatique.
-- Profils personnalisés (ns.Customs, StuffPlannerCharDB.profiles.customs ; ancien `custom` repris) :
--   isCustom(id) ; profil construit {id, spec = "CUSTOM", name?, source = « priorities » (order) | « import »,
--     weights, caps, order?, class, fallback = profil de baseID() | nil (Scoring : repli hors profil)}
--   saveCustom(id | nil, name?, {weights, caps, order?}) -> id | nil, code (FULL, UNKNOWN) : enregistre (nil =
--     nouveau), active en manuel, émet même s'il était déjà actif
--   renameCustom(id, text) -> bool, code (NAME, UNKNOWN), sans message ; deleteCustom(id) -> bool, retour à
--     l'automatique s'il était actif
--   ns.Profiles.baseID() -> profil par défaut de départ : choix manuel s'il n'est pas personnalisé, sinon
--     automatique ; nil si la classe n'en a pas
-- Profil secondaire (comparaison, T12) : secondaryID() -> profileID | nil, gardé dans
--   StuffPlannerCharDB.profiles.secondary, ignoré tant qu'il est inconnu ou égal au profil actif ;
--   secondary() -> profil | nil ; setSecondary(id | nil) -> bool (false : profil actif, inconnu ou d'une autre
--   classe) ; SP_SECONDARY_CHANGED(profileID | nil) émis si le secondaire change (setSecondary, ou deleteCustom
--   de ce profil).
-- SP_PROFILE_CHANGED(profileID) émis une fois par changement réel (set, saveCustom, deleteCustom, ou
-- SP_PLAYER_CHANGED qui franchit le niveau 60) ; le premier calcul est silencieux. Abonné : Scoring.invalidate().

local _, ns = ...

local Profiles = {}
ns.Profiles = Profiles

local CUSTOM_SPEC = "CUSTOM"
local MAX_LEVEL = 60
local current
local built = setmetatable({}, { __mode = "k" }) -- entrée sauvegardée -> profil construit

Profiles.isCustom = ns.Customs.isCustom

local function store()
    local saved = ns.DB.char("profiles")
    ns.Customs.migrate(saved)
    return saved
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
    for key, value in pairs(values or {}) do
        result[key] = value
    end
    return result
end

-- Profil construit une fois par entrée (save remplace l'entrée, rename ne change que le nom).
local function custom(id)
    local entry = ns.Customs.find(store(), id)
    if not entry then
        return nil
    end
    local profile = built[entry]
    if not profile then
        local order = entry.order and copy(entry.order)
        profile = {
            id = id,
            spec = CUSTOM_SPEC,
            source = order and "priorities" or "import",
            weights = copy(entry.weights),
            caps = copy(entry.caps),
            order = order,
        }
        built[entry] = profile
    end
    profile.name = entry.name
    profile.class = playerClass()
    profile.fallback = defaults()[Profiles.baseID()]
    return profile
end

local function lookup(id)
    if Profiles.isCustom(id) then
        return custom(id)
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
    for _, entry in ipairs(ns.Customs.list(store())) do
        ids[#ids + 1] = entry.id
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
        if profile and profile.spec == first.spec then
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
    if manual and not Profiles.isCustom(manual) and contains(ids, manual) then
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

function Profiles.secondaryID()
    local id = store().secondary
    if id and id ~= Profiles.activeID() and contains(Profiles.available(), id) then
        return id
    end
    return nil
end

function Profiles.secondary()
    local id = Profiles.secondaryID()
    return id and lookup(id)
end

function Profiles.setSecondary(profileID)
    if profileID ~= nil and (profileID == Profiles.activeID() or not contains(Profiles.available(), profileID)) then
        return false
    end
    local known = Profiles.secondaryID()
    store().secondary = profileID
    if known ~= profileID then
        ns:Send("SP_SECONDARY_CHANGED", profileID)
    end
    return true
end

function Profiles.saveCustom(id, name, profile)
    Profiles.activeID()
    local saved = store()
    local savedID, code = ns.Customs.save(saved, id, name, profile)
    if not savedID then
        return nil, code
    end
    local wasActive = current == savedID
    saved.manual = savedID
    refresh()
    if wasActive then
        ns:Send("SP_PROFILE_CHANGED", savedID)
    end
    return savedID
end

function Profiles.renameCustom(id, text)
    return ns.Customs.rename(store(), id, text)
end

function Profiles.deleteCustom(id)
    Profiles.activeID()
    local saved = store()
    if not ns.Customs.remove(saved, id) then
        return false
    end
    if saved.manual == id then
        saved.manual = nil
    end
    refresh()
    if saved.secondary == id then
        saved.secondary = nil
        ns:Send("SP_SECONDARY_CHANGED", nil)
    end
    return true
end

ns:On("SP_PLAYER_CHANGED", refresh)
ns:On("SP_PROFILE_CHANGED", function()
    if ns.Scoring then
        ns.Scoring.invalidate()
    end
end)
