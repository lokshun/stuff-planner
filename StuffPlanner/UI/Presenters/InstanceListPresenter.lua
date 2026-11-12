-- CONTRAT
-- Page « Donjons » : instances qui améliorent le personnage, et détail d'une instance. Pur : aucun appel
-- d'API. Charger après Theme.lua et DungeonPresenter.lua ; lit ns.Names, ns.Format, ns.BadgePresenter à l'appel.
--   ns.InstanceListPresenter.list(data, delta, currentID?) -> {row...}
--     data : façade Data (instanceIDs, instance, + ce que lit DungeonPresenter.build) ; delta = Results.delta
--     instance gardée si elle a un objet utile (boss ou hors boss) ; tri : instance courante, puis gain espéré
--     du passage décroissant, puis instanceID
--     row = {instanceID, name, detail (« Niv. a-b · Raid · n objets utiles »), gain (« +x »), gainColor,
--            expected, current, raid, count}
--   ns.InstanceListPresenter.detail(view, data) -> {row...} : view = DungeonPresenter.build ; par boss un
--     en-tête {header = true, text, gain (espérance), killed}, puis ses objets {itemID, icon, name, nameColor
--     (qualité), detail (taux | L.DUNGEON_CHANCE_UNKNOWN), gain (« +x % »), gainColor} ; hors boss à la fin
--     (L.DUNGEON_TRASH)

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

function InstanceListPresenter.list(data, delta, currentID)
    local rows = {}
    for _, instanceID in ipairs(data.instanceIDs()) do
        local view = ns.DungeonPresenter.build(instanceID, data, delta)
        local count = countItems(view)
        if count > 0 then
            local instance = data.instance(instanceID)
            rows[#rows + 1] = {
                instanceID = instanceID, name = ns.Names.instance(instanceID), detail = detailText(instance, count),
                gain = points(view.expected), gainColor = ns.Theme.colors.gain, expected = view.expected,
                current = instanceID == currentID, raid = instance and instance.raid == true, count = count,
            }
        end
    end
    table.sort(rows, function(a, b)
        if a.current ~= b.current then
            return a.current
        elseif a.expected ~= b.expected then
            return a.expected > b.expected
        end
        return a.instanceID < b.instanceID
    end)
    return rows
end

local function itemRow(item, data)
    local record = data.item and data.item(item.itemID)
    local chance = item.chance and ns.Format.percent(item.chance / 100, nil, item.chance < 1 and 1 or 0)
        or L.DUNGEON_CHANCE_UNKNOWN
    return {
        itemID = item.itemID, icon = ns.Names.itemIcon(item.itemID), name = ns.Names.item(item.itemID),
        nameColor = ns.Theme.quality(record and record.quality), detail = chance,
        gain = item.pct and ns.BadgePresenter.percentText(item.pct) or points(item.abs),
        gainColor = ns.Theme.colors.gain,
    }
end

local function addBoss(rows, text, boss, data)
    rows[#rows + 1] = { header = true, text = text, gain = #boss.items > 0 and points(boss.expected) or "",
        killed = boss.killed == true }
    for _, item in ipairs(boss.items) do
        rows[#rows + 1] = itemRow(item, data)
    end
end

function InstanceListPresenter.detail(view, data)
    local rows = {}
    for _, boss in ipairs(view.bosses) do
        addBoss(rows, ns.Names.npc(boss.npcID), boss, data)
    end
    if #view.trash.items > 0 then
        addBoss(rows, L.DUNGEON_TRASH, view.trash, data)
    end
    return rows
end
