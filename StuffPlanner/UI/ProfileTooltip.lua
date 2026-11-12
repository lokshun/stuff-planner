-- CONTRAT
-- Info-bulle d'une case de profil (ProfileGrid). Charger après Theme.lua.
--   ns.ProfileTooltip.show(owner, tip, hint?) : tip = ProfilePresenter.tooltip | nil ; titre, stats (valeur,
--     plafond entre parenthèses), « + n autres » ; hint (texte) en dernière ligne grisée. Rien sans tip ni hint.

local _, ns = ...

local L = ns.L

local ProfileTooltip = {}
ns.ProfileTooltip = ProfileTooltip

function ProfileTooltip.show(owner, tip, hint)
    if not tip and not hint then
        return
    end
    local colors = ns.Theme.colors
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if tip then
        GameTooltip:AddLine(tip.title, colors.title.r, colors.title.g, colors.title.b)
        for _, line in ipairs(tip.lines) do
            local right = line.capText ~= "" and line.valueText .. "  (" .. line.capText .. ")" or line.valueText
            GameTooltip:AddDoubleLine(line.label, right, colors.text.r, colors.text.g, colors.text.b,
                colors.muted.r, colors.muted.g, colors.muted.b)
        end
        if tip.more > 0 then
            GameTooltip:AddLine(L.PROFILE_TOOLTIP_MORE:format(tip.more), colors.muted.r, colors.muted.g,
                colors.muted.b)
        end
    end
    if hint then
        GameTooltip:AddLine(hint, colors.muted.r, colors.muted.g, colors.muted.b, true)
    end
    GameTooltip:Show()
end
