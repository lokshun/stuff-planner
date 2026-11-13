-- CONTRAT
-- Page « Donjons » : instances qui améliorent le personnage, et détail d'une instance. Pur : aucun appel
-- d'API. Charger après Theme.lua et DungeonPresenter.lua ; lit ns.Names, ns.Format, ns.BadgePresenter à l'appel.
--   ns.InstanceListPresenter.list(data, delta, currentID?, level?) -> {row...}
--     data : façade Data (instanceIDs, instance, + ce que lit DungeonPresenter.build) ; delta = Results.delta
--     instance gardée si elle a un objet utile (boss ou hors boss) ; reachable = pas de level, pas de minLevel
--     ou level ≥ minLevel ; tri : instance courante, puis faisable ; faisables : gain espéré du passage
--     décroissant ; non faisables : minLevel croissant (la plus proche d'abord), puis gain ; puis instanceID
--     row = {instanceID, name, detail (« Niv. a-b · Raid · n objets utiles »), gain (« +x »), gainColor,
--            expected, current, raid, count, reachable, dimmed (= non faisable)}
--   ns.InstanceListPresenter.detail(view, data) -> {row...} : view = DungeonPresenter.build ; par boss un
--     en-tête {header = true, text (L.DUNGEON_HEADER_BOSS ou L.DUNGEON_HEADER_RARE, nom du PNJ), npcID, rare,
--     gain (espérance), killed}, puis ses objets {itemID, icon, name, nameColor
--     (qualité), detail (taux | L.DUNGEON_CHANCE_UNKNOWN), gain (points, « +x »), gainColor,
--     itemSource = {type "dungeon" | "raid", id = instanceID, chance, npcID} (fiche SourceDetail)} ; hors boss à
--     la fin (L.DUNGEON_TRASH, en-tête sans npcID)
--   ns.InstanceListPresenter.chanceText(chance) -> taux en % (0 décimale dès 1 %, 1 dès 0,1 %, 2 dès 0,01 %, sinon 3)
--     | L.DUNGEON_CHANCE_UNKNOWN (nil) ; partagé avec DungeonPanel

local _, ns = ...

local L = ns.L

local InstanceListPresenter = {}
ns.InstanceListPresenter = InstanceListPresenter

local function points(value)
    return "+" .. ns.Format.number(value, nil, value < 1 and 2 or 1)
end

local function countItems(view)
    local count = #view.trash.items
    for _, boss in ipairs(view.bosses) do
        count = count + #boss.items
    end
    return count
end

local function detailText(instance, count)
    local parts = {}
    if instance and instance.minLevel then
        parts[#parts + 1] = L.INSTANCE_LEVELS:format(instance.minLevel, instance.maxLevel or instance.minLevel)
    end
    if instance and instance.raid then
        parts[#parts + 1] = L.INSTANCE_RAID
    end
    parts[#parts + 1] = L.INSTANCE_ITEMS:format(count)
    return table.concat(parts, " · ")
end

local function reachable(instance, level)
    return not (level and instance and instance.minLevel) or level >= instance.minLevel
end

function InstanceListPresenter.list(data, delta, currentID, level)
    local rows = {}
    for _, instanceID in ipairs(data.instanceIDs()) do
        local view = ns.DungeonPresenter.build(instanceID, data, delta)
        local count = countItems(view)
        if count > 0 then
            local instance = data.instance(instanceID)
            local canGo = reachable(instance, level)
            rows[#rows + 1] = {
                minLevel = instance and instance.minLevel or 0,
                instanceID = instanceID, name = ns.Names.instance(instanceID), detail = detailText(instance, count),
                gain = points(view.expected), gainColor = ns.Theme.colors.gain, expected = view.expected,
                current = instanceID == currentID, raid = instance and instance.raid == true, count = count,
                reachable = canGo, dimmed = not canGo,
            }
        end
    end
    table.sort(rows, function(a, b)
        if a.current ~= b.current then
            return a.current
        elseif a.reachable ~= b.reachable then
            return a.reachable
        elseif not a.reachable and a.minLevel ~= b.minLevel then
            return a.minLevel < b.minLevel
        elseif a.expected ~= b.expected then
            return a.expected > b.expected
        end
        return a.instanceID < b.instanceID
    end)
    return rows
end

function InstanceListPresenter.chanceText(chance)
    if not chance then
        return L.DUNGEON_CHANCE_UNKNOWN
    end
    local decimals = chance >= 1 and 0 or chance >= 0.1 and 1 or chance >= 0.01 and 2 or 3
    return ns.Format.percent(chance / 100, nil, decimals)
end

local function itemRow(item, data, source)
    local record = data.item and data.item(item.itemID)
    local chance = InstanceListPresenter.chanceText(item.chance)
    return {
        itemID = item.itemID, icon = ns.Names.itemIcon(item.itemID), name = ns.Names.item(item.itemID),
        nameColor = ns.Theme.quality(record and record.quality), detail = chance,
        gain = points(item.abs),
        gainColor = ns.Theme.colors.gain,
        itemSource = { type = source.type, id = source.id, chance = item.chance, npcID = source.npcID },
    }
end

local function addBoss(rows, text, boss, data, source)
    rows[#rows + 1] = { header = true, text = text, gain = #boss.items > 0 and points(boss.expected) or "",
        npcID = boss.npcID, killed = boss.killed == true, rare = boss.rare == true }
    local itemSource = { type = source.type, id = source.id, npcID = boss.npcID }
    for _, item in ipairs(boss.items) do
        rows[#rows + 1] = itemRow(item, data, itemSource)
    end
end

function InstanceListPresenter.detail(view, data)
    local rows = {}
    local instance = data.instance and data.instance(view.instanceID)
    local source = { type = instance and instance.raid and "raid" or "dungeon", id = view.instanceID }
    for _, boss in ipairs(view.bosses) do
        local label = boss.rare and L.DUNGEON_HEADER_RARE or L.DUNGEON_HEADER_BOSS
        addBoss(rows, label:format(ns.Names.npc(boss.npcID)), boss, data, source)
    end
    if #view.trash.items > 0 then
        addBoss(rows, L.DUNGEON_TRASH, view.trash, data, source)
    end
    return rows
end
