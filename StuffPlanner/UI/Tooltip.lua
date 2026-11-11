-- CONTRAT
-- Lignes Stuff Planner dans les info-bulles d'objet (Compat.HookItemTooltip) : gain par rapport
-- à l'objet porté, 3 stats qui pèsent le plus, avertissement si stats estimées (TooltipPresenter).
-- Tout objet équipable : hors base (butin de monde) ou à suffixe aléatoire, stats lues par le lien
-- (LiveItem.fields, seulement si LiveItem.needed).
-- Charger après TooltipPresenter.lua, Scoring.lua, LiveItem.lua, Manager.lua et Results.lua.
-- Rien en combat, avant SP_DATA_READY, sans profil actif ni si le réglage tooltip.enabled est coupé.
-- Instantané partagé de ns.Results.player() : le cache de Scoring sert à l'info-bulle, à la zone et au Parcours.

local _, ns = ...

local DETAIL_INDENT = "  "

local function addLine(tooltip, text, color)
    tooltip:AddLine(text, color.r, color.g, color.b)
end

local function addLines(tooltip, itemID, link)
    if InCombatLockdown() or not ns.Data.ready() or not ns.Options.get("tooltip.enabled") then
        return
    end
    local profile, player = ns.Profiles.active(), ns.Results.player()
    if not (profile and player) then
        return
    end
    local live = ns.LiveItem.needed(itemID, link, ns.Data) and ns.LiveItem.fields(link) or nil
    local view = ns.TooltipPresenter.build(itemID, player, profile, ns.Data, live)
    if not view then
        return
    end
    addLine(tooltip, view.gain, view.gainColor)
    for _, text in ipairs(view.details) do
        addLine(tooltip, DETAIL_INDENT .. text, ns.Theme.colors.muted)
    end
    if view.warning then
        addLine(tooltip, DETAIL_INDENT .. view.warning, view.warningColor)
    end
    tooltip:Show()
end

ns.Compat.HookItemTooltip(addLines)
