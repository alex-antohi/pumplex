# PUMPLEX app flow

Date: 21 November 2026. Status: draft v4 (built on branch `claude/game-flow-2dbf96`).
Read with [app-brief.md](app-brief.md), `pumplex.drawio` and `docs/moodboard/`.

Status key: **exists** = in the app now. **later** = waits for the design team or the rules table.

## 1. Overview

The app has 2 parts:

1. **Initial setup** (first launch only): character, class, difficulty, starting area.
2. **Play** (any time): open the workout, count the working sets, get XP.

There is no calendar, no 7-day plan, no START TRAINING clock and no I WORKED button.
The user opens the app when they want, like a video game.

The whole app is **one screen**. Views are scenes of that screen. A change of view is a
camera move (zoom in, zoom out or slide), and the one character glides to its new place.
The app never pushes a new route for a view, so it never flashes a blank screen.

```mermaid
flowchart TD
    launch([Open the app]) --> rule[Session rule: close a stale session]
    rule --> setupDone{Setup done?}
    setupDone -- no --> char[Character + class: sliders, class icons]
    char --> diff[Difficulty: fantasy-named levels]
    diff --> area[Starting area]
    area --> summary[Summary: LET'S GO]
    summary --> hub
    setupDone -- yes --> hub[Hub: character, level, XP bar, today's workout]

    hub -- tap the workout card --> work[Workout: tap = +1 working set, hold = -1]
    work -- each set --> xp[XP and level-up burst]
    work -- HUB --> hub

    hub -. PAST .-> history[Past sessions]
    hub -. menu .-> menu[Edit character, backup, chaos, cel shader]
```

## 2. Screens (scenes)

| # | Scene | Status | Purpose |
|---|---|---|---|
| 1 | Character + class | exists | WoW-style: the character large in the centre on a pedestal. Sex toggle, 🎲 random, class icons row, sliders for height, muscle and fat %. Changes live. |
| 2 | Difficulty | exists | 12 fantasy-named levels, beginner to years of lifting. Shows the XP multiplier. |
| 3 | Starting area | exists | 2 placeholder areas. Real areas come from the design team. |
| 4 | Summary | exists | Class, gear, difficulty, area. Tap a row to change it. LET'S GO (or SAVE when editing). |
| 5 | Hub | exists | The character, the level and XP bar, today's workout card. |
| 6 | Workout | exists | Exercises from the class pool. Tap adds a set, long-press removes one, swipe switches, add, remove, ↺. Tally marks. |
| 7 | Reward | exists | XP shows on each card. A level-up burst when you reach a new level. |
| 8 | Past sessions | exists | Game sessions (sets per exercise, time, XP) and the old saves (beta XP). |
| 9 | Menu | exists | Edit character, save / restore backup, chaos mode, cel shader. |

Removed: the preloader, START TRAINING and its clock, I WORKED / I RESTED and UNDO,
the 7-day pattern, rest days, rest-day stats and the preview pages.

## 3. Initial setup

Show it on the first launch, and again from the menu (EDIT CHARACTER).

1. **Character + class.**
   - Pick male or female. Sliders: height, muscle size, fat %. The user never types a weight or a height.
   - Sprites: mood board body sliders (fat 0/50/100 × muscle 0/50/100 per sex). The app shows the
     nearest frame for in-between values and stretches the sprite vertically for height.
     Nearest-neighbour scaling only.
   - "What do you train with?" One class per equipment type (working names in `lib/game/content.dart`):

     | Pick | Class (working name) |
     |---|---|
     | Nothing | Speedster: cardio, push-ups, burpees, sprints, jumps |
     | A basic home gym | Rogue: floor work, some cardio, some weights |
     | A lot of free weights | Warrior: burly strongman |
     | A lot of machines | Mage: stringy and strong |

     Until the class outfits are drawn, the class shows as the pedestal colour, a prop icon and a name tag.
