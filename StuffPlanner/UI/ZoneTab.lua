-- CONTRAT
-- Onglet « Zone actuelle » : améliorations de la zone (Chat.bestInZone, quêtes et butin des
-- instances dont l'entrée est sur la carte), filtres en puces, ScrollBox.
-- Charger après MainFrame.lua, Chat.lua, RowPresenter.lua et Filters.lua.
-- S'inscrit par ns.MainFrame.addTab("zone", …). Rafraîchi à l'ouverture et sur SP_RESULTS_UPDATED
-- (Results, après joueur, base ou profil changés) si la fenêtre est visible ; noms reçus du client : un
-- rafraîchissement regroupé (NAME_DELAY s). Filtres sauvegardés dans StuffPlannerDB.ui.zoneFilters.
-- Messages d'état (chargement, sans profil, zone inconnue, rien trouvé) au centre de la liste.
-- Clic sur une ligne : fiche de la quête (QuestDetail) ou de l'instance (SourceDetail) ;
-- Maj+clic : repère vers le donneur (quêtes) ;
-- Ctrl+clic : essayage (Compat.DressUpItem). Objet sélectionné (RowActions.select, mini-suivi compris) :
-- cadre de sélection, liste défilée jusqu'à lui si reveal (SP_SELECTION_CHANGED).
-- Survol : info-bulle de l'objet (gain ajouté par Tooltip.lua), états de la ligne et aide des clics.
-- Ligne : icône ; nom de l'objet puis emplacement · detailText (états colorés, quête) ; gainLabel seul à droite,
-- colonne de largeur fixe centrée en hauteur ; ligne grisée si dimmed.

local _, ns = ...

local L = ns.L

local MAX_ROWS = 100
local NAME_DELAY = 0.2
local UNKNOWN_ICON = 134400 -- point d'interrogation (FileDataID)
local GAIN_WIDTH = 70
local DIMMED_ALPHA = 0.5

local panel, header, chipBar, scrollBox, emptyText
local asked, refreshPending = {}, false
local lastShown

local function filterState()
    StuffPlannerDB = StuffPlannerDB or {}
    StuffPlannerDB.ui = StuffPlannerDB.ui or {}
    StuffPlannerDB.ui.zoneFilters = ns.Filters.new(StuffPlannerDB.ui.zoneFilters)
    return StuffPlannerDB.ui.zoneFilters
end

local function scheduleRefresh()
    if refreshPending then
        return
    end
    refreshPending = true
    C_Timer.After(NAME_DELAY, function()
        refreshPending = false
        ns.MainFrame.refresh()
    end)
end

local function askName(kind, id)
    local key = kind .. id
    if not asked[key] then
        asked[key] = true
        ns.Names.onReady(kind, id, scheduleRefresh)
    end
end

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

local function buildRow(button)
    local theme = ns.Theme
    local size = theme.spacing.iconSize
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(size, size)
    button.icon:SetPoint("LEFT", 2, 0)
    button.gain = button:CreateFontString(nil, "OVERLAY", theme.fonts.number)
    button.gain:SetPoint("RIGHT", -4, 0)
    button.gain:SetWidth(GAIN_WIDTH)
    button.gain:SetJustifyH("RIGHT")
    button.name = button:CreateFontString(nil, "OVERLAY", theme.fonts.body)
    button.name:SetPoint("TOPLEFT", button.icon, "TOPRIGHT", theme.spacing.gap, 1)
    button.name:SetPoint("RIGHT", button.gain, "LEFT", -theme.spacing.gap, 0)
    button.name:SetJustifyH("LEFT")
    button.name:SetWordWrap(false)
    button.source = button:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    button.source:SetPoint("BOTTOMLEFT", button.icon, "BOTTOMRIGHT", theme.spacing.gap, -1)
    button.source:SetJustifyH("LEFT")
    button.source:SetWordWrap(false)
    button.source:SetPoint("RIGHT", button.gain, "LEFT", -theme.spacing.gap, 0)
    setColor(button.source, theme.colors.muted)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)
end

local function showTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. button.itemID)
    local row = button.row
    if row.stateText ~= "" then
        GameTooltip:AddLine(row.stateText, row.stateColor.r, row.stateColor.g, row.stateColor.b)
    end
    if row.badge then
        GameTooltip:AddLine(row.badge, row.badgeColor.r, row.badgeColor.g, row.badgeColor.b)
    end
    GameTooltip:AddLine(L.ROW_CLICK_HINT, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function hideTooltip()
    GameTooltip:Hide()
end

local function onRowClick(button)
    ns.RowActions.click(button.questID, button.itemID, button.row and button.row.itemSource)
end

local function initRow(button, row)
    if not button.icon then
        buildRow(button)
        button:SetScript("OnClick", onRowClick)
        button:SetScript("OnEnter", showTooltip)
        button:SetScript("OnLeave", hideTooltip)
    end
    button.questID, button.itemID, button.row = row.questID, row.itemID, row
    ns.RowActions.mark(button, row.questID, row.itemID)
    button:SetAlpha(row.dimmed and DIMMED_ALPHA or 1)
    button.icon:SetTexture(row.icon or UNKNOWN_ICON)
    button.name:SetText(row.name)
    setColor(button.name, row.nameColor)
    button.gain:SetText(row.gainLabel)
    setColor(button.gain, row.gainColor)
    local slotName = row.slot and ns.GearPresenter.slotName(row.slot)
    local slot = slotName and ns.Compat.GlobalString(slotName) or (row.slot and L.SLOT_FALLBACK:format(row.slot))
    button.source:SetText(slot and (row.detailText ~= "" and (slot .. " · " .. row.detailText) or slot)
        or row.detailText)
end

-- Renvoie les lignes présentées, ou nil et le message d'état.
local function computeRows()
    local results, mapID = ns.Chat.currentZone(MAX_ROWS, true)
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

local function refresh()
    header:SetText("")
    local rows, message = computeRows()
    local state = filterState()
    local shown = rows and ns.Filters.apply(state, rows) or {}
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

local function create(parent)
    local theme = ns.Theme
    panel = CreateFrame("Frame", nil, parent)
    header = panel:CreateFontString(nil, "OVERLAY", theme.fonts.header)
    header:SetPoint("TOPLEFT")
    header:SetJustifyH("LEFT")
    chipBar = ns.Chips.new(panel)
    chipBar.frame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -theme.spacing.gap)
    chipBar.frame:SetPoint("RIGHT")
    scrollBox = CreateFrame("Frame", nil, panel, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", chipBar.frame, "BOTTOMLEFT", 0, -theme.spacing.gap)
    scrollBox:SetPoint("BOTTOMRIGHT", -20, 0)
    local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(theme.spacing.rowHeight)
    view:SetElementInitializer("Button", initRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    emptyText = panel:CreateFontString(nil, "OVERLAY", theme.fonts.body)
    emptyText:SetPoint("CENTER", scrollBox, "CENTER")
    setColor(emptyText, theme.colors.muted)
    return panel
end

ns.MainFrame.addTab("zone", { create = create, refresh = refresh })

ns:On("SP_RESULTS_UPDATED", ns.MainFrame.refresh)

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
    if reveal then
        revealSelection()
        -- Fenêtre tout juste ouverte : la liste n'a peut-être pas encore sa taille.
        C_Timer.After(0, revealSelection)
    end
end)
