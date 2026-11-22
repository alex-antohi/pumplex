# PUMPLEX™

Owner decisions win over this document: read [docs/decisions.md](docs/decisions.md) first.

Train, not track. An over-the-top, single-player, fully offline gym app for
Android (Flutter). All data stays on the phone.

The plan is in [docs/app-brief.md](docs/app-brief.md) and
[docs/app-flow.md](docs/app-flow.md). The systems diagram is `pumplex.drawio`.

## What works now

- **First launch:** a WoW-style character screen (sex, height, muscle, fat %
  sliders; sprite from the 5×5 body atlas), class by equipment, difficulty,
  starting area and LET'S GO.
- **Difficulty:** 6 levels from the design demo (Couch Spawn to Ascended Swolemancer) on a
  ladder with XP gems. Harder modes give more exercises, sets and XP.
- **Starting areas:** 5 areas from the design board (Riptide Shore, Gainsgard
  Keep, Rustbelt Flats, Arcade Underpass, Frostbite Summit). The class picks
  the default area; the user can pick any.
- **Hub:** the 2D character (tap it to change the body sliders; changes are
  kept as a history), the level and XP bar, today's workout.
- **Workout:** an exercise strip and the area's world scene. Tap the object =
  one working set, hold = one less; the marks stay in the world. Swipe the
  active card to switch the exercise, add or remove exercises. No reps, no
  kilos, no I WORKED button, no clock. XP = sets × XP per set × difficulty.
- **Free-form sessions:** one session per calendar day, no buttons to start
  or stop. The rule is in [docs/app-flow.md](docs/app-flow.md) §4.4.
- The whole app is one screen: views change with a camera zoom or slide.
- Class select ("CHOOSE YOUR PATH", design in `docs/moodboard/`) with the
  freeze-frame intro card, also used for level-ups.
- XP from `docs/rules.md`: sets × difficulty (×1.5 over the target, 0 past
  2× the target), 3% critical sets, +50 for the first set of the day, a
  week-streak bonus, achievements. Habitica level curve. Levels unlock gear
  (one item per slot).
- **Old-app data:** a one-time upgrade saves a backup file first, then
  turns the old sessions into XP and deletes the old kg / reps data.
- **Profile** (design demo 11): level title, the path, milestones. Tap a
  row to change the class, difficulty or world.
- Full-screen menu (⋮, design demo 12): profile, past sessions, edit character, save / restore a backup file, chaos mode,
  **cel shader** (`shaders/cel.frag`; needs Impeller).

Code map: game numbers in `lib/game/rules.dart`, names (classes, exercises,
difficulties, areas, gear, achievements) in `lib/game/content.dart`, the saved
data (to `docs/data-schema.md`) in `lib/game/model.dart` and `lib/store.dart`,
views in `lib/views/`.

## Build

```bash
flutter build apk --release
```

The APK is `build/app/outputs/flutter-apk/app-release.apk`. Install it with
`adb install -r <apk>`: `-r` replaces the app and keeps its data. Never
uninstall first.

The project path must be short (Windows 260-character limit). If the build
fails on a long path, map the folder to a drive letter with `subst`.

Tests: `flutter test`.

## Design demo

A clickable HTML demo of every screen in the app flow, linked together, is in
[`docs/demo/`](docs/demo/BRIEF.md). Open `docs/demo/index.html` in a browser.
`tools/demo/cdp.mjs` drives one headless Edge to test it (no npm packages).

## Game moodboard

The visual direction for the game side (pixel-art characters, palette, style
rules, sprites) is in [`docs/moodboard/`](docs/moodboard/README.md). Read
`docs/moodboard/README.md` before making game art or UI.
