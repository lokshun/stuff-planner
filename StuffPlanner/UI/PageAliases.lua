-- CONTRAT
-- Anciennes pages de la fenêtre principale fondues dans d'autres (phase 16) : Liste cible dans Équipement,
-- Journal dans Profil. Pur. Charger après DB.lua, avant MainFrame.lua.
--   ns.PageAliases.MAP = {wishlist = "gear", journal = "profile"}
--   ns.PageAliases.resolve(key) -> page, alias : page = MAP[key] sinon key ; alias = key si c'en est un
--   ns.PageAliases.migrate(ui) : ui.tab ancienne -> nouvelle ; ui.tipsSeen[ancienne] reporté sur la nouvelle
--     puis retiré
-- Migration ns.DB.MIGRATIONS.account[3] : migrate(root.ui) si c'est une table.

local _, ns = ...

local PageAliases = {}
ns.PageAliases = PageAliases

PageAliases.MAP = { wishlist = "gear", journal = "profile" }

function PageAliases.resolve(key)
    local page = PageAliases.MAP[key]
    if page then
        return page, key
    end
    return key
end

function PageAliases.migrate(ui)
    ui.tab = PageAliases.resolve(ui.tab)
    local seen = type(ui.tipsSeen) == "table" and ui.tipsSeen
    if not seen then
        return
    end
    for alias, page in pairs(PageAliases.MAP) do
        if seen[alias] then
            seen[page] = true
            seen[alias] = nil
        end
    end
end

ns.DB.MIGRATIONS.account[3] = function(root)
    if type(root.ui) == "table" then
        PageAliases.migrate(root.ui)
    end
end
