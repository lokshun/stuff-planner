-- CONTRAT
-- Lignes Stuff Planner dans les info-bulles d'objet (Compat.HookItemTooltip) : gain par rapport
-- à l'objet porté, 3 stats qui pèsent le plus, avertissement si stats estimées (TooltipPresenter).
-- Charger après TooltipPresenter.lua, Scoring.lua et Manager.lua.
-- Rien en combat, avant SP_DATA_READY, sans profil actif ni si le réglage tooltip.enabled est coupé.
-- Instantané du joueur gardé jusqu'à SP_PLAYER_CHANGED : le cache de Scoring reste valable d'une info-bulle à l'autre.

local _, ns = ...

local DETAIL_INDENT = "  "

local player

local function snapshot()
    player = player or ns.Player.snapshot()
    return player
end

local function addLine(tooltip, text, color)
    tooltip:AddLine(text, color.r, color.g, color.b)
end

local function addLines(tooltip, itemID)
    if InCombatLockdown() or not ns.Data.ready() or not ns.Options.get("tooltip.enabled") then
        return
    end
    local profile = ns.Profiles.active()
    if not profile then
        return
    end
    local view = ns.TooltipPresenter.build(itemID, snapshot(), profile, ns.Data)
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

ns:On("SP_PLAYER_CHANGED", function()
    player = nil
end)

ns.Compat.HookItemTooltip(addLines)
