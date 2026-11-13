-- CONTRAT
-- Seul accès aux sauvegardes StuffPlannerDB (compte) et StuffPlannerCharDB (personnage). Aucune API WoW
-- hors geterrorhandler. Charger juste après Core.lua (ne dépend de rien).
--   ns.DB.account(...) / ns.DB.char(...) -> table au bout du chemin de clés, créée au besoin (une valeur qui
--     n'est pas une table est remplacée) ; sans chemin : la racine. Sauvegarde créée à la version courante.
--   ns.DB.peek("account" | "char", ...) -> valeur au bout du chemin | nil ; ne crée rien.
--   ns.DB.VERSION -> version courante ; ns.DB.MIGRATIONS = {account = {[v] = fn(root)}, char = {...}}
-- Migrations : au premier accès (account, char ou peek) d'une racine existante de version < VERSION
--   (absente = 0), chaque MIGRATIONS[scope][v] de version+1 à VERSION, dans l'ordre, puis version = VERSION ;
--   une fois par racine (une racine remplacée, ex. rechargement, est revue). Version plus récente : rien
--   n'est touché. Erreur : remise à geterrorhandler, version laissée à la dernière migration réussie.
-- Ne pas écrire avant le chargement des sauvegardes (ADDON_LOADED) : le client remplacerait la table.
-- Les sauvegardes propres à un module gardent leur schéma (collector, items) : DB n'y touche pas.

local _, ns = ...

local DB = {}
ns.DB = DB

DB.VERSION = 3
DB.MIGRATIONS = { account = {}, char = {} }

local GLOBALS = { account = "StuffPlannerDB", char = "StuffPlannerCharDB" }
local checked = setmetatable({}, { __mode = "k" })

local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then
        handler(err)
    end
end

local function migrate(scope, root)
    if checked[root] then
        return
    end
    checked[root] = true
    local version = tonumber(root.version) or 0
    if version >= DB.VERSION then
        return
    end
    for target = version + 1, DB.VERSION do
        local step = DB.MIGRATIONS[scope][target]
        if step then
            local ok, err = pcall(step, root)
            if not ok then
                report(err)
                return
            end
        end
        root.version = target
    end
end

local function root(scope, create)
    local name = GLOBALS[scope]
    local saved = _G[name]
    if type(saved) ~= "table" then
        if not create then
            return nil
        end
        saved = { version = DB.VERSION }
        _G[name] = saved
        checked[saved] = true
    end
    migrate(scope, saved)
    return saved
end

local function walk(scope, ...)
    local node = root(scope, true)
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        if type(node[key]) ~= "table" then
            node[key] = {}
        end
        node = node[key]
    end
    return node
end

function DB.account(...)
    return walk("account", ...)
end

function DB.char(...)
    return walk("char", ...)
end

function DB.peek(scope, ...)
    local node = root(scope, false)
    for i = 1, select("#", ...) do
        if type(node) ~= "table" then
            return nil
        end
        node = node[select(i, ...)]
    end
    return node
end
