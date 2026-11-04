"""CONTRAT
Lit des constructeurs de table Lua sans jamais exécuter de Lua.
  parse(text, resolve=None, start=0) -> valeur de l'expression en position `start` ; ValueError si
    la syntaxe est hors du sous-ensemble (littéraux, tables, + - * /, chemins a.b, appels)
  long_strings(text) -> contenus de `= [[...]]`, dans l'ordre du fichier
  load_body(text) -> position de la table renvoyée par la première fonction `X:Load()`, ou None
Une table devient un dict {clé: valeur} : positions à partir de 1, trous de nil conservés par
absence de clé. resolve(chemin) donne la valeur de `a.b` ; sans réponse, ou pour un appel ou un
calcul dessus, la valeur est UNRESOLVED.
"""

import re

UNRESOLVED = type("Unresolved", (), {"__repr__": lambda self: "UNRESOLVED"})()

SKIP = re.compile(r"(?:\s+|--\[\[.*?\]\]|--[^\n]*)*", re.DOTALL)
NUMBER = re.compile(r"\d+\.\d*(?:[eE][+-]?\d+)?|\.\d+|0[xX][0-9a-fA-F]+|\d+(?:[eE][+-]?\d+)?")
NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*")
LONG_STRING = re.compile(r"=\s*\[\[(.*?)\]\]", re.DOTALL)
LOAD_FUNCTION = re.compile(r"function\s+\w+:Load\(\).*?\breturn\s*(?=\{)", re.DOTALL)
ESCAPES = {"n": "\n", "r": "\r", "t": "\t", "a": "\a", "b": "\b", "f": "\f", "v": "\v", "\n": "\n"}
CONSTANTS = {"nil": None, "true": True, "false": False}
OPERATORS = {
    "+": lambda a, b: a + b,
    "-": lambda a, b: a - b,
    "*": lambda a, b: a * b,
    "/": lambda a, b: a / b,
}


def long_strings(text):
    return LONG_STRING.findall(text)


def load_body(text):
    match = LOAD_FUNCTION.search(text)
    return match.end() if match else None


def parse(text, resolve=None, start=0):
    return _Parser(text, resolve or (lambda path: UNRESOLVED), start).expression()


class _Parser:
    def __init__(self, text, resolve, pos):
        self.text = text
        self.resolve = resolve
        self.pos = pos

    def fail(self, message):
        line = self.text.count("\n", 0, self.pos) + 1
        raise ValueError(f"ligne {line} : {message}")

    def skip(self):
        self.pos = SKIP.match(self.text, self.pos).end()

    def peek(self):
        self.skip()
        return self.text[self.pos : self.pos + 1]

    def accept(self, char):
        if self.peek() == char:
            self.pos += 1
            return True
        return False

    def expect(self, char):
        if not self.accept(char):
            self.fail(f"« {char} » attendu")

    def expression(self):
        left = self.term()
        while self.peek() in OPERATORS:
            operator = OPERATORS[self.text[self.pos]]
            self.pos += 1
            right = self.term()
            if isinstance(left, (int, float)) and isinstance(right, (int, float)):
                left = operator(left, right)
            else:
                left = UNRESOLVED
        return left

    def term(self):
        char = self.peek()
        if char == "{":
            return self.table()
        if char in ('"', "'"):
            return self.string(char)
        if char == "[" and self.text.startswith("[[", self.pos):
            return self.long_string()
        if char == "(":
            self.pos += 1
            value = self.expression()
            self.expect(")")
            return value
        if char == "-":
            self.pos += 1
            value = self.term()
            return -value if isinstance(value, (int, float)) else UNRESOLVED
        number = NUMBER.match(self.text, self.pos)
        if number:
            self.pos = number.end()
            return _number(number.group())
        name = NAME.match(self.text, self.pos)
        if name:
            self.pos = name.end()
            return self.named(name.group())
        return self.fail(f"expression attendue, trouvé « {char} »")

    def named(self, path):
        if self.peek() == "(":
            self.call_arguments()
            return UNRESOLVED
        if path == "not":
            self.term()
            return UNRESOLVED
        if path in CONSTANTS:
            return CONSTANTS[path]
        return self.resolve(path)

    def call_arguments(self):
        self.expect("(")
        while not self.accept(")"):
            self.expression()
            self.accept(",")

    def table(self):
        self.expect("{")
        result = {}
        position = 1
        while not self.accept("}"):
            key = self.field_key()
            value = self.expression()
            if key is None:
                key = position
                position += 1
            if value is not None:
                result[key] = value
            if not (self.accept(",") or self.accept(";")) and self.peek() != "}":
                self.fail("« , » ou « } » attendu")
        return result

    def field_key(self):
        char = self.peek()
        if char == "[" and not self.text.startswith("[[", self.pos):
            self.pos += 1
            key = self.expression()
            self.expect("]")
            self.expect("=")
            return key
        name = NAME.match(self.text, self.pos)
        if name and "." not in name.group():
            after = SKIP.match(self.text, name.end()).end()
            if self.text[after : after + 1] == "=" and self.text[after + 1 : after + 2] != "=":
                self.pos = after + 1
                return name.group()
        return None

    def string(self, quote):
        self.pos += 1
        parts = []
        while True:
            if self.pos >= len(self.text):
                self.fail("chaîne non fermée")
            char = self.text[self.pos]
            self.pos += 1
            if char == quote:
                return "".join(parts)
            if char == "\\":
                parts.append(self.escape())
            else:
                parts.append(char)

    def escape(self):
        char = self.text[self.pos : self.pos + 1]
        digits = re.compile(r"\d{1,3}").match(self.text, self.pos)
        if digits:
            self.pos = digits.end()
            return chr(int(digits.group()))
        self.pos += 1
        return ESCAPES.get(char, char)

    def long_string(self):
        end = self.text.find("]]", self.pos)
        if end < 0:
            self.fail("chaîne longue non fermée")
        value = self.text[self.pos + 2 : end]
        self.pos = end + 2
        return value


def _number(token):
    if token[:2] in ("0x", "0X"):
        return int(token, 16)
    if any(char in token for char in ".eE"):
        return float(token)
    return int(token)
