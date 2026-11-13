-- CONTRAT
-- Lignes et puces de la session de jeu (page Maintenant). Pur : aucun appel d'API. Charger après
-- RowPresenter.lua et GearPresenter.lua ; lit ns.SessionPlan.BUDGETS à l'appel.
--   ns.SessionPresenter.build(plan, data, budget) -> {row...} : {} sans objectif ; sinon en-tête
--     {header = true, text = L.SESSION_HEADER (nombre, durée du plan, budget ; Format.duration)}, puis un
--     objectif par ligne : RowPresenter.present + slot, slotName, source, questID (quête),
--     name = L.SESSION_ORDER (rang, nom), effortText = Format.duration(objective.seconds) (trajet compris)
--   ns.SessionPresenter.chips(budget) -> {{key, label, active}...} : segment "all" (L.SESSION_ALL : la zone,
--     active sans budget), puis un par budget (L.SESSION_30, _60, _120)
--   ns.SessionPresenter.follow(budget, plan, following) -> {key = "follow", label (L.SESSION_FOLLOW, ou
--     L.SESSION_STOP si following), active = following} quand le plan a une quête ou qu'une session est suivie ;
--     nil sinon

local _, ns = ...

local L = ns.L

local SessionPresenter = {}
ns.SessionPresenter = SessionPresenter

local LABELS = { [1800] = "SESSION_30", [3600] = "SESSION_60", [7200] = "SESSION_120" }

local function objectiveRow(index, objective, data)
    local entry = objective.row
    local row = ns.RowPresenter.present(entry, data)
    row.slot = entry.delta and entry.delta.slot
    row.slotName = row.slot and ns.GearPresenter.slotName(row.slot)
    row.source = entry.source
    if entry.source and entry.source.type == "quest" then
        row.questID = entry.source.id
    end
    row.name = L.SESSION_ORDER:format(index, row.name)
    row.effortText = ns.Format.duration(objective.seconds)
    return row
end

function SessionPresenter.build(plan, data, budget)
    if not plan or #plan.objectives == 0 then
        return {}
    end
    local rows = { {
        header = true,
        text = L.SESSION_HEADER:format(#plan.objectives, ns.Format.duration(plan.seconds) or "",
            ns.Format.duration(budget) or ""),
    } }
    for i, objective in ipairs(plan.objectives) do
        rows[#rows + 1] = objectiveRow(i, objective, data)
    end
    return rows
end

local function hasQuest(plan)
    for _, objective in ipairs(plan and plan.objectives or {}) do
        local source = objective.row.source
        if source and source.type == "quest" then
            return true
        end
    end
    return false
end

function SessionPresenter.chips(budget)
    local chips = { { key = "all", label = L.SESSION_ALL, active = budget == nil } }
    for _, seconds in ipairs(ns.SessionPlan.BUDGETS) do
        chips[#chips + 1] = { key = seconds, label = L[LABELS[seconds]], active = budget == seconds }
    end
    return chips
end

function SessionPresenter.follow(budget, plan, following)
    if following or (budget and hasQuest(plan)) then
        return { key = "follow", label = following and L.SESSION_STOP or L.SESSION_FOLLOW, active = following == true }
    end
    return nil
end
