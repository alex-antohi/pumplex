// PUMPLEX game data model (temporary, small on purpose).
//
// The real data schema is being designed in another session. This file is
// the only place that defines what the game stores, so it is easy to
// replace. Choices made here:
//
// - Storage: shared_preferences, JSON strings, new keys with a `_v1` suffix:
//     game_profile_v1   Profile (character + class + difficulty + area)
//     game_sessions_v1  List of closed GameSession
//     game_open_v1      The open GameSession, if any
//   The old keys `sessions_v2`, `logs_v2`, `swaps_v2` are never written by
//   the game. They stay as they are and go into backups.
// - Slider values are ints 0..100. Sex is 'm' or 'f'.
// - Class, difficulty and area are stored by id (lib/game/content.dart).
// - A session stores only working sets per exercise id. No reps, no kilos.
//   It also stores the class and difficulty it was trained at, so XP can be
//   computed again if the rules in lib/game/rules.dart change.
// - XP is never stored. It is computed from the sessions (plus the old
//   `sessions_v2` workouts for beta).
// - Session times: startMs = first mark, endMs = last mark (epoch ms).

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

/// Everything chosen in the initial setup.
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

/// One free-form training session: working sets per exercise.
class GameSession {
  const GameSession({
    required this.startMs,
    required this.endMs,
    required this.classId,
    required this.difficultyId,
    required this.sets,
  });

  final int startMs;
  final int endMs;
  final String classId;
  final String difficultyId;

  /// Exercise id -> working sets (only counts above 0).
  final Map<String, int> sets;

  int get totalSets => sets.values.fold(0, (a, b) => a + b);

  DateTime get start => DateTime.fromMillisecondsSinceEpoch(startMs);
  DateTime get end => DateTime.fromMillisecondsSinceEpoch(endMs);
  Duration get duration => Duration(milliseconds: endMs - startMs);

  GameSession copyWith({int? endMs, Map<String, int>? sets}) => GameSession(
        startMs: startMs,
        endMs: endMs ?? this.endMs,
        classId: classId,
        difficultyId: difficultyId,
        sets: sets ?? this.sets,
      );

  Map<String, dynamic> toJson() => {
        'startMs': startMs,
        'endMs': endMs,
        'classId': classId,
        'difficultyId': difficultyId,
        'sets': sets,
      };

  factory GameSession.fromJson(Map<String, dynamic> j) => GameSession(
        startMs: (j['startMs'] as num).toInt(),
        endMs: (j['endMs'] as num).toInt(),
        classId: j['classId'] as String? ?? '',
        difficultyId: j['difficultyId'] as String? ?? '',
        sets: {
          for (final e in Map<String, dynamic>.from(j['sets'] as Map? ?? {}).entries)
            if (e.value is num && (e.value as num) > 0) e.key: (e.value as num).toInt(),
        },
      );
}
