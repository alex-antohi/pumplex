# PUMPLEX app brief

Date: 21 November 2026, updated 22 November 2026 (D32–D37). Status: draft v2.2.
Sources: `pumplex.drawio` (the 7 systems), [docs/moodboard/](moodboard/README.md) (game look),
and the owner's decisions in [decisions.md](decisions.md). The decisions win over this brief.

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

| Equipment | First idea | Class now (working name, id) | Training style |
|---|---|---|---|
| No equipment | Speedy class | Scrapper (`scrapper`) | Cardio and bodyweight: push-ups, burpees, sprints, jumps. |
| Basic home gym (some weights) | Rogue-like class | Bargain Bruiser (`bruiser`) | Middle of the road: floor work, some cardio, some weights. |
| A lot of free weights | Warrior / paladin | Plate Paladin (`paladin`) | Burly, bulky, strongman. |
| A lot of machines | Mage / assassin | Cablemancer (`cablemancer`) | Stringy and strong. |

The class names come from the design team (D9). The final names are still open (D27). The ids are the design ids (D31).

### 4.2 Character creation (no weight or height input)

- The user never types a weight or a height.
- Character creation has **sliders**: height, muscle size, fat %.
- The sliders change the character's look. The app uses the design team's 5 × 5 body atlas:
  fat 0 / 25 / 50 / 75 / 100 × muscle 0 / 25 / 50 / 75 / 100, male and female.
  The height slider stretches the sprite (D11).
- The character is **2D** (pixel art, cel-shaded; see `docs/moodboard/README.md`).

### 4.3 Difficulty

- There are many difficulty levels, from total beginner to years of lifting experience.
- The levels have fantasy names, not "easy / medium / hard".
- Main inspiration: the Borderlands games (tone and humour only; all names and art are our own).
- A colleague is making the mood board and the design. The names come from that work.
- Now: 6 modes, Sofa, Warm-up, Sweat, Pain, Brutal and Nightmare Mode (D28).

### 4.4 Free-form sessions

- No 7-day plan. The user opens the app when they want and does a workout.
- Each calendar day with sets is one session (D6).
- The exact preset workouts (per class and character) are decided later.

### 4.5 Tracking: count working sets

- A workout lists exercises, for example squats and push-ups.
- For each exercise, the user marks **how many working sets** they did.
- The **mark depends on the starting area**. Examples:
  - Riptide Shore: put shells in a pouch.
  - Gainsgard Keep: scratch marks on a wall.

### 4.6 Starting areas

- They come from the mood board and design phase.
- Each area sets the look and the colour palette, and the style of the set marks.
- Now: 5 areas, Riptide Shore, Gainsgard Keep, Rustbelt Flats, Arcade Underpass and Frostbite Summit
  ([app-flow.md](app-flow.md) §3).

### 4.7 Existing data

- Keep the sessions that are logged now. Turn them into XP, for our beta testing.
- Delete the old kg / reps sets and swaps, after a backup file (see [data-schema.md](data-schema.md) §5).

### 4.8 Still open

- **Progress:** how the app sees progress is not decided.

## 5. The 7 systems (from the diagram)

| Group | System | Now means |
|---|---|---|
| Main goal | Motivation System | XP and levels; harder difficulty gives more XP. No streak and no achievements (D34, D35). The workout has no swap (D32), so "change exercises when there is no progress" is on hold. |
| Main game loop | Workouts | Preset workouts from the class (equipment) and the character. |
| Main game loop | Tracking Sets | Count working sets per exercise, with area-themed marks. |
| Initial setup | Character Creation | Sliders: height, muscle, fat %. 2D look. |
| Initial setup | Class System | One class per equipment type. |
| Initial setup | Starting Area | Look, palette and set-mark style. From the mood board. |
| Initial setup | Difficulty Level | Many fantasy-named levels, beginner to expert. |

## 6. Core loop

1. Open the app (any time).
2. See today's workout for your class on the hub. Tap it.
3. Do each exercise. Tap the area's object for each working set. The mark (shells, wall scratches and so on) stays in the scene.
4. Get XP for each set. See the level change. The session closes by itself ([app-flow.md](app-flow.md) §4.4).

## 7. The app today (main)

| Part | Status |
|---|---|
| Fixed exercises, sets, reps, kg, rep-outs, PRs, swaps, CSV | Removed (21 Nov). |
| Alex / Anca flavors | Removed. One app id: `com.alex.gym_app`. |
| Old sessions (`sessions_v2`), backup | One-time upgrade: backup file first, then legacy sessions with XP. |
| 7-day pattern, START TRAINING, I WORKED / I RESTED, preloader | Removed (21 Nov). Free-form sessions, hub, set counting, XP and character creation built. |
| CEL SHADER mode | Kept (`shaders/cel.frag`). |
| Old logged sets and swaps | Deleted by the one-time upgrade, after its backup file (owner's decision, [data-schema.md](data-schema.md) §5). |
| Class ids | The design ids since 22 Nov (D31). Saved data migrates once. |
| Area ids | The design ids since 22 Nov (D36): `riptide`, `gainsgard`, `rustbelt`, `arcade`, `frostbite`. Saved data migrates once. |
| Workout tools (swap, back to first, skip, remove, add) | Removed (22 Nov, D32). The workout is the list the app picks for the day. |
| Streak, week target | Removed (22 Nov, D34). The old streak XP stays as saved XP events. |
| Achievements, milestones | Removed (22 Nov, D35). The old achievement XP stays. Only gear unlocks remain. |
| Design art | In the app since 22 Nov: fonts, pixel icons, class outfits, gear sprites, area scenes and the sound pack. |
| Layout | Hub, workout, profile and menu follow the design demo (`docs/demo/`). |
| Release signing | From `android/key.properties` (see the [README](../README.md)). |

## 8. Documents

1. App flow: [app-flow.md](app-flow.md).
2. Data schema: [data-schema.md](data-schema.md).
3. Rules table: [rules.md](rules.md).
4. Owner decisions: [decisions.md](decisions.md).
5. Class and workout list: the exercises per class (later, D27).
6. Implementation plan: the build order (later).
