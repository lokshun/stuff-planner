"""CONTRAT
Cache disque des sources téléchargées, dans tools/cache (ignoré par git).
  complete(target, urls, opener=None) -> `target`, après téléchargement des fichiers manquants ;
    urls = {nom de fichier: URL} ; RuntimeError si le réseau échoue, aucun fichier partiel laissé.
opener(url) -> octets ; remplaçable pour que les tests n'utilisent jamais le réseau.
"""

import urllib.request
from pathlib import Path

TIMEOUT_SECONDS = 120
USER_AGENT = "StuffPlanner-build/1.0"


def _download(url):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
        return response.read()


def complete(target, urls, opener=None):
    opener = opener or _download
    target = Path(target)
    target.mkdir(parents=True, exist_ok=True)
    for name, url in urls.items():
        destination = target / name
        if destination.exists():
            continue
        try:
            data = opener(url)
        except OSError as error:
            raise RuntimeError(f"Téléchargement de {url} impossible : {error}") from error
        partial = destination.with_name(name + ".partial")
        partial.write_bytes(data)
        partial.replace(destination)
    return target
