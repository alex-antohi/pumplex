# PUMPLEX app flow

Date: 22 November 2026. Status: draft v9 (matches the code on `main`, with D32–D37).
Read with [decisions.md](decisions.md) (it wins), [app-brief.md](app-brief.md), [data-schema.md](data-schema.md),
`pumplex.drawio` and [docs/moodboard/](moodboard/README.md).

Status key: **exists** = in the app now. **later** = waits for the design team or the rules table.

## 1. Overview

The app has 3 parts:

1. **One-time upgrade** (only on a phone with old-app data): save a backup file, then turn the old
   sessions into XP and delete the old kg / reps data.
2. **Initial setup** (first launch): character, class, difficulty, starting area.
3. **Play** (any time): open the workout, count the working sets, get XP and levels.

There is no calendar plan, no START TRAINING clock and no I WORKED button.
The user opens the app when they want, like a video game.

The whole app is **one screen**. Views are scenes of that screen. A change of view is a
camera move (zoom in, zoom out or slide), and the one character glides to its new place.
The app never pushes a new route for a view, so it never flashes a blank screen.

```mermaid
flowchart TD
    launch([Open the app]) --> old{Old-app data?}
    old -- yes --> migrate[Upgrade: save backup file first]
    migrate -- saved --> setupDone
    migrate -- NOT NOW / no file --> setupDone
    old -- no --> setupDone{Setup done?}
    setupDone -- no --> char[Character: sliders]
    char --> cls[Class: swipe the card, difficulty slider]
    cls --> area[Starting area: swipe the card, the class picks the default]
    area --> summary[Summary: READY? LET'S GO]
    summary --> work
    setupDone -- yes --> work[Workout = home: the world with the lifter, filter tags, exercise carousel]

    work -- each set --> xp[XP, critical sets, level-up intro card]

    work -. tap the lifter or the level bar .-> lifter[Lifter profile under the minimised workout: past sessions, lifter card]
    lifter -. tap the small workout .-> work
    lifter -. BODY, CLASS, DIFFICULTY, AREA .-> edit[The setup screen under the small workout, no BACK / NEXT, saves at once]
    edit -. tap the small workout .-> work
```

## 2. Screens (scenes)

| # | Scene | Status | Purpose |
|---|---|---|---|
| 0 | Upgrade | exists | Only with old-app data. SAVE BACKUP & UPGRADE, or NOT NOW. |
| 1 | Character | exists | WoW-style: the character large in the centre on a pedestal. Sex toggle; sliders HEIGHT (1.50–2.00 m), WEIGHT (50–200 kg) and MUSCLE, with the current height and weight on the right. A lime box marks the head: tap it for skin, hair and facial hair (D45). Changes live. No ⋮ menu button on the first setup. The sprite comes from the 5×5 body atlas. |
| 2 | Class select | exists | One big card (lifter, class name, equipment, loadout, 3 tags, description). Swipe to change the class, both ways, round and round; dots under the card (D46). Under them the DIFFICULTY slider, the mode name on the right (D47). No titles in the view. NEXT: STARTING AREA. |
| 3 | Difficulty | removed | Now the slider on the class step (D47). |
| 4 | Starting area | exists | A swipe card like the class card: the area scene with the lifter in it, the name, the line, what you hit, "YOUR PATH'S HOME" on the default; dots under it (D47). The class picks the default area. |
| 5 | Summary | exists | Class, equipment, difficulty, area. Tap a row to change it. LET'S GO (or SAVE when editing). |
| 6 | Hub | removed | No hub (D49): the app opens on the workout. The level and XP bar is in the PUMPLEX bar there; tap the lifter in the world for the body sliders. |
| 7 | Workout | exists | The home screen (D49). One card (D48): the world (area scene with the lifter) on top, an exercise carousel under it (swipe both ways, round and round; dots). No tools (D32). Tap the object = +1 set to the exercise shown, hold = −1. Area marks stay in the world. Bottom bar, HUB lit (D44). |
| 8 | Reward | exists | XP on the active exercise line. CRITICAL SET message. Freeze-frame intro card for level-ups. No achievement burst (D35). Not a separate screen. |
| 9 | Past sessions | removed | Now the past-sessions card of the lifter profile (D50). |
| 10 | Gear | removed | No gear (D38). |
| 11 | Menu | removed | No ⋮ menu (D50): no menu screen and no save / restore backup buttons. |
| 12 | Lifter profile | exists | Tap the lifter (or the level bar) on the workout: the workout shrinks to a square arena tile (D52); beside it the last-session tile; the lifter editor takes the rest, starting on BODY (D53). Swipe it up / down: BODY, CLASS (with difficulty), AREA, round and round; changes save at once (D51). Tap the session tile: the sessions carousel takes the space and the lifter is the tile. Tap the arena tile to go back. |

