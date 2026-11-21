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
| D9 | Class names are design proposals. Scrapper, Bargain Bruiser, Plate Paladin and Cablemancer are the working names. The class ids never change. | 21 Nov 2026 | Final names: still open (D27). |
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
| D28 | Difficulty has 6 levels: the design team's 6 modes (Sofa, Warm-up, Sweat, Pain, Brutal, Nightmare Mode). The names stay design proposals. | 21 Nov 2026 | Difficulty. Confirmed by the owner. |
| D29 | No preloader. The app opens straight on the hub (or the creator on the first launch). | 21 Nov 2026 | Overrides design demo `01-preloader.html`. |
| D30 | No "wipe all data" / RESTART SETUP button. The setup changes with EDIT CHARACTER, and the XP and sessions stay. | 21 Nov 2026 | Overrides the DANGER ZONE in design demo `12-menu.html`. |

## 2. Where the current boards conflict

| Board / file | What it shows | Decision | What design must change |
|---|---|---|---|
| `docs/moodboard/README.md`, "Class select" | "No height slider. Owner decision, 21 November 2026" | D10, D11 | Remove the line. The creator keeps a height slider. |
| `canvas/Creator.dc.html` | Sex toggle, FAT and MUSCLE sliders only. "STEP 1 OF 3". | D10, D11 | Add a HEIGHT slider (the app stretches the sprite vertically). Change the kicker to "STEP 1 OF 5". |
| `canvas/Workout.dc.html`, README "Workout screen" | Top bar `SESSION 14 · SCRAPPER` and a running `mm:ss` clock. | D7 | Remove the session counter and the clock. Keep the class and area name. |
| Same | I WORKED button, "disabled until at least one set is logged". | D6, D7 | Remove the button. The day closes by itself. ◀ HUB goes back to the hub. |
| Same | Reward overlay on I WORKED: WORKOUT CRUSHED, `+[XP] XP`, TIME, BACK TO HUB. | D7, D19 | Remove the overlay. Give the reward per set: an XP pop on each set and CRITICAL SET. Show the freeze-frame card on a level-up. |
| Same | "Tap a card to switch" the active exercise. 3 fixed exercises. | D15, D16 | Add swipe to switch from the pool, + ADD EXERCISE, ✕ remove and ↺ back to the first exercise. Show 3 to 8 cards. |
| Same, and `canvas/Difficulty.dc.html` | "XP rules are still open (brief 4.8)". "The real multipliers come with the XP rules." | D19 | The XP rules exist now in `docs/rules.md`. The multiplier goes from 1.0 to 2.0 in even steps. |
| `readability.html`, `canvas/Readability.dc.html` | "SESSION 9 · DAY 2 OF 7 · 6 EXERCISES", "Heavy Lower" | D5, D7 | Remove the 7-day plan, the session counter and the fixed named workout. Use the hub and workout views. |
| `animation.html`, `canvas/Animation.dc.html` | `pr_flex` "for a new PR". Front squat as the "Heavy Lower main lift". | D2, D5 | There are no PRs. Use the flex for a level-up or a critical set. Remove "Heavy Lower". |
| `canvas/ClassSelect.dc.html`, README "Preview bodies" | Each class shows its own preview body. | D25 | Show the user's body from step 1. Class colour and (later) the class outfit show the class. |
| README intro, `canvas/Main.dc.html`, `game_look.html` | "Character classes are not decided yet." "Classes TBD". | D8, D9 | Classes are decided: one per equipment type. Only the final names are open. |
| All setup boards | Each step is a separate phone frame. There is no transition. | D23 | Specify the transition for each change of view. The character stays on screen between views. |

### Design demo (`docs/demo/`, from branch `design/demo-flow`, checked 21 Nov 2026)

The first build (branch `claude/game-flow-2dbf96`) follows the decisions, not the demo, in these places.

