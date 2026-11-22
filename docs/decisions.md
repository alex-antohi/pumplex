# PUMPLEX decisions

Date: 21 November 2026. Status: v1.

These are the owner's decisions. They win over the brief, the flow, the schema, the rules table and every mood board.
If a board conflicts with a decision, change the board.
Ask the owner before you design against a decision. Add each new decision here, with a number and a date.

## 1. Decisions

| ID | Decision | Date | Notes / where it applies |
|---|---|---|---|
| D1 | PUMPLEX makes you train, not track. Count only the working sets per exercise. | 21 Nov 2026 | Every screen. |
| D2 | No reps, no kilos, no tables of numbers. Progress shows as the character, the level and short messages. | 21 Nov 2026 | No PRs, no stat tables. |
| D3 | Single player, fully offline, data on the phone only, Android, one user. | 21 Nov 2026 | Cloud, friends and iOS are later. |
| D4 | Rest never punishes: no HP loss, no lost XP, no lost currency. | 21 Nov 2026 | `docs/rules.md` §7. |
| D5 | Sessions are free-form: no calendar, no weekly plan, no rest days. | 21 Nov 2026 | Hub, workout, history. |
| D6 | One session per calendar day. Every set marked on a day belongs to that day's session. A day with no sets does not count. | 21 Nov 2026 | `docs/app-flow.md` §4.4. The day closes by itself. |
| D7 | No I WORKED button, no START TRAINING button, no running session clock, no "SESSION n" counter. | 21 Nov 2026 | Owner confirmed this again on 21 Nov 2026, after the Workout board. |
| D8 | Class = equipment. One class per equipment type: none, basic home gym, lots of free weights, lots of machines. The class decides the exercises. | 21 Nov 2026 | Class select. |
| D9 | Class names are design proposals. Scrapper, Bargain Bruiser, Plate Paladin and Cablemancer are the working names. The class ids never change. | 21 Nov 2026 | Final names: still open (D27). The ids are the design ids (D31). |
| D10 | Character creation has a sex toggle and sliders for height, muscle size and fat %. The user never types a weight or a height. | 21 Nov 2026 | Creator. |
| D11 | Keep the height slider. | 21 Nov 2026 | Overrides the moodboard README line "No height slider". |
| D12 | The user can open the body sliders again at any time. The app keeps a history of body changes. | 21 Nov 2026 | Hub: tap the character. |
| D13 | Class, difficulty and starting area can all change later (for example, after joining a gym). Each session stores the class, difficulty and area it used. | 21 Nov 2026 | Summary, menu, history. |
| D14 | Difficulty has many levels, from total beginner to years of lifting. Names are fantasy names in a Borderlands-like tone, but our own. Harder difficulty gives more XP. | 21 Nov 2026 | Difficulty. The count is 6 (D28). |
| D15 | A workout has a set number of exercises from the class pool: 3 at the easiest difficulty, 8 at the hardest. Each exercise has a target number of working sets from the difficulty. | 21 Nov 2026 | Workout. Pools: still open (D27). |
| D16 | The user can switch an exercise for another from the class pool (swipe), add exercises, remove exercises and return a switched exercise to the first one. Skipping = doing no sets. | 21 Nov 2026 | Workout. |
| D17 | One mark = one working set. A long-press takes the last set back. Warm-up sets do not count. | 21 Nov 2026 | Workout, every area. |
| D18 | The design team makes the starting areas and their themed set marks (shells, wall scratches and so on). | 21 Nov 2026 | Delegated to design. |
| D19 | XP and levels follow `docs/rules.md`: sets × difficulty multiplier, bonus over the target up to 2× the target, critical sets, +50 for the first set of the day, weekly streak bonus, achievements, 150 XP per old session, Habitica level curve. | 21 Nov 2026 | Where the rules.md example table and the formula disagree, the formula wins (level 30 needs 660, not 670). |
| D20 | The streak counts N training days per calendar week. N comes from the difficulty. Missing days inside a week never break it. | 21 Nov 2026 | Hub. |
| D21 | Levels unlock gear: one item per slot (head, top, bottom, shoes, weapon). Gear never changes the body. The body stays as the sliders set it. | 21 Nov 2026 | Gear, level-up. |
| D22 | Old app data: save a backup file first. Then turn the old sessions into XP and delete the old kg/reps sets and swaps. If the backup fails or the user says NOT NOW, nothing changes. | 21 Nov 2026 | Upgrade scene. |
| D23 | The whole app feels like one screen. Every change of view is an animated transition (zoom, slide, fade, shared character). No blank or black flashes, no plain jump to a different screen. | 21 Nov 2026 | Every view change. |
| D24 | Keep the PUMPLEX look, chaos mode and the CEL SHADER mode. | 21 Nov 2026 | Menu, theme. |
| D25 | On the class-select step, the preview shows the body the user made in step 1. There is no separate preview body per class. | 21 Nov 2026 | Class select. |
| D26 | The app id stays `com.alex.gym_app`. Add no new code packages without the owner's OK. | 21 Nov 2026 | Code. |
| D27 | Still open (not decided): how to measure progress, final class names, exercise pools, the achievements list, the gear list. | 21 Nov 2026 | Ask the owner. |
| D28 | Difficulty has 6 levels: the design team's 6 modes (Sofa, Warm-up, Sweat, Pain, Brutal, Nightmare Mode). The names stay design proposals. | 21 Nov 2026 | Difficulty. Confirmed by the owner, again on 22 Nov 2026: the demo's Couch Spawn … Ascended Swolemancer are dropped (they break the "no class-like names" rule). Ids: `sofa`, `warmup`, `sweat`, `pain`, `brutal`, `nightmare`. |
| D29 | No preloader. The app opens straight on the hub (or the creator on the first launch). | 21 Nov 2026 | Overrides design demo `01-preloader.html`. |
| D30 | No "wipe all data" / RESTART SETUP button. The setup changes with EDIT CHARACTER, and the XP and sessions stay. | 21 Nov 2026 | Overrides the DANGER ZONE in design demo `12-menu.html`. |
| D31 | The class ids are the design ids: `scrapper`, `bruiser`, `paladin`, `cablemancer`. | 22 Nov 2026 | Overrides the app's `speedy`, `rogue`, `warrior`, `mage`. The app must rename them and migrate saved data once. Area, asset and icon file names already use these ids. Note: an earlier D31 (22 Nov 2026, difficulty names Couch Spawn …) was dropped by the owner the same day; see D28. |
| D32 | The workout has no tools: no swap, no back to the first exercise, no skip, no remove, no add. The workout is the list the app picks for the day. | 22 Nov 2026 | Overrides D16 and the demo `08-workout.html` swipe and tool row. |
| D33 | Exercises per workout, Sofa to Nightmare: 3, 3, 4, 5, 6, 8. | 22 Nov 2026 | D15. Overrides the demo's placeholder 3, 4, 5, 6, 7, 8. |
| D34 | No streak. No streak count, no streak XP bonus, no week target. XP that old sessions earned with a streak bonus stays. | 22 Nov 2026 | Overrides D20 and the streak part of D19. |
| D35 | No achievements. XP that users already got from achievements stays. | 22 Nov 2026 | Overrides the achievements part of D19 and D27. |
| D36 | The area ids are the design ids: `riptide`, `gainsgard`, `rustbelt`, `arcade`, `frostbite`. The app migrates saved data once (`beach` → `riptide`, `castle` → `gainsgard`, `summit` → `frostbite`). | 22 Nov 2026 | Like D31 for classes. |
| D38 | No gear: no items, no unlocks, no gear screen, no gear on the character. Levels give only the level and its title. | 22 Nov 2026 | Overrides D21. The class outfits stay (they are not gear). |
| D39 | No chaos mode. | 22 Nov 2026 | Overrides the chaos part of D24. |
| D40 | No CEL SHADER mode. | 22 Nov 2026 | Overrides the cel part of D24. The PUMPLEX look stays. |
| D41 | No sound. The `audioplayers` package is removed. | 22 Nov 2026 | Overrides the owner's earlier OK for sound (D26 exception). |
| D37 | The app name is PUMPLEX. | 22 Nov 2026 | Marketing drafts that say SWOLEMANCER must change. |
| D42 | The HTML design demo (`docs/demo/`) is removed. The app and this file are the source of truth for screens, names and numbers. New design proposals go in `docs/moodboard/`. | 22 Nov 2026 | Closes every demo row in §2. Older notes that say "design demo 07" only name the screen a design came from. |