Removed: the preloader, START TRAINING and its clock, I WORKED / I RESTED and UNDO,
the 7-day pattern, rest days, rest-day stats and the preview pages.
Removed on 22 Nov 2026: the workout tools SWAP, FIRST, SKIP, REMOVE and the ADD card (D32),
the streak and the hub's "This week" card (D34), and the achievements and milestones (D35).

## 3. Initial setup

Show it on the first launch. Later, the lifter card of the lifter profile opens the same screens under
the small workout (D51): BODY the character screen, CLASS and DIFFICULTY the class screen, AREA the area
screen. There they have no BACK / NEXT and every change saves at once. BACK / NEXT exist only in the first setup.

1. **Character.**
   - Pick male or female. Sliders (D45):
     - HEIGHT, 1.50 M to 2.00 M. Only the current value shows, above the slider on the right.
     - WEIGHT, 50 KG to 200 KG. Only the current value shows, the same way. It picks the fat column of the atlas.
     - MUSCLE, with no value and no end labels.
     No hint text: a lime outline box around the head shows it can be tapped.
     The user never types a weight or a height. The values are saved as 0–100 (`height`, `fat`, `muscle`).
   - No random button. No ⋮ menu button (D50).
   - **Tap the head** (inside the lime box): the camera zooms onto the head and the panel shows SKIN (light, deep),
     HAIR (brown, blonde) and FACIAL HAIR (none, beard; both bodies). DONE (or a tap on the head,
     or Android back) zooms out. The looks come from `tools/moodboard/looks.mjs`
     (`assets/body/looks/`): skin and hair are recolours of the body atlas, the beard is an overlay.
   - Sprites: the design team's 5×5 body atlas (`assets/body/body_atlas.png`, a copy of
     `docs/moodboard/creator/body_atlas.png`). Fat and muscle each have stops at 0/25/50/75/100,
     per sex. The app shows the nearest cell for in-between values.
   - The HEIGHT slider scales the sprite evenly, 0.86× to 1.14× (D11, D45). Nearest-neighbour scaling only.
2. **Class select and difficulty** (design: `docs/moodboard/README.md` "Class select", D46, D47).
   - No step kicker, title or subtitle in the view: the PUMPLEX bar says "CLASS · STEP 2 OF 4".
   - One big card fills the top (D46): the user's lifter (from step 1) on top, then the class name
     in its colour, the equipment, the loadout, 3 tags and the description. No stat table. The
     card's hard shadow takes the class colour. The lifter gets the biggest whole-number scale that
     leaves room for the texts; the texts scroll on a short phone.
   - Swipe the card left for the next class, right for the one before, round and round. Dots under
     the card show the class; tap a dot to jump. No class buttons and no freeze-frame card here.
     One class per equipment type.
     Proposed names, kept in `lib/game/content.dart`. The ids are the design ids (D31) and never change:

     | Equipment | Class | Id | Colour |
     |---|---|---|---|
     | No equipment | Scrapper | `scrapper` | orange |
     | Basic home gym | Bargain Bruiser | `bruiser` | sky |
     | Lots of free weights | Plate Paladin | `paladin` | lime |
     | Lots of machines | Cablemancer | `cablemancer` | violet |

   - **Difficulty** (D47): a slider under the dots, 6 stops, the mode name above it on the right in
     its rarity colour. No ladder and no freeze-frame card. Names in `lib/game/content.dart`:
     Sofa, Warm-up, Sweat, Pain, Brutal, Nightmare Mode (D28). Ids: `sofa`, `warmup`, `sweat`,
     `pain`, `brutal`, `nightmare`. The numbers per mode are in `lib/game/rules.dart`:

     | Mode | Exercises (D33) | Target sets | XP multiplier |
     |---|---|---|---|
     | Sofa | 3 | 2 | 1.0 |
     | Warm-up | 3 | 3 | 1.2 |
     | Sweat | 4 | 3 | 1.4 |
     | Pain | 5 | 4 | 1.6 |
     | Brutal | 6 | 4 | 1.8 |
     | Nightmare | 8 | 5 | 2.0 |

   - NEXT: STARTING AREA.
   - The preview shows the body the user made in step 1, in the class outfit (D25).
