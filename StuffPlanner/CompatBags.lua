-- CONTRAT
-- Sacs du joueur : liens et boutons d'objet, qui diffèrent entre Forever et Classic Era (suite de
-- Compat.lua). Charger après Compat.lua. Sans l'API : réponse vide, jamais d'erreur.
--   GetContainerItemLink(bag, slot) -> lien | nil (C_Container, sinon fonction globale)
--   EachBagButton(fn) -> fn(button, bag, slot) pour chaque bouton d'objet des sacs ouverts :
--     sacs réunis (ContainerFrameCombinedBags), sacs séparés ContainerFrame1..MAX_FRAMES ;
--     cadre moderne : EnumerateValidItems et button:GetBagID() ; cadre classique : boutons
--     « <cadre>Item1..size », sac = cadre:GetID() ; emplacement = button:GetID()
--   HookBagUpdates(fn) -> fn() à BAG_UPDATE_DELAYED et après chaque mise à jour d'un cadre de sac
--     (ContainerFrame_Update, sinon UpdateItems des cadres) ; peut arriver en rafale : à regrouper.

local _, ns = ...

local Compat = ns.Compat

local MAX_FRAMES = 13
local COMBINED = "ContainerFrameCombinedBags"

local function frameAt(index)
    return _G["ContainerFrame" .. index]
end

function Compat.GetContainerItemLink(bag, slot)
    local getLink = (C_Container and C_Container.GetContainerItemLink) or _G.GetContainerItemLink
    return getLink and getLink(bag, slot) or nil
end

local function eachModern(frame, fn)
    for _, button in frame:EnumerateValidItems() do
        local bag = button.GetBagID and button:GetBagID() or nil
        if bag then
            fn(button, bag, button:GetID())
        end
    end
end

local function eachClassic(frame, fn)
    local name, bag = frame:GetName(), frame:GetID()
    for index = 1, frame.size or 0 do
        local button = _G[name .. "Item" .. index]
        if button then
            fn(button, bag, button:GetID())
        end
    end
end

local function eachIn(frame, fn)
    if not (frame and frame:IsShown()) then
        return
    end
    if frame.EnumerateValidItems then
        eachModern(frame, fn)
    elseif frame.GetName then
        eachClassic(frame, fn)
    end
end

function Compat.EachBagButton(fn)
    eachIn(_G[COMBINED], fn)
    for index = 1, MAX_FRAMES do
        eachIn(frameAt(index), fn)
    end
end

local function hookFrame(frame, fn)
    if frame and frame.UpdateItems then
        hooksecurefunc(frame, "UpdateItems", fn)
    end
end

local function hookFrames(fn)
    hookFrame(_G[COMBINED], fn)
    for index = 1, MAX_FRAMES do
        hookFrame(frameAt(index), fn)
    end
end

function Compat.HookBagUpdates(fn)
    local events = CreateFrame("Frame")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:SetScript("OnEvent", function()
        fn()
    end)
    if not hooksecurefunc then
        return
    end
    if _G.ContainerFrame_Update then
        hooksecurefunc("ContainerFrame_Update", function()
            fn()
        end)
    else
        hookFrames(fn)
    end
end
