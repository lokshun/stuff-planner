"""Construit l'archive installable des deux addons (`make zip`).

CONTRAT
- build(root, out_dir, version) -> Path de `StuffPlanner-<version>.zip`, qui contient
  `StuffPlanner/` et `StuffPlanner_Data/`, chacun avec ses TOC Forever (`_Camelot`) et
  Classic Era (`_Vanilla`) et une copie de `LICENSE`.
- `@project-version@` est remplacé dans les .toc, .lua et .xml ; les fichiers cachés
  (`Libs/.versions`) sont exclus.
- Lève PackageError si la base n'est pas générée, si un TOC manque, si les `## Interface`
  des deux addons diffèrent pour une saveur, ou si un fichier cité par un TOC
  (ou par un XML inclus) est absent.
- version() : variable VERSION, sinon `git describe --tags --always --dirty`.
"""

import os
import re
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDONS = ("StuffPlanner", "StuffPlanner_Data")
FLAVORS = ("Camelot", "Vanilla")
TOKEN = "@project-version@"
TEXT_SUFFIXES = {".toc", ".lua", ".xml"}
XML_FILE = re.compile(r'<(Script|Include)\s+file="([^"]+)"')


class PackageError(Exception):
    pass


def toc_files(toc):
    files = []
    for line in toc.read_text(encoding="utf-8-sig").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            line = re.sub(r"\s*(\[[^\]]*\])+\s*$", "", line)  # directives en fin de ligne
            files.append(line.replace("\\", "/"))
    return files


def xml_files(addon_dir, rel):
    """Fichiers cités par un XML (relatifs à l'addon), inclusions suivies."""
    found = []
    path = addon_dir / rel
    if not path.is_file():
        return found
    base = Path(rel).parent
    for _, ref in XML_FILE.findall(path.read_text(encoding="utf-8-sig")):
        child = (base / ref.replace("\\", "/")).as_posix()
        found.append(child)
        if child.endswith(".xml"):
            found.extend(xml_files(addon_dir, child))
    return found


def missing_files(addon_dir):
    missing = set()
    for toc in sorted(addon_dir.glob("*.toc")):
        for rel in toc_files(toc):
            refs = [rel] + (xml_files(addon_dir, rel) if rel.endswith(".xml") else [])
            missing.update(ref for ref in refs if not (addon_dir / ref).is_file())
    return sorted(missing)


def interface(toc):
    match = re.search(r"^## Interface:\s*(\S+)", toc.read_text(encoding="utf-8-sig"), re.M)
    return match and match.group(1)


def check(root):
    if not (root / "StuffPlanner_Data").is_dir():
        raise PackageError("StuffPlanner_Data absent : lancer make data")
    for flavor in FLAVORS:
        tocs = [root / addon / f"{addon}_{flavor}.toc" for addon in ADDONS]
        for toc in tocs:
            if not toc.is_file():
                raise PackageError(f"TOC absent : {toc.name}")
        values = {interface(toc) for toc in tocs}
        if len(values) != 1:
            raise PackageError(f"Interface différente entre les TOC {flavor} : {sorted(map(str, values))}")
    for addon in ADDONS:
        missing = missing_files(root / addon)
        if missing:
            raise PackageError(f"{addon} : fichiers absents : {', '.join(missing)}")


def build(root, out_dir, version):
    root, out_dir = Path(root), Path(out_dir)
    check(root)
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"StuffPlanner-{version}.zip"
    license_text = (root / "LICENSE").read_bytes()
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
        for addon in ADDONS:
            for file in sorted((root / addon).rglob("*")):
                rel = file.relative_to(root / addon)
                if file.is_dir() or any(part.startswith(".") for part in rel.parts):
                    continue
                data = file.read_bytes()
                if file.suffix in TEXT_SUFFIXES:
                    data = data.replace(TOKEN.encode(), version.encode())
                archive.writestr(f"{addon}/{rel.as_posix()}", data)
            archive.writestr(f"{addon}/LICENSE", license_text)
    return path


def version():
    if os.environ.get("VERSION"):
        return os.environ["VERSION"]
    result = subprocess.run(["git", "describe", "--tags", "--always", "--dirty"],
                            capture_output=True, text=True, check=False, cwd=ROOT)
    return result.stdout.strip() or "dev"


def main():
    try:
        path = build(ROOT, ROOT / "build", version())
    except PackageError as err:
        print(f"make zip : {err}", file=sys.stderr)
        return 1
    print(f"Archive : {path.relative_to(ROOT).as_posix()} ({path.stat().st_size // 1024} Ko)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
