"""CONTRAT
Importe les EP de niveau 60 de WoWSims Forever (MIT) vers tools/weights_input/<classe>_<spé>_60.json.
Source : ui/specs/**/presets.ts à la révision REVISION, mis en cache dans tools/cache/wowsims-<rév>/.
  parse_presets(textes) -> {libellé: {StatWoWSims: EP}} des presets du premier texte (libellés propres à
    un fichier) ; résout `makePresetEpWeights('X', Nom)` par les `const Nom = Stats.fromMap(...)` et
    alias `const A = B;` de tous les textes ; preset non résolu omis
  convert(ep, rôle) -> (ep au format de gen_weights, stats ignorées triées) ; rôle dans ROLES ;
    ratings Forever -> EP par % (RATING_PER_PERCENT) ; un seul rating de toucher et de critique sur
    Forever, rangé en HIT/CRIT par la base : les rôles à sorts pondèrent aussi SPELL_HIT/SPELL_CRIT ;
    puissance des sorts = dégâts + soins (les objets « dégâts et soins » servent aux deux)
  build_profile(classe, spé, entrée SPECS, presets) -> (entrée gen_weights, ignorées) ; ValueError sinon
  SPECS : {(classe, spé): {file, preset, role}} ; spés absentes = pas d'EP dans WoWSims (estimations)
Usage : python tools/import_wowsims.py ; écrit les JSON puis lancer `make weights`.
"""

import json
import re
import sys
from pathlib import Path

from sources import cache

ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "tools" / "weights_input"
REVISION = "62c923ee3d1066cf90dc9432200b53ee7029e66c"
REVISION_DATE = "2026-11-02"
RAW_URL = "https://raw.githubusercontent.com/wowsims/forever/{rev}/ui/specs/{path}"
DECIMALS = 4

FILES = (
    "warrior/dps/presets.ts", "warrior/protection/presets.ts", "rogue/dps/presets.ts",
    "shaman/elemental/presets.ts", "shaman/enhancement/presets.ts", "paladin/retribution/presets.ts",
    "priest/dps/presets.ts", "priest/healer/presets.ts", "druid/balance/presets.ts",
    "druid/feralcat/presets.ts", "druid/feral_ep.ts",
)


def _spec(path, preset, role):
    return {"file": path, "preset": preset, "role": role}


SPECS = {
    ("WARRIOR", "ARMS"): _spec("warrior/dps/presets.ts", "Pre-BiS - Arms", "melee"),
    ("WARRIOR", "FURY"): _spec("warrior/dps/presets.ts", "Pre-BiS - Fury", "melee"),
    ("WARRIOR", "PROTECTION"): _spec("warrior/protection/presets.ts", "Pre-BiS (Defense Cap)", "tank"),
    ("ROGUE", "ASSASSINATION"): _spec("rogue/dps/presets.ts", "Assassination", "melee"),
    ("ROGUE", "COMBAT"): _spec("rogue/dps/presets.ts", "Combat Sinister", "melee"),
    ("ROGUE", "SUBTLETY"): _spec("rogue/dps/presets.ts", "Subtlety", "melee"),
    ("SHAMAN", "ELEMENTAL"): _spec("shaman/elemental/presets.ts", "Testing", "caster"),
    ("SHAMAN", "ENHANCEMENT"): _spec("shaman/enhancement/presets.ts", "Pre-BiS", "melee"),
    ("PALADIN", "RETRIBUTION"): _spec("paladin/retribution/presets.ts", "Unsealed Wrath", "melee"),
    ("PRIEST", "SHADOW"): _spec("priest/dps/presets.ts", "Shadow", "caster"),
    ("PRIEST", "HOLY"): _spec("priest/healer/presets.ts", "Holy Single-Target", "healer"),
    ("PRIEST", "DISCIPLINE"): _spec("priest/healer/presets.ts", "Disc Single-Target", "healer"),
    ("DRUID", "BALANCE"): _spec("druid/balance/presets.ts", "P1", "caster"),
    ("DRUID", "FERAL"): _spec("druid/feralcat/presets.ts", "Cat", "melee"),
}

# Rôle -> (stat de référence, plafonds en %, total talents compris : statCaps de WoWSims, 17 % des sorts
# contre un boss de niveau 63 d'après Icy Veins).
ROLES = {
    "melee": ("StatAttackPower", {"HIT": 8}),
    "tank": ("StatStamina", {"HIT": 8}),
    "caster": ("StatSpellPower", {"HIT": 17, "SPELL_HIT": 17}),
    "healer": ("StatHealingPower", {}),
}
SPELL_ROLES = ("caster", "healer")

