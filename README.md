# PUMPLEX™

Owner decisions win over this document: read [docs/decisions.md](docs/decisions.md) first.

Train, not track. An over-the-top, single-player, fully offline gym app for
Android (Flutter). You count only your working sets. A pixel-art character,
a class, levels and worlds give you a reason to come back. All data stays on
the phone.

The plan is in [docs/app-brief.md](docs/app-brief.md) and
[docs/app-flow.md](docs/app-flow.md). The systems diagram is `pumplex.drawio`.

## What works now

- **First launch:** a WoW-style character screen (sex; HEIGHT 1.50–2.00 m,
  WEIGHT 50–200 kg and MUSCLE sliders; tap the head for skin, hair and facial
  hair, D45; sprite from the 5×5 body atlas), class by equipment, difficulty,
  starting area and LET'S GO.
- **Classes:** Scrapper, Bargain Bruiser, Plate Paladin, Cablemancer (ids
  `scrapper`, `bruiser`, `paladin`, `cablemancer`, D31). The character wears
  the class outfit.
- **Difficulty:** 6 modes from the design board (Sofa to Nightmare Mode) on a
  ladder with XP gems. Harder modes give more exercises, sets and XP.
- **Starting areas:** 5 areas from the design board (Riptide Shore, Gainsgard
  Keep, Rustbelt Flats, Arcade Underpass, Frostbite Summit; ids `riptide`,
  `gainsgard`, `rustbelt`, `arcade`, `frostbite`, D36). Each area card
  shows the scene art. The class picks the default area; the user can pick any.
- **Hub**: the area scene with the lifter in it (tap the
  lifter to change the body sliders; changes are kept as a history), the
  level and XP bar, the next workout, the last training day and a
  bottom bar (HISTORY, HUB, PROFILE) that also shows on the workout, past
  sessions and the profile (D44). There is no streak (D34).
- **Workout**: an exercise strip with the day's list and
  the area scene from the design PNG layers. Tap a card to make it active.
  Tap the object = one working set, hold = one less; the marks stay in the
  world. No tools: no swap, skip, remove or add (D32). No reps, no kilos, no
  I WORKED button, no clock.
- **Free-form sessions:** one session per calendar day, no buttons to start
  or stop. The rule is in [docs/app-flow.md](docs/app-flow.md) §4.4.
- The whole app is one screen: views change with a camera zoom or slide.
- Class select ("CHOOSE YOUR PATH", design in `docs/moodboard/`) with the
  freeze-frame intro card, also used for level-ups.
- XP from [docs/rules.md](docs/rules.md): sets × difficulty (×1.5 over the
  target, 0 past 2× the target), 3% critical sets, +50 for the first set of
  the day. Habitica level curve. A level gives a level title.
  No gear (D38), no streak bonus and no achievements (D34, D35). The XP
  that the streak and achievements gave before stays.
- **Old-app data:** a one-time upgrade saves a backup file first, then
  turns the old sessions into XP and deletes the old kg / reps data.
- **Profile**: level title and the path. Tap a row to
  change the class, difficulty or world. No milestones (D35).
- Full-screen menu (⋮): profile, past sessions, edit
  character and save / restore a backup file. No chaos mode, cel shader or
  sound (D39–D41).
- **Design art:** Anton and Space Mono fonts (`assets/fonts`, OFL), pixel
  icons (`assets/icons`), class outfits and area scenes.

Code map: game numbers in `lib/game/rules.dart`, names (classes, exercises,
difficulties, areas) in `lib/game/content.dart`, the saved
data (to [docs/data-schema.md](docs/data-schema.md)) in `lib/game/model.dart`
and `lib/store.dart`, views in `lib/views/`.
`lib/game/area_art.dart` is generated: run `node tools/app/area_art.mjs`
after you copy new area art into `assets/areas/`.

## Set up

1. Install the Flutter SDK (Dart 3.9.2 or later) and the Android SDK.
2. Run `flutter pub get` in the project folder.
3. Connect an Android phone with USB debugging on, or start an emulator.

The packages are in `pubspec.yaml`. Add no new packages without the owner's
OK (D26).

The project path must be short (Windows 260-character limit). If the build
fails on a long path, map the folder to a drive letter with `subst`.

## Run

```bash
flutter run
```

## Test

```bash
flutter test
```

The tests are in `test/app_test.dart`. They cover the rules table, the saved
data and its migrations, the setup, the hub, the workout and the menu.

## Build a release APK

The app id is `com.alex.gym_app` (D26). Release builds read the signing key
from `android/key.properties`:

1. Copy `android/key.properties.example` to `android/key.properties`.
2. Fill in `storePassword`, `keyPassword`, `keyAlias` and `storeFile`.
   Use forward slashes in `storeFile`, also on Windows.
3. Never commit `key.properties` or the `.jks` file. Git ignores both.

Without `android/key.properties`, release builds use the debug key. That is
fine for your own phone, but Google Play rejects it.

```bash
flutter build apk --release
```

The APK is `build/app/outputs/flutter-apk/app-release.apk`. Install it with
`adb install -r <apk>`: `-r` replaces the app and keeps its data. Never
uninstall first.

## Docs

| File | What it holds |
|---|---|
| [docs/decisions.md](docs/decisions.md) | The owner's decisions (D1, D2 …). They win over every other doc. |
| [docs/app-brief.md](docs/app-brief.md) | Purpose, product rules, scope and the 7 systems. |
| [docs/app-flow.md](docs/app-flow.md) | Screens, setup steps, play, the session rule, history and special cases. |
| [docs/data-schema.md](docs/data-schema.md) | Saved data: keys, fields, ids and the migrations. |
| [docs/rules.md](docs/rules.md) | The rules table: XP, level curve and later systems. |
| [docs/marketing/](docs/marketing/01-name.md) | Name research, promo pictures, promo text, marketing ideas and the promo design handoff. |
| [docs/moodboard/](docs/moodboard/README.md) | Design team: the game look, sprites, areas and icons. |

## Game moodboard

The visual direction for the game side (pixel-art characters, palette, style
rules, sprites) is in [`docs/moodboard/`](docs/moodboard/README.md). Read
`docs/moodboard/README.md` before making game art or UI. The scripts in
`tools/moodboard/` build the boards, icons, outfits, animations and sounds.
