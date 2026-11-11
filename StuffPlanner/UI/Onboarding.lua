-- CONTRAT
-- Assistant de bienvenue en 3 étapes : présentation, choix du profil de poids, surfaces de l'addon.
-- Charger après Profiles/Manager.lua, ProfilePresenter.lua et Compat.lua.
--   ns.Onboarding.show() -> ouvre l'assistant à l'étape 1 (hors combat seulement)
-- Ouvert une fois par personnage, ONBOARD_DELAY s après PLAYER_LOGIN, hors combat ;
-- StuffPlannerCharDB.onboarded = true dès qu'il est fermé (Terminer, croix ou Échap).
-- Commande : /splan welcome. Étape 2 : boutons ns.Profiles.set ; message si la classe n'a pas de profil.

local _, ns = ...

local L = ns.L

local Onboarding = {}
ns.Onboarding = Onboarding

local WIDTH, HEIGHT = 400, 270
local STEPS = 3
local ONBOARD_DELAY = 3
local PORTRAIT = ns.ICON -- logo de l'addon
local BUTTON_WIDTH, BUTTON_HEIGHT = 170, 22
local MAX_OPTIONS = 6

local frame, stepText, bodyText, backButton, nextButton
local optionButtons = {}
local step = 1

local function markDone()
    ns.DB.char().onboarded = true
end

local function optionButton(index)
    local button = optionButtons[index]
    if not button then
        button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
        local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
        button:SetPoint("TOPLEFT", bodyText, "BOTTOMLEFT", column * (BUTTON_WIDTH + 8),
            -ns.Theme.spacing.gap - row * (BUTTON_HEIGHT + 4))
        optionButtons[index] = button
    end
    return button
end

local function renderOptions()
    local options = {}
    if step == 2 then
        local ids = ns.Profiles.available()
        options = ns.ProfilePresenter.options(ids, ns.Profiles.get, ns.Profiles.activeID())
    end
    for i = 1, math.min(#options, MAX_OPTIONS) do
        local option = options[i]
        local button = optionButton(i)
        button:SetText(option.label)
        button:SetEnabled(not option.active)
        button:SetScript("OnClick", function()
            ns.Profiles.set(option.id)
            renderOptions()
        end)
        button:Show()
    end
    for i = #options + 1, #optionButtons do
        optionButtons[i]:Hide()
    end
    return #options
end

local function render()
    stepText:SetText(L.ONBOARD_STEP:format(step, STEPS))
    local body = L["ONBOARD_STEP" .. step]
    local count = renderOptions()
    if step == 2 and count == 0 then
        body = body .. "\n\n" .. L.ONBOARD_NO_PROFILE
    end
    bodyText:SetText(body)
    backButton:SetEnabled(step > 1)
    nextButton:SetText(step < STEPS and L.ONBOARD_NEXT or L.ONBOARD_DONE)
end

local function onNext()
    if step < STEPS then
        step = step + 1
        render()
    else
        frame:Hide()
    end
end

local function onBack()
    step = math.max(1, step - 1)
    render()
end

local function onKeyDown(self, key)
    local escape = key == "ESCAPE"
    self:SetPropagateKeyboardInput(not escape)
    if escape then
        self:Hide()
    end
end

local function button(text, onClick)
    local result = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    result:SetText(text)
    result:SetSize(100, BUTTON_HEIGHT)
    result:SetScript("OnClick", onClick)
    return result
end

local function create()
    local theme = ns.Theme
    frame = CreateFrame("Frame", nil, UIParent, "PortraitFrameTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER", 0, 80)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:EnableKeyboard(true)
    frame:SetScript("OnKeyDown", onKeyDown)
    ns.Compat.SetFrameTitle(frame, L.ONBOARD_TITLE)
    ns.Compat.SetFramePortrait(frame, PORTRAIT)
    stepText = frame:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    stepText:SetPoint("TOPLEFT", 70, -34)
    stepText:SetTextColor(theme.colors.muted.r, theme.colors.muted.g, theme.colors.muted.b)
    bodyText = frame:CreateFontString(nil, "OVERLAY", theme.fonts.body)
    bodyText:SetPoint("TOPLEFT", 16, -70)
    bodyText:SetPoint("RIGHT", -16, 0)
    bodyText:SetJustifyH("LEFT")
    bodyText:SetJustifyV("TOP")
    bodyText:SetSpacing(2)
    nextButton = button(L.ONBOARD_NEXT, onNext)
    nextButton:SetPoint("BOTTOMRIGHT", -12, 12)
    backButton = button(L.ONBOARD_BACK, onBack)
    backButton:SetPoint("RIGHT", nextButton, "LEFT", -theme.spacing.gap, 0)
    frame:Hide()
    frame:SetScript("OnHide", markDone)
end

function Onboarding.show()
    if InCombatLockdown() then
        return
    end
    if not frame then
        create()
    end
    step = 1
    render()
    frame:Show()
end

ns:RegisterCommand("welcome", Onboarding.show, "WELCOME_COMMAND_HELP")

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
    if ns.DB.peek("char", "onboarded") then
        return
    end
    C_Timer.After(ONBOARD_DELAY, function()
        ns:RunOutOfCombat(Onboarding.show)
    end)
end)