# Ratings par % sur Forever (sim/core/base_stats_auto_gen.go) ; défense : 1 rating par point.
RATINGS = {
    "StatHitRating": ("StatMeleeHit", 10),
    "StatCritRating": ("StatMeleeCrit", 14),
    "StatHasteRating": ("StatMeleeHaste", 10),
    "StatDodgeRating": ("StatDodge", 12),
    "StatParryRating": ("StatParry", 15),
    "StatBlockRating": ("StatBlock", 5),
    "StatDefenseRating": ("StatDefense", 1),
}
SPELL_TWINS = {"StatMeleeHit": "StatSpellHit", "StatMeleeCrit": "StatSpellCrit"}
RENAMED = {
    "StatArcaneDamage": "StatArcanePower", "StatFireDamage": "StatFirePower",
    "StatFrostDamage": "StatFrostPower", "StatHolyDamage": "StatHolyPower",
    "StatNatureDamage": "StatNaturePower", "StatShadowDamage": "StatShadowPower",
    "StatSpellPiercing": "StatSpellPenetration",
}
KEPT = frozenset({
    "StatStrength", "StatAgility", "StatStamina", "StatIntellect", "StatSpirit", "StatAttackPower",
    "StatRangedAttackPower", "StatMP5", "StatArmor", "StatBlockValue", "StatSpellDamage",
    "StatHealingPower", "PseudoStatMainHandDps", "PseudoStatRangedDps",
})

ENTRY = re.compile(r"\[(?:Pseudo)?Stat\.(\w+)\]:\s*(-?[\d.]+)")
NAMED_MAP = re.compile(r"const (\w+) = (?=Stats\.fromMap\()")
ALIAS = re.compile(r"const (\w+) = (\w+);")
PRESET = re.compile(r"makePresetEpWeights\(\s*'([^']+)',\s*")


def _call_body(text, start):
    """Texte entre la parenthèse ouvrante de `Stats.fromMap(` en `start` et sa fermante."""
    depth = 0
    for i in range(text.index("(", start), len(text)):
        depth += {"(": 1, ")": -1}.get(text[i], 0)
        if depth == 0:
            return text[start:i]
    raise ValueError("parenthèse non fermée")


def _entries(body):
    return {name: float(value) for name, value in ENTRY.findall(body)}


def parse_presets(texts):
    named, aliases, pending = {}, {}, []
    for index, text in enumerate(texts):
        for m in NAMED_MAP.finditer(text):
            named[m.group(1)] = _entries(_call_body(text, m.end()))
        aliases.update(ALIAS.findall(text))
        for m in PRESET.finditer(text if index == 0 else ""):
            rest = text[m.end():]
            if rest.startswith("Stats.fromMap("):
                pending.append((m.group(1), _entries(_call_body(text, m.end()))))
            else:
                pending.append((m.group(1), re.match(r"\w+", rest).group(0)))
    presets = {}
    for label, value in pending:
        seen = set()
        while isinstance(value, str):
            if value in named:
                value = named[value]
            elif value in aliases and value not in seen:
                seen.add(value)
                value = aliases[value]
            else:
                break
        if isinstance(value, dict):
            presets[label] = value
    return presets


def convert(raw, role):
    if role not in ROLES:
        raise ValueError(f"rôle inconnu : {role}")
    ep, ignored = {}, []

    def add(name, value):
        ep[name] = round(ep.get(name, 0.0) + value, DECIMALS)

    for name, value in sorted(raw.items()):
        if value == 0:
            continue
        if name in RATINGS:
            target, per_percent = RATINGS[name]
            add(target, value * per_percent)
            if role in SPELL_ROLES and target in SPELL_TWINS:
                add(SPELL_TWINS[target], value * per_percent)
        elif name in RENAMED:
            add(RENAMED[name], value)
        elif name in KEPT:
            add(name, value)
            if name in ("StatSpellDamage", "StatHealingPower"):
                add("StatSpellPower", value)
        else:
            ignored.append(name)
    return {k: v for k, v in ep.items() if v != 0}, sorted(ignored)


def build_profile(cls, spec, entry, presets):
    if entry["preset"] not in presets:
        raise ValueError(f"{cls}_{spec} : preset absent {entry['preset']}")
    ep, ignored = convert(presets[entry["preset"]], entry["role"])
    reference, caps = ROLES[entry["role"]]
    raw = {
        "class": cls, "spec": spec, "phase": "60",
        "source": f"WoWSims Forever, preset « {entry['preset']} » (ui/specs/{entry['file']})",
        "date": REVISION_DATE, "version": REVISION[:7], "reference": reference, "ep": ep, "caps": dict(caps),
    }
    return raw, ignored


def load_texts():
    urls = {path: RAW_URL.format(rev=REVISION, path=path) for path in FILES}
    target = cache.complete(ROOT / "tools" / "cache" / f"wowsims-{REVISION[:7]}",
                            {path.replace("/", "_"): url for path, url in urls.items()})
    return {path: (target / path.replace("/", "_")).read_text(encoding="utf-8") for path in urls}


def main():
    texts = load_texts()
    ignored_all = set()
    for (cls, spec), entry in sorted(SPECS.items()):
        others = [text for path, text in texts.items() if path != entry["file"]]
        presets = parse_presets([texts[entry["file"]]] + others)
        raw, ignored = build_profile(cls, spec, entry, presets)
        ignored_all.update(ignored)
        path = OUTPUT_DIR / f"{cls.lower()}_{spec.lower()}_60.json"
        path.write_text(json.dumps(raw, ensure_ascii=False, indent=4) + "\n", encoding="utf-8", newline="\n")
    print(f"WoWSims {REVISION[:7]} : {len(SPECS)} profils, stats ignorées : {', '.join(sorted(ignored_all))}")


if __name__ == "__main__":
    sys.exit(main())
