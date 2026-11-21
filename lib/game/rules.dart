// PUMPLEX game rules: EVERY number of the game lives here.
//
// The rules table (docs/app-brief.md §8.3, docs/data-schema.md §6.3) is
// not written yet. These are placeholders for beta testing. Change them
// here and nowhere else.

import 'dart:math';

// ------------------------------------------------------------- difficulty

/// The numbers of one difficulty level (docs/data-schema.md §3).
typedef DifficultyRules = ({
  int exercisesPerWorkout, // 3 at the easiest, 8 at the hardest
  int targetSets, // working sets per exercise
  double xpMultiplier,
  int streakN, // training days per calendar week for the streak
});

/// Per difficulty level, in the order of `difficulties`
/// (lib/game/content.dart). Harder levels give more XP.
const difficultyRules = <DifficultyRules>[
  (exercisesPerWorkout: 3, targetSets: 2, xpMultiplier: 1.0, streakN: 2),
  (exercisesPerWorkout: 3, targetSets: 2, xpMultiplier: 1.1, streakN: 2),
  (exercisesPerWorkout: 4, targetSets: 3, xpMultiplier: 1.2, streakN: 2),
  (exercisesPerWorkout: 4, targetSets: 3, xpMultiplier: 1.3, streakN: 3),
  (exercisesPerWorkout: 5, targetSets: 3, xpMultiplier: 1.4, streakN: 3),
  (exercisesPerWorkout: 5, targetSets: 4, xpMultiplier: 1.5, streakN: 3),
  (exercisesPerWorkout: 6, targetSets: 4, xpMultiplier: 1.6, streakN: 4),
  (exercisesPerWorkout: 6, targetSets: 4, xpMultiplier: 1.7, streakN: 4),
  (exercisesPerWorkout: 7, targetSets: 5, xpMultiplier: 1.8, streakN: 4),
  (exercisesPerWorkout: 7, targetSets: 5, xpMultiplier: 1.9, streakN: 5),
  (exercisesPerWorkout: 8, targetSets: 5, xpMultiplier: 2.0, streakN: 5),
  (exercisesPerWorkout: 8, targetSets: 6, xpMultiplier: 2.2, streakN: 5),
];

DifficultyRules rulesFor(int difficulty) =>
    difficultyRules[difficulty.clamp(0, difficultyRules.length - 1)];

// ------------------------------------------------------------------- XP

/// XP for one working set, before the difficulty multiplier.
const xpPerSet = 10;

/// Extra XP for each working set over the exercise's target (before the
/// multiplier). So a set over target gives xpPerSet + xpPerExtraSet.
const xpPerExtraSet = 5;

/// XP for training on a day (a session with at least one working set).
const xpPerTrainingDay = 20;

/// XP for each calendar week with at least `streakN` training days.
const xpPerStreakWeek = 100;

/// Beta: XP for each old-app workout day (legacy session).
const xpPerLegacySession = 50;

/// XP for working sets on one exercise with [target] sets, at [difficulty].
int xpForExercise(int sets, int target, int difficulty) {
  final extra = max(0, sets - target);
  return ((sets * xpPerSet + extra * xpPerExtraSet) * rulesFor(difficulty).xpMultiplier).round();
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

// THE SESSION RULE (docs/app-flow.md §4.4, docs/data-schema.md §1):
// ONE SESSION PER CALENDAR DAY.
//
// - Every set mark and workout change on the same calendar day belongs to
//   that day's session. The session opens on the first one.
// - A new day starts a new session (the old one simply stays as it is).
// - A day with no working sets does not count (skipped day): no day XP,
//   no streak day, not shown in history.
//
// THE STREAK: training days per calendar week (Monday to Sunday). A week
// with at least `streakN` training days is a streak week. Missing days
// inside a week never break it. N comes from the difficulty of the last
// session of that week.

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
