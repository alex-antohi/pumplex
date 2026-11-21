// PUMPLEX game data model (temporary, small on purpose).
//
// The real data schema is being designed in another session. This file is
// the only place that defines what the game stores, so it is easy to
// replace. Choices made here:
//
// - Storage: shared_preferences, JSON strings, new keys with a `_v1` suffix:
//     game_profile_v1   Profile: current character + class + difficulty + area
//     game_body_v1      List of BodyEntry: every slider change, for charts later
//     game_sessions_v1  List of closed GameSession
//     game_open_v1      Today's GameSession, if any
//   The old keys `sessions_v2`, `logs_v2`, `swaps_v2` are never written by
//   the game. They stay as they are and go into backups.
// - Slider values are ints 0..100. Sex is 'm' or 'f'.
// - Class, difficulty and area are stored by id (lib/game/content.dart).
//   Class and difficulty can change later, so each session stores the ones
//   it used: its XP never changes when the profile changes.
// - One session per calendar day (`day`, yyyy-MM-dd).
// - A session stores its exercise list as slots. Each slot has the current
//   exercise, the exercise the workout first gave (null for one the user
//   added) and the working sets done. No reps, no kilos. Skipped = 0 sets.
// - XP is never stored. It is computed from the sessions (plus the old
//   `sessions_v2` workouts for beta) with lib/game/rules.dart.

import 'rules.dart';

class Character {
  const Character({
    this.sex = 'm',
    this.height = defaultHeight,
    this.muscle = defaultMuscle,
    this.fat = defaultFat,
  });

  final String sex;
  final int height, muscle, fat;

  bool get female => sex == 'f';

  Character copyWith({String? sex, int? height, int? muscle, int? fat}) => Character(
        sex: sex ?? this.sex,
        height: height ?? this.height,
        muscle: muscle ?? this.muscle,
        fat: fat ?? this.fat,
      );

  Map<String, dynamic> toJson() =>
      {'sex': sex, 'height': height, 'muscle': muscle, 'fat': fat};

  factory Character.fromJson(Map<String, dynamic> j) => Character(
        sex: j['sex'] == 'f' ? 'f' : 'm',
        height: _pct(j['height'], defaultHeight),
        muscle: _pct(j['muscle'], defaultMuscle),
        fat: _pct(j['fat'], defaultFat),
      );

  @override
  bool operator ==(Object other) =>
      other is Character &&
      other.sex == sex &&
      other.height == height &&
      other.muscle == muscle &&
      other.fat == fat;

  @override
  int get hashCode => Object.hash(sex, height, muscle, fat);
}

int _pct(Object? v, int fallback) => v is num ? v.toInt().clamp(0, 100) : fallback;

/// The body sliders at one moment (one entry per saved change).
class BodyEntry {
  const BodyEntry({required this.atMs, required this.character});

  final int atMs;
  final Character character;

  DateTime get at => DateTime.fromMillisecondsSinceEpoch(atMs);

  Map<String, dynamic> toJson() => {'atMs': atMs, ...character.toJson()};

  factory BodyEntry.fromJson(Map<String, dynamic> j) =>
      BodyEntry(atMs: (j['atMs'] as num).toInt(), character: Character.fromJson(j));
}

/// Everything chosen in the setup (the current values).
class Profile {
  const Profile({
    required this.character,
    required this.classId,
    required this.difficultyId,
    required this.areaId,
  });

  final Character character;
  final String classId;
  final String difficultyId;
  final String areaId;

  Map<String, dynamic> toJson() => {
        'character': character.toJson(),
        'classId': classId,
        'difficultyId': difficultyId,
        'areaId': areaId,
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        character: Character.fromJson(Map<String, dynamic>.from(j['character'] as Map? ?? {})),
        classId: j['classId'] as String? ?? '',
        difficultyId: j['difficultyId'] as String? ?? '',
        areaId: j['areaId'] as String? ?? '',
      );
}

/// One exercise in a workout.
class Slot {
  const Slot({required this.exerciseId, this.initialId, this.sets = 0});

  /// The exercise now on the card.
  final String exerciseId;

  /// The exercise the workout first gave; null if the user added the card.
  final String? initialId;

  /// Working sets done.
  final int sets;

  bool get switched => initialId != null && initialId != exerciseId;

  Slot copyWith({String? exerciseId, int? sets}) =>
      Slot(exerciseId: exerciseId ?? this.exerciseId, initialId: initialId, sets: sets ?? this.sets);

  Map<String, dynamic> toJson() => {
        'ex': exerciseId,
        if (initialId != null) 'initial': initialId,
        'sets': sets,
      };

  factory Slot.fromJson(Map<String, dynamic> j) => Slot(
        exerciseId: j['ex'] as String,
        initialId: j['initial'] as String?,
        sets: (j['sets'] as num?)?.toInt().clamp(0, 9999) ?? 0,
      );
}

/// One day's training session.
class GameSession {
  const GameSession({
    required this.day,
    required this.startMs,
    required this.endMs,
    required this.classId,
    required this.difficultyId,
    required this.slots,
  });

  /// Calendar day, yyyy-MM-dd. One session per day.
  final String day;

  /// First and last change (set mark or plan change), epoch ms.
  final int startMs;
  final int endMs;
  final String classId;
  final String difficultyId;

  /// The workout's exercises, in order.
  final List<Slot> slots;

  int get totalSets => slots.fold(0, (a, s) => a + s.sets);

  /// Exercise id -> working sets (only exercises with sets).
  Map<String, int> get sets {
    final m = <String, int>{};
    for (final s in slots) {
      if (s.sets > 0) m[s.exerciseId] = (m[s.exerciseId] ?? 0) + s.sets;
    }
    return m;
  }

  DateTime get start => DateTime.fromMillisecondsSinceEpoch(startMs);
  DateTime get end => DateTime.fromMillisecondsSinceEpoch(endMs);
  Duration get duration => Duration(milliseconds: endMs - startMs);

  GameSession copyWith({int? endMs, String? classId, String? difficultyId, List<Slot>? slots}) =>
      GameSession(
        day: day,
        startMs: startMs,
        endMs: endMs ?? this.endMs,
        classId: classId ?? this.classId,
        difficultyId: difficultyId ?? this.difficultyId,
        slots: slots ?? this.slots,
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'startMs': startMs,
        'endMs': endMs,
        'classId': classId,
        'difficultyId': difficultyId,
        'slots': [for (final s in slots) s.toJson()],
      };

  factory GameSession.fromJson(Map<String, dynamic> j) => GameSession(
        day: j['day'] as String,
        startMs: (j['startMs'] as num).toInt(),
        endMs: (j['endMs'] as num).toInt(),
        classId: j['classId'] as String? ?? '',
        difficultyId: j['difficultyId'] as String? ?? '',
        slots: [
          for (final s in j['slots'] as List? ?? const [])
            Slot.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
      );
}
