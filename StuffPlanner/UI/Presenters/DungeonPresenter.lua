-- CONTRAT
-- Objets utiles d'une instance, boss par boss, et espérance de gain d'un passage. Pur : aucun appel d'API.
--   ns.DungeonPresenter.build(instanceID, data, delta) -> view
--     data : instanceBosses, instanceItems, sourcesOf (façade Data) ; delta(itemID) -> {abs, pct, slot} | nil
--       (Results.delta) ; objet utile : abs > 0, source dungeon ou raid de cette instance.
--     view = {instanceID, bosses = {boss...}, trash = boss (npcID nil, butin hors boss),
--             expected = espérance du passage, unknownChance = nombre d'objets utiles sans taux}
--     boss = {npcID, items = {item...}, expected} ; boss dans l'ordre de data.instanceBosses (gardés même
--       sans objet utile, pour cocher les boss tués), puis boss à butin absents de l'ordre, par npcID.
--     item = {itemID, chance (% | nil), abs, pct, slot, expected = abs × taux | nil sans taux} ;
--       triés par espérance décroissante (sans taux en dernier), puis abs décroissant, puis itemID.
--     Espérance (boss et passage) : par emplacement, seul le meilleur objet tombé compte, les chutes étant
--       indépendantes : Σ abs_i × p_i × Π (1 - p_j) des objets mieux placés, p = taux / 100 borné à 1.
-- Un même objet sur deux boss : une ligne chez chacun.

local _, ns = ...

local DungeonPresenter = {}
ns.DungeonPresenter = DungeonPresenter

local KINDS = { dungeon = true, raid = true }

local function probability(chance)
    return chance and math.min(chance / 100, 1) or nil
end

local function byExpected(a, b)
    if (a.expected ~= nil) ~= (b.expected ~= nil) then
        return a.expected ~= nil
    end
    if a.expected and a.expected ~= b.expected then
        return a.expected > b.expected
    end
    if a.abs ~= b.abs then
        return a.abs > b.abs
    end
    return a.itemID < b.itemID
end

local function byAbs(a, b)
    if a.abs ~= b.abs then
        return a.abs > b.abs
    end
    return a.itemID < b.itemID
end

local function expectation(items)
    local slots = {}
    for _, item in ipairs(items) do
        if item.chance then
            local list = slots[item.slot or 0] or {}
            slots[item.slot or 0] = list
            list[#list + 1] = item
        end
    end
    local total = 0
    for _, list in pairs(slots) do
        table.sort(list, byAbs)
        local missed = 1
        for _, item in ipairs(list) do
            local p = probability(item.chance)
            total = total + item.abs * p * missed
            missed = missed * (1 - p)
        end
    end
    return total
end

local function newBoss(npcID)
    return { npcID = npcID, items = {}, expected = 0 }
end

local function collect(instanceID, data, delta)
    local byBoss, trash, all, unknown = {}, newBoss(nil), {}, 0
    for _, itemID in ipairs(data.instanceItems(instanceID)) do
        local gain = delta(itemID)
        if gain and gain.abs > 0 then
            for _, source in ipairs(data.sourcesOf(itemID) or {}) do
                if KINDS[source.type] and source.id == instanceID then
                    local p = probability(source.chance)
                    local item = { itemID = itemID, chance = source.chance, abs = gain.abs, pct = gain.pct,
                                   slot = gain.slot, expected = p and gain.abs * p or nil }
                    local boss = trash
                    if source.npcID then
                        boss = byBoss[source.npcID] or newBoss(source.npcID)
                        byBoss[source.npcID] = boss
                    end
                    boss.items[#boss.items + 1] = item
                    all[#all + 1] = item
                    unknown = unknown + (p and 0 or 1)
                end
            end
        end
    end
    return byBoss, trash, all, unknown
end

local function finish(boss)
    boss.expected = expectation(boss.items)
    table.sort(boss.items, byExpected)
    return boss
end

function DungeonPresenter.build(instanceID, data, delta)
    local byBoss, trash, all, unknown = collect(instanceID, data, delta)
    local bosses, listed = {}, {}
    for _, npcID in ipairs(data.instanceBosses(instanceID) or {}) do
        if not listed[npcID] then
            listed[npcID] = true
            bosses[#bosses + 1] = finish(byBoss[npcID] or newBoss(npcID))
        end
    end
    local extra = {}
    for npcID in pairs(byBoss) do
        if not listed[npcID] then
            extra[#extra + 1] = npcID
        end
    end
    table.sort(extra)
    for _, npcID in ipairs(extra) do
        bosses[#bosses + 1] = finish(byBoss[npcID])
    end
    return {
        instanceID = instanceID,
        bosses = bosses,
        trash = finish(trash),
        expected = expectation(all),
        unknownChance = unknown,
    }
end
