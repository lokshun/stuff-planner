"""CONTRAT
Génère StuffPlanner/Locales/<langue>.lua (langues de locale_map.LOCALES) et les `## Notes-<langue>` des TOC.
Priorité par clé : terme du jeu (wago.tools, locale_map.TERMS) > communauté CurseForge
(tools/locales/community/<langue>.json, make locales-pull) > premier jet (tools/locales/draft/<langue>.json).
Une traduction dont les jetons de format diffèrent de enUS est refusée (avertissement) : l'étage suivant s'applique.
frFR reste écrit à la main : seul un rapport des écarts avec les termes du jeu est affiché.
  parse_locale(text) -> {clé: texte} dans l'ordre du fichier (L.X = "..." [.. "..."])
  tokens(text) -> [jeton] : %s, %d, %.1f, %%, |cXXXXXXXX, |r, |n
  clean(text) -> libellé : sans `:` ni `|n` final, espaces insécables remplacés, majuscule initiale
  game_terms(locale, strings, talents) -> {clé: texte} ; strings = {BaseTag: texte}, talents = {ID: nom}
  merge(reference, layers) -> ({clé: (texte, étage)}, [avertissement]) ; layers = [(étage, {clé: texte})]
  render(locale, values) -> texte du fichier Lua
  toc_notes(text, notes) -> TOC où `## Notes-<langue>` est remplacé ou inséré après Notes-frFR
Usage : python tools/gen_locales.py ; une ligne par langue, puis les avertissements.
"""

import csv
import json
import re
import sys
from pathlib import Path

import locale_map
from sources import wago

ROOT = Path(__file__).resolve().parents[1]
ADDON_DIR = ROOT / "StuffPlanner"
LOCALES_DIR = ADDON_DIR / "Locales"
ENUS_PATH = LOCALES_DIR / "enUS.lua"
FRFR_PATH = LOCALES_DIR / "frFR.lua"
DRAFT_DIR = ROOT / "tools" / "locales" / "draft"
COMMUNITY_DIR = ROOT / "tools" / "locales" / "community"
CACHE_DIR = ROOT / "tools" / "cache" / "wago_locales"
TOCS = ("StuffPlanner_Camelot.toc", "StuffPlanner_Vanilla.toc")
TABLES = ("GlobalStrings", "TalentTab")
TOC_KEY = "_TOC_NOTES"

ENTRY = re.compile(r'^L\.(\w+)\s*=\s*((?:"(?:[^"\\]|\\.)*"\s*(?:\.\.\s*)?)+)', re.MULTILINE)
LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')
TOKEN = re.compile(r"%[-+ #0]*\d*(?:\.\d+)?[sdfiqx%]|\|c[0-9a-fA-F]{8}|\|r|\|n")
ESCAPES = {"n": "\n", "t": "\t", '"': '"', "\\": "\\", "'": "'"}


def _unescape(text):
    return re.sub(r"\\(.)", lambda match: ESCAPES.get(match.group(1), match.group(1)), text)


def parse_locale(text):
    return {
        key: "".join(_unescape(part) for part in LITERAL.findall(body))
        for key, body in ENTRY.findall(text)
    }


def tokens(text):
    return TOKEN.findall(text)


def clean(text):
    text = text.replace("\u00a0", " ").strip()
    text = re.sub(r"(\|n)+$", "", text).strip()
    text = text.rstrip(":：").strip()
    return text[:1].upper() + text[1:]


def game_terms(locale, strings, talents):
    terms = {}
    for key, (table, ref) in locale_map.TERMS.items():
        if locale in locale_map.EXCLUDED.get(key, ()):
            continue
        value = strings.get(ref) if table == "GlobalStrings" else talents.get(ref)
        if value:
            terms[key] = clean(value)
    return terms


def merge(reference, layers):
    values, warnings = {}, []
    chosen = {}
    for layer, table in layers:
        for key, text in table.items():
            if key == TOC_KEY:
                continue
            if key not in reference:
                warnings.append(f"{layer} : clé inconnue {key}")
            elif key not in chosen:
                if tokens(text) == tokens(reference[key]):
                    chosen[key] = (text, layer)
                else:
                    warnings.append(f"{layer} : jetons différents de enUS pour {key}")
    for key in reference:
        if key in chosen:
            values[key] = chosen[key]
    return values, warnings


def _quote(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def render(locale, values):
    lines = [
        "-- Fichier généré par tools/gen_locales.py (make locales) : ne pas éditer.",
        "-- Sources : termes du jeu (wago.tools), traductions CurseForge, premier jet (tools/locales/draft).",
        "local ADDON = ...",
        "",
        f'local L = LibStub("AceLocale-3.0"):NewLocale(ADDON, "{locale}")',
        "if not L then",
        "    return",
        "end",
        "",
    ]
    lines += [f"L.{key} = {_quote(text)}" for key, (text, _) in values.items()]
    return "\n".join(lines) + "\n"


def toc_notes(text, notes):
    lines = [line for line in text.split("\n")
             if not any(line.startswith(f"## Notes-{locale}:") for locale in notes)]
    anchor = next(i for i, line in enumerate(lines) if line.startswith("## Notes-frFR:"))
    added = [f"## Notes-{locale}: {notes[locale]}" for locale in sorted(notes)]
    return "\n".join(lines[:anchor + 1] + added + lines[anchor + 1:])


def read_global_strings(source_dir):
    strings = {}
    with (Path(source_dir) / "GlobalStrings.csv").open(encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            strings.setdefault(row["BaseTag"], row["TagText_lang"])
    return strings


def read_talents(source_dir):
    return {talent: row["Name_lang"] for talent, row in wago.read_table(source_dir, "TalentTab", ["Name_lang"]).items()}


def _read_json(path):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def _sources(locale):
    source_dir = wago.fetch_locale(CACHE_DIR, locale, TABLES)
    return read_global_strings(source_dir), read_talents(source_dir)


def _frfr_report(reference):
    terms = game_terms("frFR", *_sources("frFR"))
    frfr = parse_locale(FRFR_PATH.read_text(encoding="utf-8"))
    return [f"frFR : {key} = « {frfr.get(key)} », jeu : « {text} »"
            for key, text in terms.items() if key in reference and frfr.get(key) != text]


def main():
    reference = parse_locale(ENUS_PATH.read_text(encoding="utf-8"))
    notes, warnings = {}, []
    for locale in locale_map.LOCALES:
        draft = _read_json(DRAFT_DIR / f"{locale}.json")
        community = _read_json(COMMUNITY_DIR / f"{locale}.json")
        layers = [("jeu", game_terms(locale, *_sources(locale))), ("communauté", community), ("brouillon", draft)]
        values, problems = merge(reference, layers)
        warnings += [f"{locale} : {problem}" for problem in problems]
        (LOCALES_DIR / f"{locale}.lua").write_bytes(render(locale, values).encode("utf-8"))
        counts = {layer: sum(1 for _, source in values.values() if source == layer) for layer, _ in layers}
        print(f"{locale} : {len(values)}/{len(reference)} clés ({', '.join(f'{n} {k}' for k, n in counts.items())})")
        note = community.get(TOC_KEY) or draft.get(TOC_KEY)
        if note:
            notes[locale] = note
    for toc in TOCS:
        path = ADDON_DIR / toc
        path.write_bytes(toc_notes(path.read_text(encoding="utf-8"), notes).encode("utf-8"))
    for line in warnings + _frfr_report(reference):
        print(line)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
