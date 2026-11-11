-- CONTRAT
-- Prix d'hôtel des ventes lu dans un addon de prix, s'il y en a un (détection par fonctionnalité) :
-- Auctionator (API v1), puis TSM (valeur « dbmarket »). Sans addon de prix : nil partout, rien d'autre
-- ne change. Appels protégés (pcall) : une erreur de l'autre addon donne nil.
--   ns.Prices.source() -> "auctionator" | "tsm" | nil (premier addon de prix présent)
--   ns.Prices.get(link) -> prix en pièces de cuivre (> 0) | nil ; link = lien ou « item:id »

local ADDON, ns = ...

local Prices = {}
ns.Prices = Prices

local TSM_SOURCE = "dbmarket"

local function auctionatorApi()
    local auctionator = _G.Auctionator
    local api = auctionator and auctionator.API and auctionator.API.v1
    return api and api.GetAuctionPriceByItemLink and api or nil
end

local function tsmApi()
    local api = _G.TSM_API
    return api and api.GetCustomPriceValue and api.ToItemString and api or nil
end

local function positive(ok, value)
    return ok and type(value) == "number" and value > 0 and value or nil
end

local function fromAuctionator(link)
    local api = auctionatorApi()
    return api and positive(pcall(api.GetAuctionPriceByItemLink, ADDON, link)) or nil
end

local function fromTsm(link)
    local api = tsmApi()
    if not api then
        return nil
    end
    local ok, itemString = pcall(api.ToItemString, link)
    if not ok or not itemString then
        return nil
    end
    return positive(pcall(api.GetCustomPriceValue, TSM_SOURCE, itemString))
end

function Prices.source()
    if auctionatorApi() then
        return "auctionator"
    end
    return tsmApi() and "tsm" or nil
end

function Prices.get(link)
    if type(link) ~= "string" then
        return nil
    end
    return fromAuctionator(link) or fromTsm(link)
end
