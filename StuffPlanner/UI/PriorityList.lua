-- CONTRAT
-- Section « Mes stats » de l'onglet Profil : l'utilisateur classe jusqu'à 10 stats, l'addon en
-- déduit les poids (ns.Priorities). Charger après Profiles/Priorities.lua, ProfilePresenter.lua,
-- StatPicker.lua et PriorityRows.lua (lignes, plafonds HIT et SPELL_HIT saisis en %, préremplis à l'ajout
-- par Priorities.defaultCap).
--   ns.PriorityList.HEIGHT -> hauteur de la section (pixels)
--   ns.PriorityList.create(parent) -> frame ; refresh() redessine (sans effet avant create)
-- Brouillon local : ordre du profil actif (order s'il vient des priorités, sinon poids décroissants)
-- et plafonds de ce profil ; repris tant qu'il n'a pas été modifié. Ajouter (menu ns.StatPicker, groupé),
-- flèches haut/bas, x, « Partir du profil de la spé » (Profiles.baseID), « Appliquer » -> Profiles.saveCustom :
-- écrase le profil personnalisé actif, sinon en crée un (ProfilePresenter.newName « Mes stats ») ; « Nouveau
-- profil » (visible si le profil actif est personnalisé) en crée toujours un ; plein : L.PROFILE_ERR_FULL.
-- saveCustom émet SP_PROFILE_CHANGED (onglet Zone, mini-suivi).

local _, ns = ...

local L = ns.L

local PriorityList = {}
ns.PriorityList = PriorityList

local ROW_HEIGHT = ns.PriorityRows.ROW_HEIGHT
local BUTTON_HEIGHT = 22
local ARROW_SIZE = ns.PriorityRows.ARROW_SIZE

PriorityList.HEIGHT = 14 + ns.Priorities.MAX * ROW_HEIGHT + 2 * BUTTON_HEIGHT + 14 + 5 * 6

local section, hint, addButton, saveNewButton, statusText
local rows = {}
local draft -- {order, caps, source, dirty}

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
    local caps = {}
    for key, value in pairs(profile and profile.caps or {}) do
        caps[key] = value
    end
    draft = {
        order = order,
        caps = caps,
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

local function onCap(index, text)
    local key = draft.order[index]
    if not key then
        return
    end
    local cap, code = ns.Priorities.parseCap(text)
    if not cap and code ~= "EMPTY" then
        setStatus(L.PRIORITY_CAP_INVALID, ns.Theme.colors.loss)
    elseif draft.caps[key] ~= cap then
        draft.caps[key] = cap
        draft.dirty = true
        setStatus("")
    end
    PriorityList.refresh()
end

local handlers = {
    move = function(index, delta)
        edit(ns.Priorities.move(draft.order, index, delta))
    end,
    remove = function(index)
        edit(ns.Priorities.remove(draft.order, index))
    end,
    cap = onCap,
}

local function button(parent, text, onClick)
    local result = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    result:SetText(text)
    result:SetSize(result:GetFontString():GetStringWidth() + 24, BUTTON_HEIGHT)
    result:SetScript("OnClick", onClick)
    return result
end

local function row(index)
    local line = rows[index]
    if not line then
        line = ns.PriorityRows.create(section, index, handlers)
        line:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -ns.Theme.spacing.gap - (index - 1) * ROW_HEIGHT)
        rows[index] = line
    end
    return line
end

local function renderAdd()
    local full = #draft.order >= ns.Priorities.MAX
    addButton:SetEnabled(not full and #ns.Priorities.candidates(draft.order) > 0)
end

-- Stat plafonnable ajoutée sans plafond : celui du profil de spé, sinon la valeur connue de sa phase.
local function fillCap(key)
    if draft.caps[key] ~= nil then
        return
    end
    local baseID = ns.Profiles.baseID()
    local base = baseID and ns.Profiles.get(baseID)
    draft.caps[key] = ns.Priorities.defaultCap(key, base and base.phase, base and base.caps)
end

local function onAdd()
    ns.StatPicker.open(addButton, ns.ProfilePresenter.statGroups(draft.order), function(key)
        fillCap(key)
        edit(ns.Priorities.add(draft.order, key))
    end)
end

local function onFromSpec()
    local baseID = ns.Profiles.baseID()
    startDraft(baseID and ns.Profiles.get(baseID), true)
    setStatus("")
    PriorityList.refresh()
end

-- id nil : nouveau profil personnalisé, nommé « Mes stats » (numéroté si le nom est pris).
local function save(id)
    local weights, code, detail = ns.Priorities.toWeights(draft.order)
    if not weights then
        local message = code == "EMPTY" and L.PRIORITY_EMPTY or ns.ProfilePresenter.importError(code, detail)
        setStatus(message, ns.Theme.colors.loss)
        return
    end
    local name = not id and ns.ProfilePresenter.newName(L.PROFILE_MY_STATS, ns.Profiles.available(),
        ns.Profiles.get) or nil
    if not ns.Profiles.saveCustom(id, name, { weights = weights, caps = draft.caps, order = draft.order }) then
        setStatus(L.PROFILE_ERR_FULL, ns.Theme.colors.loss)
        return
    end
    startDraft(ns.Profiles.active(), false)
    setStatus(L.PRIORITY_APPLIED, ns.Theme.colors.gain)
    ns.MainFrame.refresh()
end

local function activeCustomID()
    local id = ns.Profiles.activeID()
    return id and ns.Profiles.isCustom(id) and id or nil
end

local function onApply()
    save(activeCustomID())
end

local function onSaveNew()
    save(nil)
end

function PriorityList.refresh()
    if not section then
        return
    end
    local active = ns.Profiles.active()
    saveNewButton:SetShown(activeCustomID() ~= nil)
    if not draft or (not draft.dirty and draft.source ~= active) then
        startDraft(active, false)
    end
    local order = draft.order
    local presented = ns.ProfilePresenter.priorityRows(order, ns.Priorities.toWeights(order), draft.caps,
        ns.Priorities.CAPPABLE)
    for i = 1, ns.Priorities.MAX do
        ns.PriorityRows.render(row(i), presented[i], #order)
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
    addButton = button(section, L.PRIORITY_ADD, onAdd)
    addButton:SetWidth(addButton:GetWidth() + ARROW_SIZE + 4)
    addButton:GetFontString():SetPoint("CENTER", -(ARROW_SIZE + 4) / 2, 0)
    local addArrow = addButton:CreateTexture(nil, "ARTWORK")
    addArrow:SetSize(ARROW_SIZE, ARROW_SIZE)
    addArrow:SetPoint("RIGHT", -8, 0)
    addArrow:SetTexture(ns.PriorityRows.ARROW_TEXTURE)
    addArrow:SetTexCoord(unpack(ns.PriorityRows.ARROW_DOWN))
    addButton:SetPoint("TOPLEFT", 0, rowsBottom)
    local fromSpec = button(section, L.PRIORITY_FROM_SPEC, onFromSpec)
    fromSpec:SetPoint("TOPLEFT", addButton, "BOTTOMLEFT", 0, -theme.spacing.gap)
    local apply = button(section, L.PRIORITY_APPLY, onApply)
    apply:SetPoint("LEFT", fromSpec, "RIGHT", theme.spacing.gap, 0)
    saveNewButton = button(section, L.PRIORITY_SAVE_NEW, onSaveNew)
    saveNewButton:SetPoint("LEFT", apply, "RIGHT", theme.spacing.gap, 0)
    statusText = section:CreateFontString(nil, "OVERLAY", theme.fonts.small)
    statusText:SetPoint("TOPLEFT", fromSpec, "BOTTOMLEFT", 0, -theme.spacing.gap)
    statusText:SetPoint("RIGHT")
    statusText:SetJustifyH("LEFT")
    return section
end
