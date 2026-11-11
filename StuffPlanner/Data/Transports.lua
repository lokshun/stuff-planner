-- CONTRAT
-- Bateaux et zeppelins de Classic, écrits à la main. Aucune API WoW.
--   ns.Transports = {{id, kind = "boat" | "zeppelin", faction?, a = {mapID, x, y}, b = {mapID, x, y}}...}
--     dans les deux sens ; x, y en 0–1 sur la carte de zone (uiMapID).
--   ns.TravelRegions = {[uiMapID] = région} : îles sans passage à pied (Engine/Travel, point.region).
-- Sources (QuestieDB, révision de tools/sources/questie.py) : zeppelins = maîtres de zeppelin (Frezza,
-- Zapetta, Snurk Bucksquick, Nez'raz, Hin Denburg, Squibby Overspeck) ; bateaux = gardes postés par
-- paire au bout des jetées (Menethil Sentry, Auberdine Sentinel, Theramore Guard, Ratchet Bruiser,
-- Booty Bay Bruiser, Darnassus Sentinel). Absents : tram des profondeurs (instance à part), portail de
-- Darnassus (même île que Rut'theran).

local _, ns = ...

local WETLANDS, DARKSHORE, DUSTWALLOW, TELDRASSIL = 1437, 1439, 1445, 1438
local STRANGLETHORN, BARRENS, DUROTAR, TIRISFAL, DARNASSUS = 1434, 1413, 1411, 1420, 1457

ns.Transports = {
    { id = "menethil-auberdine", kind = "boat", a = { WETLANDS, 0.047, 0.573 }, b = { DARKSHORE, 0.325, 0.436 } },
    { id = "menethil-theramore", kind = "boat", a = { WETLANDS, 0.051, 0.634 }, b = { DUSTWALLOW, 0.714, 0.561 } },
    { id = "bootybay-ratchet", kind = "boat", a = { STRANGLETHORN, 0.262, 0.732 }, b = { BARRENS, 0.637, 0.385 } },
    { id = "auberdine-rutheran", kind = "boat", a = { DARKSHORE, 0.332, 0.403 }, b = { TELDRASSIL, 0.553, 0.926 } },
    { id = "durotar-tirisfal", kind = "zeppelin", faction = "Horde",
        a = { DUROTAR, 0.508, 0.135 }, b = { TIRISFAL, 0.607, 0.589 } },
    { id = "durotar-gromgol", kind = "zeppelin", faction = "Horde",
        a = { DUROTAR, 0.507, 0.129 }, b = { STRANGLETHORN, 0.314, 0.299 } },
    { id = "tirisfal-gromgol", kind = "zeppelin", faction = "Horde",
        a = { TIRISFAL, 0.618, 0.592 }, b = { STRANGLETHORN, 0.315, 0.294 } },
}

ns.TravelRegions = { [TELDRASSIL] = "teldrassil", [DARNASSUS] = "teldrassil" }
