"""CONTRAT
Envoie le zip d'une version sur CurseForge (projet PROJECT_ID), avec la section du CHANGELOG en notes.
  changelog_section(text, version) -> corps de la section « ## <version> » (titre exclu, jusqu'à la suivante) ;
    ValueError si absente
  upload(archive, version, notes, token, opener=None) -> id du fichier CurseForge ; RuntimeError sans jeton ;
    versions de jeu GAME_VERSIONS (Classic Era 1.15.9 et Forever 1.60.1), type release, notes en Markdown
opener(request) -> octets ; remplaçable pour que les tests n'utilisent jamais le réseau.
Jeton : CF_API_TOKEN de .env (guillemets retirés) ou de l'environnement, comme curseforge_locales.
Usage : python tools/curseforge_upload.py <version>  (zip build/StuffPlanner-<version>.zip de `make zip`)
"""

import json
import re
import sys
import urllib.request
import uuid
from pathlib import Path

from curseforge_locales import PROJECT_ID, _token

ROOT = Path(__file__).resolve().parent.parent
UPLOAD_URL = f"https://wow.curseforge.com/api/projects/{PROJECT_ID}/upload-file"
GAME_VERSIONS = (16630, 17053)  # 1.15.9, 1.60.1 (ids de wow.curseforge.com/api/game/versions)
TIMEOUT_SECONDS = 300


def _open(request):
    with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
        return response.read()


def changelog_section(text, version):
    match = re.search(r"^## " + re.escape(version) + r"\b.*?\n(.*?)(?=^## |\Z)", text, re.M | re.S)
    if not match:
        raise ValueError(f"section {version} absente du CHANGELOG")
    return match.group(1).strip() + "\n"


def upload(archive, version, notes, token, opener=None):
    if not token:
        raise RuntimeError("CF_API_TOKEN manquant (.env ou environnement)")
    archive = Path(archive)
    metadata = {
        "changelog": notes,
        "changelogType": "markdown",
        "displayName": f"Stuff Planner {version}",
        "gameVersions": list(GAME_VERSIONS),
        "releaseType": "release",
    }
    boundary = uuid.uuid4().hex
    body = b"".join([
        f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\n\r\n'.encode(),
        json.dumps(metadata).encode(),
        f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{archive.name}"\r\n'
        "Content-Type: application/zip\r\n\r\n".encode(),
        archive.read_bytes(),
        f"\r\n--{boundary}--\r\n".encode(),
    ])
    request = urllib.request.Request(
        UPLOAD_URL, data=body, method="POST",
        headers={"X-Api-Token": token, "Content-Type": f"multipart/form-data; boundary={boundary}",
                 "User-Agent": "stuff-planner-release"},
    )
    return json.loads((opener or _open)(request))["id"]


def main(version):
    archive = ROOT / "build" / f"StuffPlanner-{version}.zip"
    if not archive.exists():
        raise SystemExit(f"{archive} absent : lancer d'abord VERSION={version} make zip")
    notes = changelog_section((ROOT / "CHANGELOG.md").read_text(encoding="utf-8"), version)
    print(f"Fichier CurseForge {upload(archive, version, notes, _token())} envoyé ({archive.name})")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage : python tools/curseforge_upload.py <version>")
    main(sys.argv[1])
