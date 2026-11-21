# PUMPLEX app brief

Date: 21 November 2026. Status: draft v2.
Sources: `pumplex.drawio` (the 7 systems), `docs/moodboard/` (game look v0.1),
and the owner's decisions of 21 November 2026.

## 1. Purpose

PUMPLEX makes you train, not track.

Most gym apps ask for every set, rep and kilo. PUMPLEX asks for one thing:
**how many working sets you did** for each exercise. The game layer
(character, class, levels, worlds) gives the reason to come back.

## 2. Product rules

1. **Work first.** Each screen helps you start or finish a workout.
2. **Count sets, nothing else.** For each exercise, mark the working sets you did. No reps, no kilos.
   For weight exercises, count only working sets (not warm-up sets).
3. **Not nerdy.** No tables of numbers. Progress shows as the character, the level and short messages.
4. **The app decides.** The class and the character decide the workouts.
5. **Play when you want.** There is no calendar and no weekly plan. Open the app and train, like a video game.
6. **Over the top.** Loud, funny, high contrast. Look: see `docs/moodboard/`.

## 3. Scope

| Now | Later (future updates) |
|---|---|
| One user | More profiles or accounts |
| Fully offline, data on the phone only | Cloud sync and cloud backup |
| Single player | Friends, leaderboards |
| Android | iOS (needs a Mac or a cloud build) |

## 4. Decisions (21 November 2026)

### 4.1 Class = your equipment

You pick the class by the equipment that you have. There is one class for each equipment type.
The class decides the exercises.

| Equipment | Class (working name) | Training style |
|---|---|---|
| No equipment | Speedy class | Cardio and bodyweight: push-ups, burpees, sprints, jumps. |
| Basic home gym (some weights) | Rogue-like class | Middle of the road: floor work, some cardio, some weights. |
| A lot of free weights | Warrior / paladin | Burly, bulky, strongman. |
| A lot of machines | Mage / assassin | Stringy and strong. |

The final class names come from the design phase.

### 4.2 Character creation (no weight or height input)

- The user never types a weight or a height.
- Character creation has **sliders**: height, muscle size, fat %.
- The sliders change the character's look. The mood board has the first
  body-slider sprites: fat 0 / 50 / 100 × muscle 0 / 50 / 100, male and female.
- The character is **2D** (pixel art, cel-shaded; see `docs/moodboard/README.md`).

### 4.3 Difficulty

- There are many difficulty levels, from total beginner to years of lifting experience.
- The levels have fantasy names, not "easy / medium / hard".
- Main inspiration: the Borderlands games (tone and humour only; all names and art are our own).
- A colleague is making the mood board and the design. The names come from that work.

### 4.4 Free-form sessions

- No 7-day plan. The user opens the app when they want and does a workout.
- Each workout is a session.
- The exact preset workouts (per class and character) are decided later.

### 4.5 Tracking: count working sets

- A workout lists exercises, for example squats and push-ups.
- For each exercise, the user marks **how many working sets** they did.
- The **mark depends on the starting area**. Examples:
  - Beach area: put shells in a pouch.
  - Castle area: scratch marks on a wall.

### 4.6 Starting areas

- They come from the mood board and design phase.
- Each area sets the look and the colour palette, and the style of the set marks.

### 4.7 Existing data

- Keep the sessions that are logged now. Turn them into XP, for our beta testing.
- Delete the old kg / reps sets and swaps, after a backup file (see `data-schema.md` §5).

### 4.8 Still open

- **Progress:** how the app sees progress is not decided.

## 5. The 7 systems (from the diagram)

| Group | System | Now means |
|---|---|---|
| Main goal | Motivation System | XP and levels; harder difficulty gives more XP; change exercises when there is no progress. |
| Main game loop | Workouts | Preset workouts from the class (equipment) and the character. |
| Main game loop | Tracking Sets | Count working sets per exercise, with area-themed marks. |
| Initial setup | Character Creation | Sliders: height, muscle, fat %. 2D look. |
| Initial setup | Class System | One class per equipment type. |
| Initial setup | Starting Area | Look, palette and set-mark style. From the mood board. |
| Initial setup | Difficulty Level | Many fantasy-named levels, beginner to expert. |

## 6. Core loop

1. Open the app (any time).
2. See today's workout for your class on the hub. Tap it.
3. Do each exercise. Tap the card for each working set (later: shells, wall marks, and so on).
4. Get XP for each set. See the level change. The session closes by itself (app-flow.md §4.4).

## 7. The app today (main)

| Part | Status |
|---|---|
| Fixed exercises, sets, reps, kg, rep-outs, PRs, swaps, CSV | Removed (21 Nov). |
| Alex / Anca flavors | Removed. One app id: `com.alex.gym_app`. |
| Old sessions (`sessions_v2`), backup | One-time upgrade: backup file first, then legacy sessions with XP. |
| 7-day pattern, START TRAINING, I WORKED / I RESTED, preloader | Removed (21 Nov). Free-form sessions, hub, set counting, XP and character creation built. |
| CEL SHADER mode | Kept (`shaders/cel.frag`). |
| Old logged sets and swaps | Deleted by the one-time upgrade, after its backup file (owner's decision, data-schema.md §5). |

## 8. Next documents

1. App flow: [app-flow.md](app-flow.md).
2. Data schema: character, class, starting area, difficulty, sessions, set marks, XP.
3. Rules table: XP per working set, difficulty multipliers, level curve, XP for old sessions.
4. Class and workout list: the exercises per class (later).
5. Implementation plan: the build order.
