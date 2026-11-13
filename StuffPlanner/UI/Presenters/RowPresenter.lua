-- CONTRAT
-- Champs affichés d'une ligne de liste (objet + gain + source). Charger après Theme.lua,
-- Format.lua et Names.lua. Aucun appel d'API direct : noms par ns.Names, nombres par ns.Format.
--   ns.RowPresenter.present(entry, data) -> row
--     entry = {itemID, source = {type, id, chance}?, delta = {abs, pct}?, questState?} ; source comme
--       Data.sourcesOf ; data = façade DataProvider (item, quest)
--     row = {itemID, name, icon, quality, nameColor,
--            arrow ("▲" | "▼" | ""), gainText (points, signe, 2 décimales sous 1, "" sans delta),
--            gainColor (Theme.colors gain | loss | neutral),
--            sourceKind (type de source | nil), sourceText ("" sans source),
--            originText (quête : questOrigin, « Suite de quêtes : nom » ou « Quête : nom » ; sinon sourceText),
--            unconfirmed (bool), badge (L.BADGE_UNCONFIRMED | nil), badgeColor,
--            questState (entry.questState : "log" | "level" | "prereq" | nil, voir Chat.bestInZone),
--            stateText ("" sans état ; « niv. N » = reqLevel de la quête, minLevel de l'instance),
--            stateColor,
--            unavailable (bool : "level" ou "prereq"),
--            slot (entry.delta.slot : emplacement comparé, nil sans delta),
--            gainLabel (= gainText, points signés : « +2.5 », « -0.50 », « 0.00 » ; pas de flèche, absente
--              de certaines polices ; "" sans delta ; non confirmé : rien de plus, le badge le dit),
--            secondaryLabel (SecondaryGain.value du profil secondaire, lignes avec delta seulement) | nil,
--            secondaryColor (instance s'il gagne, muted sinon) : affiché à côté de gainLabel,
--            detailText (états colorés — état de quête puis badge — séparés par « · »,
--              puis sourceText sans couleur), dimmed (= unavailable : ligne grisée)}
--   isChain(quest) -> bool : quête à prérequis (suite de quêtes) ; quest = data.quest(id) | nil
--   questOrigin(questID, data) -> L.SOURCE_ORIGIN (L.TAG_CHAIN si isChain, sinon L.TAG_QUEST ; nom de quête) ;
--     pour les textes sans le tag coloré de detailText (info-bulles, parcours, liste cible, autres sources, chat)
--   offProfile (delta.fallback : repli hors profil, Scoring.fallbackOf) : gainLabel entre parenthèses, couleur
--     muted, sans flèche ; L.TAG_OFF_PROFILE en tête de detailText
--   kindText, kindColor (quête : L.TAG_CHAIN si isChain, sinon L.TAG_QUEST, couleur title ; artisanat :
--     L.SOURCE_CRAFT, couleur craft, sourceText alors omis de detailText) : en couleur dans detailText, avant
--     le tag d'instance
--   lowDrop (isLowDrop(entry.source)) ; isLowDrop(source) -> bool : butin à faible taux, sans source sûre :
--     source world, ou dungeon / raid sans npcID (trash)
--   gain(delta) -> arrow, gainText, gainColor ; mêmes règles que les champs de present
--   state(questState, quest?) -> stateText, stateColor ("" et muted sans état)
--   questRow(entry, data) -> present d'un résultat de Chat.bestInZone {itemID, questID, delta,
--     questState} (source quête) + questID ; à utiliser par toutes les listes de quêtes
--   resultRow(entry, data) -> questRow si entry.questID, sinon present (résultat d'instance de
--     Chat.bestInZone) + itemSource = entry.source (fiche SourceDetail)
--   sameRows(a, b) -> bool : mêmes lignes affichées (ordre, objet, quête, nom, icône, gainLabel, secondaryLabel,
--     detailText, dimmed, slot) ; nil d'un côté : faux
--   instanceTag(quest, data) -> text, color | nil : « Donjon » ou « Raid » si quest.instance (raid lu dans
--     data.instance) ; lignes de quête et de butin d'instance (source dungeon, raid) : row.tagText,
--     row.tagColor, placés après l'état dans detailText
--   effortText(entry) -> « 12 min · Proche · 3 quêtes » (Format.duration de entry.seconds, Distance.label
--     de entry.hops, L.EFFORT_CHAIN si entry.steps > 1) | nil ; entry = ligne de Planner.rank
--   alternative(entry, data, effortText?) -> present + questID (source quête), itemSource,
--     effortText (donné, sinon effortText(entry)), lineText (effortText · detailText)
--   Non confirmé : objet confidence 1 (stats estimées) ou quête confidence 2 (récompenses devinées).
--   Donjon, raid : « Instance #id » tant que Names ne nomme pas les instances ; taux s'il est connu.

local _, ns = ...

local L = ns.L

local RowPresenter = {}
ns.RowPresenter = RowPresenter

local ESTIMATED_ITEM = 1
local GUESSED_QUEST = 2
local UNAVAILABLE = { level = true, prereq = true }

function RowPresenter.gain(delta)
    local theme = ns.Theme
    if not delta then
        return "", "", theme.colors.neutral
    end
    local abs = delta.abs
    local text = ns.Format.points(abs)
    if delta.fallback then
        return "", "(" .. text .. ")", theme.colors.muted
    elseif abs > 0 then
        return theme.arrows.up, text, theme.colors.gain
    elseif abs < 0 then
        return theme.arrows.down, text, theme.colors.loss
    end
    return "", text, theme.colors.neutral
end

local function instanceText(source)
    local name = ns.Names.instance(source.id)
    if source.chance then
        return L.SOURCE_DROP:format(name, ns.Format.percent(source.chance / 100))
    end
    return name
end

local function sourceText(source)
    if not source then
        return ""
    elseif source.type == "quest" then
        return ns.Names.quest(source.id)
    elseif source.type == "dungeon" or source.type == "raid" then
        return instanceText(source)
    elseif source.type == "craft" then
        return L.SOURCE_CRAFT
    elseif source.type == "world" then
        return L.SOURCE_WORLD:format(source.npcID and ns.Names.npc(source.npcID) or ns.Names.zone(source.mapID))
    end
    return ""
end

local function isUnconfirmed(item, source, data)
    if item and item.confidence == ESTIMATED_ITEM then
        return true
    end
    if source and source.type == "quest" then
        local quest = data.quest(source.id)
        return quest ~= nil and quest.confidence == GUESSED_QUEST
    end
    return false
end

function RowPresenter.state(state, quest)
    local colors = ns.Theme.colors
    if state == "log" then
        return L.STATE_IN_LOG, colors.gain
    elseif state == "level" then
        return L.STATE_LEVEL:format(quest and quest.reqLevel or 0), colors.warning
    elseif state == "prereq" then
        return L.STATE_PREREQ, colors.warning
    end
    return "", colors.muted
end

local SEPARATOR = " · "

function RowPresenter.isChain(quest)
    return quest ~= nil and quest.prereq ~= nil
end

function RowPresenter.questOrigin(questID, data)
    local kind = RowPresenter.isChain(data.quest(questID)) and L.TAG_CHAIN or L.TAG_QUEST
    return L.SOURCE_ORIGIN:format(kind, ns.Names.quest(questID))
end

function RowPresenter.isLowDrop(source)
    if not source then
        return false
    end
    local kind = source.type
    return kind == "world" or ((kind == "dungeon" or kind == "raid") and source.npcID == nil)
end

function RowPresenter.instanceTag(quest, data)
    if not (quest and quest.instance) then
        return nil
    end
    local instance = data.instance(quest.instance)
    return instance and instance.raid and L.TAG_RAID or L.TAG_DUNGEON, ns.Theme.colors.instance
end

local function detailText(row)
    local parts = {}
    if row.offProfile then
        parts[#parts + 1] = ns.Theme.colorize(L.TAG_OFF_PROFILE, ns.Theme.colors.muted)
    end
    if row.stateText ~= "" then
        parts[#parts + 1] = ns.Theme.colorize(row.stateText, row.stateColor)
    end
    if row.kindText then
        parts[#parts + 1] = ns.Theme.colorize(row.kindText, row.kindColor)
    end
    if row.tagText then
        parts[#parts + 1] = ns.Theme.colorize(row.tagText, row.tagColor)
    end
    if row.badge then
        parts[#parts + 1] = ns.Theme.colorize(row.badge, row.badgeColor)
    end
    if row.sourceText ~= "" and row.sourceKind ~= "craft" then
        parts[#parts + 1] = row.sourceText
    end
    return table.concat(parts, SEPARATOR)
end

-- Porteur du niveau affiché par l'état « niveau » : la quête, ou l'instance (niveau conseillé).
local function levelRecord(entry, data)
    local source = entry.questState and entry.source
    if not source then
        return nil
    elseif source.type == "quest" then
        return data.quest(source.id)
    end
    local instance = (source.type == "dungeon" or source.type == "raid") and data.instance(source.id)
    return instance and { reqLevel = instance.minLevel } or nil
end

function RowPresenter.present(entry, data)
    local item = data.item(entry.itemID)
    local quality = item and item.quality
    local row = {
        itemID = entry.itemID,
        name = ns.Names.item(entry.itemID),
        icon = ns.Names.itemIcon(entry.itemID, item and item.icon),
        quality = quality,
        nameColor = ns.Theme.quality(quality),
        sourceKind = entry.source and entry.source.type,
        sourceText = sourceText(entry.source),
        unconfirmed = isUnconfirmed(item, entry.source, data),
        questState = entry.questState,
        unavailable = UNAVAILABLE[entry.questState] == true,
        slot = entry.delta and entry.delta.slot,
        offProfile = entry.delta ~= nil and entry.delta.fallback == true or nil,
        lowDrop = RowPresenter.isLowDrop(entry.source),
    }
    row.stateText, row.stateColor = RowPresenter.state(entry.questState, levelRecord(entry, data))
    local kind = row.sourceKind
    if kind == "quest" then
        local quest = data.quest(entry.source.id)
        row.kindText = RowPresenter.isChain(quest) and L.TAG_CHAIN or L.TAG_QUEST
        row.kindColor = ns.Theme.colors.title
        row.originText = L.SOURCE_ORIGIN:format(row.kindText, row.sourceText)
        row.tagText, row.tagColor = RowPresenter.instanceTag(quest, data)
    elseif kind == "craft" then
        row.kindText, row.kindColor = L.SOURCE_CRAFT, ns.Theme.colors.craft
    elseif kind == "dungeon" or kind == "raid" then
        row.tagText, row.tagColor = kind == "raid" and L.TAG_RAID or L.TAG_DUNGEON, ns.Theme.colors.instance
    end
    row.originText = row.originText or row.sourceText
    row.arrow, row.gainText, row.gainColor = RowPresenter.gain(entry.delta)
    if row.unconfirmed then
        row.badge, row.badgeColor = L.BADGE_UNCONFIRMED, ns.Theme.colors.warning
    end
    row.gainLabel = row.gainText
    if entry.delta and ns.SecondaryGain then
        local second = ns.SecondaryGain.lookup(entry.itemID)
        if second then
            row.secondaryLabel = ns.SecondaryGain.value(second)
            row.secondaryColor = ns.SecondaryGain.color(second)
        end
    end
    row.detailText = detailText(row)
    row.dimmed = row.unavailable
    return row
end

function RowPresenter.questRow(entry, data)
    local row = RowPresenter.present({
        itemID = entry.itemID,
        source = { type = "quest", id = entry.questID },
        delta = entry.delta,
        questState = entry.questState,
    }, data)
    row.questID = entry.questID
    return row
end

function RowPresenter.resultRow(entry, data)
    if entry.questID then
        return RowPresenter.questRow(entry, data)
    end
    local row = RowPresenter.present(entry, data)
    row.itemSource = entry.source
    return row
end

local DISTANCE_TEXT = { near = "EFFORT_NEAR", mid = "EFFORT_MID", far = "EFFORT_FAR" }

function RowPresenter.effortText(entry)
    local parts = { ns.Format.duration(entry.seconds) }
    if entry.hops ~= nil then
        parts[#parts + 1] = L[DISTANCE_TEXT[ns.Distance.label(entry.hops)]]
    end
    if entry.steps and entry.steps > 1 then
        parts[#parts + 1] = L.EFFORT_CHAIN:format(entry.steps)
    end
    return #parts > 0 and table.concat(parts, " · ") or nil
end

function RowPresenter.alternative(entry, data, effortText)
    local row = entry.questID and RowPresenter.questRow(entry, data) or RowPresenter.present(entry, data)
    local source = entry.source or (entry.questID and { type = "quest", id = entry.questID }) or nil
    row.questID = entry.questID or (source and source.type == "quest" and source.id) or nil
    row.itemSource = source
    row.effortText = effortText or RowPresenter.effortText(entry)
    local parts = {}
    parts[#parts + 1] = row.effortText
    if row.detailText ~= "" then
        parts[#parts + 1] = row.detailText
    end
    row.lineText = table.concat(parts, " · ")
    return row
end

local SHOWN = { "itemID", "questID", "name", "icon", "gainLabel", "secondaryLabel", "detailText", "dimmed", "slot" }

function RowPresenter.sameRows(a, b)
    if not a or not b or #a ~= #b then
        return false
    end
    for i, row in ipairs(a) do
        for _, field in ipairs(SHOWN) do
            if row[field] ~= b[i][field] then
                return false
            end
        end
    end
    return true
end
