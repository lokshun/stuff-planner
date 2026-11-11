-- CONTRAT
-- Fiche d'une source d'objet hors quête (donjon, raid, artisanat). Pur : aucun appel d'API.
-- Charger après RowPresenter.lua.
--   ns.SourcePresenter.build(itemID, source, player, profile, data, seconds?) -> view | nil (quête ou nil)
--     source comme Data.sourcesOf ; profile nil = sans gain ; seconds (RouteResults.secondsOf) : dernière
--     ligne L.SOURCE_DETAIL_DURATION (Format.duration).
--     view = {itemID, kind, title, subtitle, lines = {{label, text}...}, others = {texte...},
--             item = RowPresenter.present + delta, mapID? (zone d'entrée), spellID? (recette),
--             reagents = {{itemID, count, text}...} (artisanat)}
--     Donjon, raid : title = nom d'instance ; subtitle « Donjon · 5 joueurs » ; lignes boss (hors
--       boss sans npcID), taux (inconnu sans taux), niveaux, niveau requis, entrée (si connus).
--     Artisanat : title = nom de la recette ; subtitle = métier ; lignes niveaux de métier
--       (seuils jaune et gris, le niveau requis n'est pas connu du client) et compétence du
--       joueur si player.professions la connaît ; composants « 2 × nom ».
--     others : autres sources de l'objet (texte de RowPresenter), la source affichée exclue.

local _, ns = ...

local L = ns.L

local SourcePresenter = {}
ns.SourcePresenter = SourcePresenter

local function sameSource(a, b)
    return a.type == b.type and a.id == b.id and a.npcID == b.npcID
end

local function othersOf(itemID, source, data)
    local list = {}
    for _, other in ipairs(data.sourcesOf(itemID) or {}) do
        if not sameSource(other, source) then
            list[#list + 1] = ns.RowPresenter.present({ itemID = itemID, source = other }, data).sourceText
        end
    end
    return list
end

local function instanceView(view, source, data)
    local instance = data.instance(source.id)
    local isRaid = source.type == "raid"
    view.title = ns.Names.instance(source.id)
    view.subtitle = isRaid and L.SOURCE_DETAIL_RAID or L.SOURCE_DETAIL_DUNGEON
    if instance and instance.size then
        view.subtitle = view.subtitle .. " · " .. L.SOURCE_DETAIL_SIZE:format(instance.size)
    end
    local lines = view.lines
    lines[#lines + 1] = {
        label = L.SOURCE_DETAIL_BOSS,
        text = source.npcID and ns.Names.npc(source.npcID) or L.SOURCE_DETAIL_TRASH,
    }
    lines[#lines + 1] = {
        label = L.SOURCE_DETAIL_CHANCE,
        text = source.chance and ns.Format.percent(source.chance / 100) or L.SOURCE_DETAIL_UNKNOWN,
    }
    if instance and instance.minLevel and instance.maxLevel then
        lines[#lines + 1] = { label = L.SOURCE_DETAIL_LEVELS, text = instance.minLevel .. "-" .. instance.maxLevel }
    end
    if instance and instance.reqLevel then
        lines[#lines + 1] = { label = L.SOURCE_DETAIL_REQUIRED, text = tostring(instance.reqLevel) }
    end
    if instance and instance.mapID then
        view.mapID = instance.mapID
        lines[#lines + 1] = { label = L.SOURCE_DETAIL_ENTRANCE, text = ns.Names.zone(instance.mapID) }
    end
end

local function craftView(view, source, player)
    view.title = ns.Names.spell(source.id)
    view.subtitle = ns.Names.profession(source.skillLine)
    view.spellID = source.id
    if source.yellow and source.grey then
        view.lines[#view.lines + 1] = {
            label = L.SOURCE_DETAIL_SKILL_LEVELS,
            text = L.SOURCE_DETAIL_SKILL_RANGE:format(source.yellow, source.grey),
        }
    end
    view.reagents = {}
    for i, reagent in ipairs(source.reagents or {}) do
        view.reagents[i] = {
            itemID = reagent.itemID,
            count = reagent.count,
            text = L.SOURCE_DETAIL_REAGENT:format(reagent.count, ns.Names.item(reagent.itemID)),
        }
    end
    local rank = player and player.professions and player.professions[source.skillLine]
    if rank then
        view.lines[#view.lines + 1] = { label = L.SOURCE_DETAIL_SKILL, text = tostring(rank) }
    end
end

function SourcePresenter.build(itemID, source, player, profile, data, seconds)
    if not source or source.type == "quest" then
        return nil
    end
    local delta = profile and player and ns.Scoring.delta(itemID, player, profile, data) or nil
    local view = {
        itemID = itemID,
        kind = source.type,
        lines = {},
        item = ns.RowPresenter.present({ itemID = itemID, source = source, delta = delta }, data),
        others = othersOf(itemID, source, data),
    }
    if source.type == "craft" then
        craftView(view, source, player)
    else
        instanceView(view, source, data)
    end
    if seconds then
        view.lines[#view.lines + 1] = { label = L.SOURCE_DETAIL_DURATION, text = ns.Format.duration(seconds) }
    end
    return view
end
