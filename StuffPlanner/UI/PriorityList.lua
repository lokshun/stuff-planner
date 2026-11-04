-- CONTRAT
-- Section « Mes stats » de l'onglet Profil : l'utilisateur classe jusqu'à 10 stats, l'addon en
-- déduit les poids (ns.Priorities). Charger après Profiles/Priorities.lua et ProfilePresenter.lua.
--   ns.PriorityList.HEIGHT -> hauteur de la section (pixels)
--   ns.PriorityList.create(parent) -> frame ; refresh() redessine (sans effet avant create)
-- Brouillon local : ordre du profil actif (order s'il vient des priorités, sinon poids décroissants)
-- et plafonds de ce profil ; repris tant qu'il n'a pas été modifié. Ajouter (sélecteur < >), flèches haut/bas, x,
-- « Partir du profil de la spé » (Profiles.baseID), « Appliquer » -> Profiles.setCustom({weights,
-- caps, order}), qui émet SP_PROFILE_CHANGED (onglet Zone, mini-suivi).

local _, ns = ...

local L = ns.L

local PriorityList = {}
ns.PriorityList = PriorityList

local ROW_HEIGHT = 18
local SMALL_BUTTON = 22
local BUTTON_HEIGHT = 22
local ARROW_SIZE = 10
local ARROW_TEXTURE = "Interface\\ChatFrame\\ChatFrameExpandArrow"
local ARROW_UP = { 1, 0, 0, 0, 1, 1, 0, 1 }
local ARROW_DOWN = { 0, 1, 1, 1, 0, 0, 1, 0 }

PriorityList.HEIGHT = 14 + ns.Priorities.MAX * ROW_HEIGHT + 2 * BUTTON_HEIGHT + 14 + 5 * 6

local section, hint, addLabel, addButton, statusText
local rows = {}
local draft -- {order, caps, source, dirty}
local candidateIndex = 1

local function setStatus(text, color)
    statusText:SetText(text or "")
    if color then
        statusText:SetTextColor(color.r, color.g, color.b)
    end
end

local function startDraft(profile, dirty)
    local order = {}
    for i, key in ipairs(profile and (profile.order or ns.Priorities.fromWeights(profile.weights)) or {}) do
        order[i] = key
    end
    draft = {
        order = order,
        caps = profile and profile.caps or {},
        source = ns.Profiles.active(),
        dirty = dirty,
    }
end

local function edit(order)
    draft.order = order
    draft.dirty = true
    setStatus("")
    PriorityList.refresh()
end

local function smallButton(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(SMALL_BUTTON, ROW_HEIGHT)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

-- Bouton à flèche dessinée (les glyphes ^ et v ne sont pas centrés dans la police du jeu) :
-- texture de flèche vers la droite tournée d'un quart de tour par SetTexCoord.
local function arrowButton(parent, coords, onClick)
    local button = smallButton(parent, "", onClick)
    local arrow = button:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(ARROW_SIZE, ARROW_SIZE)
    arrow:SetPoint("CENTER")
    arrow:SetTexture(ARROW_TEXTURE)
    arrow:SetTexCoord(unpack(coords))
    return button
end

local function button(parent, text, onClick)
    local result = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    result:SetText(text)
    result:SetSize(result:GetFontString():GetStringWidth() + 24, BUTTON_HEIGHT)
    result:SetScript("OnClick", onClick)
    return result
end

local function row(index)
    local line = rows[index]
    if line then
        return line
    end
    local theme = ns.Theme
    line = CreateFrame("Frame", nil, section)
    line:SetSize(420, ROW_HEIGHT)
    line:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -theme.spacing.gap - (index - 1) * ROW_HEIGHT)
    line.label = line:CreateFontString(nil, "OVERLAY", theme.fonts.body)
    line.label:SetPoint("LEFT")
    line.label:SetWidth(220)
    line.label:SetJustifyH("LEFT")
    line.weight = line:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    line.weight:SetPoint("LEFT", 225, 0)
    line.weight:SetTextColor(theme.colors.muted.r, theme.colors.muted.g, theme.colors.muted.b)
    line.up = arrowButton(line, ARROW_UP, function()
        edit(ns.Priorities.move(draft.order, index, -1))
    end)
    line.up:SetPoint("LEFT", 280, 0)
    line.down = arrowButton(line, ARROW_DOWN, function()
        edit(ns.Priorities.move(draft.order, index, 1))
    end)
    line.down:SetPoint("LEFT", line.up, "RIGHT", 2, 0)
    line.remove = smallButton(line, "x", function()
        edit(ns.Priorities.remove(draft.order, index))
    end)
    line.remove:SetPoint("LEFT", line.down, "RIGHT", 2, 0)
    rows[index] = line
    return line
end

local function currentCandidate()
    local candidates = ns.Priorities.candidates(draft.order)
    if #candidates == 0 then
        return nil
    end
    candidateIndex = (candidateIndex - 1) % #candidates + 1
    return candidates[candidateIndex]
end

local function cycle(delta)
    candidateIndex = candidateIndex + delta
    PriorityList.refresh()
end

local function renderAdd()
    local key = currentCandidate()
    local full = #draft.order >= ns.Priorities.MAX
    addLabel:SetText(key and (rawget(L, "STAT_" .. key) or key) or "")
    addButton:SetEnabled(key ~= nil and not full)
end

local function onAdd()
    local key = currentCandidate()
    if key then
        edit(ns.Priorities.add(draft.order, key))
    end
end

local function onFromSpec()
    local baseID = ns.Profiles.baseID()
    startDraft(baseID and ns.Profiles.get(baseID), true)
    setStatus("")
    PriorityList.refresh()
end

local function onApply()
    local weights, code, detail = ns.Priorities.toWeights(draft.order)
    if not weights then
        local message = code == "EMPTY" and L.PRIORITY_EMPTY or ns.ProfilePresenter.importError(code, detail)
        setStatus(message, ns.Theme.colors.loss)
        return
    end
    ns.Profiles.setCustom({ weights = weights, caps = draft.caps, order = draft.order })
    startDraft(ns.Profiles.active(), false)
    setStatus(L.PRIORITY_APPLIED, ns.Theme.colors.gain)
    ns.MainFrame.refresh()
end

function PriorityList.refresh()
    if not section then
        return
    end
    local active = ns.Profiles.active()
    if not draft or (not draft.dirty and draft.source ~= active) then
        startDraft(active, false)
    end
    local order = draft.order
    local presented = ns.ProfilePresenter.priorityRows(order, ns.Priorities.toWeights(order))
    for i = 1, ns.Priorities.MAX do
        local data = presented[i]
        local line = row(i)
        if data then
            line.label:SetText(data.label)
            line.weight:SetText(data.weightText)
            line.up:SetEnabled(i > 1)
            line.down:SetEnabled(i < #order)
        end
        line:SetShown(data ~= nil)
    end
    renderAdd()
end

function PriorityList.create(parent)
    local theme = ns.Theme
    section = CreateFrame("Frame", nil, parent)
    section:SetHeight(PriorityList.HEIGHT)
    hint = section:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    hint:SetPoint("TOPLEFT")
    hint:SetPoint("RIGHT")
    hint:SetJustifyH("LEFT")
    hint:SetText(L.PRIORITY_HINT)
    local rowsBottom = -(14 + 2 * theme.spacing.gap + ns.Priorities.MAX * ROW_HEIGHT)
    local previous = smallButton(section, "<", function()
        cycle(-1)
    end)
    previous:SetPoint("TOPLEFT", 0, rowsBottom)
    addLabel = section:CreateFontString(nil, "OVERLAY", theme.fonts.body)
    addLabel:SetPoint("LEFT", previous, "RIGHT", theme.spacing.gap, 0)
    addLabel:SetWidth(160)
    local nextButton = smallButton(section, ">", function()
        cycle(1)
    end)
    nextButton:SetPoint("LEFT", addLabel, "RIGHT", theme.spacing.gap, 0)
    addButton = button(section, L.PRIORITY_ADD, onAdd)
    addButton:SetPoint("LEFT", nextButton, "RIGHT", theme.spacing.gap, 0)
    local fromSpec = button(section, L.PRIORITY_FROM_SPEC, onFromSpec)
    fromSpec:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -theme.spacing.gap)
    local apply = button(section, L.PRIORITY_APPLY, onApply)
    apply:SetPoint("LEFT", fromSpec, "RIGHT", theme.spacing.gap, 0)
    statusText = section:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    statusText:SetPoint("TOPLEFT", fromSpec, "BOTTOMLEFT", 0, -theme.spacing.gap)
    statusText:SetPoint("RIGHT")
    statusText:SetJustifyH("LEFT")
    return section
end
