# Changelog

## Unreleased

### Changes
- Quest chains: the quest detail button now reads "Follow". The arrow then guides you step by step
  (pick up, objective, turn in) through every quest of the chain, and resumes after a reload.
- A small steps window lists the followed chain (done, current, upcoming, objective progress); click a step
  to aim the arrow and open the map. Options: show and lock the window.
- Item tooltips now show the Stuff Planner gain for every equippable item, including world drops
  that are not in the database and random-suffix items ("of the Monkey"), read from the item link.
- When the suggested upgrade is a crafted item, its alternatives now start with the best quest reward for
  that slot (Route and Gear tabs), even if the quest takes more effort.

## 1.4.2 — 2026-11-09

### Changes
- Sort chips "By slot" / "Best gain" on the Zone, Route and Gear tabs. Best gain puts the biggest upgrades
  first (within each level range on the Route tab); the choice is kept per tab. Zone stays sorted by gain by
  default.

### Fixes
- Tab buttons no longer overflow the window with long labels (French, German, Russian…): they shrink to fit,
  and a truncated label shows in full in a tooltip.

## 1.4.1 — 2026-11-08

### Changes
- Easier alternatives: the "[+N]" text is replaced by an arrow button (the same as in My stats: down to
  unfold, up to fold), placed at the right of the line on both the Route and Gear tabs, with the gain next to it;
  gains of the alternatives and of the raid line line up under it.
- Selecting an alternative frames that line only; the Gear tab now shows the selection frame too (upgrade,
  raid line and alternatives), also when the item was picked from another tab.

## 1.4.0 — 2026-11-08

### Changes
- Easier alternatives: on the Route and Gear tabs, a "[+N]" button next to a suggestion unfolds up to three
  other items for the same slot that are cheaper to get (closer zone, shorter quest chain, no dungeon run),
  with their gain and effort ("Nearby", "2 zones away", "Far", "3 quests").
- Route tab: past level ranges are back, folded under "Levels 1-10 · for reference": the best item of each
  slot as if you were that level, greyed, marked "Already better equipped" or "Quest done".
- Effort now counts the distance to the quest's zone or the dungeon entrance (zones crossed, boats and
  zeppelins included), so a nearby quest wins over a far one with a similar gain.
- Zone neighbours are shipped with the data: the Current zone list, mini tracker and map pins now also cover
  the zones around you, as intended.

## 1.3.1 — 2026-11-07

### Changes
- Options: icon size sliders for quest givers on the world map and on the minimap (50 % to 200 %).

### Fixes
- Quests of the other faction (or restricted to other races) are no longer suggested, nor offered as
  prerequisites; quests without race data take the faction of their quest givers.

## 1.3.0 — 2026-11-06

### Changes
- Quest rewards: fixed rewards and choices now come from CMaNGOS classic-db; quests with an
  unconfirmed reward split drop from 870 to 138 (the rest are Forever additions). Data rebuilt with
  QuestieDB 21be340 and WoW-Spyglass 20292cf.
- Gains in lists show only the arrow and the value ("▲ 2.5"): no more + sign or ~ mark (the unconfirmed badge
  already says it); texts without an arrow (chat, tooltips) keep the + / - sign.
- Clicking an item (mini tracker, Current zone or Route list) frames its row in the list; from the mini tracker,
  the Current zone list scrolls to it.
- Quest sheet: hovering a step of the quest chain (or a prerequisite) shows that quest's details
  (level, state, zone, giver, rewards with gain).
- Profile tab: hovering a cell of the profile grid shows its top stats, weights and caps; "Automatic choice"
  shows the profile it resolves to.
- Profile tab: summary of the active profile at the top (main stats, caps, source) with an "Edit" button that
  opens "My stats".
- My stats: the "Add" button opens a menu of the remaining stats grouped by category, instead of the < > selector.
- My stats: hit and spell hit caps (in %) can be edited on their rows; editing no longer risks changing the spec
  profile's own caps. Adding hit or spell hit fills in the known cap (spec profile's, else 8 % / 17 % at 60).
- Leveling caster profiles: hit cap raised from 3 % to 4 % (same-level spell hit cap on Forever).
- Up to 10 named custom profiles per character: "Apply" updates the active custom profile or creates one,
  "New profile" always creates one, imports create their own; rename or delete the active one from the grid.
  The previous single custom profile is kept as "My stats".

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
