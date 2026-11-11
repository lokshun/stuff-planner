-- CONTRAT
-- Bateaux et zeppelins entre continents (Classic), écrits à la main. Aucune API WoW.
--   ns.Transports = {{id, kind = "boat" | "zeppelin", faction?, a = {mapID, x, y}, b = {mapID, x, y}}...}
--   Dans les deux sens ; x, y en 0–1 sur la carte de zone (uiMapID) ; quais à vérifier en jeu
--   (❓ docs/API_NOTES.md, Forever peut différer). Trajets sur un même continent absents (tram, Rut'theran).

local _, ns = ...

local WETLANDS, DARKSHORE, DUSTWALLOW = 1437, 1439, 1445
local STRANGLETHORN, BARRENS, DUROTAR, TIRISFAL = 1434, 1413, 1411, 1420

ns.Transports = {
    { id = "menethil-auberdine", kind = "boat", a = { WETLANDS, 0.046, 0.571 }, b = { DARKSHORE, 0.324, 0.438 } },
    { id = "menethil-theramore", kind = "boat", a = { WETLANDS, 0.050, 0.634 }, b = { DUSTWALLOW, 0.716, 0.564 } },
    { id = "bootybay-ratchet", kind = "boat", a = { STRANGLETHORN, 0.259, 0.731 }, b = { BARRENS, 0.637, 0.386 } },
    { id = "durotar-tirisfal", kind = "zeppelin", faction = "Horde",
        a = { DUROTAR, 0.509, 0.126 }, b = { TIRISFAL, 0.608, 0.584 } },
    { id = "durotar-gromgol", kind = "zeppelin", faction = "Horde",
        a = { DUROTAR, 0.506, 0.139 }, b = { STRANGLETHORN, 0.316, 0.291 } },
}
