-- CONTRAT
-- Bouton Repère / Suivre de la fiche de quête. Charger après DetailWidgets.lua, DetailPresenter.lua,
-- Integrations/TomTom.lua et Follow.lua.
--   ns.WaypointButton.new(parent) -> button (DetailWidgets.button) ; button:update(view) d'après
--     DetailPresenter.waypointButton(view, Follow.current(), repère placé) ; view nil : grisé
-- Clic, mode "follow" : Follow.start(view.questID) ou Follow.stop() si elle est suivie.
-- Clic, mode "waypoint" : repère vers view.waypoint (ns.Waypoint, clé = quête qui commence la suite,
--   sinon la quête) ou retrait du repère posé.

local _, ns = ...

local L = ns.L

local WaypointButton = {}
ns.WaypointButton = WaypointButton

-- Clé du repère : la quête qui commence la suite (view.waypoint.questID), sinon la quête elle-même.
local function markOf(view)
    return view.waypoint and view.waypoint.questID or view.questID
end

local function modeOf(view)
    return ns.DetailPresenter.waypointButton(view, ns.Follow.current(), ns.Waypoint.has(markOf(view)))
end

local function update(button, view)
    button.view = view
    if not view then
        button:SetText(L.DETAIL_WAYPOINT)
        button:SetEnabled(false)
        return
    end
    local mode = modeOf(view)
    button:SetText(mode.label)
    button:SetEnabled(mode.enabled)
end

local function click(button)
    local view = button.view
    if not view then
        return
    end
    if modeOf(view).mode == "follow" then
        if ns.Follow.current() == view.questID then
            ns.Follow.stop()
        else
            ns.Follow.start(view.questID)
        end
    elseif ns.Waypoint.has(markOf(view)) then
        ns.Waypoint.clear(markOf(view))
    elseif view.waypoint then
        local target = view.waypoint
        ns.Waypoint.set(target.mapID, target.x, target.y, target.title, target.questID, target.giver, target.npcID)
    end
    update(button, view)
end

function WaypointButton.new(parent)
    local button = ns.DetailWidgets.button(parent, L.DETAIL_UNFOLLOW)
    button.update = update
    button:SetScript("OnClick", click)
    return button
end
