# Changelog

## 1.1.0 — 2026-11-04

### Changes
- Translated into every language of the WoW Forever client: German, Spanish (EU and Latin America),
  Brazilian Portuguese, Russian, Korean, Simplified and Traditional Chinese (English and French already).
- Game terms (stats, specializations, interface words) come from the game's own data, so they match
  what you see in game; the other phrases are first drafts. Corrections are welcome on the
  CurseForge translation page.
- Addon description translated in the addon list.

## 1.0.0 — 2026-11-04

First stable release, for WoW Forever launch day. Source code now public on GitHub.

### Changes
- CurseForge project ID in the TOC (updates through the CurseForge app).
- New README.

## 0.1.0 — 2026-11-03

First packaged build, for WoW Forever (1.60.1) and Classic Era (1.15.9).

### Features
- Ranks quest rewards, dungeon and raid loot and crafted items by the gain they bring
  to your character, using per-specialization stat weights (27 specs, leveling and level 60;
  14 level-60 profiles imported from WoWSims Forever, the others estimated).
- Main window (`/splan`) with Zone, Route, Gear and Profile tabs; mini tracker
  (`/splan tracker`); quest, dungeon and craft detail panels.
- Tooltip gain line, quest giver highlight, map and minimap pins, waypoints (TomTom if loaded).
- Stat priority editor, custom weights import/export (`SPW1` strings), 3-step onboarding.
- Route planner: quest chains, effort, XP and gear lifetime.
- Optional QuestieDB support; player-collected data export (`/splan export`).
- English and French; other client languages fall back to English.

### Known limitations
- Forever not yet tested in game (servers open 2026-11-04).
- Some item stats are estimated on Classic Era and flagged as unconfirmed.
- No world drop or vendor sources.
