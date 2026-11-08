"""CONTRAT
Écrit StuffPlanner_Data en Lua 5.1, de façon déterministe (tri, LF, UTF-8, aucune date).
  lua_string(text) -> littéral Lua sur une ligne
  lua_value(value) -> None, bool, int, float, str, list, dict en Lua ; ValueError si impossible
  encode_record(table, record) -> liste dans l'ordre du schéma, sans l'identifiant ; ValueError si
    champ inconnu, champ requis manquant ou source inconnue
  record_string(value) -> chaîne compacte d'un tuple, lue par StuffPlanner/Data/Codec.lua :
    littéral Lua sans chaîne, nil vide (« {1,,3} »), nil finaux omis, clés identifiants ; ValueError sinon
  emit_table(table, records) -> contenu de Quests.lua, Items.lua, Origins.lua, Instances.lua ou Npcs.lua ;
    une chaîne record_string par enregistrement (une table Lua coûte trop en jeu) ; ValueError si doublon
  emit_schema() -> contenu de Schema.lua
  emit_register() -> contenu de Register.lua, chargé en dernier : passe le ns de l'addon de données
    à l'addon principal par AceAddon (StuffPlanner:RegisterData(ns)), sans nouveau global
  lua_name(table) -> nom Lua d'une table (« eraItems » -> « EraItems ») : ns.<nom> dans <nom>.lua
  emit_toc(interface, name_files=(), flavor=None) -> contenu d'un TOC LoadOnDemand ; name_files avant
    Register.lua ; EraItems.lua (après Items.lua) pour le seul flavor ERA_FLAVOR
  emit_names(var, locale, names, fallback=False) -> <var>_<langue>.lua (var : NpcNames, QuestNames, ItemNames) :
    ns.<var> = {[id]="nom"} si GetLocale() vaut la langue ; fallback (anglais, chargé après les autres) : si
    aucune autre ne l'a rempli. emit_npc_names(locale, names, fallback) = emit_names("NpcNames", ...)
  emit_overlay(overlay) -> Overlay.lua : ns.Overlay = {quests={[id]={champ=valeur}}} en tables Lua (lues par
    Data, peu nombreuses) ; ValueError si table ou champ absent de schema.FIELDS
  emit_neighbors(neighbors) -> Neighbors.lua : ns.Neighbors = {[uiMapID]={uiMapID...}} (Data.neighbors)
  write_addon(out_dir, tables, interfaces, npc_names=None, overlay=None, quest_names=None, item_names=None,
    neighbors=None) -> écrit tous les fichiers, mentions de licence comprises ; EraItems.lua et Neighbors.lua
    toujours écrits (vides sans données) ; *_names = {langue: {id: nom}}, "enUS" en repli ; overlay vide par défaut
"""

import math
import re
from pathlib import Path

import schema

HEADER = "-- Généré par tools/build_db.py depuis tools/schema.py. Ne pas modifier.\n"
OVERLAY_HEADER = "-- Généré par tools/merge_exports.py depuis les exports des joueurs. Ne pas modifier.\n"
LUA_KEYWORDS = frozenset(
    "and break do else elseif end false for function if in local nil not or repeat "
    "return then true until while".split()
)
IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
ESCAPES = {'"': '\\"', "\\": "\\\\", "\n": "\\n", "\r": "\\r", "\t": "\\t"}
TOC_FILES = (
    "Schema.lua",
    "Quests.lua",
    "Items.lua",
    "Origins.lua",
    "Instances.lua",
    "Npcs.lua",
    "Neighbors.lua",
    "Overlay.lua",
    "Register.lua",
)
ERA_FLAVOR = "Vanilla"
ERA_FILE = "EraItems.lua"
NOTICE = Path(__file__).with_name("THIRD_PARTY.txt")


def lua_string(text):
    parts = []
    for char in text:
        if char in ESCAPES:
            parts.append(ESCAPES[char])
        elif ord(char) < 32 or ord(char) == 127:
            parts.append(f"\\{ord(char):03d}")
        else:
            parts.append(char)
    return '"' + "".join(parts) + '"'


