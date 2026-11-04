"""CONTRAT
Génère StuffPlanner/Profiles/Defaults.lua depuis les EP exportés de WoWSims (tools/weights_input/*.json).
Entrée, un fichier par profil : {"class", "spec", "phase" ("leveling" | "60"), "source", "date" (AAAA-MM-JJ),
  "version", "reference" (nom WoWSims de la stat de référence), "ep" {StatWoWSims: EP},
  "caps" {StatKey: plafond, unités de StatKeys}}. Les EP de toucher et de critique sont par point de %.
  load_stat_keys(path) -> ensemble des clés de StuffPlanner/Engine/StatKeys.lua
  normalize(raw, stat_keys) -> (profil, avertissements) ; poids = EP / EP de référence, arrondis à
    3 décimales, nuls retirés ; stat WoWSims inconnue : avertissement et ignorée ; ValueError si champ
    manquant ou vide, référence absente ou ≤ 0, phase, date ou clé de plafond invalide, deux stats sur une clé
  emit_defaults(profils) -> contenu de Defaults.lua, trié par identifiant ; ValueError si doublon
  generate(input_dir, stat_keys) -> (texte, avertissements)
Usage : python tools/gen_weights.py ; écrit Defaults.lua et affiche une ligne.
"""

import json
import re
import sys
from pathlib import Path

import emit_lua

ROOT = Path(__file__).resolve().parents[1]
INPUT_DIR = ROOT / "tools" / "weights_input"
STAT_KEYS_PATH = ROOT / "StuffPlanner" / "Engine" / "StatKeys.lua"
OUTPUT = ROOT / "StuffPlanner" / "Profiles" / "Defaults.lua"

REQUIRED = ("class", "spec", "phase", "source", "date", "version", "reference", "ep", "caps")
PHASES = ("leveling", "60")
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
DECIMALS = 3

WOWSIMS_STATS = {
    "StatStrength": "STR",
    "StatAgility": "AGI",
    "StatStamina": "STA",
    "StatIntellect": "INT",
    "StatSpirit": "SPI",
    "StatAttackPower": "AP",
    "StatRangedAttackPower": "RAP",
    "StatMeleeHit": "HIT",
    "StatMeleeCrit": "CRIT",
    "StatMeleeHaste": "HASTE",
    "StatSpellPower": "SPELL_POWER",
    "StatSpellDamage": "SPELL_DMG",
    "StatHealingPower": "HEALING",
    "StatSpellHit": "SPELL_HIT",
    "StatSpellCrit": "SPELL_CRIT",
    "StatSpellPenetration": "SPELL_PEN",
    "StatHolyPower": "HOLY_DMG",
    "StatFirePower": "FIRE_DMG",
    "StatNaturePower": "NATURE_DMG",
    "StatFrostPower": "FROST_DMG",
    "StatShadowPower": "SHADOW_DMG",
    "StatArcanePower": "ARCANE_DMG",
    "StatArmor": "ARMOR",
    "StatDefense": "DEF",
    "StatDodge": "DODGE",
    "StatParry": "PARRY",
    "StatBlock": "BLOCK",
    "StatBlockValue": "BLOCK_VALUE",
    "StatMP5": "MP5",
    "StatHolyResistance": "RES_HOLY",
    "StatFireResistance": "RES_FIRE",
    "StatNatureResistance": "RES_NATURE",
    "StatFrostResistance": "RES_FROST",
    "StatShadowResistance": "RES_SHADOW",
    "StatArcaneResistance": "RES_ARCANE",
    "PseudoStatMainHandDps": "DPS",
    "PseudoStatRangedDps": "DPS",
}

HEADER = """-- Généré par tools/gen_weights.py depuis tools/weights_input/ : ne pas modifier à la main.
-- CONTRAT
-- ns.ProfileDefaults[profileID] = {class, spec, phase ("leveling" | "60"), source, date, version,
--   weights = {[StatKey]=poids}, caps = {[StatKey]=plafond}} ; poids relatifs à la stat de référence.
-- profileID = CLASSE_SPE_PHASE (« WARLOCK_AFFLICTION_60 »). Tables partagées, à ne pas modifier.

local _, ns = ...

"""