## 2. Where the current boards conflict

Checked on 22 Nov 2026 at commit `b954de3` (design demo and moodboard: "follow owner decisions D6-D30").
The "What the app does" column was rechecked against the app on 22 Nov 2026 at commit `a237791`.

All earlier conflicts are fixed. The boards and the demo now have the HEIGHT slider, the user's body on class select,
no preloader, no START TRAINING, no clock, no `SESSION n`, no I WORKED, no reward screen, no DANGER ZONE, rows by date,
6 difficulty levels, XP from `docs/rules.md`, 3 to 8 exercises, and a D23 transitions table
(`docs/moodboard/README.md` "Transitions between views").
D32–D36 (22 Nov 2026) came after that check. The new conflicts they make are in the table below.

D42 (22 Nov 2026) closes the demo rows below: the demo is removed, so there is nothing left to update.
The app is now the reference for the layout, the names and the numbers. The table stays as a record.

| Was in the demo | What it showed | Decision | Outcome |
|---|---|---|---|
| `demo.js` exercises per level | 3, 4, 5, 6, 7, 8 (placeholder). | D15, D33 | The app uses 3, 3, 4, 5, 6, 8 (`lib/game/rules.dart`). |
| `demo.js` streak N per level | 2, 2, 3, 3, 4, 4 days (placeholder). | D20, D34 | No streak. |
| `12-menu.html` SOUND | A sound toggle. | D26, D41 | Built on 22 Nov 2026 (`1a2f33e`), then removed by D41: no sound. |
| `BRIEF.md` "No emojis" | Pixel SVG icons only. | Design rule | Done (`1a2f33e`): pixel icons in `assets/icons`. The ⏱ glyph in past sessions is now the word TIME. |
| Screens 02–12 | The new layout. | None | The hub (07), workout (08), profile (11) and menu (12) were ported. Setup 02–06 and past sessions (10) were never checked against the demo. The app's screens are now the layout. |
| `demo.js` area ids | `riptide`, `gainsgard`, `rustbelt`, `arcade`, `frostbite`. | D36 | Done: the app uses the same ids. |
| `08-workout.html` swipe and tool row | Swipe to switch, a tool row and an ADD card. | D32 | The app has no tools. |
| `07-hub.html`, `11-profile.html` streak | A "this week" card, streak weeks and embers. | D34 | The app has no streak. |
| `11-profile.html` milestones | A milestones list with pixel medals. | D35 | The app has no achievements. |