3. **Starting area** (design: `docs/moodboard/README.md` "Starting areas", D47).
   - No titles in the view: the PUMPLEX bar says "STARTING AREA · STEP 3 OF 4".
   - 5 areas. Each area has an object to hit, a set-mark style and a stamp for every 5th set:

     | Area | Id | Object | Set marks | Stamp | Default for |
     |---|---|---|---|---|---|
     | Riptide Shore | `riptide` | treasure chest | shells | PEARL! | — |
     | Gainsgard Keep | `gainsgard` | wall | tally marks | SLASHED! | Plate Paladin |
     | Rustbelt Flats | `rustbelt` | barrel | spray-painted Xs | TAGGED! | Scrapper |
     | Arcade Underpass | `arcade` | punch machine | tickets | COMBO! | Bargain Bruiser |
     | Frostbite Summit | `frostbite` | ice block | flags up a slope | SUMMIT! | Cablemancer |

   - The ids are the design ids (D36). The id is also the design's folder name in
     `assets/areas/`. Old saved ids (`beach`, `castle`, `summit`) migrate once
     ([data-schema.md](data-schema.md) §5.3).
   - The class picks the default area until the user picks one. The user can choose any area.
   - One swipe card like the class card: the area's scene edge to edge at a whole-number scale
     (the sides may be cut a little, never stretched) with the lifter standing in it, then the name,
     the line, what you hit (e.g. SCRATCH THE WALL) and "YOUR PATH'S HOME" on the default area.
     Swipe both ways, round and round; dots under the card.
   - The scenes are the design team's PNG layers (`assets/areas/<area id>/`). `tools/app/area_art.mjs`
     turns their `anim.json` files into `lib/game/area_art.dart`.
   - NEXT: READY?.
4. **Summary** ("STEP 4 OF 4 · READY?"). Its DIFFICULTY row opens the class step. LET'S GO saves the profile. If old sessions were upgraded, the welcome burst shows their XP.

## 4. Play

### 4.1 Hub (removed) and the lifter profile

There is no hub screen (D49), no bottom bar and no menu (D50). The app opens on the workout (§4.2).

- **Level and XP bar:** in the PUMPLEX bar on the workout.
- **Lifter profile** (D50, D53): tap the lifter in the world, or the level bar. The workout and the lifter
  shrink into a square tile at the top left that shows only the arena (D52).
  - Beside it: the **last-session tile** (date, sets, XP). Under them: the **lifter editor**, starting on BODY.
  - **The lifter editor** is the setup screen of one property, without BACK / NEXT (D51): BODY (the character
    screen), CLASS (the class card with the difficulty slider) or AREA (the area card). Swipe it up for the next
    property, down for the one before, round and round; small bars at its right edge show which. Every change
    saves at once; a slider saves when it is let go, so each body change is one entry in the history.
  - **Tap the session tile:** the past-sessions card takes the space (one training day at a time, swipe both
    ways, round and round, "n / m"), and the lifter becomes a tile (class, difficulty, area). Tap the lifter
    tile to get the editor back.
  - There is no lifter card and no GEAR row (D51, D53).
  - Tap the arena tile to make the workout full screen again.
