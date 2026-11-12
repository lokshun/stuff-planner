# Changelog

## 2.0.0 — 2026-11-12

### New interface
- The main window was redesigned: an icon bar on the left opens the pages Now, Dungeons, Target list,
  Route 1-60, Gear, Journal and Profile. The gear icon opens the settings, the "?" icon lists the commands
  and tips.
- Two window styles: "Notebook" (default) or Blizzard (Settings, then reload the interface).
- Every item row looks and behaves the same everywhere. Right-click a row for its menu: open details, follow,
  pin to the target list, try on, use or compare a profile.
- One floating frame replaces the mini-tracker, the quest steps window and the dungeon panel. It shows one
  mode at a time (dungeon, then followed chain, then zone); click its title to switch mode, right-click to
  collapse.
- The welcome guide has 4 steps and can be reopened with `/splan welcome`.

### Time instead of effort
- Priorities are now gain per minute of play: quest steps, travel (flight paths, boats and zeppelins
  included), dungeon and raid runs are counted in seconds. Lists show the estimated time ("~12 min").
- Stuff Planner measures your own pace (quests, dungeon runs, travel; AFK and offline time excluded) and
  adjusts its estimates after 5 measures. Turn it off in Settings › Route.
- Sessions on the Now page: pick 30 min, 1 h or 2 h and get a numbered plan that fits the time, then
  "Follow the session" to be guided from quest to quest.

### Gain wherever there is an item
- Green arrows with the gain in your bags, at vendors and in the auction house browse list (Classic auction
  house). With Auctionator or TradeSkillMaster, the item tooltip also shows the gain per gold coin.
- Entering a new zone shows a short toast with its best upgrades (once per zone and per session); click it
  to open the Now page.

### Dungeon mode
- Inside a dungeon or raid, the floating frame lists the bosses in order with their useful items (gain and
  drop chance) and the expected gain left in the run. Killed bosses are checked automatically; click a boss to
  check or uncheck it.
- Group loot rolls show "Need: +x" or "Greed" above the roll frame (or in chat). Stuff Planner never rolls
  for you.
- The Dungeons page lists the instances with useful items for you: those at your level first (by expected
  gain), the others after, dimmed. Click one for its bosses and items.

### Profiles and goals
- Secondary profile: right-click a profile in the grid to compare it. Gains for both profiles appear side by
  side, and items only useful to the secondary profile are marked "keep for…".
- Pawn scales can be imported in the Profile page ("( Pawn: v1: … )").
- "My stats" now values stats by what they really give: crit, spell power, health, mana, dodge, parry, block,
  defense (with the crit immunity cap at 60), and the share of INT, AGI and STR that turns into them.
- Target list: Alt-click an item (or Pin in its details) to aim for it. The Target list page shows the
  fastest source, the quests left and what is already obtained; it can be exported and imported.
- Journal page: your score per level and your last upgrades, plus your other characters (same realm and
  faction) with the items in your bags that would suit them. Item tooltips say "Useful to X" when an item is
  better for one of your other characters.

### Community
- Optional sharing of quest reward confirmations with your guild and group (off by default, Settings ›
  Sharing). Nothing is sent in combat; received data is never saved.

### Changes
- The data collector now only keeps equippable loot (grey items, cloth and other junk are ignored), at most
  20 loot records per creature. Existing saved data is cleaned once on load: smaller saved variables and
  shorter `/splan export` strings.
- Creature names are only saved when they are useful (quest givers, bosses) and differ from the built-in
  names; older saved variables are cleaned on load.
- Gains are shown in points everywhere.
- Each language now loads only its own name files: less memory.
- Two unused libraries (AceDB-3.0, AceConsole-3.0) are no longer shipped; AceComm-3.0 was added for sharing.
- Faster: results are only recomputed when your character really changes (level, zone, gear, profile), and
  travel times are only recomputed after you move.

### Fixes
- Journal, other characters: a bind-on-equip item you have already worn (so now bound) is no longer offered.
- The row menu closes when clicking anywhere else.
- Ring and trinket tooltips (two comparisons) open on the side of the screen with room, no longer over the
  window.
- A crafted suggestion or an empty slot always lists a quest reward first among its alternatives.

## 1.5.0 — 2026-11-11

### Changes
- Quest chains: the quest detail button now reads "Follow". The arrow then guides you step by step
  (pick up, objective, turn in) through every quest of the chain, and resumes after a reload.
- A small steps window lists the followed chain (done, current, upcoming, objective progress); click a step
  to aim the arrow and open the map. Options: show and lock the window.
- While following, the arrow leads to a known flight master when flying is faster, and to the boat or
  zeppelin when that is faster (Rut'theran and the Undercity–Grom'gol zeppelin included). Discovered flight
  paths are read directly (on Classic Era, open a flight map once to record them).
  The arrow also shows the target zone and how many zones away it is.
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
