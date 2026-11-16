-- CONTRAT
-- Origines choisies par page (ns.Origins), sauvegardées dans StuffPlannerDB.ui.origins[page].
-- Charger après DB.lua et Engine/Origins.lua, avant les pages.
--   ns.PageOrigins.PAGES -> {"route", "zone", "gear"} : pages qui ont leur choix (Parcours, Maintenant, Équipement)
--   ns.PageOrigins.get(page) -> état Origins (table sauvegardée, gardée par référence)
--   ns.PageOrigins.toggle(page, kind) -> bool (changé ; la dernière origine visible reste)
--   ns.PageOrigins.migrate(ui) : ancien filtre de la page Maintenant, ui.zoneFilters.hidden ({[type] = true}),
--     déplacé vers ui.origins.zone.hidden (choix déjà présent gardé)
-- Migration ns.DB.MIGRATIONS.account[4] : migrate(root.ui) si c'est une table.

local _, ns = ...

local PageOrigins = {}
ns.PageOrigins = PageOrigins

PageOrigins.PAGES = { "route", "zone", "gear" }

function PageOrigins.get(page)
    return ns.Origins.new(ns.DB.account("ui", "origins", page))
end

function PageOrigins.toggle(page, kind)
    return ns.Origins.toggle(PageOrigins.get(page), kind)
end

function PageOrigins.migrate(ui)
    local filters = type(ui.zoneFilters) == "table" and ui.zoneFilters or nil
    local hidden = filters and type(filters.hidden) == "table" and filters.hidden or nil
    if not hidden then
        return
    end
    filters.hidden = nil
    if next(hidden) == nil then
        return
    end
    ui.origins = type(ui.origins) == "table" and ui.origins or {}
    local zone = type(ui.origins.zone) == "table" and ui.origins.zone or {}
    if type(zone.hidden) ~= "table" then
        zone.hidden = hidden
    end
    ui.origins.zone = zone
end

ns.DB.MIGRATIONS.account[4] = function(root)
    if type(root.ui) == "table" then
        PageOrigins.migrate(root.ui)
    end
end
