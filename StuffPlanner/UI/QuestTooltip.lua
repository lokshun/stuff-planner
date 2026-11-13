-- CONTRAT
-- Info-bulle des quêtes listées dans la fiche (suite de quêtes, prérequis). Charger après Theme.lua,
-- avant QuestDetail.lua. Cadres seulement (GameTooltip, vérifié en jeu).
--   ns.QuestTooltip.show(owner, views) : views = {view...} (DetailPresenter.build), une section par
--     quête (alternatives séparées d'une ligne vide) : titre, niveau, état, condition, zone, instance,
--     badge, donneur, « Commence par », récompenses puis choix (icône, nom, gain) ; rien si views est vide
--   ns.QuestTooltip.hide()

local _, ns = ...

local L = ns.L

local QuestTooltip = {}
ns.QuestTooltip = QuestTooltip

local ICON = "|T%s:14:14|t "

local function addLine(text, color)
    if text and text ~= "" then
        color = color or ns.Theme.colors.text
        GameTooltip:AddLine(text, color.r, color.g, color.b, true)
    end
end

local function addItems(header, rows)
    if #rows == 0 then
        return
    end
    addLine(header, ns.Theme.colors.title)
    for _, row in ipairs(rows) do
        local left = (row.icon and ICON:format(row.icon) or "") .. row.name
        local name, gain = row.nameColor, row.gainColor or ns.Theme.colors.neutral
        GameTooltip:AddDoubleLine(left, row.gainLabel or "", name.r, name.g, name.b, gain.r, gain.g, gain.b)
    end
end

local function addView(view)
    local colors = ns.Theme.colors
    addLine(view.title, colors.title)
    addLine(view.levelText, colors.muted)
    addLine(view.stateText, view.stateColor)
    addLine(view.conditionText, colors.warning)
    addLine(view.zoneText, colors.muted)
    addLine(view.instanceText, colors.instance)
    addLine(view.badge, colors.warning)
    addLine(L.DETAIL_GIVER_HEADER, colors.title)
    addLine(view.giverText)
    addLine(view.startText, colors.gain)
    addItems(L.DETAIL_REWARDS, view.rewards)
    addItems(L.DETAIL_CHOICES, view.choices)
end

function QuestTooltip.show(owner, views)
    if #views == 0 then
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    for index, view in ipairs(views) do
        if index > 1 then
            GameTooltip:AddLine(" ")
        end
        addView(view)
    end
    GameTooltip:Show()
end

function QuestTooltip.hide()
    GameTooltip:Hide()
end
