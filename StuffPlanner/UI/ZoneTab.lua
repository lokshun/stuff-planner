-- CONTRAT
-- Page « Maintenant » (clé zone) : améliorations de la zone (Chat.bestInZone, quêtes et butin des
-- instances dont l'entrée est sur la carte), ScrollBox. Une barre : segment Zone / 30 min / 1 h / 2 h
-- (SessionPresenter.chips, SessionPlan.toggle) à gauche ; à droite bouton « Filtres (n) » (ns.FilterMenu :
-- filtres Filters.chips à cocher, tri) en mode zone, et bouton Suivre / Arrêter la session
-- (SessionPresenter.follow) ; budget choisi : liste de la session (SessionPlan.get, SessionPresenter.build,
-- ns.RouteRows) à la place de la zone ; rafraîchi aussi sur SP_ROUTE_UPDATED et SP_FOLLOW_CHANGED.
-- Charger après MainFrame.lua, Chat.lua, RowPresenter.lua, Filters.lua, ItemRow.lua, RouteRows.lua,
-- SessionPlan.lua, SessionPresenter.lua et FilterMenu.lua.
-- S'inscrit par ns.MainFrame.addTab("zone", …). Rafraîchi à l'ouverture et sur SP_RESULTS_UPDATED
-- (Results, après joueur, base ou profil changés) si la fenêtre est visible ; noms reçus du client : un
-- rafraîchissement regroupé (NameAsker). Filtres sauvegardés dans StuffPlannerDB.ui.zoneFilters.
-- Tri du menu : Meilleur gain (défaut) / Par emplacement (GearPresenter.sortBySlot, StuffPlannerDB.ui.zoneBySlot).
-- Messages d'état (chargement, sans profil, zone inconnue, rien trouvé) au centre de la liste.
-- Clic sur une ligne : fiche de la quête (QuestDetail) ou de l'instance (SourceDetail) ;
-- Maj+clic : lien dans la discussion ;
-- Ctrl+clic : essayage (Compat.DressUpItem). Objet sélectionné (RowActions.select, mini-suivi compris) :
-- cadre de sélection, liste défilée jusqu'à lui si reveal (SP_SELECTION_CHANGED).
-- Survol : info-bulle de l'objet (gain ajouté par Tooltip.lua), états de la ligne et aide des clics.
-- Ligne (ns.ItemRow) : icône ; nom de l'objet puis emplacement · detailText (états colorés, quête) ;
-- gainLabel seul à droite, colonne de largeur fixe centrée en hauteur ; ligne grisée si dimmed.

local _, ns = ...

local L = ns.L

local MAX_ROWS = 100

local panel, header, barRow, sessionBar, filterMenu, followButton, scrollBox, sessionScroll, emptyText
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
        gain = row.gainLabel, gainColor = row.gainColor, dimmed = row.dimmed,
        gain2 = row.secondaryLabel, gain2Color = row.secondaryColor,
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
    filterMenu:SetShown(not session)
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
    local chips = rows and ns.Filters.chips(state, rows) or {}
    local P = ns.FilterMenuPresenter
    filterMenu:update(P.label(chips), function()
        local current = rows and ns.Filters.chips(filterState(), rows) or {}
        return P.entries(current, P.sorts(ns.DB.account("ui").zoneBySlot and "slot" or "gain", { "gain", "slot" }))
    end, function(kind, value)
        if kind == "filter" then
            ns.Filters.toggle(filterState(), value)
        else
            ns.DB.account("ui").zoneBySlot = value == "slot" or nil
        end
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
    sessionBar:render(ns.SessionPresenter.chips(budget), function(key)
        ns.SessionPlan.toggle(key, plan)
        ns.MainFrame.refresh()
    end)
    local follow = ns.SessionPresenter.follow(budget, plan, ns.SessionPlan.following())
    followButton:SetShown(follow ~= nil)
    if follow then
        followButton:SetText(follow.label)
        followButton:SetWidth(followButton:GetFontString():GetStringWidth() + 24)
        followButton:ClearAllPoints()
        followButton:SetPoint("RIGHT", budget and barRow or filterMenu.button, budget and "RIGHT" or "LEFT",
            budget and 0 or -ns.Theme.spacing.gap, 0)
        followButton.plan = plan
    end
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
    barRow = CreateFrame("Frame", nil, panel)
    barRow:SetHeight(ns.Chips.HEIGHT)
    barRow:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -theme.spacing.gap)
    barRow:SetPoint("RIGHT")
    sessionBar = ns.Chips.new(barRow)
    sessionBar.frame:SetPoint("LEFT")
    filterMenu = ns.FilterMenu.new(barRow)
    filterMenu.button:SetPoint("RIGHT")
    followButton = ns.Skin.button(barRow)
    followButton:SetHeight(ns.Chips.HEIGHT)
    followButton:SetScript("OnClick", function(self)
        ns.SessionPlan.toggle("follow", self.plan)
        ns.MainFrame.refresh()
    end)
    followButton:Hide()
    scrollBox = newScroll(barRow, theme.spacing.rowHeight, initRow)
    sessionScroll = newScroll(barRow, sessionRows.extent, sessionRows.init)
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
