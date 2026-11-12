-- CONTRAT
-- Onglet « Profil », contenu défilant (UIPanelScrollFrameTemplate, barre cachée quand tout tient) :
-- résumé du profil actif (ns.ProfileSummary ; « Modifier » ouvre « Mes stats » et y défile), puis
-- trois sections ns.Section repliables : choix du profil (ns.ProfileGrid, ouverte par défaut),
-- « Mes stats » (ns.PriorityList), réglages avancés (poids du profil actif en barres ns.WeightBars,
-- import/export d'une chaîne ProfileIO). Sections indépendantes.
-- Charger après MainFrame.lua, Profiles/Manager.lua, ProfileIO.lua, ProfilePresenter.lua,
-- PriorityList.lua, ProfileGrid.lua, ProfileSummary.lua et WeightBars.lua.
-- S'inscrit par ns.MainFrame.addTab("profile", …) ; rafraîchi par ns.MainFrame.refresh
-- (SP_PROFILE_CHANGED abonné par ZoneTab). Repli sauvegardé dans StuffPlannerDB.ui.profileGrid
-- (false = replié), profileStats et profileAdvanced (true = ouvert).

local _, ns = ...

local L = ns.L

local BUTTON_HEIGHT = 22
local SCROLLBAR_SPACE = 24
local IO_HEIGHT = 140 -- consigne, champ, boutons et message sous les barres
local STATS = { key = "profileStats" }

local scroll, content, summaryFrame
local sections = {}
local gridFrame, statsSection, advanced, barsFrame, ioBox, statusText

local function setColor(region, color)
    region:SetTextColor(color.r, color.g, color.b)
end

local function setStatus(text, color)
    statusText:SetText(text or "")
    if color then
        setColor(statusText, color)
    end
end

local function selectProfile(id)
    ns.Profiles.set(id)
    ns.MainFrame.refresh()
end

-- Info-bulle d'une case : nil = « Choix automatique », montré par le profil qu'il résout.
local function describeProfile(id)
    local auto = id == nil
    local profileID = auto and ns.Profiles.automaticID() or id
    return ns.ProfilePresenter.tooltip(profileID and ns.Profiles.get(profileID), auto)
end

-- Renommer / Supprimer du profil personnalisé actif, dans la grille.
local gridActions = {
    rename = function(id, text)
        local renamed = ns.Profiles.renameCustom(id, text)
        if renamed then
            ns.MainFrame.refresh()
        end
        return renamed
    end,
    delete = function(id)
        ns.Profiles.deleteCustom(id)
        ns.MainFrame.refresh()
    end,
    -- Clic droit : profil de comparaison ; sur le secondaire actuel, retiré ; profil actif refusé.
    secondary = function(id)
        if ns.Profiles.setSecondary(ns.Profiles.secondaryID() ~= id and id or nil) then
            ns.MainFrame.refresh()
        end
    end,
}

local function renderGrid()
    local grid = ns.ProfilePresenter.grid(ns.Profiles.available(), ns.Profiles.get,
        ns.Profiles.activeID(), ns.Profiles.manualID(), ns.Profiles.secondaryID())
    return ns.ProfileGrid.render(grid, selectProfile, describeProfile, gridActions)
end

local function renderStats()
    ns.PriorityList.refresh()
    return ns.PriorityList.HEIGHT
end

local function renderAdvanced()
    local profile = ns.Profiles.active()
    local barsHeight = ns.WeightBars.render(ns.ProfilePresenter.weightRows(profile))
    local height = ns.Theme.spacing.gap + barsHeight + IO_HEIGHT
    advanced:SetHeight(height)
    return height
end

local function refresh()
    local theme = ns.Theme
    local y = -(ns.ProfileSummary.render(ns.ProfilePresenter.summary(ns.Profiles.active())) + theme.spacing.gap)
    for _, section in ipairs(sections) do
        section.top = -y
        local open
        open, y = section.place(y)
        y = y - theme.spacing.gap
        section.body:SetShown(open)
        if open then
            section.body:ClearAllPoints()
            section.body:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            y = y - section.render() - theme.spacing.gap
        end
    end
    content:SetHeight(math.max(1, -y))
end

local function addSection(spec, title, body, render)
    spec.title = title
    local section = ns.Section.new(content, spec, refresh)
    section.key, section.body, section.render = spec.key, body, render
    sections[#sections + 1] = section
end

-- « Modifier » du résumé : ouvre « Mes stats » et fait défiler jusqu'à son en-tête.
local function editStats()
    ns.Section.setOpen(STATS, true)
    refresh()
    for _, section in ipairs(sections) do
        if section.key == "profileStats" then
            scroll:UpdateScrollChildRect()
            scroll:SetVerticalScroll(math.min(section.top, scroll:GetVerticalScrollRange()))
        end
    end
end

local function onImport()
    local profile, code, detail = ns.ProfileIO.decode(ioBox:GetText())
    if not profile then
        setStatus(ns.ProfilePresenter.importError(code, detail), ns.Theme.colors.loss)
        return
    end
    local base = profile.name or L.PROFILE_CUSTOM
    local name = ns.ProfilePresenter.newName(base, ns.Profiles.available(), ns.Profiles.get)
    if not ns.Profiles.saveCustom(nil, name, profile) then
        setStatus(L.PROFILE_ERR_FULL, ns.Theme.colors.loss)
        return
    end
    ioBox:ClearFocus()
    local ignored = ns.ProfilePresenter.ignoredText(profile.ignored)
    if ignored then
        setStatus(L.PROFILE_IMPORTED_IGNORED:format(ignored), ns.Theme.colors.warning)
    else
        setStatus(L.PROFILE_IMPORTED, ns.Theme.colors.gain)
    end
    ns.MainFrame.refresh()
end

local function onExport()
    local profile = ns.Profiles.active()
    if not profile then
        setStatus(L.BEST_NO_PROFILE, ns.Theme.colors.warning)
        return
    end
    ioBox:SetText(ns.ProfileIO.encode(profile))
    ioBox:SetFocus()
    ioBox:HighlightText()
    setStatus("")
end

local function button(parent, text, onClick)
    local result = ns.Skin.button(parent)
    result:SetText(text)
    result:SetSize(result:GetFontString():GetStringWidth() + 24, BUTTON_HEIGHT)
    result:SetScript("OnClick", onClick)
    return result
end

local function createAdvanced()
    local theme = ns.Theme
    advanced = CreateFrame("Frame", nil, content)
    advanced:SetWidth(content:GetWidth())
    barsFrame = ns.WeightBars.create(advanced)
    barsFrame:SetPoint("TOPLEFT")
    local hint = advanced:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    hint:SetPoint("TOPLEFT", barsFrame, "BOTTOMLEFT", 0, -theme.spacing.gap)
    hint:SetPoint("RIGHT")
    hint:SetJustifyH("LEFT")
    hint:SetText(L.PROFILE_IO_HINT)
    ioBox = CreateFrame("EditBox", nil, advanced, "InputBoxTemplate")
    ioBox:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 6, -theme.spacing.gap)
    ioBox:SetPoint("RIGHT", -4, 0)
    ioBox:SetHeight(24)
    ioBox:SetAutoFocus(false)
    ioBox:SetScript("OnEscapePressed", ioBox.ClearFocus)
    ioBox:SetScript("OnEnterPressed", onImport)
    local import = button(advanced, L.PROFILE_IMPORT, onImport)
    import:SetPoint("TOPLEFT", ioBox, "BOTTOMLEFT", -6, -theme.spacing.gap)
    local export = button(advanced, L.PROFILE_EXPORT, onExport)
    export:SetPoint("LEFT", import, "RIGHT", theme.spacing.gap, 0)
    statusText = advanced:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    statusText:SetPoint("TOPLEFT", import, "BOTTOMLEFT", 0, -theme.spacing.gap)
    statusText:SetPoint("RIGHT")
    statusText:SetJustifyH("LEFT")
end

local function create(parent)
    local panel = CreateFrame("Frame", nil, parent)
    scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR_SPACE, 0)
    scroll.scrollBarHideable = true
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(ns.WeightBars.WIDTH, 1)
    scroll:SetScrollChild(content)
    summaryFrame = ns.ProfileSummary.create(content, editStats)
    summaryFrame:SetPoint("TOPLEFT")
    gridFrame = ns.ProfileGrid.create(content)
    addSection({ key = "profileGrid", open = true }, L.PROFILE_HEADER, gridFrame, renderGrid)
    statsSection = ns.PriorityList.create(content)
    statsSection:SetSize(content:GetWidth(), ns.PriorityList.HEIGHT)
    addSection(STATS, L.PROFILE_MY_STATS, statsSection, renderStats)
    createAdvanced()
    addSection({ key = "profileAdvanced" }, L.PROFILE_ADVANCED, advanced, renderAdvanced)
    return panel
end

ns.MainFrame.addTab("profile", { create = create, refresh = refresh })
