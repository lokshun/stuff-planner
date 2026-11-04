"""CONTRAT
Décodage des chaînes SP1 de /splan export (StuffPlanner/Data/Export.lua), sans bibliothèque Lua.
  decode(text) -> valeur Lua relue (dict, list, int, float, str, bool, None) ; ExportError(code) sinon,
    code = "prefix" | "print" | "deflate" | "serializer" (ceux d'Export.decode)
  Table Lua 1..n -> list (table vide comprise), autre table -> dict.
"""

import re
import zlib

PREFIX = "SP1:"
PRINT_ALPHABET = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789()"
PRINT_VALUES = {char: index for index, char in enumerate(PRINT_ALPHABET)}
TOKEN = re.compile(r"\^(.)([^^]*)", re.DOTALL)
INTEGER = re.compile(r"-?\d+")
ESCAPED = {"~z": "\x1e", "~{": "\x7f", "~|": "~", "~}": "^"}


class ExportError(ValueError):
    def __init__(self, code):
        super().__init__(code)
        self.code = code


def _decode_print(text):
    value, bits = 0, 0
    for char in text:
        if char not in PRINT_VALUES:
            raise ExportError("print")
        value |= PRINT_VALUES[char] << bits
        bits += 6
    return (value & ((1 << (bits // 8 * 8)) - 1)).to_bytes(bits // 8, "little")


def _inflate(data):
    inflater = zlib.decompressobj(-15)
    try:
        out = inflater.decompress(data) + inflater.flush()
    except zlib.error as error:
        raise ExportError("deflate") from error
    if not inflater.eof:
        raise ExportError("deflate")
    return out.decode("latin-1")


def _unescape(text):
    def one(match):
        escape = match.group(0)
        return ESCAPED.get(escape) or chr(ord(escape[1]) - 64)

    return re.sub(r"~.", one, text, flags=re.DOTALL).encode("latin-1").decode("utf-8", "replace")


def _number(text):
    if INTEGER.fullmatch(text):
        return int(text)
    try:
        return float(text)
    except ValueError as error:
        raise ExportError("serializer") from error


def _as_python(table):
    if all(isinstance(key, int) for key in table) and sorted(table) == list(range(1, len(table) + 1)):
        return [table[index] for index in range(1, len(table) + 1)]
    return table


def _value(token, tokens):
    kind, data = token
    if kind == "S":
        return _unescape(data)
    if kind == "N":
        return _number(data)
    if kind == "F":
        exponent = next(tokens, None)
        if not exponent or exponent[0] != "f":
            raise ExportError("serializer")
        return _number(data) * 2.0 ** _number(exponent[1])
    if kind in ("B", "b", "Z"):
        return {"B": True, "b": False, "Z": None}[kind]
    if kind == "T":
        table = {}
        while True:
            key = next(tokens, None)
            if key is None:
                raise ExportError("serializer")
            if key[0] == "t":
                return _as_python(table)
            value = next(tokens, None)
            if value is None:
                raise ExportError("serializer")
            table[_value(key, tokens)] = _value(value, tokens)
    raise ExportError("serializer")


def _deserialize(text):
    tokens = iter(TOKEN.findall(text))
    if not text.startswith("^1") or next(tokens) != ("1", ""):
        raise ExportError("serializer")
    first = next(tokens, None)
    if first is None or first[0] == "^":
        raise ExportError("serializer")
    value = _value(first, tokens)
    if next(tokens, None) != ("^", ""):
        raise ExportError("serializer")
    return value


def decode(text):
    text = text.strip()
    if not text.startswith(PREFIX):
        raise ExportError("prefix")
    value = _deserialize(_inflate(_decode_print(text[len(PREFIX):])))
    if not isinstance(value, (dict, list)):
        raise ExportError("serializer")
    return value
