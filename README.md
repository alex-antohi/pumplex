# PUMPLEX™

Train, not track. An over-the-top, single-player, fully offline gym app for
Android (Flutter). All data stays on the phone.

The plan is in [docs/app-brief.md](docs/app-brief.md) and
[docs/app-flow.md](docs/app-flow.md). The systems diagram is `pumplex.drawio`.

## What works now

- The program runs on **sessions**, not the calendar: a 7-day pattern of
  workout and rest days. The day only moves on when you press
  **I WORKED 💪** or **I RESTED 😴**. UNDO shows for 6 seconds.
- **START TRAINING ▶** starts a clock; I WORKED stops it. Past sessions show
  how long they took.
- Swipe right for past sessions, left to preview the next 6. The floating
  "↩ NOW" goes back.
- Rest days show THE STATS™: workouts, rest days, time trained.
- Menu (⋮): save / restore a backup file, chaos mode.

The workout system (exercises from class, equipment and difficulty) is being
rebuilt. The old fixed exercises, sets and reps were removed. Data logged with
them stays in storage and in backup files.

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
