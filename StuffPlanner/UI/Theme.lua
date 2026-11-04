-- CONTRAT
-- Direction artistique « Carnet d'aventurier » : palette, polices du jeu, espacements.
-- Aucun appel d'API : valeurs fixes, lisibles par les tests.
--   ns.Theme.colors.<nom> -> {r, g, b} (0-1) ; noms : background, border (filet doré), title,
--     text, muted, gain (vert), loss (rouge), neutral, warning (badge « non confirmé »)
--   ns.Theme.quality(q) -> {r, g, b} ; couleurs officielles des qualités 0-7, commune (1) sinon
--   ns.Theme.hex(color) -> "ffRRGGBB" ; ns.Theme.colorize(text, color) -> "|cffRRGGBB" .. text .. "|r"
--   ns.Theme.fonts.<rôle> -> nom d'objet de police du client ; rôles : title, header, body, small, number
--   ns.Theme.spacing.<nom> -> pixels ; noms : padding, gap, rowHeight, iconSize, border
--   ns.Theme.arrows.up / down -> "▲" / "▼"
-- Tables partagées : ne pas les modifier.

local _, ns = ...

local Theme = {}
ns.Theme = Theme

local function rgb(hex)
    return {
        r = tonumber(hex:sub(1, 2), 16) / 255,
        g = tonumber(hex:sub(3, 4), 16) / 255,
        b = tonumber(hex:sub(5, 6), 16) / 255,
    }
end

Theme.colors = {
    background = rgb("14110d"),
    border = rgb("c9a34a"),
    title = rgb("ffd100"),
    text = rgb("f2e6c9"),
    muted = rgb("9a8f7a"),
    gain = rgb("1eff00"),
    loss = rgb("ff2020"),
    neutral = rgb("bfbfbf"),
    warning = rgb("ff9a1f"),
    instance = rgb("5fb4ff"),
}

-- Valeurs d'ITEM_QUALITY_COLORS du client.
local QUALITIES = {
    [0] = rgb("9d9d9d"),
    [1] = rgb("ffffff"),
    [2] = rgb("1eff00"),
    [3] = rgb("0070dd"),
    [4] = rgb("a335ee"),
    [5] = rgb("ff8000"),
    [6] = rgb("e6cc80"),
    [7] = rgb("00ccff"),
}
local COMMON = 1

Theme.fonts = {
    title = "GameFontNormalLarge",
    header = "GameFontNormal",
    body = "GameFontHighlight",
    small = "GameFontHighlightSmall",
    number = "NumberFontNormal",
}

Theme.spacing = {
    padding = 12,
    gap = 6,
    rowHeight = 28,
    iconSize = 22,
    border = 1,
}

Theme.arrows = { up = "▲", down = "▼" }

function Theme.quality(q)
    return QUALITIES[q] or QUALITIES[COMMON]
end

local function byte(value)
    return math.floor(value * 255 + 0.5)
end

function Theme.hex(color)
    return string.format("ff%02x%02x%02x", byte(color.r), byte(color.g), byte(color.b))
end

function Theme.colorize(text, color)
    return "|c" .. Theme.hex(color) .. text .. "|r"
end
