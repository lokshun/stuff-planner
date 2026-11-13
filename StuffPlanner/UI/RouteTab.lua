-- CONTRAT
-- Page « Parcours 1-60 » : meilleur objet par emplacement et par palier de niveau
-- (RouteResults, RoutePresenter), ScrollBox avec en-têtes de palier (ns.RouteRows). Charger après
-- MainFrame.lua, RouteResults.lua, RoutePresenter.lua, FilterMenu.lua et RouteRows.lua.
-- S'inscrit par ns.MainFrame.addTab("route", …). Classement partagé (RouteResults), recalculé
-- à l'affichage de la page après SP_PLAYER_CHANGED, SP_DATA_READY ou SP_PROFILE_CHANGED :
-- « calcul en cours » d'ici là ; rafraîchi sur SP_ROUTE_UPDATED ;
-- noms reçus du client : nouvelle présentation regroupée (NameAsker), sans recalcul ; noms
-- encore inconnus : nouvelle présentation toutes les RETRY_DELAY s, RETRY_MAX fois au plus.
-- Paliers passés (référence, grisés) repliés par défaut : clic sur l'en-tête, état gardé dans
-- StuffPlannerDB.ui.routePastOpen = {[min du palier] = true}. Bouton « Tri » à droite
-- de l'en-tête (ns.FilterMenu : Par emplacement / Meilleur gain dans chaque palier, StuffPlannerDB.ui.routeByGain).
-- Raids exclus. Clics des lignes : ns.RouteRows (fiche, repère, essayage, menu clic droit).
-- Alternatives plus faciles (AltLines) : bouton flèche à droite, état déplié local (non gardé), par clé
-- RoutePresenter expandKey. Session de jeu : page « Maintenant » (ZoneTab, T14.6).

local _, ns = ...

local L = ns.L

local RETRY_DELAY, RETRY_MAX = 1, 10

local header, sortMenu, footer, scrollBox, emptyText
local expanded = {}
local retries, retryPending = 0, false

local askName = ns.NameAsker.new(function()
    ns.MainFrame.refresh()
end)

-- Filet de sécurité : une réponse du client peut arriver avant que le nom soit lisible.
local function scheduleRetry(missing)
    if not missing then
        retries = 0
        return
    end
    if retryPending or retries >= RETRY_MAX then
        return
    end
    retries, retryPending = retries + 1, true
    C_Timer.After(RETRY_DELAY, function()
        retryPending = false
        ns.MainFrame.refresh()
    end)
end

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

local function uiState()
    return ns.DB.account("ui")
end

local function pastOpen()
    local ui = uiState()
    ui.routePastOpen = ui.routePastOpen or {}
    return ui.routePastOpen
end

local routeRows = ns.RouteRows.new({
    expand = function(key)
        expanded[key] = not expanded[key] or nil
        ns.MainFrame.refresh()
    end,
    tier = function(toggle)
        local open = pastOpen()
        open[toggle] = not open[toggle] or nil
        ns.MainFrame.refresh()
    end,
})

local function refresh()
    local tiers, info = ns.RouteResults.get()
    local rows = tiers and ns.RoutePresenter.build(tiers, ns.Data, pastOpen(), expanded,
        uiState().routeByGain == true) or {}
    scheduleRetry(ns.RouteRows.askNames(rows, askName))
    header:SetText(L.ROUTE_HEADER)
    local P = ns.FilterMenuPresenter
    sortMenu:update(P.label(nil), function()
        return P.entries(nil, P.sorts(uiState().routeByGain and "gain" or "slot", { "slot", "gain" }))
    end, function(_, value)
        uiState().routeByGain = value == "gain"
        ns.MainFrame.refresh()
    end)
    footer:SetText(tiers and L.ROUTE_FOOTER:format(info) or "")
    ns.Compat.SetRows(scrollBox, rows, true)
    emptyText:SetText(#rows == 0 and (not tiers and info or L.ROUTE_EMPTY) or "")
end

local function create(parent)
    local theme = ns.Theme
    local panel = CreateFrame("Frame", nil, parent)
    header = panel:CreateFontString(nil, "OVERLAY", theme.fonts.header)
    sortMenu = ns.FilterMenu.new(panel)
    sortMenu.button:SetPoint("TOPRIGHT")
    header:SetPoint("LEFT", panel, "TOPLEFT", 0, -ns.Chips.HEIGHT / 2)
    header:SetPoint("RIGHT", sortMenu.button, "LEFT", -theme.spacing.gap, 0)
    header:SetJustifyH("LEFT")
    footer = panel:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    footer:SetPoint("BOTTOMLEFT")
    footer:SetJustifyH("LEFT")
    setColor(footer, theme.colors.muted)
    scrollBox = CreateFrame("Frame", nil, panel, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", 0, -ns.Chips.HEIGHT - theme.spacing.gap)
    scrollBox:SetPoint("BOTTOMRIGHT", -20, 18)
    local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtentCalculator(function(_, row)
        return routeRows.extent(row)
    end)
    view:SetElementInitializer("Button", routeRows.init)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    emptyText = panel:CreateFontString(nil, "OVERLAY", theme.fonts.body)
    emptyText:SetPoint("CENTER", scrollBox, "CENTER")
    setColor(emptyText, theme.colors.muted)
    return panel
end

ns.MainFrame.addTab("route", {
    create = create, refresh = refresh, order = 2, label = L.TAB_ROUTE, short = L.TAB_ROUTE_SHORT,
    icon = "Interface\\Icons\\INV_Misc_Book_09",
})

ns:On("SP_ROUTE_UPDATED", ns.MainFrame.refresh)
ns:On("SP_PLAYER_CHANGED", ns.MainFrame.refresh)
ns:On("SP_DATA_READY", ns.MainFrame.refresh)
ns:On("SP_PROFILE_CHANGED", ns.MainFrame.refresh)

ns:On("SP_SELECTION_CHANGED", function()
    if scrollBox then
        scrollBox:ForEachFrame(routeRows.mark)
    end
end)
