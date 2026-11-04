-- CONTRAT
-- Traduit les stats d'objet (API ou lignes d'info-bulle) en clés internes (ns.StatKeys).
-- Pur : aucun appel à l'API WoW ; les chaînes globales arrivent par getString.
--   fromApi(apiStats) -> {[StatKey]=value} ; apiStats = retour de Compat.GetItemStats, nil accepté
--   buildPatterns(getString) -> patterns ; getString(name) -> chaîne globale | nil
--     (en jeu : ns.Compat.GlobalString). Motifs issus des formats ITEM_MOD_*, ARMOR_TEMPLATE,
--     DPS_TEMPLATE, SHIELD_BLOCK_TEMPLATE ; préfixe ITEM_SPELL_TRIGGER_ONEQUIP retiré ;
--     nombres selon DECIMAL_SEPERATOR et LARGE_NUMBER_SEPERATOR (repli « . » et « , »).
--   fromLines(lines, patterns) -> {[StatKey]=value} ; lignes non reconnues ignorées
--   merge(a, b) -> nouvelle table : a, complétée par les clés absentes de b
-- Scores (toucher, critique, esquive, parade, blocage, hâte) convertis en % aux taux Forever.
-- Plusieurs sources pour une même clé : valeurs additionnées.
-- Résistances : API seule (le format de ligne frFR n'a pas un seul nombre).

local _, ns = ...
local K = ns.StatKeys

local StatParser = {}
ns.StatParser = StatParser

-- Mêmes taux que tools/sources/wago.py ; variantes « sorts » supposées identiques.
local RATING_PER_PERCENT = {
    [K.HIT] = 10, [K.SPELL_HIT] = 10, [K.CRIT] = 14, [K.SPELL_CRIT] = 14,
    [K.DODGE] = 12, [K.PARRY] = 15, [K.BLOCK] = 5, [K.HASTE] = 10,
}

-- Suffixe des chaînes ITEM_MOD_<nom> (format de ligne) et ITEM_MOD_<nom>_SHORT (clé d'API).
local MODS = {
    STRENGTH = K.STR, AGILITY = K.AGI, STAMINA = K.STA, INTELLECT = K.INT, SPIRIT = K.SPI,
    ATTACK_POWER = K.AP, RANGED_ATTACK_POWER = K.RAP,
    HIT_RATING = K.HIT, HIT_MELEE_RATING = K.HIT, HIT_RANGED_RATING = K.HIT, HIT_SPELL_RATING = K.SPELL_HIT,
    CRIT_RATING = K.CRIT, CRIT_MELEE_RATING = K.CRIT, CRIT_RANGED_RATING = K.CRIT,
    CRIT_SPELL_RATING = K.SPELL_CRIT, HASTE_RATING = K.HASTE,
    SPELL_POWER = K.SPELL_POWER, SPELL_DAMAGE_DONE = K.SPELL_DMG, SPELL_HEALING_DONE = K.HEALING,
    HOLY_DAMAGE_DONE = K.HOLY_DMG, FIRE_DAMAGE_DONE = K.FIRE_DMG, NATURE_DAMAGE_DONE = K.NATURE_DMG,
    FROST_DAMAGE_DONE = K.FROST_DMG, SHADOW_DAMAGE_DONE = K.SHADOW_DMG, ARCANE_DAMAGE_DONE = K.ARCANE_DMG,
    SPELL_PENETRATION = K.SPELL_PEN, MANA_REGENERATION = K.MP5, HEALTH_REGEN = K.HP5,
    DEFENSE_SKILL_RATING = K.DEF, DODGE_RATING = K.DODGE, PARRY_RATING = K.PARRY,
    BLOCK_RATING = K.BLOCK, BLOCK_VALUE = K.BLOCK_VALUE, EXTRA_ARMOR = K.ARMOR,
}

local API_KEYS = {
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = K.DPS,
    ITEM_MOD_POWER_REGEN0_SHORT = K.MP5,
    RESISTANCE0_NAME = K.ARMOR,
    RESISTANCE1_NAME = K.RES_HOLY, RESISTANCE2_NAME = K.RES_FIRE, RESISTANCE3_NAME = K.RES_NATURE,
    RESISTANCE4_NAME = K.RES_FROST, RESISTANCE5_NAME = K.RES_SHADOW, RESISTANCE6_NAME = K.RES_ARCANE,
}

local LINE_FORMATS = {
    ARMOR_TEMPLATE = K.ARMOR,
    DPS_TEMPLATE = K.DPS,
    SHIELD_BLOCK_TEMPLATE = K.BLOCK_VALUE,
}

for name, key in pairs(MODS) do
    API_KEYS["ITEM_MOD_" .. name .. "_SHORT"] = key
    LINE_FORMATS["ITEM_MOD_" .. name] = key
end

local function add(stats, key, value)
    local rate = RATING_PER_PERCENT[key]
    if rate then
        value = value / rate
    end
    stats[key] = (stats[key] or 0) + value
end

function StatParser.fromApi(apiStats)
    local stats = {}
    for apiKey, value in pairs(apiStats or {}) do
        local key = API_KEYS[apiKey]
        if key and type(value) == "number" then
            add(stats, key, value)
        end
    end
    return stats
end

local MAGIC = "[%^%$%(%)%%%.%[%]%*%+%-%?]"
local SIGN = "([%+%-])"

local function escape(text)
    return (text:gsub(MAGIC, "%%%0"))
end

-- Format printf du client -> motif Lua ancré. Exige une seule valeur numérique ;
-- %c est le signe. Arguments numérotés (%2$d) acceptés. nil si le format ne convient pas.
local function compile(format, number)
    local parts, captures = {}, {}
    local pos, seq = 1, 0
    while pos <= #format do
        local s, e, arg, conv = format:find("^%%(%d+)%$([cdsfi])", pos)
        if not s then
            s, e, conv = format:find("^%%[%-%d%.]*([cdsfi])", pos)
            if s then
                seq = seq + 1
                arg = seq
            end
        end
        if s then
            captures[#captures + 1] = { arg = tonumber(arg), sign = conv == "c" }
            parts[#parts + 1] = conv == "c" and SIGN or number
            pos = e + 1
        elseif format:sub(pos, pos + 1) == "%%" then
            parts[#parts + 1] = "%%"
            pos = pos + 2
        else
            local ch = format:sub(pos, pos)
            parts[#parts + 1] = ch:find(MAGIC) and "%" .. ch or ch
            pos = pos + 1
        end
    end
    local valueAt, signAt
    for index, capture in ipairs(captures) do
        if capture.sign then
            signAt = index
        elseif valueAt then
            return nil
        else
            valueAt = index
        end
    end
    if not valueAt then
        return nil
    end
    return { pattern = "^" .. table.concat(parts) .. "$", valueAt = valueAt, signAt = signAt }
end

-- Séparateurs du client (frFR : « 57,50 », aucun séparateur de milliers) ; repli enUS.
local function parseNumber(text, patterns)
    if patterns.large ~= "" then
        text = text:gsub(escape(patterns.large), "")
    end
    if patterns.decimal ~= "." then
        text = text:gsub(escape(patterns.decimal), ".")
    end
    return tonumber(text)
end

local function separator(getString, name, default)
    local value = getString(name)
    return type(value) == "string" and value or default
end

function StatParser.buildPatterns(getString)
    local decimal = separator(getString, "DECIMAL_SEPERATOR", ".")
    local large = separator(getString, "LARGE_NUMBER_SEPERATOR", ",")
    local number = "([%d" .. escape(decimal) .. escape(large) .. "]+)"
    local names = {}
    for name in pairs(LINE_FORMATS) do
        names[#names + 1] = name
    end
    table.sort(names)
    local list = {}
    for _, name in ipairs(names) do
        local format = getString(name)
        local compiled = type(format) == "string" and compile(format, number)
        if compiled then
            compiled.key = LINE_FORMATS[name]
            list[#list + 1] = compiled
        end
    end
    return { equip = getString("ITEM_SPELL_TRIGGER_ONEQUIP"), list = list, decimal = decimal, large = large }
end

local function stripEquip(line, equip)
    if equip and line:sub(1, #equip) == equip then
        line = line:sub(#equip + 1)
    end
    return line:match("^%s*(.-)%s*$")
end

local function parseLine(stats, line, patterns)
    for _, entry in ipairs(patterns.list) do
        local captures = { line:match(entry.pattern) }
        if captures[1] then
            local value = parseNumber(captures[entry.valueAt], patterns)
            if value then
                if entry.signAt and captures[entry.signAt] == "-" then
                    value = -value
                end
                add(stats, entry.key, value)
                return
            end
        end
    end
end

function StatParser.fromLines(lines, patterns)
    local stats = {}
    for _, line in ipairs(lines or {}) do
        if type(line) == "string" then
            parseLine(stats, stripEquip(line, patterns.equip), patterns)
        end
    end
    return stats
end

function StatParser.merge(a, b)
    local merged = {}
    for key, value in pairs(b or {}) do
        merged[key] = value
    end
    for key, value in pairs(a or {}) do
        merged[key] = value
    end
    return merged
end
