-- CONTRAT
-- Socle de l'addon. Charger après embeds.xml et Locales/.
--   ns.L -> libellés AceLocale ; ns.Addon -> objet AceAddon
--   ns.ICON -> chemin du logo (portraits, bouton de la minicarte)
--   ns:NewModule(name, ...) -> module AceAddon ; ns:GetModule(name) -> module | nil
--   ns:Send(msg, ...), ns:On(msg, fn) -> bus interne ; fn reçoit (...) ;
--     abonnés appelés dans l'ordre d'inscription, une erreur n'arrête pas les suivants
--   ns:RunOutOfCombat(fn) -> exécute maintenant, ou à PLAYER_REGEN_ENABLED en combat
--   ns:RegisterCommand(name, fn, helpKey) -> sous-commande de /splan ; fn reçoit le reste
--     de la ligne ; helpKey est une clé de ns.L
--   ns:Commands() -> {{name, help}...} triées par nom (help = texte de ns.L)
-- /splan sans argument ou inconnu affiche l'aide ; /splan attend la fin du combat.
-- Menu des addons : commande show si elle existe, sinon l'aide.
-- Messages du bus (émetteur, détail dans son CONTRAT) : SP_PLAYER_CHANGED, SP_QUEST_LOG_CHANGED (Player),
--   SP_DATA_READY (Loader), SP_ITEMS_CONFIRMED (ItemProbe), SP_QUEST_OBSERVED (Collector, Share),
--   SP_PROFILE_CHANGED, SP_SECONDARY_CHANGED (Manager), SP_RESULTS_UPDATED (Results), SP_ROUTE_UPDATED
--   (RouteResults), SP_OPTION_CHANGED (Options), SP_FOLLOW_CHANGED, SP_FOLLOW_UPDATED (Follow),
--   SP_WAYPOINT_CHANGED (TomTom), SP_DUNGEON_CHANGED (DungeonRun), SP_WISHLIST_CHANGED (WishlistStore),
--   SP_HISTORY_CHANGED (History), SP_SELECTION_CHANGED (RowActions).

local ADDON, ns = ...

local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)
local addon = LibStub("AceAddon-3.0"):NewAddon(ADDON, "AceEvent-3.0")

ns.L = L
ns.Addon = addon
ns.ICON = [[Interface\AddOns\StuffPlanner\Media\Icon]]

function ns:NewModule(name, ...) -- luacheck: ignore 212/self
    return addon:NewModule(name, ...)
end

function ns:GetModule(name) -- luacheck: ignore 212/self
    return addon:GetModule(name, true)
end

local function safeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        geterrorhandler()(err)
    end
end

local listeners = {}

function ns:On(msg, fn) -- luacheck: ignore 212/self
    local list = listeners[msg]
    if not list then
        list = {}
        listeners[msg] = list
    end
    list[#list + 1] = fn
end

function ns:Send(msg, ...) -- luacheck: ignore 212/self
    local list = listeners[msg]
    if not list then
        return
    end
    for i = 1, #list do
        safeCall(list[i], ...)
    end
end

local pending = {}

function ns:RunOutOfCombat(fn) -- luacheck: ignore 212/self
    if InCombatLockdown() then
        pending[#pending + 1] = fn
    else
        fn()
    end
end

addon:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    local queue = pending
    pending = {}
    for i = 1, #queue do
        safeCall(queue[i])
    end
end)

local commands = {}

function ns:Commands() -- luacheck: ignore 212/self
    local list = {}
    for name, command in pairs(commands) do
        list[#list + 1] = { name = name, help = L[command.helpKey] }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function showHelp()
    print(L.HELP_HEADER)
    for _, command in ipairs(ns:Commands()) do
        print(L.HELP_LINE:format(command.name, command.help))
    end
end

function ns:RegisterCommand(name, fn, helpKey) -- luacheck: ignore 212/self
    commands[name:lower()] = { fn = fn, helpKey = helpKey }
end

local function dispatch(input)
    local name, args = input:match("^%s*(%S*)%s*(.-)%s*$")
    local command = commands[name:lower()]
    if command then
        command.fn(args)
    else
        if name ~= "" then
            print(L.UNKNOWN_COMMAND:format(name))
        end
        showHelp()
    end
end

ns:RegisterCommand("help", showHelp, "HELP_COMMAND_HELP")

local function handleSlash(input)
    ns:RunOutOfCombat(function()
        dispatch(input or "")
    end)
end

SLASH_STUFFPLANNER1 = "/splan"
SlashCmdList.STUFFPLANNER = handleSlash

function StuffPlanner_OnAddonCompartmentClick()
    handleSlash(commands.show and "show" or "")
end
