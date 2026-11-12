-- CONTRAT
-- Objets et info-bulles d'objet qui diffèrent entre Forever et Classic Era (suite de Compat.lua).
-- Charger après Compat.lua. Sans l'API : réponse vide, jamais d'erreur.
--   GetItemStats(link) -> {[apiKey]=value}, vide si inconnu
--   GetItemInfoInstant(item) -> {equipLoc, classID, subclassID} | nil (objet inconnu, API absente)
--   GetBindType(item) -> bindType de GetItemInfo (0 aucun, 1 ramassé, 2 équipé, 3 utilisé, 4 quête) | nil
--     (objet pas en cache, API absente)
--   GetItemCount(itemID) -> nombre (sacs, banque et objets portés), 0 sans l'API
--   GetTooltipLines(link) -> {string...}, texte de gauche, vide si objet pas encore en cache
--   HookItemTooltip(fn) -> fn(tooltip, itemID, link) à chaque info-bulle d'objet ; link : data.hyperlink,
--     sinon tooltip:GetItem(), nil possible
-- Classic Era : C_TooltipInfo y est vide et TooltipDataProcessor absent, d'où les replis.

local _, ns = ...

local Compat = ns.Compat

local MAX_SCAN_LINES = 30
local SCAN_TOOLTIP = "StuffPlannerScanTooltip"

local scanTooltip

function Compat.GetItemStats(link)
    local stats
    if C_Item and C_Item.GetItemStats then
        stats = C_Item.GetItemStats(link)
    elseif GetItemStats then
        stats = GetItemStats(link)
    end
    return stats or {}
end

function Compat.GetBindType(item)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not getInfo then
        return nil
    end
    return (select(14, getInfo(item)))
end

function Compat.GetItemCount(itemID)
    local getCount = (C_Item and C_Item.GetItemCount) or GetItemCount
    return getCount and getCount(itemID, true) or 0
end

function Compat.GetItemInfoInstant(item)
    local getInfo = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not getInfo then
        return nil
    end
    local itemID, _, _, equipLoc, _, classID, subclassID = getInfo(item)
    if not itemID then
        return nil
    end
    return { equipLoc = equipLoc, classID = classID, subclassID = subclassID }
end

-- Info-bulle nommée à modèle (global StuffPlannerScanTooltip) : un cadre anonyme à AddFontStrings
-- déversait ses lignes sous les info-bulles du jeu sur Classic Era (recette T5.5, 2026-11-03).
local function scanLines(link)
    scanTooltip = scanTooltip or CreateFrame("GameTooltip", SCAN_TOOLTIP, nil, "GameTooltipTemplate")
    scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTooltip:ClearLines()
    scanTooltip:SetHyperlink(link)
    local lines = {}
    for i = 1, math.min(scanTooltip:NumLines(), MAX_SCAN_LINES) do
        local left = _G[SCAN_TOOLTIP .. "TextLeft" .. i]
        local text = left and left:GetText()
        if text then
            lines[#lines + 1] = text
        end
    end
    scanTooltip:Hide()
    return lines
end

function Compat.GetTooltipLines(link)
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then
        return scanLines(link)
    end
    local lines = {}
    local data = C_TooltipInfo.GetHyperlink(link)
    for _, line in ipairs(data and data.lines or {}) do
        if line.leftText then
            lines[#lines + 1] = line.leftText
        end
    end
    return lines
end

local function hookScript(tooltip, fn)
    if not tooltip then
        return
    end
    tooltip:HookScript("OnTooltipSetItem", function(self)
        local _, link = self:GetItem()
        local itemID = link and tonumber(link:match("item:(%d+)"))
        if itemID then
            fn(self, itemID, link)
        end
    end)
end

local function tooltipLink(tooltip, data)
    if type(data.hyperlink) == "string" then
        return data.hyperlink
    end
    if type(tooltip) == "table" and type(tooltip.GetItem) == "function" then
        local _, link = tooltip:GetItem()
        return link
    end
    return nil
end

function Compat.HookItemTooltip(fn)
    if TooltipDataProcessor then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            if data and data.id then
                fn(tooltip, data.id, tooltipLink(tooltip, data))
            end
        end)
    else
        hookScript(GameTooltip, fn)
        hookScript(ItemRefTooltip, fn)
    end
end
