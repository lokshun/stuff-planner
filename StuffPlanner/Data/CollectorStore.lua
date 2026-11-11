-- CONTRAT
-- Règles de garde des observations du collecteur : clé de doublon, objets de butin utiles, migration.
-- Charger après CompatItem.lua, avant Collector.lua.
--   ns.CollectorStore.MAX_LOOT_PER_SOURCE -> 20, butins gardés au plus par source
--   ns.CollectorStore.key(record) -> clé de doublon : kind, questID, npcID (mapID si npcID nil),
--     choices et rewards ; la position l'ignore
--   ns.CollectorStore.source(record) -> source d'un butin : npcID, sinon "map" .. mapID
--   ns.CollectorStore.gearOnly(itemIDs) -> nouvelle liste des objets équipables, ordre gardé :
--     Compat.GetItemInfoInstant connu, equipLoc ni vide, ni sac, munitions, carquois, chemise, tabard
--   ns.CollectorStore.migrate(records) -> nouvelle liste (schéma 1 -> 2) : butins réduits à gearOnly,
--     vides retirés, doublons fusionnés, MAX_LOOT_PER_SOURCE par source ; autres observations intactes

local _, ns = ...

local CollectorStore = {}
ns.CollectorStore = CollectorStore

CollectorStore.MAX_LOOT_PER_SOURCE = 20

-- Emplacements qui ne portent pas de stats utiles au score.
local NOT_GEAR = {
    [""] = true, INVTYPE_BAG = true, INVTYPE_AMMO = true, INVTYPE_QUIVER = true,
    INVTYPE_BODY = true, INVTYPE_TABARD = true, INVTYPE_NON_EQUIP_IGNORE = true,
}

function CollectorStore.source(record)
    return record.npcID and tostring(record.npcID) or "map" .. tostring(record.mapID)
end

function CollectorStore.key(record)
    return table.concat({
        tostring(record.kind),
        tostring(record.questID),
        CollectorStore.source(record),
        table.concat(record.choices or {}, ","),
        table.concat(record.rewards or {}, ","),
    }, "|")
end

local function isGear(itemID)
    local info = ns.Compat.GetItemInfoInstant(itemID)
    return info ~= nil and info.equipLoc ~= nil and not NOT_GEAR[info.equipLoc]
end

function CollectorStore.gearOnly(itemIDs)
    local kept = {}
    for _, itemID in ipairs(itemIDs or {}) do
        if isGear(itemID) then
            kept[#kept + 1] = itemID
        end
    end
    return kept
end

function CollectorStore.migrate(records)
    local kept, keys, counts = {}, {}, {}
    for _, record in ipairs(records) do
        local keep = true
        if record.kind == "loot" then
            record.rewards = CollectorStore.gearOnly(record.rewards)
            local key, source = CollectorStore.key(record), CollectorStore.source(record)
            local count = counts[source] or 0
            keep = #record.rewards > 0 and not keys[key] and count < CollectorStore.MAX_LOOT_PER_SOURCE
            if keep then
                keys[key], counts[source] = true, count + 1
            end
        end
        if keep then
            kept[#kept + 1] = record
        end
    end
    return kept
end