- **The phone's back button** leaves the app, on every screen (D51).

### 4.2 Workout

Design: `docs/moodboard/README.md` "Workout screen", with the
owner's rules ([decisions.md](decisions.md)).

- A workout has a set number of exercises from the class exercise **pool**: 3 at the easiest
  difficulty, 8 at the hardest (§3). Each exercise has a **target** number of working sets from
  the difficulty. The pools are placeholders, all in `lib/game/content.dart`. The first exercise
  moves along the pool each day.
- **One card** (D48), like the starting-area card. No header.
- **The world** on top of the card: see "World scene" below. It adds sets to the exercise shown
  under it.
- **Filter tags** between the world and the carousel (D49): CLASS (your class), DIFFICULTY (your
  mode) and BODY PART (ALL BODY PARTS). They show the defaults; they do not filter yet.
- **Exercise carousel** under them: one exercise of the day's list at a time (no "x of y" line):
  the name, the target slots as Xs (filled in rarity colours), +n for sets over
  the target, and "SET n OF t" (or sets / target) with the XP so far. Swipe left for the next
  exercise, right for the one before, round and round. Dots under it; tap one to jump.
- **No tools** (D32): no swap, no back to the first exercise, no skip, no remove, no add.
  The workout is the list the app picks for the day. To skip an exercise, do no sets on it.
- Old sessions (from before D32) can still hold removed, added or switched exercises.
  The carousel does not show removed ones.
- **World scene:** the area's scene from the design PNG layers, with the lifter and the area's object.
  - TAP THE OBJECT: one working set of the exercise shown in the carousel.
  - HOLD THE OBJECT: take the last set back.
  - Each set plays the object's hit frames and shakes the scene in hard steps (320 ms). A starburst
    says "+1 SET", "CRUSHED!" at the target, or the area's stamp on every 5th set.
  - The marks stay in the world, in the area's mark style, in groups of five.
  - At the target, the carousel moves to the next unfinished exercise after 0.8 s.
- **Over the sky:** the area's tap hint.
- **Tip:** on the first workout, until the first set, a tag says "Only working sets count".
- No sound (D41).
- Reduced motion: no scene animation.
- The workout is home: Android back leaves the app from here. Tap the lifter for the body sliders.
- Not used from the design board: the I WORKED button, the running clock and "SESSION n"
  (owner decisions D6 and D7 in [decisions.md](decisions.md)). There is one session per calendar day (§4.4).
- Not used from the design board: the swipe and the tool row (D32 replaces D16).

### 4.3 XP and level

The numbers come from [rules.md](rules.md) (draft v1). They are all in `lib/game/rules.dart`.

| Source | XP |
|---|---|
| Working set | 10 × difficulty multiplier (1.0 → 2.0, 6 modes). Sets above the target ×1.5, up to 2× the target; beyond that 0. |
| Critical set | 3% chance, ×2, "CRITICAL SET!!!". The roll is repeatable (seed: date, exercise, set number). |
| First set of the day | +50. |
| Legacy | 150 for each old-app workout day (beta). |
| Old streak bonus | No new streak XP (D34). The bonus that old sessions had is saved once as `streak` XP events. |
| Old achievements | No new achievement XP (D35). The saved `achievement` XP events stay. |

- Sets and first-set XP are computed from the sessions, so a rule change updates them.
  Legacy XP and the old streak and achievement XP are saved XP events.
- Level curve (Habitica): 25 × L for levels 1–4, 150 at level 5, then
  round((0.25 L² + 10 L + 139.75) / 10) × 10. Level 30 needs 660 (D19: the formula wins).
- A level-up shows the freeze-frame intro card ("LEVEL n" and a joke line).
- A level gives only the level and its title. There is no gear (D38) and there are no achievements (D35).
- Not built yet (later in rules.md): mastery stars, the difficulty climb, character stats,
  bounties, new game+. Embers are part of the streak, so they are gone (D34).
  The swap suggestion is on hold: the workout has no swap (D32).
