# Handoff: branch `design-fixes`

Date: 24 Nov 2026. For the next agent picking up the design work on PUMPLEX (Flutter, Android). Read this first, then `docs/decisions.md` (the source of truth; newest rows at the bottom).

## Where things stand

- `design-fixes` is pushed to origin and is main plus our design work. Last pushed commit: fd2f8b8 (CHALK: dimmed tiles stay tappable).
- **In flight:** a FORGE redesign is being built by an agent in a worktree branch (likely `worktree-agent-a002b30808d5a827f`, under `.claude/worktrees/`). The target design is `docs/moodboard/chalk/debate-02/forge-visual-map.html`: FORGE is the continuation of CHALK's 0-matches screen. It should add decision **D88**. If that branch has a finished commit, merge it into `design-fixes`, run `flutter analyze` and `flutter test`, install, and ask the owner before pushing. If it is unfinished, read its diff and carry on from the mockup. Owner defaults for the mockup's open questions: BACK returns to CHALK's 0-matches screen; move chips get no picture; FORGE ANOTHER behaves as today.

## Recent decisions (ours on this branch)

- D73–D76: filter-sheet and workout-card tweaks (renumbered from our old D67–D70 when main took those numbers).
- D84: weight and reps "MINIMAL" strip on weighted moves (`lib/views/set_log.dart`, `SetLog` in `lib/game/model.dart`).
- D85: the strip shows from the start; no corner text; a hold on − / + steps by 5.
- D86: CHALK before the first word showed only a hint (superseded by D87).
- D87: CHALK is the VISUAL MAP (`lib/views/chalk.dart`):
  - Opens on your lifter, with body tags and a gear rack of pixel tool icons (`assets/icons/tools/*.png`, made by `node tools/tool_icons.mjs`; the hammer icon too).
  - A tool or move folds it into lime picked chips, NARROW, and loot cards with pips.
  - 0 matches shows a dashed EMPTY SLOT, FORGE IT, and OR DROP ONE.
  - Dimmed pieces stay tappable.
- Design debates and mockups: `docs/moodboard/chalk/DEBATE-01.md`, `DEBATE-02.md`, and `debate-02/*.html` (the flow is drawn on each mockup).

## Open items

- CHALK: no tap zones on the lifter sprite; BACK does not turn the lifter (no back view). Romanian texts for CHALK, FORGE and log are a first draft.
- FORGE / CHALK owner questions in DEBATE-02 and the mockups.
- D71 XP tiers: the values are not set yet (owner).
- Weight log: personal bests from typed values, and pounds, are open questions (`docs/moodboard/today-logging/MINIMAL.md`).

## How we work (the owner's preferences)

- Ask if unsure. Use few screenshots, scaled down; read text instead where possible.
- Design work ships real app files: assets plus Dart code, not just a mockup.
- Commit messages end with a blank line and `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Push only when the owner says so.
- New decisions get the next D-number, one table row in `docs/decisions.md`. Every text goes in both `assets/i18n/en.json` and `ro.json`, with the same keys (a test checks this).
- Install on the phone, keeping the data: `flutter build apk --release`, then `& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" install -r build\app\outputs\flutter-apk\app-release.apk` (package com.alex.pumplex). Leave the other app, com.alex.gym_app.anca, alone. `adb` is not on PATH in bash; use the full path from PowerShell.
- Looking at a screen without the phone: write a throwaway widget test that pumps `GymApp` at 1080×2340, dpr 2.75. Load the Anton and Space Mono fonts with `FontLoader` from `assets/fonts`, and precache `allSpriteAssets` plus the icons inside `t.runAsync`. Then use `matchesGoldenFile` with `--update-goldens`, read the PNG, and delete the test, the PNGs and `test/failures` afterwards. Without the real fonts, tests use a wide box font, so layout checks in normal tests over-report overflow.
- Anton and Space Mono lack ▸ ◂ ✓ × ⚒ ↻. Use `PxIcon('next' / 'back' / 'check' / 'close' / 'restore')` and the hammer asset; '×' works in Space Mono.
- On the phone: `adb shell screencap -p /sdcard/pl.png` then `adb pull`; `adb shell input tap x y` drives the app (1080×2340 pixels).
