-- CONTRAT
-- Pastilles de gain (ItemBadge) sur les objets en vente chez le marchand ouvert. Charger après ItemBadge.lua.
-- Boutons MerchantItem1..MAX_BUTTONS « ItemButton » ; page affichée = MerchantFrame.page, objet n° (page - 1)
-- × MERCHANT_ITEMS_PER_PAGE + i (GetMerchantItemLink) ; onglet de rachat (selectedTab 2) : pastilles retirées.
-- Parcours demandé à MERCHANT_SHOW, MERCHANT_UPDATE et après MerchantFrame_UpdateMerchantInfo /
-- MerchantFrame_UpdateBuybackInfo (changement de page ou d'onglet) ; regroupé par ItemBadge.scheduler.
-- Option badges.merchant coupée : pastilles du marchand retirées, plus de parcours.
--   ns.MerchantBadges.scan() : parcours immédiat (tests)

local _, ns = ...

local MerchantBadges = {}
ns.MerchantBadges = MerchantBadges

local OPTION = "badges.merchant"
local MAX_BUTTONS = 12 -- 10 objets par page, 12 au rachat
local DEFAULT_PER_PAGE = 10
local BUYBACK_TAB = 2

local function buttonAt(index)
    return _G["MerchantItem" .. index .. "ItemButton"]
end

local function hideAll()
    for index = 1, MAX_BUTTONS do
        local button = buttonAt(index)
        if button then
            ns.ItemBadge.hide(button)
        end
    end
end

local function linkAt(index)
    local getLink = _G.GetMerchantItemLink
    return getLink and getLink(index) or nil
end

function MerchantBadges.scan()
    local frame = _G.MerchantFrame
    if not (frame and frame:IsShown()) or not ns.Options.get(OPTION) then
        return
    end
    if frame.selectedTab == BUYBACK_TAB then
        hideAll()
        return
    end
    local perPage = _G.MERCHANT_ITEMS_PER_PAGE or DEFAULT_PER_PAGE
    local first = ((frame.page or 1) - 1) * perPage
    for index = 1, MAX_BUTTONS do
        local button = buttonAt(index)
        if button then
            if index <= perPage then
                ns.ItemBadge.show(button, linkAt(first + index))
            else
                ns.ItemBadge.hide(button)
            end
        end
    end
end

local schedule = ns.ItemBadge.scheduler(MerchantBadges.scan)

local function request()
    if ns.Options.get(OPTION) then
        schedule()
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("MERCHANT_UPDATE")
events:SetScript("OnEvent", request)

if hooksecurefunc then
    for _, name in ipairs({ "MerchantFrame_UpdateMerchantInfo", "MerchantFrame_UpdateBuybackInfo" }) do
        if _G[name] then
            hooksecurefunc(name, request)
        end
    end
end

ns:On("SP_OPTION_CHANGED", function(key, value)
    if key ~= OPTION then
        return
    end
    if value then
        request()
    else
        hideAll()
    end
end)
