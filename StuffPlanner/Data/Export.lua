-- CONTRAT
-- Transforme les observations en chaîne à copier, pour merge_exports.py. Charger après Collector.lua.
--   ns.Export.encode(records) -> "SP1:" + EncodeForPrint(CompressDeflate(AceSerializer)) ;
--     seuls les champs du contrat de Collector et d'ItemProbe (itemID, stats) sortent : aucun nom
--     de personnage. /splan export : observations du collecteur, stats lues par ItemProbe, puis médianes
--     du chronométrage {kind = "timing", measure = Calibration.KINDS, median, count} (Timings.medians)
--   ns.Export.decode(str) -> records | nil, err ; err est un code, pas un texte à afficher
-- Commande /splan export : affiche la chaîne dans un champ à copier, refermé par Échap ou Entrée.

local _, ns = ...

local L = ns.L
local Serializer = LibStub("AceSerializer-3.0")
local Deflate = LibStub("LibDeflate")

local Export = {}
ns.Export = Export

local PREFIX = "SP1:"
local FIELDS = { "kind", "questID", "level", "npcID", "mapID", "x", "y", "choices", "rewards", "itemID", "stats",
    "measure", "median", "count" }

local function keepKnownFields(record)
    local kept = {}
    for _, field in ipairs(FIELDS) do
        kept[field] = record[field]
    end
    return kept
end

function Export.encode(records)
    local kept = {}
    for index, record in ipairs(records) do
        kept[index] = keepKnownFields(record)
    end
    return PREFIX .. Deflate:EncodeForPrint(Deflate:CompressDeflate(Serializer:Serialize(kept)))
end

function Export.decode(str)
    if type(str) ~= "string" or str:sub(1, #PREFIX) ~= PREFIX then
        return nil, "prefix"
    end
    local compressed = Deflate:DecodeForPrint(str:sub(#PREFIX + 1))
    if not compressed then
        return nil, "print"
    end
    local serialized = Deflate:DecompressDeflate(compressed)
    if not serialized then
        return nil, "deflate"
    end
    local ok, records = Serializer:Deserialize(serialized)
    if not ok or type(records) ~= "table" then
        return nil, "serializer"
    end
    return records
end

local box

local function closeBox(self)
    self:ClearFocus()
    self:Hide()
end

local function showBox(text)
    if not box then
        box = CreateFrame("EditBox", nil, UIParent, "InputBoxTemplate")
        box:SetSize(480, 24)
        box:SetPoint("CENTER")
        box:SetFrameStrata("DIALOG")
        box:SetAutoFocus(true)
        box:SetScript("OnEscapePressed", closeBox)
        box:SetScript("OnEnterPressed", closeBox)
    end
    box:Show()
    box:SetText(text)
    box:SetFocus()
    box:HighlightText()
end

ns:RegisterCommand("export", function()
    local records = {}
    for _, record in ipairs(ns.Collector.records()) do
        records[#records + 1] = record
    end
    for _, record in ipairs(ns.ItemProbe and ns.ItemProbe.records() or {}) do
        records[#records + 1] = record
    end
    for _, row in ipairs(ns.Timings and ns.Timings.medians() or {}) do
        if row.median then
            records[#records + 1] = { kind = "timing", measure = row.kind, median = row.median, count = row.count }
        end
    end
    if #records == 0 then
        print(L.EXPORT_EMPTY)
        return
    end
    showBox(Export.encode(records))
    print(L.EXPORT_READY)
end, "EXPORT_COMMAND_HELP")
