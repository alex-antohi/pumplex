// PUMPLEX game rules: EVERY number of the game lives here.
//
// Numbers from docs/rules.md (rules table draft v1, beta testing). Change
// them here and nowhere else. Not built yet (later in rules.md): embers,
// mastery stars, bounties, new game+.

import 'dart:math';

// ------------------------------------------------------------- difficulty

/// The numbers of one difficulty level (docs/data-schema.md §3). There
/// are no workout targets (D52): the mode sets the XP multiplier and the
/// hardest exercise level the filters show (lib/game/exercises.dart).
typedef DifficultyRules = ({
  double xpMultiplier, // 1.0 at the lowest, even steps to 2.0 at the highest
});

/// Per difficulty level, in the order of `difficulties`
/// (lib/game/content.dart): the design team's 6 modes. Multiplier in even
/// steps from 1.0 to 2.0 (rules.md §1).
const difficultyRules = <DifficultyRules>[
  (xpMultiplier: 1.0), // Sofa
  (xpMultiplier: 1.2), // Warm-up
  (xpMultiplier: 1.4), // Sweat
  (xpMultiplier: 1.6), // Pain
  (xpMultiplier: 1.8), // Brutal
  (xpMultiplier: 2.0), // Nightmare
];

DifficultyRules rulesFor(int difficulty) =>
    difficultyRules[difficulty.clamp(0, difficultyRules.length - 1)];

// ------------------------------------------------------------------- XP

/// XP for one working set, before the difficulty multiplier.
const xpPerSet = 10;

/// Only the first this many sets of one exercise in a day give XP (no
/// farming). There are no targets (D52), so this is the only cap.
const xpSetsPerExercise = 10;

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

/// XP of set number [setNumber] (from 1) of one exercise in a day, before
/// rounding: base × difficulty, ×2 on a critical, 0 past the cap.
double setXp({required int setNumber, required int difficulty, bool critical = false}) {
  if (setNumber > xpSetsPerExercise) return 0;
  var xp = xpPerSet * rulesFor(difficulty).xpMultiplier;
  if (critical) xp *= critMultiplier;
  return xp;
}

/// [setXp], rounded.
int xpForSet({required int setNumber, required int difficulty, bool critical = false}) =>
    setXp(setNumber: setNumber, difficulty: difficulty, critical: critical).round();

/// Set XP by the rules before D52 (targets, ×1.5 over the target up to 2×
/// the target). Only for the one-time freeze of old sessions (store.dart).
double oldSetXp({required int setNumber, required int target, required int difficulty, bool critical = false}) {
  if (setNumber > target * 2) return 0;
  var xp = xpPerSet * rulesFor(difficulty).xpMultiplier;
  if (setNumber > target) xp *= 1.5;
  if (critical) xp *= critMultiplier;
  return xp;
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

/// Head looks (tools/moodboard/looks.mjs). The first id is the drawn atlas.
const skinIds = ['light', 'deep'];
const hairIds = ['brown', 'blonde'];
const facialHairIds = ['none', 'beard'];
const defaultSkin = 'light', defaultHair = 'brown', defaultFacialHair = 'none';

/// Height slider 0..100 shown as 1.50 m .. 2.00 m.
const minHeightM = 1.5, maxHeightM = 2.0;
double heightMetres(int v) => minHeightM + (maxHeightM - minHeightM) * v / 100;

/// The fat slider 0..100 is shown as body weight, 50 kg .. 200 kg.
const minWeightKg = 50, maxWeightKg = 200;
int weightKg(int fat) => (minWeightKg + (maxWeightKg - minWeightKg) * fat / 100).round();

/// Height models (D64): five heights, one per slider stop. Each removes
/// (negative) or repeats (positive) pixel rows of the 52x64 body cell, the
/// same rows in every layer (body, looks, beard, outfit), so all of them
/// stay lined up. The rows are the ones that look most like the next row in
/// every cell (chest 19, hips 37, shins 48 and 50), so the seams do not show.
const heightSteps = [-4, -2, 0, 2, 4];
const heightRows2 = [37, 50];
const heightRows4 = [19, 37, 48, 50];

/// The tallest model, against the 64-row cell (to fit the sprite in a box).
const maxHeightScale = (64 + 4) / 64;

/// Native sprite size in pixels (docs/moodboard/README.md).
const spriteWidth = 52;
const spriteHeight = 64;
