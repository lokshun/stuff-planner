-- CONTRAT
-- Page « Maintenant » (clé zone) : améliorations de la zone (Chat.bestInZone, quêtes et butin des
-- instances dont l'entrée est sur la carte), filtres en puces, ScrollBox ; en tête, puces de session
-- (SessionPresenter.chips, SessionPlan.toggle) : Tout / 30 min / 1 h / 2 h, puis Suivre la session ;
-- budget choisi : liste de la session (SessionPlan.get, SessionPresenter.build, ns.RouteRows) à la place
-- de la zone, filtres et tri cachés ; rafraîchi aussi sur SP_ROUTE_UPDATED et SP_FOLLOW_CHANGED.
-- Charger après MainFrame.lua, Chat.lua, RowPresenter.lua, Filters.lua, ItemRow.lua, RouteRows.lua,
-- SessionPlan.lua et SessionPresenter.lua.
-- S'inscrit par ns.MainFrame.addTab("zone", …). Rafraîchi à l'ouverture et sur SP_RESULTS_UPDATED
-- (Results, après joueur, base ou profil changés) si la fenêtre est visible ; noms reçus du client : un
-- rafraîchissement regroupé (NameAsker). Filtres sauvegardés dans StuffPlannerDB.ui.zoneFilters.
-- Puces Meilleur gain (défaut) / Par emplacement (GearPresenter.sortBySlot, StuffPlannerDB.ui.zoneBySlot).
-- Messages d'état (chargement, sans profil, zone inconnue, rien trouvé) au centre de la liste.
-- Clic sur une ligne : fiche de la quête (QuestDetail) ou de l'instance (SourceDetail) ;
-- Maj+clic : repère vers le donneur (quêtes) ;
-- Ctrl+clic : essayage (Compat.DressUpItem). Objet sélectionné (RowActions.select, mini-suivi compris) :
-- cadre de sélection, liste défilée jusqu'à lui si reveal (SP_SELECTION_CHANGED).
-- Survol : info-bulle de l'objet (gain ajouté par Tooltip.lua), états de la ligne et aide des clics.
-- Ligne (ns.ItemRow) : icône ; nom de l'objet puis emplacement · detailText (états colorés, quête) ;
-- gainLabel seul à droite, colonne de largeur fixe centrée en hauteur ; ligne grisée si dimmed.

local _, ns = ...

local L = ns.L

local MAX_ROWS = 100

local panel, header, sessionBar, chipBar, sortBar, scrollBox, sessionScroll, emptyText
local lastShown

local function filterState()
    local ui = ns.DB.account("ui")
    ui.zoneFilters = ns.Filters.new(ui.zoneFilters)
    return ui.zoneFilters
end

local askName = ns.NameAsker.new(function()
    ns.MainFrame.refresh()
end)

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

local function stateLines(_, row)
    if row.stateText ~= "" then
        GameTooltip:AddLine(row.stateText, row.stateColor.r, row.stateColor.g, row.stateColor.b)
    end
    if row.badge then
        GameTooltip:AddLine(row.badge, row.badgeColor.r, row.badgeColor.g, row.badgeColor.b)
    end
end

local ROW_OPTS = { tooltip = stateLines }

local function detailOf(row)
    local slotName = row.slot and ns.GearPresenter.slotName(row.slot)
    local slot = slotName and ns.Compat.GlobalString(slotName) or (row.slot and L.SLOT_FALLBACK:format(row.slot))
    if not slot then
        return row.detailText
    end
    return row.detailText ~= "" and (slot .. " · " .. row.detailText) or slot
end

local function initRow(button, row)
    if not button.icon then
        ns.ItemRow.build(button, ROW_OPTS)
    end
    ns.ItemRow.set(button, {
        row = row, questID = row.questID, itemID = row.itemID, itemSource = row.itemSource,
        icon = row.icon, name = row.name, nameColor = row.nameColor, detail = detailOf(row),
        gain = row.gainLabel, gainColor = row.gainColor, dimmed = row.dimmed, hint = L.ROW_CLICK_HINT,
    })
end

-- Renvoie les lignes présentées, ou nil et le message d'état.
local function computeRows()
    local results, mapID = ns.Chat.currentZone(MAX_ROWS, true, true)
    if not results then
        return nil, mapID
    end
    header:SetText(L.ZONE_HEADER:format(ns.Names.zone(mapID)))
    local rows = {}
    for i, entry in ipairs(results) do
        askName("item", entry.itemID)
        if entry.questID then
            askName("quest", entry.questID)
        end
        rows[i] = ns.RowPresenter.resultRow(entry, ns.Data)
    end
    return rows, L.ZONE_EMPTY
end

local sessionRows = ns.RouteRows.new({})

local function renderSession(budget)
    local tiers, info = ns.RouteResults.get()
    local plan = tiers and ns.SessionPlan.get(budget)
    local rows = plan and ns.SessionPresenter.build(plan, ns.Data, budget) or {}
    ns.RouteRows.askNames(rows, askName)
    sessionScroll:SetDataProvider(CreateDataProvider(rows))
    emptyText:SetText(#rows == 0 and (not tiers and info or L.SESSION_EMPTY) or "")
    return plan
end

local function setMode(session)
    chipBar.frame:SetShown(not session)
    sortBar.frame:SetShown(not session)
    scrollBox:SetShown(not session)
    scrollBox.bar:SetShown(not session)
    sessionScroll:SetShown(session)
    sessionScroll.bar:SetShown(session)
end

local function refreshZone()
    local rows, message = computeRows()
    local state = filterState()
    local shown = rows and ns.Filters.apply(state, rows) or {}
    local ui = ns.DB.account("ui")
    if ui.zoneBySlot then
        shown = ns.GearPresenter.sortBySlot(shown)
    end
    sortBar:render({
        { key = "slot", label = L.SORT_SLOT, active = ui.zoneBySlot == true },
        { key = "gain", label = L.SORT_GAIN, active = not ui.zoneBySlot },
    }, function(key)
        ui.zoneBySlot = key == "slot" or nil
        ns.MainFrame.refresh()
    end)
    chipBar:render(rows and ns.Filters.chips(state, rows) or {}, function(key)
        ns.Filters.toggle(filterState(), key)
        ns.MainFrame.refresh()
    end)
    -- Liste inchangée : rien à reconstruire (la ligne survolée et son info-bulle restent).
    if not ns.RowPresenter.sameRows(lastShown, shown) then
        lastShown = shown
        scrollBox:SetDataProvider(CreateDataProvider(shown))
    end
    emptyText:SetText(#shown == 0 and message or "")
end

local function refresh()
    header:SetText("")
    local budget = ns.SessionPlan.budget()
    setMode(budget ~= nil)
    local plan
    if budget then
        plan = renderSession(budget)
    else
        refreshZone()
    end
    sessionBar:render(ns.SessionPresenter.chips(budget, plan, ns.SessionPlan.following()), function(key)
        ns.SessionPlan.toggle(key, plan)
        ns.MainFrame.refresh()
    end)
end

local function newScroll(anchor, extent, init)
    local theme = ns.Theme
    local box = CreateFrame("Frame", nil, panel, "WowScrollBoxList")
    box:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -theme.spacing.gap)
    box:SetPoint("BOTTOMRIGHT", -20, 0)
    box.bar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
    box.bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 6, 0)
    box.bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 6, 0)
    local view = CreateScrollBoxListLinearView()
    if type(extent) == "function" then
        view:SetElementExtentCalculator(function(_, row)
            return extent(row)
        end)
    else
        view:SetElementExtent(extent)
    end
    view:SetElementInitializer("Button", init)
    ScrollUtil.InitScrollBoxListWithScrollBar(box, box.bar, view)
    return box
