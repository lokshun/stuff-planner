"""CONTRAT
Estime la mémoire occupée en jeu par StuffPlanner_Data, sans lancer Lua.
  value_bytes(value, strings) -> octets de la valeur telle qu'émise par emit_lua.lua_value ;
    `strings` (set) reçoit les chaînes déjà comptées : une chaîne Lua est internée, comptée une fois
  estimate(tables) -> octets des tables `ns.<Table>` construites par les fichiers émis
    (une chaîne emit_lua.record_string par enregistrement)
Modèle : Lua 5.1, client 64 bits. Table 64 o, case de tableau 16 o, nœud de hachage 40 o,
chaîne 24 o + longueur + 1. Tailles des constructeurs : luaO_int2fb, hachage arrondi à 2^k.
Ne compte ni le code de l'addon principal ni les caches de DataProvider.
"""

import emit_lua

TABLE = 64
TVALUE = 16
NODE = 40
STRING = 25


def _fb_size(count):
    """Taille réservée par OP_NEWTABLE pour `count` éléments (luaO_int2fb puis luaO_fb2int)."""
    exponent = 0
    while count >= 16:
        count = (count + 1) >> 1
        exponent += 1
    return count << exponent


def _node_count(count):
    if count == 0:
        return 0
    size = 1
    while size < _fb_size(count):
        size <<= 1
    return size


def _string_bytes(text, strings):
    if text in strings:
        return 0
    strings.add(text)
    return STRING + len(text.encode("utf-8"))


def value_bytes(value, strings):
    if isinstance(value, str):
        return _string_bytes(value, strings)
    if isinstance(value, (list, tuple)):
        total = TABLE + TVALUE * _fb_size(len(value))
        return total + sum(value_bytes(item, strings) for item in value)
    if isinstance(value, dict):
        total = TABLE + NODE * _node_count(len(value))
        for key, item in value.items():
            total += value_bytes(key, strings) + value_bytes(item, strings)
        return total
    return 0


def estimate(tables):
    strings = set()
    total = 0
    for table, records in tables.items():
        encoded = {
            record["id"]: emit_lua.record_string(emit_lua.encode_record(table, record))
            for record in records
        }
        total += _string_bytes(emit_lua.lua_name(table), strings) + value_bytes(encoded, strings)
    return total
