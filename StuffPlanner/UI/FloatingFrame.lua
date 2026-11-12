-- CONTRAT
-- Cadre flottant déplaçable (fond de ns.Skin, position sauvegardée). Charger après Skin.lua et Options.lua.
--   ns.FloatingFrame.new(opts) -> frame
--     opts = {width, saved = function() -> table {point, relativePoint, x, y}, locked = clé ns.Options
--             (pas de glisser si vraie), default = {point, x, y}, alpha = opacité du fond}
--     frame.draggable(region) : glisser region déplace le cadre ; frame.resetPosition()
--   ns.FloatingFrame.hint(owner, text) ; ns.FloatingFrame.hideHint()

local _, ns = ...

local FloatingFrame = {}
ns.FloatingFrame = FloatingFrame

function FloatingFrame.new(opts)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetWidth(opts.width)
    frame:SetFrameStrata("LOW")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)

    local function restore()
        local saved = opts.saved()
        frame:ClearAllPoints()
        if saved.point then
            frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
        else
            frame:SetPoint(opts.default.point, UIParent, opts.default.point, opts.default.x, opts.default.y)
        end
    end

    local function stopMoving()
        frame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = frame:GetPoint()
        local saved = opts.saved()
        saved.point, saved.relativePoint, saved.x, saved.y = point, relativePoint, x, y
    end

    function frame.draggable(region)
        region:RegisterForDrag("LeftButton")
        region:SetScript("OnDragStart", function()
            if not ns.Options.get(opts.locked) then
                frame:StartMoving()
            end
        end)
        region:SetScript("OnDragStop", stopMoving)
    end

    function frame.resetPosition()
        local saved = opts.saved()
        saved.point, saved.relativePoint, saved.x, saved.y = nil, nil, nil, nil
        restore()
    end

    frame.draggable(frame)
    ns.Skin.panel(frame, { alpha = opts.alpha })
    restore()
    return frame
end

function FloatingFrame.hint(owner, text)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddLine(text, 1, 1, 1)
    GameTooltip:Show()
end

function FloatingFrame.hideHint()
    GameTooltip:Hide()
end
