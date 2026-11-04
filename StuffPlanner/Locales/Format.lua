-- CONTRAT
-- Mise en forme des nombres selon la langue. Charger avec Locales/ ; ne dépend que de GetLocale.
--   ns.Format.percent(ratio [, locale [, decimals]]) -> string ; 0.183 -> "18,3 %" (frFR), "18.3%" (enUS) ;
--     decimals vaut 1 par défaut
--   ns.Format.number(value [, locale [, decimals]]) -> string ; 1234 -> "1 234" (frFR), "1,234" (enUS) ;
--     decimals vaut 0 par défaut
-- locale vaut GetLocale() par défaut ; une langue inconnue suit enUS.
-- Les séparateurs d'espace sont des espaces ordinaires, pas insécables.

local _, ns = ...

local Format = {}
ns.Format = Format

local POINT_COMMA = { decimal = ".", thousands = ",", percent = "%" }
local COMMA_POINT = { decimal = ",", thousands = ".", percent = "%" }
local COMMA_POINT_SPACED = { decimal = ",", thousands = ".", percent = " %" }
local COMMA_SPACE_SPACED = { decimal = ",", thousands = " ", percent = " %" }

local CONVENTIONS = {
    enUS = POINT_COMMA,
    esMX = POINT_COMMA,
    koKR = POINT_COMMA,
    zhCN = POINT_COMMA,
    zhTW = POINT_COMMA,
    itIT = COMMA_POINT,
    ptBR = COMMA_POINT,
    deDE = COMMA_POINT_SPACED,
    esES = COMMA_POINT_SPACED,
    frFR = COMMA_SPACE_SPACED,
    ruRU = COMMA_SPACE_SPACED,
}

local function conventionsFor(locale)
    return CONVENTIONS[locale or GetLocale()] or POINT_COMMA
end

local function formatFixed(value, decimals, conventions)
    local text = string.format("%." .. decimals .. "f", value)
    local sign, whole, fraction = text:match("^(-?)(%d+)%.?(%d*)$")
    if not (whole .. fraction):find("[1-9]") then
        sign = ""
    end
    local replaced
    repeat
        whole, replaced = whole:gsub("^(%d+)(%d%d%d)", "%1" .. conventions.thousands .. "%2")
    until replaced == 0
    if fraction ~= "" then
        fraction = conventions.decimal .. fraction
    end
    return sign .. whole .. fraction
end

function Format.percent(ratio, locale, decimals)
    local conventions = conventionsFor(locale)
    return formatFixed(ratio * 100, decimals or 1, conventions) .. conventions.percent
end

function Format.number(value, locale, decimals)
    return formatFixed(value, decimals or 0, conventionsFor(locale))
end
