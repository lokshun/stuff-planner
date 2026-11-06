# Changelog

## Unreleased

### Changes
- Clicking an item (mini tracker, Current zone or Route list) frames its row in the list; from the mini tracker,
  the Current zone list scrolls to it.
- Quest sheet: hovering a step of the quest chain (or a prerequisite) shows that quest's details
  (level, state, zone, giver, rewards with gain).
- Profile tab: hovering a cell of the profile grid shows its top stats, weights and caps; "Automatic choice"
  shows the profile it resolves to.

## 1.2.0 — 2026-11-05

### Fixes
- Quest and item names no longer show as "Quest #id" / "Item #id" when the client has not loaded them:
  localized names from QuestieDB are shipped as a fallback (English fills the gaps).
- Item icons: the client icon replaces the question mark once the server sends a hidden item.
- Settings gear on the main window shown again on WoW Forever (it was hidden behind the frame title bar).

### Changes
- Mini tracker tooltip shows the full item tooltip (stats and gain) before the source and state lines.
- "Show on map" pings the quest giver: pulsing ring at its position, removed when the map closes.
- Data rebuilt for client 1.60.1.70790 and QuestieDB revision 4ab6431 (post-launch).

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
