-- CONTRAT
-- Liste « Parcourir » de l'hôtel des ventes classique (Blizzard_AuctionUI, chargé à la demande), suite de
-- Compat.lua. Charger après Compat.lua. L'hôtel des ventes moderne (Blizzard_AuctionHouseUI : clés d'objet,
-- pas de liens par ligne) n'est pas pris en charge : aucune ligne, jamais d'erreur.
--   HasClassicAuctionHouse() -> bool : liste classique chargée (BrowseScrollFrame, GetAuctionItemLink)
--   EachAuctionButton(fn) -> fn(button, link | nil) pour les NUM_BROWSE_TO_DISPLAY lignes, onglet Parcourir
--     ouvert seulement ; button = « BrowseButtonNItem » ; ligne cachée : link nil ; objet n° défilement + N
--   HookAuctionUpdates(fn) -> fn() à AUCTION_ITEM_LIST_UPDATE et après AuctionFrameBrowse_Update
--     (défilement, page) ; accroché dès que Blizzard_AuctionUI est chargé (ADDON_LOADED), une seule fois

local _, ns = ...

local Compat = ns.Compat

local DEFAULT_ROWS = 8
local AUCTION_UI = "Blizzard_AuctionUI"
local BROWSE_UPDATE = "AuctionFrameBrowse_Update"

local function shown(frame)
    return frame ~= nil and frame:IsShown()
end

function Compat.HasClassicAuctionHouse()
    return _G.BrowseScrollFrame ~= nil and _G.GetAuctionItemLink ~= nil
end

function Compat.EachAuctionButton(fn)
    if not Compat.HasClassicAuctionHouse() or not (shown(_G.AuctionFrame) and shown(_G.AuctionFrameBrowse)) then
        return
    end
    local getOffset = _G.FauxScrollFrame_GetOffset
    local offset = getOffset and getOffset(_G.BrowseScrollFrame) or 0
    for row = 1, _G.NUM_BROWSE_TO_DISPLAY or DEFAULT_ROWS do
        local button = _G["BrowseButton" .. row .. "Item"]
        if button then
            local link = shown(_G["BrowseButton" .. row]) and _G.GetAuctionItemLink("list", offset + row) or nil
            fn(button, link)
        end
    end
end

function Compat.HookAuctionUpdates(fn)
    local hooked = false
    local function hook()
        if hooked or not (hooksecurefunc and _G[BROWSE_UPDATE]) then
            return
        end
        hooked = true
        hooksecurefunc(BROWSE_UPDATE, function()
            fn()
        end)
    end
    local events = CreateFrame("Frame")
    events:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
    events:RegisterEvent("ADDON_LOADED")
    events:SetScript("OnEvent", function(_, event, name)
        if event == "ADDON_LOADED" then
            if name == AUCTION_UI then
                hook()
            end
        else
            fn()
        end
    end)
    hook()
end
