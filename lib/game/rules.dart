// PUMPLEX game rules: EVERY number of the game lives here.
//
// Numbers from docs/rules.md (rules table draft v1, beta testing). Change
// them here and nowhere else. Not built yet (later in rules.md): embers,
// mastery stars, bounties, gear drops with rarity, new game+.

import 'dart:math';

// ------------------------------------------------------------- difficulty

/// The numbers of one difficulty level (docs/data-schema.md §3).
typedef DifficultyRules = ({
  int exercisesPerWorkout, // 3 at the easiest, 8 at the hardest
  int targetSets, // working sets per exercise
  double xpMultiplier, // 1.0 at the lowest, even steps to 2.0 at the highest
  int streakN, // training days per calendar week for the streak
});

/// Per difficulty level, in the order of `difficulties`
/// (lib/game/content.dart). Multiplier = 1 + i / 11 (rules.md §1).
const difficultyRules = <DifficultyRules>[
  (exercisesPerWorkout: 3, targetSets: 2, xpMultiplier: 1.0, streakN: 2),
  (exercisesPerWorkout: 3, targetSets: 2, xpMultiplier: 1.09, streakN: 2),
  (exercisesPerWorkout: 4, targetSets: 3, xpMultiplier: 1.18, streakN: 2),
  (exercisesPerWorkout: 4, targetSets: 3, xpMultiplier: 1.27, streakN: 3),
  (exercisesPerWorkout: 5, targetSets: 3, xpMultiplier: 1.36, streakN: 3),
  (exercisesPerWorkout: 5, targetSets: 4, xpMultiplier: 1.45, streakN: 3),
  (exercisesPerWorkout: 6, targetSets: 4, xpMultiplier: 1.55, streakN: 4),
  (exercisesPerWorkout: 6, targetSets: 4, xpMultiplier: 1.64, streakN: 4),
  (exercisesPerWorkout: 7, targetSets: 5, xpMultiplier: 1.73, streakN: 4),
  (exercisesPerWorkout: 7, targetSets: 5, xpMultiplier: 1.82, streakN: 5),
  (exercisesPerWorkout: 8, targetSets: 5, xpMultiplier: 1.91, streakN: 5),
  (exercisesPerWorkout: 8, targetSets: 6, xpMultiplier: 2.0, streakN: 5),
];

DifficultyRules rulesFor(int difficulty) =>
    difficultyRules[difficulty.clamp(0, difficultyRules.length - 1)];

// ------------------------------------------------------------------- XP

/// XP for one working set, before the difficulty multiplier.
const xpPerSet = 10;

/// A set above the target (up to [overTargetCap] × the target) gives this
/// many times the XP. Sets beyond the cap give 0 (no farming).
const overTargetMultiplier = 1.5;
const overTargetCap = 2;

/// XP for the first working set of the day.
const xpFirstSetOfDay = 50;

/// Streak bonus: +5% set XP per streak week in a row, at most +25%.
const streakBonusPerWeek = 0.05;
const streakBonusMax = 0.25;

/// Critical set: 3% chance, ×2 XP. The roll is repeatable (seed from the
/// date, the exercise and the set number), so XP can be computed again.
const critChance = 0.03;
const critMultiplier = 2;

/// Beta: XP for each old-app workout day (legacy session).
const xpPerLegacySession = 150;

/// Repeatable 3% roll for set [setNumber] of [exerciseId] on [date].
bool isCritical(String date, String exerciseId, int setNumber) {
  // FNV-1a, 32 bit: the same on every phone and every run.
  var h = 0x811c9dc5;
  for (final c in '$date|$exerciseId|$setNumber'.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h % 10000 < (critChance * 10000).round();
}

/// Streak multiplier for [weeks] streak weeks in a row.
double streakMultiplier(int weeks) => 1 + min(streakBonusMax, streakBonusPerWeek * max(0, weeks));

/// XP of set number [setNumber] (from 1) on an exercise with [target] sets,
/// in the order of rules.md §1: base, over target, critical, streak, round.
int xpForSet({
  required int setNumber,
  required int target,
  required int difficulty,
  bool critical = false,
  int streakWeeks = 0,
}) {
  var xp = xpPerSet * rulesFor(difficulty).xpMultiplier;
  if (setNumber > target * overTargetCap) return 0;
  if (setNumber > target) xp *= overTargetMultiplier;
  if (critical) xp *= critMultiplier;
  xp *= streakMultiplier(streakWeeks);
  return xp.round();
}

// ---------------------------------------------------------------- levels

/// XP needed to go from [level] to [level] + 1 (Habitica's curve, rules.md §2).
int xpToNext(int level) {
  if (level <= 4) return 25 * level;
  if (level == 5) return 150;
  return ((0.25 * level * level + 10 * level + 139.75) / 10).round() * 10;
}

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
// - A day with no working sets does not count (skipped day): no XP, no
//   streak day, not shown in history.
//
// THE STREAK: training days per calendar week (Monday to Sunday). A week
// with at least `streakN` training days is a streak week. Missing days
// inside a week never break it. N comes from the difficulty of the last
// session of that week. The streak bonus of a session uses the streak
// weeks in a row BEFORE that session's week (so it never changes later).

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
