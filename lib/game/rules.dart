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
});

/// Per difficulty level, in the order of `difficulties`
/// (lib/game/content.dart): the design team's 6 modes. Multiplier in even
/// steps from 1.0 to 2.0 (rules.md §1); 3 exercises at the easiest, 8 at
/// the hardest (exercise counts: D33). Targets are placeholders.
const difficultyRules = <DifficultyRules>[
  (exercisesPerWorkout: 3, targetSets: 2, xpMultiplier: 1.0), // Sofa
  (exercisesPerWorkout: 3, targetSets: 3, xpMultiplier: 1.2), // Warm-up
  (exercisesPerWorkout: 4, targetSets: 3, xpMultiplier: 1.4), // Sweat
  (exercisesPerWorkout: 5, targetSets: 4, xpMultiplier: 1.6), // Pain
  (exercisesPerWorkout: 6, targetSets: 4, xpMultiplier: 1.8), // Brutal
  (exercisesPerWorkout: 8, targetSets: 5, xpMultiplier: 2.0), // Nightmare
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

/// XP of set number [setNumber] (from 1) on an exercise with [target] sets,
/// before rounding, in the order of rules.md §1: base, over target, critical.
double setXp({required int setNumber, required int target, required int difficulty, bool critical = false}) {
  if (setNumber > target * overTargetCap) return 0;
  var xp = xpPerSet * rulesFor(difficulty).xpMultiplier;
  if (setNumber > target) xp *= overTargetMultiplier;
  if (critical) xp *= critMultiplier;
  return xp;
}

/// [setXp], rounded.
int xpForSet({required int setNumber, required int target, required int difficulty, bool critical = false}) =>
    setXp(setNumber: setNumber, target: target, difficulty: difficulty, critical: critical).round();

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
// - A day with no working sets does not count (skipped day): no XP, not
//   shown in history.
//
// No streak (D34) and no achievements (D35). The XP they gave before is
// kept as saved XP events (lib/store.dart).

// ------------------------------------------------------------- character

/// Slider stops that have drawn cells (docs/moodboard/creator/body_atlas.png).
const spriteStops = [0, 25, 50, 75, 100];

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