The Profile screen, the full-screen menu and the level titles (Fresh Spawn … Mythic Meathead, design proposals) came from the demo.
Note: the Workout board allows extra sets up to 9. That is fine, but sets beyond 2× the target give 0 XP (D19).

Code notes (22 Nov 2026, at `a237791`, updated for D32–D37). Where the code and a decision differ:

- D16 (switch by swipe) is replaced by D32: done. The workout has no tools (no swipe, SWAP, FIRST, SKIP, REMOVE or ADD).
  Old sessions can still hold removed, added or switched exercises. The model keeps those fields for old data.
- D33: done. Exercises per workout are 3, 3, 4, 5, 6, 8 (`lib/game/rules.dart`).
- D34: done. No streak, no week target, no streak bonus. The old streak XP is saved once as `streak` XP events (`docs/data-schema.md` §5.4).
- D35: done. No achievements and no milestones. The key `achievements_v1` is deleted on start; the saved `achievement` XP events stay.
- D36: done. The area ids are the design ids, and saved data migrates once (`docs/data-schema.md` §5.3). The separate art id is gone.
- D37: done in the docs. The app name is PUMPLEX. The class-select kicker "THE SWOLEMANCER'S PATHS" stays as a tagline (`lib/game/content.dart`).
- D31: done. The class ids are `scrapper`, `bruiser`, `paladin`, `cablemancer`, and saved data migrates once (`docs/data-schema.md` §5.2).
- D28: done. The difficulty ids and names are the 6 MODE names.

## 3. What design owns

All of this stays inside the decisions above.

- Starting areas and their scenes (D18).
- The set-mark style for each area (D17, D18).
- Pixel art: body frames, class outfits, gear sprites, area scenes, animations.
- Names: classes, difficulty levels, areas, items (D9, D14). No achievements (D35).