def _lua_number(value):
    if isinstance(value, float):
        if not math.isfinite(value):
            raise ValueError(f"nombre illisible en Lua : {value}")
        if value.is_integer():
            return str(int(value))
        return repr(value)
    return str(value)


def _lua_key(key):
    if isinstance(key, str):
        if IDENTIFIER.match(key) and key not in LUA_KEYWORDS:
            return key
        return f"[{lua_string(key)}]"
    if isinstance(key, int) and not isinstance(key, bool):
        return f"[{key}]"
    raise ValueError(f"clé illisible en Lua : {key!r}")


def _sort_key(key):
    return (1, key) if isinstance(key, str) else (0, key)


def lua_value(value):
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return _lua_number(value)
    if isinstance(value, str):
        return lua_string(value)
    if isinstance(value, (list, tuple)):
        return "{" + ",".join(lua_value(item) for item in value) + "}"
    if isinstance(value, dict):
        items = sorted(value.items(), key=lambda pair: _sort_key(pair[0]))
        return "{" + ",".join(f"{_lua_key(k)}={lua_value(v)}" for k, v in items) + "}"
    raise ValueError(f"valeur illisible en Lua : {value!r}")


def _compact(value):
    if value is None:
        return ""
    if isinstance(value, str):
        raise ValueError(f"chaîne interdite dans un enregistrement : {value!r}")
    if isinstance(value, (list, tuple)):
        items = list(value)
        while items and items[-1] is None:
            items.pop()
        return "{" + ",".join(_compact(item) for item in items) + "}"
    if isinstance(value, dict):
        for key in value:
            if not isinstance(key, str) or _lua_key(key) != key:
                raise ValueError(f"clé illisible par le décodeur : {key!r}")
        items = sorted(value.items())
        return "{" + ",".join(f"{k}={_compact(v)}" for k, v in items) + "}"
    return lua_value(value)


def record_string(value):
    return _compact(value)


def encode_record(table, record):
    fields = schema.FIELDS[table]
    unknown = set(record) - set(fields) - {"id"}
    if unknown:
        raise ValueError(f"{table} {record.get('id')} : champs inconnus {sorted(unknown)}")
    encoded = []
    for field in fields:
        if field not in record and field not in schema.OPTIONAL[table]:
            raise ValueError(f"{table} {record.get('id')} : champ manquant {field}")
        value = record.get(field)
        if field == "source":
            if value not in schema.SOURCES:
                raise ValueError(f"{table} {record.get('id')} : source inconnue {value!r}")
            value = schema.SOURCES[value]
        encoded.append(value)
    return encoded


def lua_name(table):
    return table[0].upper() + table[1:]


def emit_table(table, records):
    by_id = {}
    for record in records:
        record_id = record["id"]
        if record_id in by_id:
            raise ValueError(f"{table} : doublon {record_id}")
        by_id[record_id] = record
    lines = [HEADER, "local _, ns = ...\n\n", f"ns.{lua_name(table)} = {{\n"]
    for record_id in sorted(by_id):
        encoded = lua_string(record_string(encode_record(table, by_id[record_id])))
        lines.append(f"    [{record_id}]={encoded},\n")
    lines.append("}\n")
    return "".join(lines)


def emit_schema():
    lines = [HEADER, "local _, ns = ...\n\n", "ns.Schema = {\n"]
    lines.append(f"    version = {schema.VERSION},\n")
    for table in sorted(schema.FIELDS):
        positions = {field: i for i, field in enumerate(schema.FIELDS[table], start=1)}
        lines.append(f"    {table} = {lua_value(positions)},\n")
    lines.append(f"    sources = {lua_value(schema.SOURCES)},\n")
    lines.append(f"    originKinds = {lua_value(schema.ORIGIN_KINDS)},\n")
    lines.append("}\n")
    return "".join(lines)


