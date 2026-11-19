// Training programs. One app build per person (Android flavor, see
// android/app/build.gradle.kts):
//   alex: "Conjugate Program - Sheet1(1).csv"
//   anca: "Conjugate Program Anca - Sheet1.csv"
//
// Each exercise's `id` must stay the same when a program is edited:
// logged history is keyed by it. Days without an entry are rest days.
// The program does not follow the calendar: the next day only comes up
// after "I WORKED" / "I RESTED" (see LogStore.complete).

import 'package:flutter/services.dart' show appFlavor;

/// Whose app this is: 'alex' (default) or 'anca', from `--flavor`.
final String person = appFlavor ?? 'alex';

/// Shown in the app for anyone but the original owner.
String? get ownerLabel => person == 'alex' ? null : person.toUpperCase();

/// The program this build trains.
final Map<int, Workout> program = person == 'anca' ? ancaProgram : alexProgram;

class Exercise {
  const Exercise(
    this.id,
    this.scheme, {
    this.name = '',
    this.hint = '',
    this.note,
    this.percentOf,
  });

  final String id;

  /// As written in the sheet: "3x8", "3-5 Rep Max", "-25% Rep Out", "WORK".
  final String scheme;

  /// Movement from the sheet (can be swapped in the app later).
  final String name;

  /// The "< ..." note from the sheet, e.g. "Unilateral Movement".
  final String hint;

  final String? note;

  /// For "-25% Rep Out": id of the max-effort exercise it is a percentage of.
  final String? percentOf;
}

class Workout {
  const Workout(this.title, this.exercises);

  final String title;
  final List<Exercise> exercises;

  Exercise? byId(String id) {
    for (final e in exercises) {
      if (e.id == id) return e;
    }
    return null;
  }
}

const _boxNote = "Box height by your height: up to 5'6\" → 12\" · "
    "5'7\"–5'10\" → 14\" · 5'11\"–6'2\" → 16\" · 6'3\"+ → 18\"";

/// Anca's sheet. Same slots (and ids) as Alex's; obvious typos fixed
/// ("Lounges" → Lunges, "Font" → Front, "Dumbell" → Dumbbell).
const ancaProgram = <int, Workout>{
  1: Workout('Light Upper', [
    Exercise('lu1', '5x5', name: 'Bench Press'),
    Exercise('lu2', '3x6', name: 'Close Grip Bench'),
    Exercise('lu3', '3x8', name: 'Barbell Rows'),
    Exercise('lu4', '3x8', name: 'Lat Pulldowns'),
    Exercise('lu5', '3x10', name: 'Side Delt Raises'),
    Exercise('lu6', '3x10', name: 'Bicep Curls'),
    Exercise('lu7', '3x12', name: 'Rear Delt Fly'),
  ]),
  2: Workout('Heavy Lower', [
    Exercise('hl1', '3-5 Rep Max', name: 'Front Squat'),
    Exercise('hl2', '-25% Rep Out', name: 'Front Squat', percentOf: 'hl1'),
    Exercise('hl3', '4x6', name: 'Stiffies'),
    Exercise('hl4', '3x8', name: 'Lunges', hint: 'Unilateral Movement'),
    Exercise('hl5', '3x8', name: 'Leg Curls', hint: 'Moderate Posterior Chain Movement'),
    Exercise('hl6', 'WORK', name: 'Abs', hint: 'Heavy Abs'),
  ]),
  4: Workout('Heavy Upper', [
    Exercise('hu1', '3-5 Rep Max', name: 'Bench Press', hint: 'Pressing Movement'),
    Exercise('hu2', '-25% Rep Out', name: 'Bench Press', hint: 'Same Movement', percentOf: 'hu1'),
    Exercise('hu3', '-25% Rep Out', name: 'Bench Press', hint: 'Same Movement', percentOf: 'hu2'),
    Exercise('hu4', '3x6', name: 'Close Grip Pushups', hint: 'Tricep Dominant Movement'),
    Exercise('hu5', '3x8', name: 'Dumbbell Rows', hint: 'Horizontal Pull'),
    Exercise('hu6', '3x8', name: 'Lat Pulldowns Reverse Grip', hint: 'Vertical Pull'),
    Exercise('hu7', '3x10', name: 'Front Delt Raises', hint: 'Shoulder or Pec Fly'),
    Exercise('hu8', '3x10', name: 'Hammer Curls', hint: 'Arm Isolation Movement'),
    Exercise('hu9', '3x12', name: 'High Rows', hint: 'Rear Delt Movement'),
  ]),
  6: Workout('Light Lower', [
    Exercise('ll1', '5x5', name: 'Box Squat', note: _boxNote),
    Exercise('ll2', '4x6', name: 'Stiffies', hint: 'Hard Posterior Chain Movement'),
    Exercise('ll3', '3x8', name: 'Bulgarian Split Squats', hint: 'Unilateral Movement'),
    Exercise('ll4', '3x8', name: 'Leg Raises', hint: 'Moderate Posterior Chain Movement'),
    Exercise('ll5', 'WORK', name: 'Abs'),
  ]),
};

