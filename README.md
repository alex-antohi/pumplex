# PUMPLEX™ gym log

Personal Android gym tracker for the conjugate program in
`Conjugate Program - Sheet1.csv`. Flutter, same SDK and packages as `doc_app`
(only `shared_preferences`, already in the pub cache). All data stays on the phone.

## What it does

- The program runs on **sessions**, not the calendar. The first launch is
  Session 1 = Day 1 (Light Upper). The day only moves on when you press
  **I WORKED 💪** (workout days) or **I RESTED 😴** (rest days) at the bottom
  of the page. A snackbar offers UNDO for a few seconds.
- Opens on the current session; swipe right to look back at earlier sessions
  and left to preview the rest of the week. The floating "↩ NOW" jumps back.
- **START TRAINING ▶** at the top of a workout starts a clock (or the first ✔ set
  starts it); I WORKED stops it. Past sessions show how long they took, rest days show the average.
- ✔ on a set needs a weight and reps (0 kg for bodyweight); typing alone
  never ticks. A weight typed in one set is offered to the sets below it.
- Rest days (Day 3, 5, 7) show **THE STATS™**: total kg moved (in elephants),
  workouts, sets, reps, rest days, PRs, this week vs last week, heaviest lifts,
  kg per workout.
- Each exercise card shows the last session of that movement ("LAST WEEK: …"),
  the all-time best, and greyed-out numbers in the set fields. The ✔ copies them in.
  It turns into 🔥 when a set beats last time.
- **-25% Rep Out**: the first time it's 75% of that day's max (rounded to 2.5 kg).
  After that it's the same weight as the last rep-out of that movement, and you
  beat the reps (the ✔ fills the weight only). A new max-effort movement starts
  over at 75%. The second Heavy Upper rep-out is -25% on top of the first one
  (75% of the first rep-out's weight).
- **⇄ SWAP** changes the movement in a slot from that day on. Old logs keep their
  names. Last week, PRs and rep-out weights follow the movement.
- **Swap reminders** (in the app, on the card and in the day header). A "week"
  is one time round the 7-day program:
  - First exercise of Light Upper, Heavy Lower and Heavy Upper: every 2 weeks
    (heads-up in week 2, swap due from week 3).
  - Second movement (Tricep Dominant / Hard Posterior Chain): every 4 weeks
    (heads-up in week 4, swap due from week 5).
  - Everything else, the Box Squat too: after 2 weeks in a row with no progress
    (no new best estimated 1RM and no new best volume).
  - "NOT YET" hides a reminder until that workout comes round again.
  - Rules live at the top of `lib/movements.dart`.
- Menu (⋮): **Export CSV** for the last 7 / 30 / 90 days, all time, or picked
  dates (one row per set, dated by when the session was marked done).
  **Save / restore backup file** (sessions + logs + swaps). **Chaos mode**.

## One app per person

Two Android flavors, each its own app with its own data:

| Flavor | App id | Launcher name | Program |
| --- | --- | --- | --- |
| `alex` | `com.alex.gym_app` (the original) | PUMPLEX | `alexProgram` |
| `anca` | `com.alex.gym_app.anca` | PUMPLEX ANCA (sky-blue icon) | `ancaProgram` |

Always build with `--flavor`; `alex` must keep its app id so updates keep its data.

## Updating a program from the spreadsheet

Everything is in `lib/program.dart` (`alexProgram`, `ancaProgram`). Keep each
exercise's `id` (`lu1`, `hl3`, …) the same when editing: history is keyed by it.
Add new exercises with new ids.

## Build

Windows' 260-character path limit breaks Flutter's shader compiler when the
project sits in a deep folder. Either keep the project at a short path, or map
it to a drive letter for the build:

```bash
subst P: "<path to gym_app>"
cd /d P:\ && flutter build apk --release --flavor alex
subst P: /d
```

The APK lands in `build/app/outputs/flutter-apk/app-<flavor>-release.apk`.
Install with `adb install -r <apk>` (`-r` replaces the app and keeps its data;
never uninstall first), or copy it to the phone and open it.

Tests: `flutter test`.
