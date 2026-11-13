-- CONTRAT
-- Lignes du Parcours et de la session (RoutePresenter.build, SessionPresenter.build) pour une ScrollBox :
-- en-têtes de palier ou de session, lignes d'objet (ns.ItemRow ancrée en haut), alternatives (AltLines).
-- Charger après ItemRow.lua et AltLines.lua.
--   ns.RouteRows.new(handlers) -> rows ; handlers = {expand(expandKey)?, tier(toggle)?} : bouton des
--     alternatives, clic sur un en-tête de palier repliable
--     rows.init(button, row) : initialiseur de ScrollBox ; rows.extent(row) -> hauteur (alternatives comprises)
--     rows.mark(button) : cadres de sélection (ligne et sous-lignes), sur SP_SELECTION_CHANGED
--   ns.RouteRows.sourceLine(row) -> « emplacement · tag · source · badge · note · durée »
--   ns.RouteRows.askNames(rows, askName) -> vrai si un nom d'objet ou de quête manque (NameAsker)
-- Ligne : clic = RowActions.click (fiche, Maj : lien, Ctrl : essayage), clic droit = menu ;
-- en-tête : titre doré (grisé s'il se replie), sans menu ; paliers passés : icône désaturée, textes grisés.

local _, ns = ...

local L = ns.L

local RouteRows = {}
ns.RouteRows = RouteRows

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

function RouteRows.sourceLine(row)
    local slot = row.slotName and ns.Compat.GlobalString(row.slotName)
        or (row.slot and L.SLOT_FALLBACK:format(row.slot)) or ""
    local parts = { slot ~= "" and slot or nil }
    if row.tagText then
        parts[#parts + 1] = ns.Theme.colorize(row.tagText, row.tagColor)
    end
    local origin = row.originText or row.sourceText
    if origin and origin ~= "" then
        parts[#parts + 1] = origin
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

local function showParts(button, isHeader, toggle)
    button.title:SetShown(isHeader)
    button.icon:SetShown(not isHeader)
    button.name:SetShown(not isHeader)
    button.detail:SetShown(not isHeader)
    button.gain:SetShown(not isHeader)
    if isHeader then
        button.gain2:Hide() -- ItemRow.setGains le remontre sur une ligne d'objet
    end
    button.highlight:SetShown(not isHeader or toggle)
end

-- Noms demandés pour les lignes affichées (sous-lignes dépliées comprises) ; vrai si un nom manque encore.
function RouteRows.askNames(rows, askName)
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
    return missing
end

function RouteRows.new(handlers)
    local rows = {}

    local function onClick(button)
        if button.toggle then
            if handlers.tier then
                handlers.tier(button.toggle)
            end
            return
        end
        local view = button.view
        if not button.isHeader and view then
            ns.RowActions.click(view.questID, view.itemID, view.itemSource)
        end
    end

    local function onExpand(key)
        if handlers.expand then
            handlers.expand(key)
        end
    end

    -- Parties ancrées en haut : la ligne grandit vers le bas quand ses alternatives sont dépliées.
    local function build(button)
        local theme = ns.Theme
        local height = theme.spacing.rowHeight
        ns.ItemRow.build(button, { top = true, gainWidth = 1, markHeight = height, onClick = onClick })
        ns.AltLines.build(button, onExpand)
        button.altToggle:SetPoint("RIGHT", button, "TOPRIGHT", -4, -height / 2)
        button.gain:SetWidth(0)
        button.gain2:SetWidth(0)
        ns.ItemRow.setGainAnchor(button, button.altToggle, "LEFT", -theme.spacing.gap, 0)
        button.title = button:CreateFontString(nil, "OVERLAY", theme.fonts.header)
        button.title:SetPoint("BOTTOMLEFT", 2, 4)
    end

    function rows.init(button, row)
        if not button.icon then
            build(button)
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
                nameColor = row.muted and muted or row.nameColor, detail = RouteRows.sourceLine(row),
                gain = row.gainLabel, gainColor = row.muted and muted or row.gainColor,
                gain2 = row.secondaryLabel, gain2Color = row.muted and muted or row.secondaryColor,
            })
        end
        ns.AltLines.render(button, isHeader and {} or row, theme.spacing.rowHeight,
            theme.spacing.iconSize + theme.spacing.gap + 2)
    end

    function rows.extent(row)
        return ns.Theme.spacing.rowHeight + ns.AltLines.extra(row)
    end

    function rows.mark(button)
        ns.RowActions.mark(button, button.questID, button.itemID, ns.Theme.spacing.rowHeight)
        ns.AltLines.mark(button)
    end

    return rows
end
