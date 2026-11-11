-- CONTRAT
-- Cadre flottant déplaçable (fond du thème, filets dorés, position sauvegardée). Charger après Theme.lua
-- et Options.lua.
--   ns.FloatingFrame.new(opts) -> frame
--     opts = {width, saved = function() -> table {point, relativePoint, x, y}, locked = clé ns.Options
--             (pas de glisser si vraie), default = {point, x, y}, alpha = opacité du fond}
--     frame.draggable(region) : glisser region déplace le cadre ; frame.resetPosition()
--   ns.FloatingFrame.hint(owner, text) ; ns.FloatingFrame.hideHint()

local _, ns = ...

local FloatingFrame = {}
ns.FloatingFrame = FloatingFrame

local function border(frame, color)
    local size = ns.Theme.spacing.border
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" } }) do
        local edge = frame:CreateTexture(nil, "BORDER")
        edge:SetColorTexture(color.r, color.g, color.b, 0.8)
        edge:SetHeight(size)
        edge:SetPoint(side[1])
        edge:SetPoint(side[2])
    end
end

function FloatingFrame.new(opts)
    local theme = ns.Theme
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
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    local bg = theme.colors.background
    background:SetColorTexture(bg.r, bg.g, bg.b, opts.alpha)
    border(frame, theme.colors.border)
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