2. **Difficulty.** 12 levels with our own fantasy names (placeholders, `lib/game/content.dart`).
3. **Starting area.** Placeholders. Later: background, palette and set-mark style.
4. **Summary.** LET'S GO saves the profile. If the phone has old sessions, the welcome burst shows the beta XP.

## 4. Play

### 4.1 Hub

- The character, the class and difficulty name tag, the level and the XP bar.
- Tap the character (or ✎ BODY) to change the body sliders at any time. Each saved change is kept
  in a history (for charts later). In this edit, NEXT goes straight to the summary; tap a summary row
  to change the class, difficulty or area too.
- Today's workout card: today's exercises, with tally marks for the sets done today.
  Tap the card: the camera zooms into the workout.
- ◀ PAST (top left) slides to the past sessions.

### 4.2 Workout

- A workout has a set number of exercises, from the class exercise **pool**. The number depends on
  the difficulty (`exercisesPerWorkout` in `lib/game/rules.dart`). The pools are placeholders, all in
  `lib/game/content.dart`. The first exercise moves along the pool each day.
- One card per exercise. Tap: one more working set. Long-press: one set less (for a wrong tap).
- **Swipe** a card left or right: switch it for the next or previous pool exercise that is not on
  another card. **↺** on a switched card returns it to the exercise the workout first gave.
- **+ ADD EXERCISE** adds a card from the rest of the pool. **✕** removes a card.
- Switch, ↺ and ✕ work only on a card with no sets (take the sets away first). Skipping = doing no sets.
- The mark is a plain tally mark for now. Themed marks per starting area (shells, wall scratches) come later.
- On the first workout a hint says: working sets only, warm-up sets do not count.
- ◀ HUB (or Android back) goes back to the hub.

### 4.3 XP and level

- XP = working sets × XP per set × difficulty multiplier of the session.
- Each session stores the class, the difficulty and the exercise list it used, so its XP stays the
  same when the profile changes later (for example, after joining a gym).
- A class or difficulty change applies to today's workout only if it has no sets yet (the plan is made
  again). Otherwise today keeps its class and difficulty, and the change shows from the next day.
- Old sessions from `sessions_v2` give a fixed XP each (beta).
- Every number is in `lib/game/rules.dart`: XP per set, multipliers, level curve, XP per old session,
  exercises per workout.

### 4.4 The session rule (owner's decision: one session per calendar day)

There is no I WORKED button. The calendar day decides:

1. **One session per calendar day.** All set marks (and workout changes) on the same day belong to that day's session.
2. The session **opens** with the first mark or change of the day.
3. It **closes** when the app is opened, or a set is marked, on a **later calendar day**.
   (A workout that goes past midnight becomes 2 sessions.)
4. A day with no working sets is not kept (skipped day).
5. A closed session never opens again.

When the app opens and closes a session, a message says: "LAST SESSION BANKED: N SETS · +X XP".

## 5. History

- Game sessions: date, sets, time from the first to the last change, class, XP, tally per exercise.
  The open session shows first, marked NOW.
- Old saves (from the old app): date, worked or rested, time if the old clock was used.

## 6. Special cases

| Case | What the app does |
|---|---|
| First launch with old data (sessions exist) | Run the initial setup. Old sessions become XP (beta). |
| App closed during a workout | The marks are saved. Open the app the same day to continue. |
| Wrong mark | Long-press the exercise card. |
| Restore a backup | Replace all data. Old version-2 backups still load; they have no game data, so the setup runs again. |

## 7. Data

The temporary data model is in `lib/game/model.dart` (notes at the top of the file).
The real schema is designed in a separate document.

- Profile (`game_profile_v1`): character (sex, height, muscle, fat 0–100), class id, difficulty id, area id.
- Body history (`game_body_v1`): every saved slider change, with its time.
- Sessions (`game_sessions_v1`, today's in `game_open_v1`): day, first and last change time, class id,
  difficulty id, and the exercise list (current exercise, first exercise, working sets per card).
- XP and level are not stored. They are computed.
- Old keys `sessions_v2`, `logs_v2`, `swaps_v2` are never changed by the game and stay in backups.