def emit_register():
    return (
        HEADER
        + "local _, ns = ...\n\n"
        + 'local main = LibStub("AceAddon-3.0"):GetAddon("StuffPlanner", true)\n'
        + "if main and main.RegisterData then\n"
        + "    main:RegisterData(ns)\n"
        + "end\n"
    )


def emit_names(var, locale, names, fallback=False):
    if fallback:
        guard = f"if ns.{var} then\n    return\nend\n\n"
    else:
        guard = f"if GetLocale() ~= {lua_string(locale)} then\n    return\nend\n\n"
    lines = [HEADER, "local _, ns = ...\n\n", guard, f"ns.{var} = {{\n"]
    for npc_id in sorted(names):
        lines.append(f"    [{npc_id}]={lua_string(names[npc_id])},\n")
    lines.append("}\n")
    return "".join(lines)


def emit_npc_names(locale, names, fallback=False):
    return emit_names("NpcNames", locale, names, fallback)


def emit_overlay(overlay):
    lines = [OVERLAY_HEADER, "local _, ns = ...\n\n", "ns.Overlay = {\n"]
    for table in sorted(overlay):
        if table not in schema.FIELDS:
            raise ValueError(f"Overlay : table inconnue {table}")
        lines.append(f"    {table} = {{\n")
        for record_id in sorted(overlay[table]):
            fields = overlay[table][record_id]
            unknown = set(fields) - set(schema.FIELDS[table])
            if unknown:
                raise ValueError(f"Overlay : champ inconnu {sorted(unknown)} ({table} {record_id})")
            lines.append(f"        [{int(record_id)}] = {lua_value(fields)},\n")
        lines.append("    },\n")
    lines.append("}\n")
    return "".join(lines)


def emit_neighbors(neighbors):
    lines = [HEADER, "local _, ns = ...\n\n", "ns.Neighbors = {\n"]
    for map_id in sorted(neighbors):
        lines.append(f"    [{int(map_id)}]={lua_value(sorted(neighbors[map_id]))},\n")
    lines.append("}\n")
    return "".join(lines)


def _name_files(var, by_locale):
    locales = sorted(locale for locale in (by_locale or {}) if locale != "enUS")
    if by_locale and "enUS" in by_locale:
        locales.append("enUS")
    return [f"{var}_{locale}.lua" for locale in locales]


def emit_toc(interface, name_files=(), flavor=None):
    files = list(TOC_FILES[:-1])
    if flavor == ERA_FLAVOR:
        files.insert(files.index("Items.lua") + 1, ERA_FILE)
    lines = [
        f"## Interface: {interface}",
        "## Title: Stuff Planner Data",
        "## Version: @project-version@",
        "## LoadOnDemand: 1",
        "## Dependencies: StuffPlanner",
        "",
        *files,
        *name_files,
        TOC_FILES[-1],
    ]
    return "\n".join(lines) + "\n"


def write_addon(
    out_dir, tables, interfaces, npc_names=None, overlay=None, quest_names=None, item_names=None, neighbors=None
):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    files = {
        "Schema.lua": emit_schema(),
        "Register.lua": emit_register(),
        "Overlay.lua": emit_overlay(overlay or {}),
        "Neighbors.lua": emit_neighbors(neighbors or {}),
        ERA_FILE: emit_table("eraItems", []),
    }
    for table, records in tables.items():
        files[f"{lua_name(table)}.lua"] = emit_table(table, records)
    name_files = []
    for var, by_locale in (("NpcNames", npc_names), ("QuestNames", quest_names), ("ItemNames", item_names)):
        for locale, names in (by_locale or {}).items():
            files[f"{var}_{locale}.lua"] = emit_names(var, locale, names, fallback=locale == "enUS")
        name_files += _name_files(var, by_locale)
    for flavor, interface in interfaces.items():
        files[f"StuffPlanner_Data_{flavor}.toc"] = emit_toc(interface, name_files, flavor)
    files["THIRD_PARTY.txt"] = NOTICE.read_text(encoding="utf-8")
    for name, content in files.items():
        (out_dir / name).write_bytes(content.encode("utf-8"))