- Each session stores the class, difficulty, area and exercise list it used, so its XP stays the
  same when the profile changes later (for example, after joining a gym).
- A class, difficulty or area change applies to today's workout only if it has no sets yet (the plan
  is made again). Otherwise today keeps its own, and the change shows from the next day.

### 4.4 The session rule (owner's decision: one session per calendar day)

There is no I WORKED button. The calendar day decides:

1. **One session per calendar day.** All set marks (and workout changes) on the same day belong to that day's session.
2. The session **opens** with the first mark or change of the day.
3. A later calendar day starts a new session. (A workout that goes past midnight becomes 2 sessions.)
4. A day with no working sets does not count: no XP, not in the history.

### 4.5 The streak (removed)

- There is no streak, no streak count and no week target (D34, 22 Nov 2026).
- The streak bonus that old sessions earned stays as saved XP ([data-schema.md](data-schema.md) §5.4).

## 5. History

- Training days, newest first: date, sets, time from the first to the last mark, class, area, XP,
  and "sets / target" with a tally per exercise. Today shows first, marked TODAY.
- Old saves (legacy sessions from the old app): date and time, if the old clock was used.
- Shown one day at a time in the past-sessions card of the lifter profile (D50).

## 6. Special cases

| Case | What the app does |
|---|---|
| First launch with old-app data | The upgrade scene. SAVE BACKUP & UPGRADE opens Android's "Save as". Only if the file is saved: old workout days become legacy sessions with XP, then the old keys are deleted. Cancel or NOT NOW: nothing changes, the scene comes back on the next launch. |
| App closed during a workout | The marks are saved. Open the app the same day to continue. |
| Wrong mark | Hold the area's object in the workout scene. |
| Restore a backup | No button for it now (D50). The code stays: it replaces all game data. Version 4 is the current file. A version-3 file loses its achievements list, and the app works out its old streak XP again. Old version-2 backups go through the same migration (legacy sessions + XP, no profile, so the setup runs again). Old-app keys on the phone are only deleted by the upgrade. Old class and area ids in the file become the design ids. |
| Saved data with old class or area ids | On launch, `speedy`, `rogue`, `warrior` and `mage` become `scrapper`, `bruiser`, `paladin` and `cablemancer` (D31), and `beach`, `castle` and `summit` become `riptide`, `gainsgard` and `frostbite` (D36), one time. The old text is kept first ([data-schema.md](data-schema.md) §5.2, §5.3). |
| First launch after the streak and achievements went (D34, D35) | One time: the old streak bonus of each session is saved as XP. The `achievements_v1` key is deleted. No one loses XP ([data-schema.md](data-schema.md) §5.4). |

## 7. Data

The saved data follows [data-schema.md](data-schema.md). The code is in `lib/game/model.dart`
(choices at the top of the file) and `lib/store.dart`.

| Key | Content |
|---|---|
| `profile_v1` | Profile + character (current values), `schemaVersion`, `createdAt`. |
| `body_history_v1` | Every saved slider change, with its time. |
| `sessions_v3` | Map date → session: class, difficulty, area, first and last mark, legacy, exercise list. |
| `xp_events_v1` | Saved XP events (legacy, and the old streak and achievement XP). |
| `gear_v1`, `chaos`, `cel`, `sound` | Removed (D38–D41). Deleted on start. |
| `class_ids_v0_backup` | The profile and sessions text from before the class id migration (D31). |
| `area_ids_v0_backup` | The profile and sessions text from before the area id migration (D36). |
| `streak_xp_frozen_v1` | True once the old streak XP is saved as XP events (D34). |

The key `achievements_v1` (achievement id → unlock time) is deleted on start (D35).

The old keys `sessions_v2`, `logs_v2`, `swaps_v2`, `session_started_ms` and `snooze2_*` are
deleted by the one-time upgrade, after its backup file is saved.
