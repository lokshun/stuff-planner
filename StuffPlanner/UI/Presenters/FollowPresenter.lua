-- CONTRAT
-- Contenu de la fenêtre des étapes du suivi (UI/FollowWindow.lua). Pur : aucun appel d'API.
-- Charger après RowPresenter.lua.
--   ns.FollowPresenter.build(view, data, ctx) -> {title, target = row | nil, lines = {line...}, first}
--     view = Follow.view() (FollowSteps.build) ; data = façade DataProvider (quest, item)
--     ctx = {mapID (zone du joueur), objective = function(questID) -> texte du 1er objectif non fini | nil,
--            player?, profile?} ; sans player ou profile : pas de cible
--     title = nom de la quête finale ; target = RowPresenter.present du meilleur objet de la quête finale
--       (récompenses et choix, Scoring.delta > 0)
--     line = {kind = "quest", questID, text, color (title si elle porte l'étape courante, sinon text)}
--          | {kind = "step", step (indice dans view.steps), questID, text, color, icon (texture | nil),
--             current (bool), clickable (étape placée, pas encore faite)}
--     texte d'étape : L.FOLLOW_PICKUP/OBJECTIVE/TURNIN (PNJ, objectif) ou variante _ANY ;
--       « · zone » si la zone diffère de ctx.mapID, « · lieu inconnu » sans position ; prise bloquée :
--       état entre parenthèses (RowPresenter.state). Faite : muted + coche ; courante : gain + flèche.
--     first = indice de la ligne de quête de l'étape courante (1 sans étape courante)

local _, ns = ...

local L = ns.L

local FollowPresenter = {}
ns.FollowPresenter = FollowPresenter

local SEPARATOR = " · "
FollowPresenter.ICONS = {
    done = "Interface\\RaidFrame\\ReadyCheck-Ready",
    current = "Interface\\ChatFrame\\ChatFrameExpandArrow",
}

local function bestTarget(quest, data, ctx)
    if not (ctx.player and ctx.profile) then
        return nil
    end
    local bestID, bestDelta
    for _, list in ipairs({ quest.rewards or {}, quest.choices or {} }) do
        for _, itemID in ipairs(list) do
            local delta = ns.Scoring.delta(itemID, ctx.player, ctx.profile, data)
            if delta and delta.abs > 0 and (not bestDelta or delta.abs > bestDelta.abs) then
                bestID, bestDelta = itemID, delta
            end
        end
    end
    if not bestID then
        return nil
    end
    return ns.RowPresenter.present({ itemID = bestID, delta = bestDelta }, data)
end

local function baseText(step, ctx)
    if step.kind == "objective" then
        local objective = ctx.objective and ctx.objective(step.questID)
        return objective and L.FOLLOW_OBJECTIVE:format(objective) or L.FOLLOW_OBJECTIVE_ANY
    end
    local name = step.npcID and ns.Names.npc(step.npcID)
    if step.kind == "pickup" then
        return name and L.FOLLOW_PICKUP:format(name) or L.FOLLOW_PICKUP_ANY
    end
    return name and L.FOLLOW_TURNIN:format(name) or L.FOLLOW_TURNIN_ANY
end

local function stepLine(index, step, data, ctx)
    local colors = ns.Theme.colors
    local text = baseText(step, ctx)
    if not step.mapID then
        text = text .. SEPARATOR .. L.FOLLOW_UNPLACED
    elseif step.mapID ~= ctx.mapID then
        text = text .. SEPARATOR .. ns.Names.zone(step.mapID)
    end
    if step.blocked then
        text = text .. " (" .. ns.RowPresenter.state(step.blocked, data.quest(step.questID)) .. ")"
    end
    local line = { kind = "step", step = index, questID = step.questID, text = text,
        current = step.state == "current", clickable = step.mapID ~= nil and step.state ~= "done" }
    if step.state == "done" then
        line.color, line.icon = colors.muted, FollowPresenter.ICONS.done
    elseif line.current then
        line.color, line.icon = colors.gain, FollowPresenter.ICONS.current
    else
        line.color = step.blocked and colors.muted or colors.text
    end
    return line
end

function FollowPresenter.build(view, data, ctx)
    local colors = ns.Theme.colors
    local final = data.quest(view.final)
    local out = {
        title = ns.Names.quest(view.final),
        target = final and bestTarget(final, data, ctx) or nil,
        lines = {},
        first = 1,
    }
    local currentQuest = view.current and view.steps[view.current].questID
    local lastQuest
    for index, step in ipairs(view.steps) do
        if step.questID ~= lastQuest then
            lastQuest = step.questID
            local isCurrent = step.questID == currentQuest
            out.lines[#out.lines + 1] = { kind = "quest", questID = step.questID,
                text = ns.Names.quest(step.questID), color = isCurrent and colors.title or colors.text }
            if isCurrent then
                out.first = #out.lines
            end
        end
        out.lines[#out.lines + 1] = stepLine(index, step, data, ctx)
    end
    return out
end
