-- CONTRAT
-- Onglet « Parcours 1-60 » : meilleur objet par emplacement et par palier de niveau
-- (RouteResults, RoutePresenter), ScrollBox avec en-têtes de palier. Charger après MainFrame.lua,
-- RouteResults.lua et RoutePresenter.lua.
-- S'inscrit par ns.MainFrame.addTab("route", …). Classement partagé (RouteResults), recalculé
-- à l'affichage de l'onglet après SP_PLAYER_CHANGED, SP_DATA_READY ou SP_PROFILE_CHANGED :
-- « calcul en cours » d'ici là ; rafraîchi sur SP_ROUTE_UPDATED ;
-- noms reçus du client : nouvelle présentation regroupée (NAME_DELAY s), sans recalcul ; noms
-- encore inconnus : nouvelle présentation toutes les RETRY_DELAY s, RETRY_MAX fois au plus.
-- Raids exclus. Clic sur une ligne de quête : fiche (QuestDetail) ; Maj+clic : repère ;
-- donjon, artisanat : fiche de la source (SourceDetail). Objet sélectionné : cadre (RowActions.mark).

local _, ns = ...

local L = ns.L

local NAME_DELAY = 0.2
local RETRY_DELAY, RETRY_MAX = 1, 10
local UNKNOWN_ICON = 134400 -- point d'interrogation (FileDataID)

local panel, header, footer, scrollBox, emptyText
local asked, refreshPending = {}, false
local retries, retryPending = 0, false

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
    return ns.Names.isKnown(kind, id)
end

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

local function buildRow(button)
    local theme = ns.Theme
    local size = theme.spacing.iconSize
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(size, size)
    button.icon:SetPoint("LEFT", 2, 0)
    button.gain = button:CreateFontString(nil, "OVERLAY", theme.fonts.number)
    button.gain:SetPoint("RIGHT", -4, 0)
    button.name = button:CreateFontString(nil, "OVERLAY", theme.fonts.body)
    button.name:SetPoint("TOPLEFT", button.icon, "TOPRIGHT", theme.spacing.gap, 1)
    button.name:SetPoint("RIGHT", button.gain, "LEFT", -theme.spacing.gap, 0)
    button.name:SetJustifyH("LEFT")
    button.name:SetWordWrap(false)
    button.source = button:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    button.source:SetPoint("BOTTOMLEFT", button.icon, "BOTTOMRIGHT", theme.spacing.gap, -1)
    button.source:SetPoint("RIGHT", button.gain, "LEFT", -theme.spacing.gap, 0)
    button.source:SetJustifyH("LEFT")
    button.source:SetWordWrap(false)
    setColor(button.source, theme.colors.muted)
    button.title = button:CreateFontString(nil, "OVERLAY", theme.fonts.header)
    button.title:SetPoint("BOTTOMLEFT", 2, 4)
    setColor(button.title, theme.colors.title)
    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetAllPoints()
    button.highlight:SetColorTexture(1, 1, 1, 0.08)
end

local function onRowClick(button)
    ns.RowActions.click(button.questID, button.itemID, button.itemSource)
end

local function showParts(button, isHeader)
    button.title:SetShown(isHeader)
    button.icon:SetShown(not isHeader)
    button.name:SetShown(not isHeader)
    button.source:SetShown(not isHeader)
    button.gain:SetShown(not isHeader)
    button.highlight:SetShown(not isHeader)
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
    return text
end

local function initRow(button, row)
    if not button.icon then
        buildRow(button)
        button:SetScript("OnClick", onRowClick)
    end
    showParts(button, row.header == true)
    button.questID, button.itemID, button.itemSource = row.questID, row.itemID, row.source
    ns.RowActions.mark(button, row.questID, row.itemID)
    if row.header then
        button.title:SetText(row.text)
        return
    end
    button.icon:SetTexture(row.icon or UNKNOWN_ICON)
    button.name:SetText(row.name)
    setColor(button.name, row.nameColor)
    button.gain:SetText(row.gainLabel)
    setColor(button.gain, row.gainColor)
    button.source:SetText(sourceLine(row))
end

local function presentRows(result)
    local rows = ns.RoutePresenter.build(result, ns.Data)
    local missing = false
    for _, row in ipairs(rows) do
        if row.itemID and not askName("item", row.itemID) then
            missing = true
        end
        if row.questID and not askName("quest", row.questID) then
            missing = true
        end
    end
    scheduleRetry(missing)
    return rows
end

local function refresh()
    local tiers, info = ns.RouteResults.get()
    local message = not tiers and info or nil
    local rows = tiers and presentRows(tiers) or {}
    header:SetText(L.ROUTE_HEADER)
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
    footer = panel:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    footer:SetPoint("BOTTOMLEFT")
    footer:SetJustifyH("LEFT")
    setColor(footer, theme.colors.muted)
    scrollBox = CreateFrame("Frame", nil, panel, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -theme.spacing.gap)
    scrollBox:SetPoint("BOTTOMRIGHT", -20, 18)
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

ns.MainFrame.addTab("route", { create = create, refresh = refresh })

ns:On("SP_ROUTE_UPDATED", ns.MainFrame.refresh)
ns:On("SP_PLAYER_CHANGED", ns.MainFrame.refresh)
ns:On("SP_DATA_READY", ns.MainFrame.refresh)
ns:On("SP_PROFILE_CHANGED", ns.MainFrame.refresh)

ns:On("SP_SELECTION_CHANGED", function()
    if scrollBox then
        scrollBox:ForEachFrame(function(button)
            ns.RowActions.mark(button, button.questID, button.itemID)
        end)
    end
end)
