-- CONTRAT
-- Lecture des liens d'objet (« |Hitem:id:enchant:gemme1:gemme2:gemme3:gemme4:suffixe:… »). Pur.
--   itemID(link) -> number | nil ; link = lien complet ou chaîne « item:… »
--   suffix(link) -> number : 7e champ (suffixe aléatoire « … du Singe »), 0 si vide ou absent
--   inventoryType(equipLoc) -> InventoryType du client (1–28) | nil ; equipLoc = « INVTYPE_HEAD »…

local _, ns = ...

local ItemLink = {}
ns.ItemLink = ItemLink

local SUFFIX_FIELD = 6 -- indice depuis 0 (identifiant), soit le 7e champ

local INVENTORY_TYPES = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_BODY = 4, INVTYPE_CHEST = 5,
    INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10,
    INVTYPE_FINGER = 11, INVTYPE_TRINKET = 12, INVTYPE_WEAPON = 13, INVTYPE_SHIELD = 14,
    INVTYPE_RANGED = 15, INVTYPE_CLOAK = 16, INVTYPE_2HWEAPON = 17, INVTYPE_BAG = 18,
    INVTYPE_TABARD = 19, INVTYPE_ROBE = 20, INVTYPE_WEAPONMAINHAND = 21, INVTYPE_WEAPONOFFHAND = 22,
    INVTYPE_HOLDABLE = 23, INVTYPE_AMMO = 24, INVTYPE_THROWN = 25, INVTYPE_RANGEDRIGHT = 26,
    INVTYPE_QUIVER = 27, INVTYPE_RELIC = 28,
}

local function body(link)
    return type(link) == "string" and link:match("item:([%-%d:]+)") or nil
end

function ItemLink.itemID(link)
    local fields = body(link)
    return fields and tonumber(fields:match("^(%d+)")) or nil
end

function ItemLink.suffix(link)
    local fields = body(link)
    if not fields then
        return 0
    end
    local index = 0
    for value in (fields .. ":"):gmatch("([^:]*):") do
        if index == SUFFIX_FIELD then
            return tonumber(value) or 0
        end
        index = index + 1
    end
    return 0
end

function ItemLink.inventoryType(equipLoc)
    return INVENTORY_TYPES[equipLoc]
end
