-- CONTRAT
-- Deux sections de la page Profil, reprises de l'ancienne page Journal : « Progression » (ns.HistoryChart : score
-- par niveau, dernières améliorations ; clé ui.journalProgress, ouverte par défaut) et « Autres personnages »
-- (AltListPresenter : personnages du royaume et objets échangeables des sacs qui leur iraient ; clé
-- ui.journalAlts, repliée par défaut). Cadres seulement. Charger après MainFrame.lua, Section.lua, ItemRow.lua,
-- HistoryChart.lua, AltListPresenter.lua, Alts.lua, LiveItem.lua, avant ProfileTab.lua.
--   ns.JournalSections.PROGRESS -> spec de la section Progression (ns.Section)
--   ns.JournalSections.create(parent) -> {{spec, title, body, render}...} : corps à placer par l'appelant
--     (TOPLEFT, largeur du parent) ; render() -> hauteur du corps (pixels)
-- Affichage de parent : History.record(). Commande /splan journal : Profil déroulé sur Progression
-- (MainFrame.show("journal")), ou fermeture si Profil est déjà affiché. Rafraîchi par ns.MainFrame.refresh sur
-- SP_HISTORY_CHANGED, SP_PROFILE_CHANGED et BAG_UPDATE_DELAYED (Autres personnages affichée).
-- Objets : clic = source, clic droit = menu.

local _, ns = ...

local L = ns.L

local JournalSections = {}
ns.JournalSections = JournalSections

local PROGRESS = { key = "journalProgress", open = true }
local ALTS = { key = "journalAlts" }
JournalSections.PROGRESS = PROGRESS

local ROW_HEIGHT = 24
local NOTE_HEIGHT = 30
local TRADEABLE = { [0] = true, [2] = true }
local ROW_OPTS = { iconSize = 18, compact = true, nameWidth = 180, gainWidth = 90, height = ROW_HEIGHT }

local chart, altsBody, note
local rowButtons = {}

local askName = ns.NameAsker.new(function()
    ns.MainFrame.refresh()
end)

local function className(token)
    local names = _G.LOCALIZED_CLASS_NAMES_MALE
    return names and names[token] or token or ""
end

local function classColor(token)
    local colors = _G.RAID_CLASS_COLORS
    return colors and colors[token] or ns.Theme.colors.title
end

local function setRow(button, row)
    if row.alt then
        ns.ItemRow.set(button, { row = row, name = row.name, nameColor = classColor(row.class),
            detail = row.detail, detailColor = ns.Theme.colors.muted, gain = row.gain,
            gainColor = ns.Theme.colors.muted })
    else
        ns.ItemRow.set(button, row)
    end
    button.icon:SetShown(not row.alt)
end

local function bagItems()
    local items = {}
    ns.Compat.EachBagItem(function(link, bag, slot)
        local itemID = tonumber(link:match("item:(%d+)"))
        if itemID and TRADEABLE[ns.Compat.GetBindType(link) or -1]
            and not ns.Compat.IsContainerItemBound(bag, slot) then
            local live = ns.LiveItem.needed(itemID, link, ns.Data) and ns.LiveItem.fields(link) or nil
            local fields = live or ns.Data.item(itemID)
            if fields then
                items[#items + 1] = { itemID = itemID, fields = fields }
            end
        end
    end)
    return items
end

local function renderProgress()
    if not ns.Data.ready() then
        return 0
    end
    return ns.HistoryChart.refresh()
end

-- Lignes des autres personnages, sans défilement propre (la page Profil défile).
local function renderAlts()
    if not ns.Data.ready() then
        return 0
    end
    local view = ns.AltListPresenter.build(ns.Alts.others(), bagItems(), ns.Data, time(), className)
    for index, row in ipairs(view.rows) do
        if row.itemID then
            askName("item", row.itemID)
        end
        local button = rowButtons[index] or ns.ItemRow.new(altsBody, ROW_OPTS)
        rowButtons[index] = button
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", altsBody, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
        button:SetPoint("RIGHT", altsBody, "RIGHT")
        setRow(button, row)
        button:Show()
    end
    for index = #view.rows + 1, #rowButtons do
        rowButtons[index]:Hide()
    end
    local message = view.empty or view.note
    note:SetText(message or "")
    local height = #view.rows * ROW_HEIGHT + (message and NOTE_HEIGHT or 0)
    altsBody:SetHeight(math.max(1, height))
    return height
end

function JournalSections.create(parent)
    local theme = ns.Theme
    chart = ns.HistoryChart.create(parent)
    chart:SetWidth(parent:GetWidth())
    altsBody = CreateFrame("Frame", nil, parent)
    altsBody:SetWidth(parent:GetWidth())
    note = altsBody:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    note:SetPoint("BOTTOMLEFT")
    note:SetPoint("RIGHT")
    note:SetHeight(NOTE_HEIGHT)
    note:SetJustifyH("LEFT")
    note:SetTextColor(theme.colors.muted.r, theme.colors.muted.g, theme.colors.muted.b)
    parent:HookScript("OnShow", function()
        ns.History.record()
    end)
    ns.History.record()
    return {
        { spec = PROGRESS, title = L.JOURNAL_PROGRESS, body = chart, render = renderProgress },
        { spec = ALTS, title = L.ALTS_TITLE, body = altsBody, render = renderAlts },
    }
end

ns:On("SP_HISTORY_CHANGED", ns.MainFrame.refresh)
ns:On("SP_PROFILE_CHANGED", ns.MainFrame.refresh)

local events = CreateFrame("Frame")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:SetScript("OnEvent", function()
    if altsBody and altsBody:IsVisible() then
        ns.MainFrame.refresh()
    end
end)

ns:RegisterCommand("journal", function()
    if InCombatLockdown() then
        return
    end
    if ns.MainFrame.isShown() and ns.MainFrame.page() == "profile" then
        ns.MainFrame.hide()
    else
        ns.MainFrame.show("journal")
    end
end, "JOURNAL_COMMAND_HELP")

ns:On("SP_SELECTION_CHANGED", function()
    for _, button in ipairs(rowButtons) do
        if button:IsShown() then
            ns.RowActions.mark(button, button.questID, button.itemID)
        end
    end
end)
