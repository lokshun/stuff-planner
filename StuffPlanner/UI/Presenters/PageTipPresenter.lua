-- CONTRAT
-- Astuces des pages de la fenêtre principale : une phrase « à quoi sert la page » (accueil, étape 3) et un
-- bandeau « comment s'en servir » au premier passage (ns.PageTip). Pur.
--   ns.PageTipPresenter.list(pages) -> {{key, icon, label, text}...} : pages = ns.NavBar.order(...), même
--     ordre ; pages sans texte ignorées
--   ns.PageTipPresenter.tip(key, seen?) -> texte | nil : nil si seen[key] ou page sans astuce
-- Textes : L.PAGE_WHAT_<CLÉ> et L.PAGE_TIP_<CLÉ> (table KEYS).

local _, ns = ...

local L = ns.L

local PageTipPresenter = {}
ns.PageTipPresenter = PageTipPresenter

local KEYS = {
    zone = "ZONE", wishlist = "WISHLIST", route = "ROUTE", dungeon = "DUNGEON", gear = "GEAR",
    profile = "PROFILE", journal = "JOURNAL",
}

function PageTipPresenter.list(pages)
    local rows = {}
    for _, page in ipairs(pages) do
        local suffix = KEYS[page.key]
        if suffix then
            rows[#rows + 1] = { key = page.key, icon = page.icon, label = page.label,
                text = L["PAGE_WHAT_" .. suffix] }
        end
    end
    return rows
end

function PageTipPresenter.tip(key, seen)
    local suffix = KEYS[key]
    if not suffix or (seen and seen[key]) then
        return nil
    end
    return L["PAGE_TIP_" .. suffix]
end
