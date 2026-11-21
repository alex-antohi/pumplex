# PUMPLEX™

Train, not track. An over-the-top, single-player, fully offline gym app for
Android (Flutter). All data stays on the phone.

The plan is in [docs/app-brief.md](docs/app-brief.md) and
[docs/app-flow.md](docs/app-flow.md). The systems diagram is `pumplex.drawio`.

## What works now

- **First launch:** a WoW-style character screen (sex, height, muscle, fat %
  sliders, class by equipment), then difficulty, starting area and LET'S GO.
- **Hub:** the 2D character, the level and XP bar, today's workout.
- **Workout:** one card per exercise. Tap = one working set, long-press =
  one less. No reps, no kilos. XP = sets × XP per set × difficulty.
- **Free-form sessions:** no calendar, no buttons to start or stop. The rule
  is in [docs/app-flow.md](docs/app-flow.md) §4.4.
- The whole app is one screen: views change with a camera zoom or slide.
- Old sessions (`sessions_v2`) give beta XP and show in PAST.
- Menu (⋮): edit character, save / restore a backup file, chaos mode,
  **cel shader** (`shaders/cel.frag`; needs Impeller).

Code map: game numbers in `lib/game/rules.dart`, names (classes, exercises,
difficulties, areas) in `lib/game/content.dart`, the temporary data model in
`lib/game/model.dart`, views in `lib/views/`. Old logged sets and swaps stay
in storage and in backup files.

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

## Game moodboard

The visual direction for the game side (pixel-art characters, palette, style
rules, sprites) is in [`docs/moodboard/`](docs/moodboard/README.md). Read
`docs/moodboard/README.md` before making game art or UI.
