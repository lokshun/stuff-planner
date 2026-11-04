-- CONTRAT
-- Contrôles du panneau de réglages, liés à une clé de ns.Options. Charger après Options.lua et Theme.lua.
-- Chaque constructeur rend un cadre ancrable avec .height (pixels) et :refresh() (relit ns.Options).
--   ns.OptionsWidgets.header(parent, text)
--   ns.OptionsWidgets.checkbox(parent, key, label)
--   ns.OptionsWidgets.slider(parent, key, label, format(value) -> string)
--   ns.OptionsWidgets.choice(parent, key, label, {{value, label}...}) : cases radio, une par valeur
--   ns.OptionsWidgets.button(parent, label, onClick)
-- Modèles du client présents sur Forever et Classic Era : UICheckButtonTemplate, UIRadioButtonTemplate,
-- UIPanelButtonTemplate ; curseur = Slider nu avec textures du client (aucun modèle de curseur).

local _, ns = ...

local Widgets = {}
ns.OptionsWidgets = Widgets

local WIDTH = 520
local SLIDER_WIDTH = 220
local THUMB = "Interface\\Buttons\\UI-SliderBar-Button-Horizontal"

local function noRefresh() end

local function label(parent, text, font)
    local fontString = parent:CreateFontString(nil, "OVERLAY", font or ns.Theme.fonts.body)
    fontString:SetText(text)
    fontString:SetJustifyH("LEFT")
    return fontString
end

function Widgets.header(parent, text)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(WIDTH, 28)
    local title = label(frame, text, ns.Theme.fonts.header)
    title:SetPoint("BOTTOMLEFT", 0, 4)
    local gold = ns.Theme.colors.border
    local line = frame:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(gold.r, gold.g, gold.b, 0.5)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    frame.height, frame.refresh = 32, noRefresh
    return frame
end

function Widgets.checkbox(parent, key, text)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(WIDTH, 26)
    local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("LEFT")
    label(frame, text):SetPoint("LEFT", check, "RIGHT", 4, 0)
    check:SetScript("OnClick", function(self)
        ns.Options.set(key, self:GetChecked() and true or false)
    end)
    function frame.refresh()
        check:SetChecked(ns.Options.get(key))
    end
    frame.height = 28
    return frame
end

function Widgets.slider(parent, key, text, format)
    local spec = ns.Options.spec(key)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(WIDTH, 40)
    label(frame, text):SetPoint("TOPLEFT", 4, 0)
    local slider = CreateFrame("Slider", nil, frame)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(SLIDER_WIDTH, 16)
    slider:SetPoint("TOPLEFT", 8, -18)
    slider:SetMinMaxValues(spec.min, spec.max)
    slider:SetValueStep(spec.step)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end
    slider:EnableMouse(true)
    slider:SetThumbTexture(THUMB)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0, 0, 0, 0.6)
    track:SetHeight(6)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    local value = label(frame, "", ns.Theme.fonts.number)
    value:SetPoint("LEFT", slider, "RIGHT", 12, 0)
    local refreshing = false
    slider:SetScript("OnValueChanged", function(_, raw)
        if refreshing then
            return
        end
        ns.Options.set(key, raw)
        value:SetText(format(ns.Options.get(key)))
    end)
    function frame.refresh()
        refreshing = true
        local current = ns.Options.get(key)
        slider:SetValue(current)
        value:SetText(format(current))
        refreshing = false
    end
    frame.height = 44
    return frame
end

function Widgets.choice(parent, key, text, values)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(WIDTH, 24)
    local title = label(frame, text)
    title:SetPoint("LEFT", 4, 0)
    local radios, previous = {}, title
    for _, entry in ipairs(values) do
        local radio = CreateFrame("CheckButton", nil, frame, "UIRadioButtonTemplate")
        radio:SetPoint("LEFT", previous, "RIGHT", 16, 0)
        local caption = label(frame, entry[2])
        caption:SetPoint("LEFT", radio, "RIGHT", 4, 0)
        radio:SetScript("OnClick", function()
            ns.Options.set(key, entry[1])
            frame.refresh()
        end)
        radios[#radios + 1] = { radio = radio, value = entry[1] }
        previous = caption
    end
    function frame.refresh()
        local current = ns.Options.get(key)
        for _, item in ipairs(radios) do
            item.radio:SetChecked(item.value == current)
        end
    end
    frame.height = 28
    return frame
end

function Widgets.button(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetText(text)
    button:SetSize(button:GetFontString():GetStringWidth() + 32, 22)
    button:SetScript("OnClick", onClick)
    button.height, button.refresh = 26, noRefresh
    return button
end
