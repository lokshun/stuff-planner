-- CONTRAT
-- Onglet « Parcours 1-60 » : meilleur objet par emplacement et par palier de niveau
-- (RouteResults, RoutePresenter), ScrollBox avec en-têtes de palier. Charger après MainFrame.lua,
-- RouteResults.lua, RoutePresenter.lua, Chips.lua, ItemRow.lua et AltLines.lua.
-- S'inscrit par ns.MainFrame.addTab("route", …). Classement partagé (RouteResults), recalculé
-- à l'affichage de l'onglet après SP_PLAYER_CHANGED, SP_DATA_READY ou SP_PROFILE_CHANGED :
-- « calcul en cours » d'ici là ; rafraîchi sur SP_ROUTE_UPDATED ;
-- noms reçus du client : nouvelle présentation regroupée (NameAsker), sans recalcul ; noms
-- encore inconnus : nouvelle présentation toutes les RETRY_DELAY s, RETRY_MAX fois au plus.
-- Paliers passés (référence, grisés) repliés par défaut : clic sur l'en-tête, état gardé dans
-- StuffPlannerDB.ui.routePastOpen = {[min du palier] = true}. Puces Par emplacement / Meilleur gain sous
-- l'en-tête : tri dans chaque palier (StuffPlannerDB.ui.routeByGain).
-- Raids exclus. Clic sur une ligne de quête : fiche (QuestDetail) ; Maj+clic : repère ;
-- donjon, artisanat : fiche de la source (SourceDetail). Objet sélectionné : cadre (RowActions.mark).
-- Ligne d'objet : ns.ItemRow (ancrée en haut), survol = info-bulle de l'objet.
-- Alternatives plus faciles (AltLines) : bouton flèche à droite (gain à sa gauche), sous-lignes sous la
-- ligne, cadre de sélection sur la sous-ligne choisie ; état
-- déplié local (non gardé), par clé RoutePresenter expandKey.
-- Puces de session sous le tri (SessionPresenter.chips, SessionPlan.toggle) : Tout / 30 min / 1 h / 2 h,
-- puis Suivre la session ; budget choisi : liste de la session (SessionPlan.get, SessionPresenter.build)
-- à la place des paliers ; rafraîchi aussi sur SP_FOLLOW_CHANGED. Charger après SessionPlan.lua.

local _, ns = ...

local L = ns.L

local RETRY_DELAY, RETRY_MAX = 1, 10

local panel, header, sortBar, sessionBar, footer, scrollBox, emptyText
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

local function onToggle(key)
    expanded[key] = not expanded[key] or nil
    ns.MainFrame.refresh()
end

local onRowClick

-- Parties ancrées en haut : la ligne grandit vers le bas quand ses alternatives sont dépliées.
local function buildRow(button)
    local theme = ns.Theme
    local height = theme.spacing.rowHeight
    ns.ItemRow.build(button, {
        top = true, gainWidth = 1, markHeight = height,
        onClick = function(self)
            onRowClick(self)
        end,
    })
    ns.AltLines.build(button, onToggle)
    button.altToggle:SetPoint("RIGHT", button, "TOPRIGHT", -4, -height / 2)
    button.gain:ClearAllPoints()
    button.gain:SetWidth(0)
    button.gain:SetPoint("RIGHT", button.altToggle, "LEFT", -theme.spacing.gap, 0)
    button.title = button:CreateFontString(nil, "OVERLAY", theme.fonts.header)
    button.title:SetPoint("BOTTOMLEFT", 2, 4)
    setColor(button.title, theme.colors.title)
end

local function uiState()
    return ns.DB.account("ui")
end

local function pastOpen()
    local ui = uiState()
    ui.routePastOpen = ui.routePastOpen or {}
    return ui.routePastOpen
end

function onRowClick(button)
    if button.toggle then
        local open = pastOpen()
        open[button.toggle] = not open[button.toggle] or nil
        ns.MainFrame.refresh()
        return
    end
    if button.isHeader then
        return
    end
    local view = button.view
    ns.RowActions.click(view.questID, view.itemID, view.itemSource)
end

local function showParts(button, isHeader, toggle)
    button.title:SetShown(isHeader)
    button.icon:SetShown(not isHeader)
    button.name:SetShown(not isHeader)
    button.detail:SetShown(not isHeader)
    button.gain:SetShown(not isHeader)
    button.highlight:SetShown(not isHeader or toggle)
end

