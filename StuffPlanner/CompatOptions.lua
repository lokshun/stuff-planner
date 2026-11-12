-- CONTRAT
-- Suite de ns.Compat : panneau dans Échap > Options > AddOns. Charger après Compat.lua.
-- Détection par fonctionnalité ; API absente : nil ou false, jamais d'erreur.
--   RegisterOptionsPanel(frame, title) -> handle | nil : Settings.RegisterCanvasLayoutCategory +
--     Settings.RegisterAddOnCategory, sinon InterfaceOptions_AddCategory (frame.name = title)
--   OpenOptionsPanel(handle) -> bool : Settings.OpenToCategory(ID), sinon
--     InterfaceOptionsFrame_OpenToCategory (appelé deux fois : le premier appel ne déroule pas la liste)
--     Le client rouvre le menu du jeu (GameMenuFrame) en fermant le panneau : s'il était fermé à
--     l'ouverture par l'addon, il est refermé à l'image suivante (crochet OnHide posé une fois).
--   OnOptionsClosed(handle, fn) -> bool : fn() à chaque fermeture du panneau du client (SettingsPanel ou
--     InterfaceOptionsFrame, selon handle) ; faux sans panneau

local _, ns = ...

local Compat = ns.Compat

local function settingsApi()
    local api = _G.Settings
    if type(api) == "table" and type(api.RegisterCanvasLayoutCategory) == "function"
        and type(api.RegisterAddOnCategory) == "function" then
        return api
    end
    return nil
end

function Compat.RegisterOptionsPanel(frame, title)
    local api = settingsApi()
    if api then
        local category = api.RegisterCanvasLayoutCategory(frame, title)
        api.RegisterAddOnCategory(category)
        return { category = category }
    end
    local add = _G.InterfaceOptions_AddCategory
    if type(add) == "function" then
        frame.name = title
        add(frame)
        return { frame = frame }
    end
    return nil
end

local closeMenu = false
local hooked = {}

local function onPanelHide()
    if not closeMenu then
        return
    end
    closeMenu = false
    C_Timer.After(0, function()
        local menu = _G.GameMenuFrame
        if menu and menu:IsShown() and type(_G.HideUIPanel) == "function" then
            _G.HideUIPanel(menu)
        end
    end)
end

local function watchClose(container)
    if type(container) ~= "table" or type(container.HookScript) ~= "function" then
        return
    end
    if not hooked[container] then
        hooked[container] = true
        container:HookScript("OnHide", onPanelHide)
    end
    local menu = _G.GameMenuFrame
    closeMenu = not (menu and menu:IsShown())
end

function Compat.OpenOptionsPanel(handle)
    if not handle then
        return false
    end
    local api = settingsApi()
    if handle.category and api and type(api.OpenToCategory) == "function" then
        local category = handle.category
        local id = type(category.GetID) == "function" and category:GetID() or category.ID
        watchClose(_G.SettingsPanel)
        api.OpenToCategory(id)
        return true
    end
    local open = _G.InterfaceOptionsFrame_OpenToCategory
    if handle.frame and type(open) == "function" then
        watchClose(_G.InterfaceOptionsFrame)
        open(handle.frame)
        open(handle.frame)
        return true
    end
    return false
end

function Compat.OnOptionsClosed(handle, fn)
    local container = handle and (handle.category and _G.SettingsPanel or handle.frame and _G.InterfaceOptionsFrame)
    if type(container) ~= "table" or type(container.HookScript) ~= "function" then
        return false
    end
    container:HookScript("OnHide", fn)
    return true
end
