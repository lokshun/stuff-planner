-- CONTRAT
-- Demandes de noms au client pour un écran, avec un rafraîchissement regroupé. Charger après Data/Names.lua.
--   ns.NameAsker.new(refresh) -> ask(kind, id) -> bool : vrai si le nom est déjà connu (Names.isKnown) ;
--     sinon demandé une fois (Names.onReady), refresh appelé une fois NAME_DELAY s après la dernière
--     arrivée regroupée ; demande oubliée à l'arrivée du nom. id nil : faux, rien demandé.
--   ns.NameAsker.pending(ask) -> demandes en attente (tests, /splan perf)
--   ns.NameAsker.MAX_PENDING : au-delà, les demandes en attente sont oubliées (objets jamais reçus) ;
--     une demande oubliée peut être refaite, son rappel éventuel ne fait qu'un rafraîchissement de plus.

local _, ns = ...

local NameAsker = {}
ns.NameAsker = NameAsker

NameAsker.MAX_PENDING = 500
local NAME_DELAY = 0.2

local states = setmetatable({}, { __mode = "k" })

function NameAsker.new(refresh)
    local state = { asked = {}, count = 0, scheduled = false }
    local function schedule()
        if state.scheduled then
            return
        end
        state.scheduled = true
        C_Timer.After(NAME_DELAY, function()
            state.scheduled = false
            refresh()
        end)
    end
    local function ask(kind, id)
        if id == nil then
            return false
        end
        if ns.Names.isKnown(kind, id) then
            return true
        end
        local key = kind .. id
        if not state.asked[key] then
            if state.count >= NameAsker.MAX_PENDING then
                state.asked, state.count = {}, 0
            end
            state.asked[key], state.count = true, state.count + 1
            ns.Names.onReady(kind, id, function()
                if state.asked[key] then
                    state.asked[key], state.count = nil, state.count - 1
                end
                schedule()
            end)
        end
        return false
    end
    states[ask] = state
    return ask
end

function NameAsker.pending(ask)
    local state = states[ask]
    return state and state.count or 0
end