end

local function create(parent)
    local theme = ns.Theme
    panel = CreateFrame("Frame", nil, parent)
    header = panel:CreateFontString(nil, "OVERLAY", theme.fonts.header)
    header:SetPoint("TOPLEFT")
    header:SetJustifyH("LEFT")
    sessionBar = ns.Chips.new(panel)
    sessionBar.frame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -theme.spacing.gap)
    sessionBar.frame:SetPoint("RIGHT")
    chipBar = ns.Chips.new(panel)
    chipBar.frame:SetPoint("TOPLEFT", sessionBar.frame, "BOTTOMLEFT", 0, -theme.spacing.gap)
    chipBar.frame:SetPoint("RIGHT")
    sortBar = ns.Chips.new(panel)
    sortBar.frame:SetPoint("TOPLEFT", chipBar.frame, "BOTTOMLEFT", 0, -theme.spacing.gap)
    sortBar.frame:SetPoint("RIGHT")
    scrollBox = newScroll(sortBar.frame, theme.spacing.rowHeight, initRow)
    sessionScroll = newScroll(sessionBar.frame, sessionRows.extent, sessionRows.init)
    emptyText = panel:CreateFontString(nil, "OVERLAY", theme.fonts.body)
    emptyText:SetPoint("CENTER", panel, "CENTER")
    setColor(emptyText, theme.colors.muted)
    return panel
end

ns.MainFrame.addTab("zone", {
    create = create, refresh = refresh, order = 1, label = L.TAB_NOW, icon = "Interface\\Icons\\INV_Misc_Map_01",
})

ns:On("SP_RESULTS_UPDATED", ns.MainFrame.refresh)
ns:On("SP_ROUTE_UPDATED", ns.MainFrame.refresh)
ns:On("SP_FOLLOW_CHANGED", ns.MainFrame.refresh)

local function isSelectedRow(row)
    return ns.RowActions.isSelected(row.questID, row.itemID)
end

local function revealSelection()
    if scrollBox and scrollBox.ScrollToElementDataByPredicate then
        scrollBox:ScrollToElementDataByPredicate(isSelectedRow, ScrollBoxConstants.AlignCenter,
            ScrollBoxConstants.NoScrollInterpolation)
    end
end

ns:On("SP_SELECTION_CHANGED", function(reveal)
    if not scrollBox then
        return
    end
    scrollBox:ForEachFrame(function(button)
        ns.RowActions.mark(button, button.questID, button.itemID)
    end)
    sessionScroll:ForEachFrame(sessionRows.mark)
    if reveal then
        revealSelection()
        -- Fenêtre tout juste ouverte : la liste n'a peut-être pas encore sa taille.
        C_Timer.After(0, revealSelection)
    end
end)
