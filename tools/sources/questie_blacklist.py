"""CONTRAT
Liste noire de l'addon Questie (Database/Corrections/QuestieQuestBlacklist.lua, épinglée par questie.ADDON_COMMIT).
  load(source_dir) -> {questID} dont la valeur vaut vrai sur Forever ; fichier absent : ensemble vide
Seule la table `questsToBlacklist` de Load() est lue (les listes automatiques Wotlk, Titan, SoD sont ignorées).
Valeur : expression évaluée avec FOREVER_SYMBOLS (contenu Era, ni SoD ni Titan) ; HIDE_ON_MAP (caché sur la
carte seulement), false et tout symbole inconnu (phases de contenu, région) : quête gardée. Clé répétée : la
dernière l'emporte, comme en Lua. Aucun code amont exécuté : seuls des jetons connus atteignent eval.
"""

import re
from pathlib import Path


# Valeurs de la liste noire pour Forever : contenu Era (Expansions.Current = Era), ni SoD ni Titan.
FOREVER_SYMBOLS = {
    "Expansions.Current": "0", "Expansions.Era": "0", "Expansions.Tbc": "1", "Expansions.Wotlk": "2",
    "Expansions.Cata": "3", "Expansions.MoP": "4", "Questie.IsSoD": "False", "Questie.IsTitanReforged": "False",
    "Questie.IsForever": "True", "true": "True", "false": "False", "HIDE_ON_MAP": "False",
    "and": "and", "or": "or", "not": "not", "(": "(", ")": ")",
    "==": "==", "~=": "!=", "<": "<", ">": ">", "<=": "<=", ">=": ">=",
}
BLACKLIST_TOKEN = re.compile(r"\s*([A-Za-z_][\w.]*|==|~=|<=|>=|[<>()])")
BLACKLIST_ENTRY = re.compile(r"^\s*\[(\d+)\]\s*=\s*(.+?),?\s*(?:--.*)?$")


def _forever_value(expression):
    """Valeur de l'expression sur Forever ; None si un symbole est inconnu (entrée ignorée)."""
    tokens, position = [], 0
    while position < len(expression.rstrip()):
        match = BLACKLIST_TOKEN.match(expression, position)
        if not match or match.group(1) not in FOREVER_SYMBOLS:
            return None
        tokens.append(FOREVER_SYMBOLS[match.group(1)])
        position = match.end()
    try:
        return bool(eval(" ".join(tokens), {"__builtins__": {}}, {}))  # noqa: S307 (jetons de FOREVER_SYMBOLS seuls)
    except SyntaxError:
        return None


def load(source_dir):
    path = Path(source_dir) / "QuestieQuestBlacklist.lua"
    if not path.exists():
        return set()
    text = path.read_text(encoding="utf-8")
    start = text.index("local questsToBlacklist = {")
    values = {}
    for line in text[start:].splitlines()[1:]:
        if line.strip() == "}":
            break
        match = BLACKLIST_ENTRY.match(line)
        if match:
            values[int(match.group(1))] = _forever_value(match.group(2).rstrip(","))
    return {quest_id for quest_id, value in values.items() if value}
