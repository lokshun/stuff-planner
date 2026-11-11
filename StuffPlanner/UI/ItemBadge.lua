-- CONTRAT
-- Pastille de gain (flèche verte + pourcentage, BadgePresenter) dans le coin d'un bouton d'objet.
-- Charger après BadgePresenter.lua, LiveItem.lua, Manager.lua et Results.lua.
--   ns.ItemBadge.show(button, link) : pastille demandée ; calculée plus tard, MAX_PER_FRAME boutons
--     par image, jamais en combat (reprise à la fin du combat) ; le dernier lien demandé l'emporte ;
--     même lien que la pastille posée : rien (pas de recalcul). link nil : comme hide.
--   ns.ItemBadge.hide(button) : pastille retirée tout de suite, demande en attente oubliée.
--   ns.ItemBadge.refreshAll() : toutes les pastilles posées sont recalculées (file).
--   ns.ItemBadge.pending() -> nombre de boutons en attente (tests, débogage)
-- Pastille absente avant SP_DATA_READY, sans profil actif, ou si l'objet n'est pas une amélioration.
-- Objet hors base pas encore en cache : pas de pastille, le prochain show relit (LiveItem).
-- SP_RESULTS_UPDATED (nouvel instantané, profil, stats confirmées) → refreshAll.

local _, ns = ...

local ItemBadge = {}
ns.ItemBadge = ItemBadge

local MAX_PER_FRAME = 8
local ARROW_SIZE = 12
local ARROW_TEXTURE = "Interface\\ChatFrame\\ChatFrameExpandArrow"
local ARROW_UP = { 1, 0, 0, 0, 1, 1, 0, 1 }
local INSET = 1

local WEAK_KEYS = { __mode = "k" }
local wanted = setmetatable({}, WEAK_KEYS) -- bouton -> lien demandé (posé ou en attente)
local queued = setmetatable({}, WEAK_KEYS) -- bouton -> true si en attente
local queue, head = {}, 1
local runner

local function overlay(button)
    local badge = button.stuffPlannerBadge
    if badge then
        return badge
    end
    badge = CreateFrame("Frame", nil, button)
    badge:SetAllPoints(button)
    badge:SetFrameLevel(button:GetFrameLevel() + 2)
    local arrow = badge:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(ARROW_SIZE, ARROW_SIZE)
    arrow:SetPoint("TOPLEFT", INSET, -INSET)
    arrow:SetTexture(ARROW_TEXTURE)
    arrow:SetTexCoord(unpack(ARROW_UP))
    arrow:SetDesaturated(true) -- flèche jaune du jeu : teinte verte nette par SetVertexColor
    local label = badge:CreateFontString(nil, "OVERLAY", ns.Theme.fonts.number)
    label:SetPoint("LEFT", arrow, "RIGHT", 0, 0)
    badge.arrow, badge.label = arrow, label
    badge:Hide()
    button.stuffPlannerBadge = badge
    return badge
end

local function clear(button)
    local badge = button.stuffPlannerBadge
    if badge then
        badge:Hide()
    end
end

local function view(link)
    if not ns.Data.ready() then
        return nil
    end
    local profile, player = ns.Profiles.active(), ns.Results.player()
    if not (profile and player) then
        return nil
    end
    return ns.BadgePresenter.build(link, player, profile, ns.Data, ns.LiveItem.fields)
end

local function apply(button)
    local link = wanted[button]
    local shown = link and view(link)
    if not shown then
        clear(button)
        return
    end
    local badge = overlay(button)
    local color = shown.color
    badge.arrow:SetVertexColor(color.r, color.g, color.b)
    badge.label:SetText(shown.text)
    badge.label:SetTextColor(color.r, color.g, color.b)
    badge:Show()
end

local function step()
    if InCombatLockdown() then
        return
    end
    local done = 0
    while head <= #queue and done < MAX_PER_FRAME do
        local button = queue[head]
        queue[head] = nil
        head = head + 1
        if queued[button] then
            queued[button] = nil
            apply(button)
            done = done + 1
        end
    end
    if head > #queue then
        queue, head = {}, 1
        runner:Hide()
    end
end

runner = CreateFrame("Frame")
runner:Hide()
runner:SetScript("OnUpdate", step)

local function enqueue(button)
    if not queued[button] then
        queued[button] = true
        queue[#queue + 1] = button
    end
    runner:Show()
end

function ItemBadge.show(button, link)
    if not link then
        ItemBadge.hide(button)
        return
    end
    if wanted[button] == link then
        return -- déjà posée pour ce lien (ou en attente) ; les recalculs passent par refreshAll
    end
    wanted[button] = link
    enqueue(button)
end

function ItemBadge.hide(button)
    wanted[button] = nil
    queued[button] = nil
    clear(button)
end

function ItemBadge.refreshAll()
    for button in pairs(wanted) do
        enqueue(button)
    end
end

function ItemBadge.pending()
    local count = 0
    for _ in pairs(queued) do
        count = count + 1
    end
    return count
end

ns:On("SP_RESULTS_UPDATED", ItemBadge.refreshAll)
