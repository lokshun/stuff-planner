-- CONTRAT
-- Pseudo-langue de test : repère les textes codés en dur et les libellés trop longs pour leur cadre.
-- Pur : aucun appel d'API.
--   ns.Pseudo.transform(text) -> lettres ASCII accentuées, « · » ajoutés (30 % des lettres, arrondi
--     supérieur), le tout entre crochets ; intacts : %d, %s, %.1f, %%..., |c........, |r, |T...|t,
--     |H...|h, |h, |n, || et les caractères non ASCII
--   ns.Pseudo.apply(L) -> remplace sur place chaque valeur texte de L par transform(valeur)

local _, ns = ...

local Pseudo = {}
ns.Pseudo = Pseudo

local ACCENTS = {
    a = "á", e = "é", i = "í", o = "ö", u = "ü", c = "ç", n = "ñ", y = "ý",
    A = "Å", E = "É", I = "Î", O = "Ø", U = "Û", C = "Ç", N = "Ñ",
}
local KEPT = {
    "^%%[-+ #0]*%d*%.?%d*[%a%%]",
    "^|c%x%x%x%x%x%x%x%x",
    "^|T.-|t",
    "^|H.-|h",
    "^|[rhn|]",
}
local PADDING = 0.3

local function keptAt(text, position)
    for _, pattern in ipairs(KEPT) do
        local first, last = text:find(pattern, position)
        if first then
            return last
        end
    end
    return nil
end

function Pseudo.transform(text)
    local parts, letters, position = {}, 0, 1
    while position <= #text do
        local last = keptAt(text, position)
        if last then
            parts[#parts + 1] = text:sub(position, last)
            position = last + 1
        else
            local char = text:sub(position, position)
            if char:match("%a") then
                letters = letters + 1
            end
            parts[#parts + 1] = ACCENTS[char] or char
            position = position + 1
        end
    end
    local pad = math.ceil(letters * PADDING)
    local tail = pad > 0 and (" " .. string.rep("·", pad)) or ""
    return "[" .. table.concat(parts) .. tail .. "]"
end

function Pseudo.apply(L)
    local changed = {}
    for key, value in pairs(L) do
        if type(value) == "string" then
            changed[key] = Pseudo.transform(value)
        end
    end
    for key, value in pairs(changed) do
        L[key] = value
    end
end
