-- CONTRAT
-- Fenêtre principale et combat : ce qu'il faut rouvrir à la sortie du combat. Pur : aucun appel d'API.
--   ns.CombatReopen.new() -> state
--   state:enter(shown, tab?, detail?) -> bool : entrée en combat ; vrai si la fenêtre était ouverte (à cacher,
--     page et fiche « quest » | « source » mémorisées pour la sortie) ; une fenêtre fermée n'est pas rouverte
--   state:request(tab?) -> bool : ouverture demandée en combat ; la fenêtre s'ouvrira à la sortie, sur tab s'il
--     est donné, sinon la page mémorisée ; vrai à la première demande du combat seulement (avis à afficher)
--   state:leave() -> {tab, detail} | nil : sortie du combat ; ce qu'il faut rouvrir, puis tout est oublié
-- Fermeture manuelle hors combat : rien n'est mémorisé, donc rien n'est rouvert.

local _, ns = ...

local CombatReopen = {}
ns.CombatReopen = CombatReopen

local State = {}
State.__index = State

function CombatReopen.new()
    return setmetatable({ plan = nil, noticed = false }, State)
end

function State:enter(shown, tab, detail)
    self.noticed = false
    self.plan = shown and { tab = tab, detail = detail } or nil
    return shown == true
end

function State:request(tab)
    local plan = self.plan or {}
    plan.tab = tab or plan.tab
    self.plan = plan
    local notice = not self.noticed
    self.noticed = true
    return notice
end

function State:leave()
    local plan = self.plan
    self.plan, self.noticed = nil, false
    return plan
end
