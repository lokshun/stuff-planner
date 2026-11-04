-- CONTRAT
-- Dit si une classe peut équiper un objet (armure ou arme). Pur : aucun appel à l'API WoW.
--   canEquip(class, level, itemClass, itemSubClass, opts) -> bool
--     class : jeton anglais (« WARRIOR ») ; level : nil compté comme sous 40 ;
--     itemClass / itemSubClass : valeurs du client (2 arme, 4 armure).
--     opts.learned = {[sousClasseArme]=true} : armes apprises ; si fourni, seules elles
--     comptent (même hors table de classe : talent du chaman), divers et pêche toujours.
-- Table d'après Classic : maille (chasseur, chaman) et plaque (guerrier, paladin) à 40 ;
-- armes que la classe peut apprendre d'un maître d'armes ; reliques par classe.
-- Toute autre classe d'objet, classe de joueur ou sous-classe inconnue : false.

local _, ns = ...

local Proficiency = {}
ns.Proficiency = Proficiency

local WEAPON, ARMOR = 2, 4
local UPGRADE_LEVEL = 40

local ARMOR_CLOTH, ARMOR_LEATHER, ARMOR_MAIL, ARMOR_PLATE = 1, 2, 3, 4
local ARMOR_MISC, ARMOR_SHIELD, LIBRAM, IDOL, TOTEM = 0, 6, 7, 8, 9

local AXE1H, AXE2H, BOW, GUN, MACE1H, MACE2H = 0, 1, 2, 3, 4, 5
local POLEARM, SWORD1H, SWORD2H, STAFF, FIST = 6, 7, 8, 10, 13
local WEAPON_MISC, DAGGER, THROWN, CROSSBOW, WAND, FISHING_POLE = 14, 15, 16, 18, 19, 20

-- Armure : sous-classe -> niveau minimal (1 = dès le départ).
local function armor(entries)
    local set = { [ARMOR_MISC] = 1, [ARMOR_CLOTH] = 1 }
    for subClass, level in pairs(entries) do
        set[subClass] = level
    end
    return set
end

local function weapons(list)
    local set = { [WEAPON_MISC] = true, [FISHING_POLE] = true }
    for _, subClass in ipairs(list) do
        set[subClass] = true
    end
    return set
end

local CLASSES = {
    WARRIOR = {
        armor = armor({
            [ARMOR_LEATHER] = 1,
            [ARMOR_MAIL] = 1,
            [ARMOR_PLATE] = UPGRADE_LEVEL,
            [ARMOR_SHIELD] = 1,
        }),
        weapons = weapons({
            AXE1H, AXE2H, BOW, GUN, MACE1H, MACE2H, POLEARM, SWORD1H, SWORD2H, STAFF, FIST, DAGGER, THROWN, CROSSBOW,
        }),
    },
    PALADIN = {
        armor = armor({
            [ARMOR_LEATHER] = 1,
            [ARMOR_MAIL] = 1,
            [ARMOR_PLATE] = UPGRADE_LEVEL,
            [ARMOR_SHIELD] = 1,
            [LIBRAM] = 1,
        }),
        weapons = weapons({ AXE1H, AXE2H, MACE1H, MACE2H, POLEARM, SWORD1H, SWORD2H }),
    },
    HUNTER = {
        armor = armor({ [ARMOR_LEATHER] = 1, [ARMOR_MAIL] = UPGRADE_LEVEL }),
        weapons = weapons({
            AXE1H, AXE2H, BOW, GUN, POLEARM, SWORD1H, SWORD2H, STAFF, FIST, DAGGER, THROWN, CROSSBOW,
        }),
    },
    SHAMAN = {
        armor = armor({ [ARMOR_LEATHER] = 1, [ARMOR_MAIL] = UPGRADE_LEVEL, [ARMOR_SHIELD] = 1, [TOTEM] = 1 }),
        weapons = weapons({ AXE1H, MACE1H, STAFF, FIST, DAGGER }),
    },
    ROGUE = {
        armor = armor({ [ARMOR_LEATHER] = 1 }),
        weapons = weapons({ BOW, GUN, MACE1H, SWORD1H, FIST, DAGGER, THROWN, CROSSBOW }),
    },
    DRUID = {
        armor = armor({ [ARMOR_LEATHER] = 1, [IDOL] = 1 }),
        weapons = weapons({ MACE1H, MACE2H, STAFF, FIST, DAGGER }),
    },
    PRIEST = { armor = armor({}), weapons = weapons({ MACE1H, STAFF, DAGGER, WAND }) },
    MAGE = { armor = armor({}), weapons = weapons({ SWORD1H, STAFF, DAGGER, WAND }) },
    WARLOCK = { armor = armor({}), weapons = weapons({ SWORD1H, STAFF, DAGGER, WAND }) },
}

local function canWield(rules, subClass, opts)
    if subClass == WEAPON_MISC or subClass == FISHING_POLE then
        return true
    end
    local learned = opts and opts.learned
    if learned then
        return learned[subClass] == true
    end
    return rules.weapons[subClass] == true
end

function Proficiency.canEquip(class, level, itemClass, itemSubClass, opts)
    local rules = class and CLASSES[class]
    if not rules then
        return false
    end
    if itemClass == ARMOR then
        local minLevel = rules.armor[itemSubClass]
        return minLevel ~= nil and (level or 1) >= minLevel
    end
    if itemClass == WEAPON then
        return canWield(rules, itemSubClass, opts)
    end
    return false
end
