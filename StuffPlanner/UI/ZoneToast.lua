-- CONTRAT
-- Toast d'entrée de carte : « Forêt d'Elwynn : 4 améliorations, la meilleure +12 % » (ZoneToastPresenter),
-- 5 s en haut de l'écran (ns.Toast) ; clic : onglet Zone de la fenêtre principale. Charger après Chat.lua,
-- ZoneToastPresenter.lua, Toast.lua et MainFrame.lua.
-- Vérifié à chaque SP_RESULTS_UPDATED (gains de la carte calculés, Results.busy() faux) : une fois par
-- carte (mapID de l'instantané, une sous-zone ne change rien) et par session ; carte marquée vue dès
-- que son classement est lisible, même vide (aucun toast sans amélioration).
-- Jamais en combat : vérification reportée à la sortie (ns:RunOutOfCombat). Option toast.zone coupée :
-- plus de vérification, toast affiché masqué.
--   ns.ZoneToast.check() : vérification immédiate (tests)
--   ns.ZoneToast.display(text) : affiche le toast (remplaçable dans les tests)

local _, ns = ...

local ZoneToast = {}
ns.ZoneToast = ZoneToast

local OPTION = "toast.zone"
local DURATION = 5
local OFFSET_Y = -140
local MAX_ENTRIES = 999

local seen = {}
local deferred = false
local toast

local function hide()
    if toast then
        toast:hide()
    end
end

local function openZone()
    hide()
    ns.WindowCombat.after(function()
        ns.MainFrame.show("zone")
    end)
end

function ZoneToast.display(text)
    toast = toast or ns.Toast.new({ offsetY = OFFSET_Y, duration = DURATION, onClick = openZone })
    toast:show(text)
end

function ZoneToast.check()
    if not ns.Options.get(OPTION) or ns.Results.busy() then
        return
    end
    if InCombatLockdown() then
        if not deferred then
            deferred = true
            ns:RunOutOfCombat(function()
                deferred = false
                ZoneToast.check()
            end)
        end
        return
    end
    local player = ns.Results.player()
    local mapID = player and player.mapID
    if not mapID or seen[mapID] then
        return
    end
    local results = ns.Chat.currentZone(MAX_ENTRIES, true)
    if not results then
        return
    end
    seen[mapID] = true
    local text = ns.ZoneToastPresenter.build(results, ns.Names.zone(mapID))
    if text then
        ZoneToast.display(text)
    end
end

ns:On("SP_RESULTS_UPDATED", function()
    ZoneToast.check()
end)

ns:On("SP_OPTION_CHANGED", function(key, value)
    if key == OPTION and not value then
        hide()
    end
end)
