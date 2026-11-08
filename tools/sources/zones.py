"""CONTRAT
Zones voisines de Classic, saisies à la main (aucune source amont ne les donne).
  links() -> {areaID: {areaID...}} symétrique, sans boucle : passages à pied, bateaux et zeppelins
  neighbors(areas) -> {uiMapID: [uiMapID...] trié} ; areas = questie.area_map (areaID -> uiMapID) ;
    zone sans carte (absente ou 0) ignorée ; carte sans voisine connue absente
Identifiants de zone (AreaTable) de Classic, stables entre Forever et Classic Era ; les cartes (uiMapID)
viennent de areaIdToUiMapId de QuestieDB, comme le champ mapID des quêtes.
"""

# Royaumes de l'Est
DUN_MOROGH, BADLANDS, BLASTED_LANDS, SWAMP_OF_SORROWS = 1, 3, 4, 8
DUSKWOOD, WETLANDS, ELWYNN = 10, 11, 12
WESTERN_PLAGUELANDS, STRANGLETHORN, ALTERAC, LOCH_MODAN, WESTFALL = 28, 33, 36, 38, 40
DEADWIND, REDRIDGE, ARATHI, BURNING_STEPPES, HINTERLANDS, SEARING_GORGE = 41, 44, 45, 46, 47, 51
TIRISFAL, SILVERPINE, EASTERN_PLAGUELANDS, HILLSBRAD = 85, 130, 139, 267
UNDERCITY, STORMWIND, IRONFORGE = 1497, 1519, 1537
# Kalimdor
DUROTAR, DUSTWALLOW, AZSHARA, BARRENS = 14, 15, 16, 17
TELDRASSIL, DARKSHORE, MULGORE, ASHENVALE, FERALAS, FELWOOD = 141, 148, 215, 331, 357, 361
THOUSAND_NEEDLES, DESOLACE, STONETALON, TANARIS, UNGORO, MOONGLADE = 400, 405, 406, 440, 490, 493
WINTERSPRING, SILITHUS, ORGRIMMAR, THUNDER_BLUFF, DARNASSUS = 618, 1377, 1637, 1638, 1657

# Une ligne par passage, dans un seul sens ; links() ajoute le retour.
PASSAGES = (
    (ELWYNN, STORMWIND), (ELWYNN, WESTFALL), (ELWYNN, DUSKWOOD), (ELWYNN, REDRIDGE),
    (WESTFALL, DUSKWOOD), (DUSKWOOD, REDRIDGE), (DUSKWOOD, DEADWIND), (DUSKWOOD, STRANGLETHORN),
    (DEADWIND, SWAMP_OF_SORROWS), (SWAMP_OF_SORROWS, BLASTED_LANDS),
    (REDRIDGE, BURNING_STEPPES), (BURNING_STEPPES, SEARING_GORGE), (SEARING_GORGE, BADLANDS),
    (BADLANDS, LOCH_MODAN), (LOCH_MODAN, DUN_MOROGH), (DUN_MOROGH, IRONFORGE), (LOCH_MODAN, WETLANDS),
    (IRONFORGE, STORMWIND),  # tram des profondeurs
    (WETLANDS, ARATHI), (ARATHI, HILLSBRAD), (ARATHI, HINTERLANDS), (HILLSBRAD, HINTERLANDS),
    (HILLSBRAD, ALTERAC), (HILLSBRAD, SILVERPINE), (ALTERAC, SILVERPINE), (ALTERAC, WESTERN_PLAGUELANDS),
    (SILVERPINE, TIRISFAL), (TIRISFAL, UNDERCITY), (TIRISFAL, WESTERN_PLAGUELANDS),
    (WESTERN_PLAGUELANDS, EASTERN_PLAGUELANDS),
    (DUROTAR, ORGRIMMAR), (DUROTAR, BARRENS), (ORGRIMMAR, AZSHARA), (BARRENS, MULGORE),
    (MULGORE, THUNDER_BLUFF), (BARRENS, STONETALON), (BARRENS, ASHENVALE), (BARRENS, THOUSAND_NEEDLES),
    (BARRENS, DUSTWALLOW), (STONETALON, ASHENVALE), (STONETALON, DESOLACE), (ASHENVALE, DARKSHORE),
    (ASHENVALE, FELWOOD), (ASHENVALE, AZSHARA), (DARKSHORE, TELDRASSIL), (TELDRASSIL, DARNASSUS),
    (FELWOOD, WINTERSPRING), (FELWOOD, MOONGLADE), (WINTERSPRING, MOONGLADE), (DESOLACE, FERALAS),
    (FERALAS, THOUSAND_NEEDLES), (THOUSAND_NEEDLES, TANARIS), (TANARIS, UNGORO), (UNGORO, SILITHUS),
    # bateaux et zeppelins
    (WETLANDS, DUSTWALLOW), (WETLANDS, DARKSHORE), (BARRENS, STRANGLETHORN),
    (DUROTAR, TIRISFAL), (DUROTAR, STRANGLETHORN),
)


def links():
    out = {}
    for first, second in PASSAGES:
        out.setdefault(first, set()).add(second)
        out.setdefault(second, set()).add(first)
    return out


def neighbors(areas):
    out = {}
    for area, others in links().items():
        map_id = areas.get(area)
        if not map_id:
            continue
        maps = {areas.get(other) for other in others} - {None, 0, map_id}
        if maps:
            out[map_id] = sorted(maps)
    return out
