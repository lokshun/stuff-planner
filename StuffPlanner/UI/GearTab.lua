-- CONTRAT
-- Onglet « Équipement » : objets portés et meilleure amélioration de chaque emplacement (zone, à défaut
-- palier courant du Parcours : RouteResults, calcul lancé à l'affichage) ; GearPresenter.
-- Charger après MainFrame.lua, Chat.lua, RouteResults.lua, GearPresenter.lua, Chips.lua, GearRows.lua.
-- S'inscrit par ns.MainFrame.addTab("gear", …). Rafraîchi à l'ouverture ; les messages
-- SP_PLAYER_CHANGED, SP_DATA_READY, SP_PROFILE_CHANGED, SP_ROUTE_UPDATED passent par ns.MainFrame.refresh.
-- En-tête : profil actif, résumé (GearPresenter.summary), puces Tous / Améliorations
--   (StuffPlannerDB.ui.gearOnlyUpgrades).
-- Lignes : UI/GearRows.lua (40 px, 56 avec une ligne raid, + alternatives dépliées : AltLines) ; état
-- déplié local (non gardé), par emplacement.
-- Objets portés absents de la base : stats lues par Compat.GetItemStats + StatParser.fromApi.

local _, ns = ...

local L = ns.L

local MAX_ZONE_ENTRIES = 100
local NAME_DELAY = 0.2
local expanded = {}

local profileText, summaryText, chipBar, footer, scrollBox
local asked, refreshPending = {}, false

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

local function uiState()
    StuffPlannerDB = StuffPlannerDB or {}
    StuffPlannerDB.ui = StuffPlannerDB.ui or {}
    return StuffPlannerDB.ui
end

-- Stats, qualité et icône des objets portés, lues en jeu.
local function readWorn(player)
    local worn = {}
    for slot, itemID in pairs(player.equipped or {}) do
        local link = GetInventoryItemLink("player", slot)
        local stats
        if link and not ns.Data.item(itemID) then
            stats = ns.StatParser.fromApi(ns.Compat.GetItemStats(link))
            stats = next(stats) and stats or nil
        end
        worn[slot] = {
            stats = stats,
            quality = GetInventoryItemQuality("player", slot),
            icon = GetInventoryItemTexture("player", slot),
        }
    end
    return worn
end

local function askNames(rows)
    for _, row in ipairs(rows) do
        if row.itemID then
            askName("item", row.itemID)
        end
        if row.upgrade then
            askName("item", row.upgrade.itemID)
            if row.upgrade.questID then
                askName("quest", row.upgrade.questID)
            end
        end
        if row.raid then
            askName("item", row.raid.itemID)
        end
        for _, alt in ipairs(row.expanded and row.alternatives or {}) do
            askName("item", alt.itemID)
            if alt.questID then
                askName("quest", alt.questID)
            end
        end
    end
end

local function profileLabel()
    local id = ns.Profiles.activeID()
    local option = id and ns.ProfilePresenter.options({ id }, ns.Profiles.get, id)[1]
    return option and option.label
end

local function refresh()
    local player = ns.Player.snapshot()
    local profile = ns.Profiles.active()
    local entries = ns.Chat.currentZone(MAX_ZONE_ENTRIES)
    ns.RouteResults.get()
    local route, alternatives = ns.RouteResults.current(player.level)
    local rows = ns.GearPresenter.build(player, profile, ns.Data, entries, readWorn(player), route, alternatives,
        expanded)
    askNames(rows)
    local summary = ns.GearPresenter.summary(rows)
    profileText:SetText(profile and profileLabel() or L.BEST_NO_PROFILE)
    summaryText:SetText(profile and summary.text or "")
    local ui = uiState()
    local only = ui.gearOnlyUpgrades == true and summary.count > 0
    chipBar:render({
        { key = "all", label = L.GEAR_FILTER_ALL:format(#rows), active = not only },
        { key = "upgrades", label = L.GEAR_FILTER_UPGRADES:format(summary.count), active = only },
    }, function(key)
        uiState().gearOnlyUpgrades = key == "upgrades"
        ns.MainFrame.refresh()
    end)
    scrollBox:SetDataProvider(CreateDataProvider(ns.GearPresenter.filter(rows, only)))
end

local function create(parent)
    local theme = ns.Theme
    local panel = CreateFrame("Frame", nil, parent)
    profileText = panel:CreateFontString(nil, "OVERLAY", theme.fonts.header)
    profileText:SetPoint("TOPLEFT")
    profileText:SetPoint("RIGHT")
    profileText:SetJustifyH("LEFT")
    summaryText = panel:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    summaryText:SetPoint("TOPLEFT", profileText, "BOTTOMLEFT", 0, -2)
    summaryText:SetPoint("RIGHT")
    summaryText:SetJustifyH("LEFT")
    setColor(summaryText, theme.colors.text)
    chipBar = ns.Chips.new(panel)
    chipBar.frame:SetPoint("TOPLEFT", summaryText, "BOTTOMLEFT", 0, -theme.spacing.gap)
    chipBar.frame:SetPoint("RIGHT")
    footer = panel:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    footer:SetPoint("BOTTOMLEFT")
    footer:SetPoint("RIGHT")
    footer:SetJustifyH("LEFT")
    footer:SetText(L.GEAR_CLICK_HINT)
    setColor(footer, theme.colors.muted)
    scrollBox = CreateFrame("Frame", nil, panel, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", chipBar.frame, "BOTTOMLEFT", 0, -theme.spacing.gap)
    scrollBox:SetPoint("BOTTOM", footer, "TOP", 0, theme.spacing.gap)
    scrollBox:SetPoint("RIGHT", -20, 0)
    local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtentCalculator(function(_, row)
        return ns.GearRows.baseHeight(row) + ns.AltLines.extra(row)
    end)
    ns.GearRows.onToggle(function(key)
        expanded[key] = not expanded[key] or nil
        ns.MainFrame.refresh()
    end)
    view:SetElementInitializer("Button", ns.GearRows.init)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    return panel
end

ns.MainFrame.addTab("gear", { create = create, refresh = refresh })
