-- CONTRAT
-- /splan why <lien d'objet> : détail du score de l'objet pour le profil actif, une ligne par stat
-- (WhyPresenter), puis le gain affiché sur les pastilles (BadgePresenter). Tout est lu à l'appel :
-- ns.ItemLink, ns.Data, ns.LiveItem, ns.Profiles, ns.Results, ns.StatValue, ns.WhyPresenter, ns.BadgePresenter.
-- Sans lien : L.WHY_USAGE ; base ou profil pas prêts : L.WHY_NOT_READY ; objet inconnu ou non lisible :
-- L.WHY_UNKNOWN. Les stats sont celles du calcul : base, ou lues en jeu (objet hors base, suffixe).

local _, ns = ...

local L = ns.L

local function fieldsOf(itemID, link)
    if ns.LiveItem.needed(itemID, link, ns.Data) then
        return ns.LiveItem.fields(link)
    end
    return ns.Data.item(itemID)
end

local function why(args)
    local link = args ~= "" and args or nil
    local itemID = link and ns.ItemLink.itemID(link)
    if not itemID then
        print(L.WHY_USAGE)
        return
    end
    local profile, player = ns.Data.ready() and ns.Profiles.active(), ns.Results.player()
    if not (profile and player) then
        print(L.WHY_NOT_READY)
        return
    end
    local fields = fieldsOf(itemID, link)
    if not (fields and fields.stats) then
        print(L.WHY_UNKNOWN:format(link))
        return
    end
    local stats = ns.StatValue and ns.StatValue.withDerived(fields.stats) or fields.stats
    print(L.WHY_HEADER:format(link))
    for _, line in ipairs(ns.WhyPresenter.lines(stats, profile.weights, L)) do
        print("  " .. line)
    end
    local view = ns.BadgePresenter.build(link, player, profile, ns.Data, ns.LiveItem.fields)
    print(view and L.WHY_GAIN:format(view.text) or L.WHY_NO_GAIN)
end

ns:RegisterCommand("why", why, "WHY_COMMAND_HELP")
