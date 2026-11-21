// PUMPLEX game rules: EVERY number of the game lives here.
//
// The rules table (docs/app-brief.md §8.3) is not written yet. These are
// placeholders for beta testing. Change them here and nowhere else.

import 'dart:math';

// ------------------------------------------------------------------- XP

/// XP for one working set, before the difficulty multiplier.
const xpPerSet = 10;

/// XP multiplier per difficulty level, in the order of `difficulties`
/// (lib/game/content.dart). Harder levels give more XP.
const difficultyMultipliers = <double>[
  1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0, 2.2,
];

/// Beta: XP for each workout logged by the old app (`sessions_v2`).
const xpPerOldWorkout = 50;

/// Beta: XP for each rest day logged by the old app (`sessions_v2`).
const xpPerOldRestDay = 0;

/// XP for [sets] working sets at difficulty index [difficulty].
int xpForSets(int sets, int difficulty) {
  final i = difficulty.clamp(0, difficultyMultipliers.length - 1);
  return (sets * xpPerSet * difficultyMultipliers[i]).round();
}

// ---------------------------------------------------------------- levels

/// XP from level 1 to level 2.
const levelBaseXp = 100;

/// Each next level needs this much more XP than the one before.
const levelStepXp = 50;

/// XP needed to go from [level] to [level] + 1.
int xpToNext(int level) => levelBaseXp + levelStepXp * (level - 1);

/// Level (from 1), XP into that level, and XP the level needs.
({int level, int into, int need}) levelFor(int xp) {
  var level = 1;
  var left = max(0, xp);
  while (left >= xpToNext(level)) {
    left -= xpToNext(level);
    level++;
  }
  return (level: level, into: left, need: xpToNext(level));
}

// -------------------------------------------------------------- sessions

// THE SESSION RULE (also in docs/app-flow.md §4.4), owner's decision:
// ONE SESSION PER CALENDAR DAY.
//
// - Every set mark and plan change on the same calendar day belongs to
//   that day's session. The session opens on the first one.
// - It closes when the app is opened, or a set is marked, on a later
//   calendar day. A session with no working sets is dropped (skipped day).
// - A closed session never opens again.
// (No numbers needed: the rule is the calendar day.)

// --------------------------------------------------------------- workouts

/// Exercises in a new workout, per difficulty level (same order as
/// `difficulties`). Capped by the size of the class pool.
const exercisesPerWorkout = <int>[3, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 6];

/// Exercises in a workout for difficulty index [difficulty].
int workoutSize(int difficulty) =>
    exercisesPerWorkout[difficulty.clamp(0, exercisesPerWorkout.length - 1)];

// ------------------------------------------------------------- character

/// Slider stops that have drawn sprites (docs/moodboard/body_sliders).
const spriteStops = [0, 50, 100];

/// Default slider values for a new character (0..100).
const defaultHeight = 50;
const defaultMuscle = 50;
const defaultFat = 50;

/// Vertical sprite scale at height 0 and at height 100.
const minHeightScale = 0.86;
const maxHeightScale = 1.14;

/// Native sprite size in pixels (docs/moodboard/README.md).
const spriteWidth = 52;
const spriteHeight = 64;
