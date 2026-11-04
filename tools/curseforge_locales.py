"""CONTRAT
Échange les phrases avec le portail de traduction CurseForge (projet PROJECT_ID).
  push(phrases, skipped, token, opener=None, language="enUS") : envoie les phrases (format TableAdditions)
    dans `language`, sauf les clés de `skipped` (termes du jeu) ; RuntimeError sans jeton
  pull(locale, token, opener=None) -> {clé: texte} traduit sur le portail (non traduit : ignoré)
  write_community(directory, locale, phrases) -> directory/<langue>.json
opener(request) -> octets ; remplaçable pour que les tests n'utilisent jamais le réseau.
Jeton : CF_API_TOKEN dans .env ou l'environnement (curseforge.com, Paramètres > Jetons d'API).
Usage : python tools/curseforge_locales.py push|push-drafts|pull
  push-drafts : premiers jets (tools/locales/draft) envoyés comme traductions de départ
"""

import json
import os
import re
import sys
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

import gen_locales
import locale_map

PROJECT_ID = 1781853
BASE_URL = f"https://wow.curseforge.com/api/projects/{PROJECT_ID}/localization"
TIMEOUT_SECONDS = 60
ENTRY = re.compile(r'^L\["(\w+)"\]\s*=\s*"((?:[^"\\]|\\.)*)"', re.MULTILINE)


def _open(request):
    with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
        return response.read()


def _quote(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def push(phrases, skipped, token, opener=None, language="enUS"):
    if not token:
        raise RuntimeError("CF_API_TOKEN manquant (.env)")
    lua = "\n".join(f'L["{key}"] = {_quote(text)}' for key, text in phrases.items() if key not in skipped)
    metadata = json.dumps({"language": language, "formatType": "TableAdditions",
                           "missing-phrase-handling": "DoNothing"})
    boundary = uuid.uuid4().hex
    parts = [(name, value) for name, value in (("metadata", metadata), ("localizations", lua))]
    body = "".join(
        f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n' for name, value in parts
    ) + f"--{boundary}--\r\n"
    request = urllib.request.Request(
        f"{BASE_URL}/import", data=body.encode("utf-8"), method="POST",
        headers={"X-Api-Token": token, "Content-Type": f"multipart/form-data; boundary={boundary}"},
    )
    return (opener or _open)(request)


def pull(locale, token, opener=None):
    query = urllib.parse.urlencode({"lang": locale, "export-type": "TableAdditions", "unlocalized": "Ignore"})
    request = urllib.request.Request(f"{BASE_URL}/export?{query}", headers={"X-Api-Token": token})
    text = (opener or _open)(request).decode("utf-8")
    return {key: gen_locales.parse_locale(f'L.{key} = "{value}"')[key] for key, value in ENTRY.findall(text)}


def write_community(directory, locale, phrases):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / f"{locale}.json"
    path.write_text(json.dumps(phrases, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return path


def _token():
    env = gen_locales.ROOT / ".env"
    if env.exists():
        for line in env.read_text(encoding="utf-8").splitlines():
            if line.startswith("CF_API_TOKEN="):
                return line.split("=", 1)[1].strip().strip('"')
    return os.environ.get("CF_API_TOKEN", "")


def main(command):
    token = _token()
    if command == "push":
        phrases = gen_locales.parse_locale(gen_locales.ENUS_PATH.read_text(encoding="utf-8"))
        push(phrases, set(locale_map.TERMS), token)
        print(f"{len(phrases) - len(set(locale_map.TERMS) & set(phrases))} phrases envoyées")
    elif command == "push-drafts":
        for locale in locale_map.LOCALES:
            draft = json.loads((gen_locales.DRAFT_DIR / f"{locale}.json").read_text(encoding="utf-8"))
            draft.pop(gen_locales.TOC_KEY, None)
            push(draft, set(locale_map.TERMS), token, language=locale)
            print(f"{locale} : {len(set(draft) - set(locale_map.TERMS))} phrases")
    elif command == "pull":
        for locale in locale_map.LOCALES:
            phrases = pull(locale, token)
            write_community(gen_locales.COMMUNITY_DIR, locale, phrases)
            print(f"{locale} : {len(phrases)} phrases")
    else:
        raise SystemExit("Usage : python tools/curseforge_locales.py push|push-drafts|pull")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "")