const alexProgram = <int, Workout>{
  1: Workout('Light Upper', [
    Exercise('lu1', '5x5', name: 'Bench'),
    Exercise('lu2', '3x6', name: 'Close Bench'),
    Exercise('lu3', '3x8', name: 'BB Row'),
    Exercise('lu4', '3x8', name: 'Pull up'),
    Exercise('lu5', '3x10', name: 'Side Raise'),
    Exercise('lu6', '3x10', name: 'Bicep Curl'),
    Exercise('lu7', '3x12', name: 'Rear Delt Fly'),
  ]),
  2: Workout('Heavy Lower', [
    Exercise('hl1', '3-5 Rep Max', name: 'LB Squat'),
    Exercise('hl2', '-25% Rep Out', name: 'LB Squat', percentOf: 'hl1'),
    Exercise('hl3', '4x6', name: 'Good Morning'),
    Exercise('hl4', '3x8', name: 'Lunges', hint: 'Unilateral Movement'),
    Exercise('hl5', '3x8', name: 'Leg curl', hint: 'Moderate Posterior Chain Movement'),
    Exercise('hl6', 'WORK', name: 'Cable Ab Curls', hint: 'Heavy Abs'),
  ]),
  4: Workout('Heavy Upper', [
    Exercise('hu1', '3-5 Rep Max', name: 'Bench', hint: 'Pressing Movement'),
    Exercise('hu2', '-25% Rep Out', name: 'Bench', hint: 'Same Movement', percentOf: 'hu1'),
    Exercise('hu3', '-25% Rep Out', name: 'Bench', hint: 'Same Movement', percentOf: 'hu2'),
    Exercise('hu4', '3x6', name: 'Rolling DB Ext.', hint: 'Tricep Dominant Movement'),
    Exercise('hu5', '3x8', name: 'DB Row', hint: 'Horizontal Pull'),
    Exercise('hu6', '3x8', name: 'Pull up', hint: 'Vertical Pull'),
    Exercise('hu7', '3x10', name: 'Front Raise', hint: 'Shoulder or Pec Fly'),
    Exercise('hu8', '3x10', name: 'Bicep Curl', hint: 'Arm Isolation Movement'),
    Exercise('hu9', '3x12', name: 'Band Pull Apart', hint: 'Rear Delt Movement'),
  ]),
  6: Workout('Light Lower', [
    Exercise('ll1', '5x5', name: 'Box Squat', note: _boxNote),
    Exercise('ll2', '4x6', name: 'Stiff Leg DL', hint: 'Hard Posterior Chain Movement'),
    Exercise('ll3', '3x8', name: 'Bulgarian Split Squats', hint: 'Unilateral Movement'),
    Exercise('ll4', '3x8', name: 'Leg Raise', hint: 'Moderate Posterior Chain Movement'),
    Exercise('ll5', 'WORK', name: 'Heavy Abs'),
  ]),
};

/// How a scheme string from the sheet is shown and pre-filled.
class Scheme {
  const Scheme({
    required this.sets,
    required this.description,
    required this.repsHint,
    required this.badge,
    this.reps,
    this.percent,
  });

  /// Set rows shown by default (more can be added).
  final int sets;
  final String description;

  /// Short label for the spinning starburst, e.g. "5×5".
  final String badge;

  /// Placeholder for the reps field when there is no previous log.
  final String repsHint;

  /// Numeric rep target, if the scheme has one.
  final int? reps;

  /// For rep-outs: fraction of today's top set, e.g. 0.75.
  final double? percent;

  factory Scheme.parse(String raw) {
    final s = raw.trim();

    final sxr = RegExp(r'^(\d+)\s*[xX×]\s*(\d+)$').firstMatch(s);
    if (sxr != null) {
      final sets = int.parse(sxr.group(1)!);
      final reps = int.parse(sxr.group(2)!);
      return Scheme(
        sets: sets,
        reps: reps,
        repsHint: '$reps',
        badge: '$sets×$reps',
        description: '$sets sets × $reps reps',
      );
    }

    final rm = RegExp(r'^(\d+(?:\s*-\s*\d+)?)\s*Rep\s*Max$', caseSensitive: false)
        .firstMatch(s);
    if (rm != null) {
      final range = rm.group(1)!.replaceAll(' ', '');
      return Scheme(
        sets: 1,
        repsHint: range,
        badge: '$range\nRM',
        description: 'Work up to a $range rep max',
      );
    }

    final ro = RegExp(r'^-\s*(\d+)\s*%\s*Rep\s*Out$', caseSensitive: false)
        .firstMatch(s);
    if (ro != null) {
      final cut = int.parse(ro.group(1)!);
      final keep = 100 - cut;
      return Scheme(
        sets: 1,
        repsHint: 'max',
        percent: keep / 100,
        badge: '-$cut%',
        description: "1 set, max reps. First time: $keep% of today's max. "
            'After that: same weight, beat the reps',
      );
    }

    if (s.toUpperCase() == 'WORK') {
      return const Scheme(
        sets: 3,
        repsHint: 'reps',
        badge: 'WORK',
        description: 'Work: sets and reps as you like',
      );
    }

    return Scheme(sets: 3, repsHint: 'reps', badge: s, description: s);
  }
}

/// Where an exercise id lives in the program (null if it was removed).
({Workout workout, Exercise exercise, int index})? findExercise(String id) {
  for (final w in program.values) {
    for (var i = 0; i < w.exercises.length; i++) {
      if (w.exercises[i].id == id) return (workout: w, exercise: w.exercises[i], index: i);
    }
  }
  return null;
}