| Demo screen / file | What it shows | Decision | What the build does | What design must change |
|---|---|---|---|---|
| `01-preloader.html` | A loading screen with a fake progress bar before every launch. | D29 | No preloader. The app opens on the hub or the creator. | Remove the preloader screen. |
| `02-character.html` | Sex toggle, FAT and MUSCLE sliders only. | D10, D11 | Keeps the HEIGHT slider. | Add a HEIGHT slider. |
| `03-class.html`, `shared/demo.js` `CLASSES[].body` | Each class shows its own preview body. | D25 | Shows the body from step 1. | Use the user's body. |
| `04-difficulty.html`, `demo.js` `DIFFICULTIES` | **8** levels (Couch Larva … Swolemancer Prime), multipliers 1.0 to 2.25. | D28, D19 | Keeps the **6** modes (Sofa … Nightmare Mode), 1.0 to 2.0. | Go back to 6 levels. The names can change (D28). |
| `07-hub.html` | A START TRAINING button. | D7 | The workout card (TRAIN ▶) opens the workout. | Remove START TRAINING. |
| `08-workout.html` | `SESSION n` kicker, a running `mm:ss` clock, an I WORKED button, 3 fixed exercises, tap a card to switch. | D6, D7, D15, D16 | No counter, no clock, no I WORKED. 3 to 8 exercises, swipe to switch, add, remove, ↺. | Remove the counter, clock and button. Add swipe, add and remove. |
| `09-reward.html` | A reward screen after I WORKED: LOOT DROP · SESSION n, TIME UNDER IRON, "n SESSIONS SURVIVED". | D7, D19 | No reward screen. XP on each set, CRITICAL SET, the freeze-frame card on a level-up. | Turn the loot look into the per-set and level-up rewards. |
| `10-history.html` | Rows named `SESSION n`, total time "OF PURE EFFORT", START TRAINING in the empty state. | D7 | Rows by date. No session numbers. | Use dates. Remove START TRAINING. |
| `12-menu.html` DANGER ZONE | RESTART SETUP: "WIPE IT" deletes the lifter and all sessions. | D30, D13 | Not built. EDIT CHARACTER changes the setup and keeps the XP. | Remove the DANGER ZONE. |
| `12-menu.html` SOUND | A sound toggle. | None (no sound files yet) | A disabled SOUND row with a SOON tag (placeholder). | Deliver the sound pack. |
| `shared/demo.js` XP | 10 XP per set × multiplier, level curve 50·L·(L−1). | D19 | Uses `docs/rules.md` (Habitica curve, bonuses, critical sets). | Use the rules table. |
| `shared/demo.js` `WORKOUTS` | 3 fixed exercises per class. | D15 | 3 to 8 exercises from the class pool. | None for the demo. The pools are still open (D27). |
| `BRIEF.md` "No emojis" | Pixel SVG icons only. | None (design rule) | The app still uses emoji as placeholders (areas, gear, milestones, buttons). | Deliver the pixel icon set. The app swaps them in. |

Aligned and built from the demo: the Profile screen (`11-profile.html`: level title, the path, milestones, PAST SESSIONS),
the full-screen menu (`12-menu.html`: YOU, GAINS INSURANCE, LOOK AND FEEL) and the level titles (Fresh Spawn … Mythic Meathead, design proposals).

Checked, no conflict: no board shows rest days or a weekly plan, except the Readability board above.
Note: the Difficulty board has 6 modes, and the app uses the same 6 modes (D28).
Note: the app now has the starting areas, the difficulty modes and the workout layout from the design boards. The owner's rules apply: no I WORKED button, no clock, no "SESSION n", and the height slider stays.
Note: the Workout board allows extra sets up to 9. That is fine, but sets beyond 2× the target give 0 XP (D19).

## 3. What design owns

All of this stays inside the decisions above.

- Starting areas and their scenes (D18).
- The set-mark style for each area (D17, D18).
- Pixel art: body frames, class outfits, gear sprites, area scenes, animations.
- Names: classes, difficulty levels, areas, items, achievements (D9, D14).
