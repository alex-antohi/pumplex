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

## 2. Where the current boards conflict

Checked on 22 Nov 2026 at commit `b954de3` (design demo and moodboard: "follow owner decisions D6-D30").
The "What the app does" column was rechecked against the app on 22 Nov 2026 at commit `a237791`.

All earlier conflicts are fixed. The boards and the demo now have the HEIGHT slider, the user's body on class select,
no preloader, no START TRAINING, no clock, no `SESSION n`, no I WORKED, no reward screen, no DANGER ZONE, rows by date,
6 difficulty levels, XP from `docs/rules.md`, 3 to 8 exercises with swap, add and remove, and a D23 transitions table
(`docs/moodboard/README.md` "Transitions between views").

Still open (no decision is broken, but the app and the design differ):

| Board / file | What it shows | Decision | What the app does | Next step |
|---|---|---|---|---|
| `docs/demo/shared/demo.js` exercises per level | 3, 4, 5, 6, 7, 8 exercises (marked PLACEHOLDER). | D15 | 3, 3, 4, 5, 6, 8 (`lib/game/rules.dart`). | Agree one list (the end points, 3 and 8, already match). |
| `docs/demo/shared/demo.js` streak N per level | 2, 2, 3, 3, 4, 4 days (marked PLACEHOLDER). | D20 | 2, 2, 2, 3, 3, 4 (`lib/game/rules.dart`). | Agree one list. (Added 22 Nov 2026.) |
| `12-menu.html` SOUND | A sound toggle. | None (no sound files yet) | A disabled SOUND row with a SOON tag (placeholder). | Design delivers the sound pack. **Done 22 Nov 2026 (`1a2f33e`):** the sound pack is in `assets/sounds` and the SOUND row is a working toggle (`lib/sound.dart`, `audioplayers` with the owner's OK, D26). |
| `docs/demo/BRIEF.md` "No emojis" | Pixel SVG icons only. | None (design rule) | Emoji placeholders (areas, gear, milestones, buttons). | Design delivers the pixel icon set. The app swaps them in. **Done 22 Nov 2026 (`1a2f33e`):** pixel icons in `assets/icons`. The last text glyph (⏱ in the past-sessions rows) is now the word TIME. |
| `docs/demo/` screens | The new demo layout (character, workout, profile and others). | None | The app still has the first-build layout. | Port the demo layout into the app. **Partly done 22 Nov 2026:** the hub (07, `f224762`), the workout (08, `1a2f33e`), the profile (11) and the menu (12) follow the demo. Not checked against the demo: setup steps 02–06, past sessions (10) and gear. |
| `docs/demo/shared/demo.js` area ids | `riptide`, `gainsgard`, `rustbelt`, `arcade`, `frostbite`. | None (D31 is about class ids only) | Saved data keeps `beach`, `castle`, `rustbelt`, `arcade`, `summit`. Art and sound files use the design ids. | Nothing, unless the owner wants the area ids to change too. (Added 22 Nov 2026.) |

Built from the demo: the Profile screen, the full-screen menu and the level titles (Fresh Spawn … Mythic Meathead, design proposals).
Note: the Workout board allows extra sets up to 9. That is fine, but sets beyond 2× the target give 0 XP (D19).

Code notes (22 Nov 2026, at `a237791`). Where the code and a decision differ:

- D16 says "switch (swipe)". The workout has no swipe now. A SWAP button switches to the next pool exercise (forward only).
- D31: done. The class ids are `scrapper`, `bruiser`, `paladin`, `cablemancer`, and saved data migrates once (`docs/data-schema.md` §5.2).
- D28: done. The difficulty ids and names are the 6 MODE names.

## 3. What design owns

All of this stays inside the decisions above.

- Starting areas and their scenes (D18).
- The set-mark style for each area (D17, D18).
- Pixel art: body frames, class outfits, gear sprites, area scenes, animations.
- Names: classes, difficulty levels, areas, items, achievements (D9, D14).