local function sourceLine(row)
    local slot = row.slotName and ns.Compat.GlobalString(row.slotName)
        or (row.slot and L.SLOT_FALLBACK:format(row.slot)) or ""
    local parts = { slot ~= "" and slot or nil }
    if row.tagText then
        parts[#parts + 1] = ns.Theme.colorize(row.tagText, row.tagColor)
    end
    if row.sourceText ~= "" then
        parts[#parts + 1] = row.sourceText
    end
    local text = table.concat(parts, " · ")
    if row.badge then
        text = text .. " · " .. ns.Theme.colorize(row.badge, row.badgeColor)
    end
    if row.noteText then
        text = text .. " · " .. row.noteText
    end
    if row.effortText then
        text = text .. " · " .. row.effortText
    end
    return text
end

local function initRow(button, row)
    if not button.icon then
        buildRow(button)
    end
    local isHeader = row.header == true
    showParts(button, isHeader, row.toggle ~= nil)
    button.isHeader, button.toggle = isHeader, row.toggle
    local theme = ns.Theme
    local muted = theme.colors.muted
    if isHeader then
        ns.ItemRow.set(button, { row = row })
        button.title:SetText(row.text)
        setColor(button.title, row.toggle and muted or theme.colors.title)
    else
        ns.ItemRow.set(button, {
            row = row, questID = row.questID, itemID = row.itemID, itemSource = row.source,
            icon = row.icon, muted = row.muted, name = row.name,
            nameColor = row.muted and muted or row.nameColor, detail = sourceLine(row),
            gain = row.gainLabel, gainColor = row.muted and muted or row.gainColor, hint = L.ROW_CLICK_HINT,
        })
    end
    ns.AltLines.render(button, isHeader and {} or row, theme.spacing.rowHeight,
        theme.spacing.iconSize + theme.spacing.gap + 2)
end

-- Noms demandés pour les lignes affichées (sous-lignes dépliées comprises).
local function askNames(rows)
    local missing = false
    local function ask(row)
        if row.itemID and not askName("item", row.itemID) then
            missing = true
        end
        if row.questID and not askName("quest", row.questID) then
            missing = true
        end
    end
    for _, row in ipairs(rows) do
        ask(row)
        for _, alt in ipairs(row.expanded and row.alternatives or {}) do
            ask(alt)
        end
    end
    scheduleRetry(missing)
    return rows
end

local function presentRows(tiers, budget, plan)
    if budget then
        return askNames(ns.SessionPresenter.build(plan, ns.Data, budget))
    end
    return tiers and askNames(ns.RoutePresenter.build(tiers, ns.Data, pastOpen(), expanded,
        uiState().routeByGain == true)) or {}
end

local function refresh()
    local tiers, info = ns.RouteResults.get()
    local message = not tiers and info or nil
    local budget = ns.SessionPlan.budget()
    local plan = budget and tiers and ns.SessionPlan.get(budget)
    message = message or (budget and L.SESSION_EMPTY) or nil
    local rows = presentRows(tiers, budget, plan)
    sessionBar:render(ns.SessionPresenter.chips(budget, plan, ns.SessionPlan.following()), function(key)
        ns.SessionPlan.toggle(key, plan)
        ns.MainFrame.refresh()
    end)
    header:SetText(L.ROUTE_HEADER)
    local byGain = uiState().routeByGain == true
    sortBar:render({
        { key = "slot", label = L.SORT_SLOT, active = not byGain },
        { key = "gain", label = L.SORT_GAIN, active = byGain },
    }, function(key)
        uiState().routeByGain = key == "gain"
        ns.MainFrame.refresh()
    end)
    footer:SetText(tiers and L.ROUTE_FOOTER:format(info) or "")
    scrollBox:SetDataProvider(CreateDataProvider(rows))
    emptyText:SetText(#rows == 0 and (message or L.ROUTE_EMPTY) or "")
end

local function create(parent)
    local theme = ns.Theme
    panel = CreateFrame("Frame", nil, parent)
    header = panel:CreateFontString(nil, "OVERLAY", theme.fonts.header)
    header:SetPoint("TOPLEFT")
    header:SetPoint("RIGHT")
    header:SetJustifyH("LEFT")
    sortBar = ns.Chips.new(panel)
    sortBar.frame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -theme.spacing.gap)
    sortBar.frame:SetPoint("RIGHT")
    sessionBar = ns.Chips.new(panel)
    sessionBar.frame:SetPoint("TOPLEFT", sortBar.frame, "BOTTOMLEFT", 0, -theme.spacing.gap)
    sessionBar.frame:SetPoint("RIGHT")
    footer = panel:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    footer:SetPoint("BOTTOMLEFT")
    footer:SetJustifyH("LEFT")
    setColor(footer, theme.colors.muted)
    scrollBox = CreateFrame("Frame", nil, panel, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", sessionBar.frame, "BOTTOMLEFT", 0, -theme.spacing.gap)
    scrollBox:SetPoint("BOTTOMRIGHT", -20, 18)
    local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtentCalculator(function(_, row)
        return theme.spacing.rowHeight + ns.AltLines.extra(row)
    end)
    view:SetElementInitializer("Button", initRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    emptyText = panel:CreateFontString(nil, "OVERLAY", theme.fonts.body)
    emptyText:SetPoint("CENTER", scrollBox, "CENTER")
    setColor(emptyText, theme.colors.muted)
    return panel
end

ns.MainFrame.addTab("route", {
    create = create, refresh = refresh, order = 2, label = L.TAB_ROUTE, icon = "Interface\\Icons\\INV_Misc_Book_09",
})

ns:On("SP_ROUTE_UPDATED", ns.MainFrame.refresh)
ns:On("SP_PLAYER_CHANGED", ns.MainFrame.refresh)
ns:On("SP_DATA_READY", ns.MainFrame.refresh)
ns:On("SP_PROFILE_CHANGED", ns.MainFrame.refresh)
ns:On("SP_FOLLOW_CHANGED", ns.MainFrame.refresh)

ns:On("SP_SELECTION_CHANGED", function()
    if scrollBox then
        scrollBox:ForEachFrame(function(button)
            ns.RowActions.mark(button, button.questID, button.itemID, ns.Theme.spacing.rowHeight)
            ns.AltLines.mark(button)
        end)
    end
end)
