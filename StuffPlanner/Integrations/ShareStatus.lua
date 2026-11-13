-- CONTRAT
-- /splan share : état du partage des confirmations de quête (Integrations/Share.lua). Charger après Share.lua.
--   ns.ShareStatus.lines(enabled, channels, stats) -> {texte...} : L.SHARE_STATUS_ON | L.SHARE_STATUS_OFF,
--     L.SHARE_CHANNELS (canaux joints par « , », L.SHARE_NO_CHANNEL sans canal), L.SHARE_COUNTS (envoyés,
--     reçus, appliqués, rejetés) ; channels = Share.channels(), stats = Share.stats()
-- Commande : option share.enabled, Share.channels(), Share.stats(), une ligne de discussion par texte.

local _, ns = ...

local L = ns.L

local ShareStatus = {}
ns.ShareStatus = ShareStatus

function ShareStatus.lines(enabled, channels, stats)
    local joined = #channels > 0 and table.concat(channels, ", ") or L.SHARE_NO_CHANNEL
    return {
        enabled and L.SHARE_STATUS_ON or L.SHARE_STATUS_OFF,
        L.SHARE_CHANNELS:format(joined),
        L.SHARE_COUNTS:format(stats.sent, stats.received, stats.applied, stats.rejected),
    }
end

if not ns.RegisterCommand then
    return
end

ns:RegisterCommand("share", function()
    local lines = ShareStatus.lines(ns.Options.get("share.enabled") == true, ns.Share.channels(), ns.Share.stats())
    for _, line in ipairs(lines) do
        print(line)
    end
end, "SHARE_COMMAND_HELP")