def load_stat_keys(path):
    text = Path(path).read_text(encoding="utf-8")
    block = re.search(r"local KEYS = \{(.*?)\n\}", text, re.S)
    if not block:
        raise ValueError(f"liste KEYS introuvable dans {path}")
    return set(re.findall(r'"([A-Z0-9_]+)"', block.group(1)))


def _check(raw):
    for field in REQUIRED:
        if field not in raw or raw[field] in ("", None):
            raise ValueError(f"champ manquant ou vide : {field}")
    if raw["phase"] not in PHASES:
        raise ValueError(f"phase invalide : {raw['phase']}")
    if not DATE.match(raw["date"]):
        raise ValueError(f"date invalide : {raw['date']}")
    reference = raw["ep"].get(raw["reference"])
    if not reference or reference <= 0:
        raise ValueError(f"stat de référence absente ou nulle : {raw['reference']}")
    return reference


def normalize(raw, stat_keys):
    reference = _check(raw)
    profile_id = f"{raw['class']}_{raw['spec']}_{raw['phase'].upper()}"
    warnings = []
    weights, sources = {}, {}
    for name, ep in sorted(raw["ep"].items()):
        key = WOWSIMS_STATS.get(name)
        if key is None:
            warnings.append(f"{profile_id} : stat WoWSims ignorée {name}")
            continue
        if key not in stat_keys:
            raise ValueError(f"clé interne inconnue : {key}")
        if key in sources:
            raise ValueError(f"{profile_id} : {sources[key]} et {name} donnent tous deux {key}")
        sources[key] = name
        weight = round(ep / reference, DECIMALS)
        if weight != 0:
            weights[key] = weight
    for key in raw["caps"]:
        if key not in stat_keys:
            raise ValueError(f"clé de plafond inconnue : {key}")
    profile = {field: raw[field] for field in ("class", "spec", "phase", "source", "date", "version")}
    profile.update(id=profile_id, weights=weights, caps=dict(raw["caps"]))
    return profile, warnings


def _emit_map(name, values):
    lines = [f"        {name} = {{"]
    for key in sorted(values):
        lines.append(f"            {key} = {emit_lua.lua_value(values[key])},")
    lines.append("        },")
    return lines


def emit_defaults(profiles):
    seen = set()
    lines = [HEADER.rstrip("\n"), "", "ns.ProfileDefaults = {"]
    for profile in sorted(profiles, key=lambda p: p["id"]):
        if profile["id"] in seen:
            raise ValueError(f"profil en double : {profile['id']}")
        seen.add(profile["id"])
        lines.append(f"    {profile['id']} = {{")
        for field in ("class", "spec", "phase", "source", "date", "version"):
            lines.append(f"        {field} = {emit_lua.lua_string(profile[field])},")
        lines += _emit_map("weights", profile["weights"])
        lines += _emit_map("caps", profile["caps"])
        lines.append("    },")
    lines.append("}")
    return "\n".join(lines) + "\n"


def generate(input_dir, stat_keys):
    profiles, warnings = [], []
    for path in sorted(Path(input_dir).glob("*.json")):
        profile, profile_warnings = normalize(json.loads(path.read_text(encoding="utf-8")), stat_keys)
        profiles.append(profile)
        warnings += profile_warnings
    return emit_defaults(profiles), warnings


def main():
    text, warnings = generate(INPUT_DIR, load_stat_keys(STAT_KEYS_PATH))
    OUTPUT.write_text(text, encoding="utf-8", newline="\n")
    for warning in warnings:
        print(warning)
    print(f"Defaults.lua : {text.count('        phase = ')} profils, {len(warnings)} avertissements")


if __name__ == "__main__":
    sys.exit(main())
