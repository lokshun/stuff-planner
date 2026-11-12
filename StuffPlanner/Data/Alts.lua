-- CONTRAT
-- Instantanés compacts des autres personnages du compte, pour « utile à X » (UI/Presenters/AltGain.lua).
-- Sauvegarde StuffPlannerDB.alts = {["Nom-Royaume"] = record}. Charger après DB.lua, Player.lua, Manager.lua.
--   ns.Alts.MAX = 40 : au-delà, le relevé le plus ancien (at) est retiré
--   ns.Alts.compact(snapshot, profile, name, realm, at) -> record (pur, tables copiées) :
--     {name, realm, class, race, raceID, faction, level, equipped, equippedStats, spellHit, meleeHit,
--      profile = {weights, caps}, at} ; utilisable comme instantané par Scoring.deltaFields.
--   ns.Alts.save(record) : rangé sous « name-realm »
--   ns.Alts.others(name?, realm?, faction?) -> {record...} par nom : même royaume et même faction (courrier
--     possible), sans le personnage name ; par défaut, le personnage courant.
-- PLAYER_LOGOUT : personnage courant enregistré (profil actif et Data prête requis).

local _, ns = ...

local Alts = {}
ns.Alts = Alts

Alts.MAX = 40

local function copy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, inner in pairs(value) do
        result[key] = copy(inner)
    end
    return result
end

function Alts.compact(snapshot, profile, name, realm, at)
    return {
        name = name, realm = realm, class = snapshot.class, race = snapshot.race, raceID = snapshot.raceID,
        faction = snapshot.faction, level = snapshot.level, equipped = copy(snapshot.equipped or {}),
        equippedStats = copy(snapshot.equippedStats or {}), spellHit = snapshot.spellHit,
        meleeHit = snapshot.meleeHit, avoidCrit = snapshot.avoidCrit,
        profile = { weights = copy(profile.weights or {}), caps = copy(profile.caps or {}) },
        at = at,
    }
end

function Alts.save(record)
    local alts = ns.DB.account("alts")
    alts[record.name .. "-" .. record.realm] = record
    local count, oldestKey, oldest = 0, nil, math.huge
    for key, other in pairs(alts) do
        count = count + 1
        if (other.at or 0) < oldest then
            oldestKey, oldest = key, other.at or 0
        end
    end
    if count > Alts.MAX then
        alts[oldestKey] = nil
    end
end

local function current()
    return UnitName("player"), GetRealmName(), UnitFactionGroup("player")
end

function Alts.others(name, realm, faction)
    if not name then
        name, realm, faction = current()
    end
    local result = {}
    for _, record in pairs(ns.DB.peek("account", "alts") or {}) do
        if record.name ~= name and record.realm == realm and record.faction == faction then
            result[#result + 1] = record
        end
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function()
    local profile = ns.Profiles and ns.Profiles.active()
    if not (profile and ns.Data and ns.Data.ready()) then
        return
    end
    local name, realm = current()
    if name and realm then
        Alts.save(Alts.compact(ns.Player.snapshot(), profile, name, realm, time()))
    end
end)
