// PUMPLEX saved data, built to docs/data-schema.md (draft v1, 21 Nov 2026).
//
// Keys (shared_preferences, JSON strings):
//   profile_v1        Profile + Character (current values)
//   body_history_v1   List of BodyChange
//   sessions_v3       Map date -> Session (with its SessionExercise list)
//   xp_events_v1      List of XpEvent (only the ones that cannot be computed)
//
// Choices made here, where the schema leaves room:
// - Times are local ISO-8601 strings without a zone ("2026-11-21T18:02:11").
// - BodyChange also stores `sex`, so a history entry is a full body.
// - XP: the schema says "total XP = sum of XP_EVENT, calculated, never
//   saved" and "change a rule, and the values update". So the XP events
//   for sets and training days are COMPUTED from the sessions with
//   rules.dart every time. Only events that cannot be computed again are
//   saved in xp_events_v1: `legacy` (old-app days), `streak` and
//   `achievement` (kept from before D34 and D35 removed them), and
//   `workout` (the XP of sessions from before the exercise list, D54).
//   The total is the sum of both.
// - A session lists only the exercises with sets that day, in the order
//   of the first set. Exercise ids are free-exercise-db ids (D50).

import 'rules.dart';

String isoNow(DateTime t) => t.toIso8601String().split('.').first;

class Character {
  const Character({
    this.sex = 'male',
    this.height = defaultHeight,
    this.muscle = defaultMuscle,
    this.fat = defaultFat,
    this.skin = defaultSkin,
    this.hair = defaultHair,
    this.facialHair = defaultFacialHair,
    this.name,
  });

  /// 'male' or 'female'.
  final String sex;

  /// Slider values 0..100. The creator shows height in metres and fat as
  /// body weight in kg (rules.dart); the saved value stays 0..100.
  final int height, muscle, fat;

  /// Head looks (ids in rules.dart: skinIds, hairIds, facialHairIds).
  final String skin, hair, facialHair;
  final String? name;

  bool get female => sex == 'female';

  Character copyWith({String? sex, int? height, int? muscle, int? fat, String? skin, String? hair, String? facialHair}) =>
      Character(
        sex: sex ?? this.sex,
        height: height ?? this.height,
        muscle: muscle ?? this.muscle,
        fat: fat ?? this.fat,
        skin: skin ?? this.skin,
        hair: hair ?? this.hair,
        facialHair: facialHair ?? this.facialHair,
        name: name,
      );

  /// Same body and looks (the name does not count).
  bool sameBody(Character o) =>
      o.sex == sex &&
      o.height == height &&
      o.muscle == muscle &&
      o.fat == fat &&
      o.skin == skin &&
      o.hair == hair &&
      o.facialHair == facialHair;

  Map<String, dynamic> toJson() => {
        'sex': sex,
        'height': height,
        'muscle': muscle,
        'fat': fat,
        'skin': skin,
        'hair': hair,
        'facialHair': facialHair,
        if (name != null) 'name': name,
      };

  /// Saved data from before the head looks gets the default looks.
  factory Character.fromJson(Map<String, dynamic> j) => Character(
        sex: j['sex'] == 'female' ? 'female' : 'male',
        height: _pct(j['height'], defaultHeight),
        muscle: _pct(j['muscle'], defaultMuscle),
        fat: _pct(j['fat'], defaultFat),
        skin: _id(j['skin'], skinIds, defaultSkin),
        hair: _id(j['hair'], hairIds, defaultHair),
        facialHair: _id(j['facialHair'], facialHairIds, defaultFacialHair),
        name: j['name'] as String?,
      );

  @override
  bool operator ==(Object other) => other is Character && sameBody(other) && other.name == name;

  @override
  int get hashCode => Object.hash(sex, height, muscle, fat, skin, hair, facialHair, name);
}

int _pct(Object? v, int fallback) => v is num ? v.toInt().clamp(0, 100) : fallback;

String _id(Object? v, List<String> ids, String fallback) => ids.contains(v) ? v as String : fallback;

/// BODY_CHANGE: the sliders at one moment.
class BodyChange {
  const BodyChange({required this.at, required this.character});

  final String at;
  final Character character;

  /// The body only: a history entry has no name.
  Map<String, dynamic> toJson() => {'at': at, ...character.toJson()..remove('name')};

  factory BodyChange.fromJson(Map<String, dynamic> j) =>
      BodyChange(at: j['at'] as String, character: Character.fromJson(j));
}

/// PROFILE + CHARACTER: the current choices.
class Profile {
  const Profile({
    required this.character,
    required this.classId,
    required this.difficultyId,
    required this.areaId,
    this.schemaVersion = 1,
    this.createdAt = '',
  });

  final Character character;
  final String classId, difficultyId, areaId;
  final int schemaVersion;
  final String createdAt;

  Profile copyWith({Character? character, String? classId, String? difficultyId, String? areaId, String? createdAt}) =>
      Profile(
        character: character ?? this.character,
        classId: classId ?? this.classId,
        difficultyId: difficultyId ?? this.difficultyId,
        areaId: areaId ?? this.areaId,
        schemaVersion: schemaVersion,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'classId': classId,
        'difficultyId': difficultyId,
        'areaId': areaId,
        'createdAt': createdAt,
        'character': character.toJson(),
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        character: Character.fromJson(Map<String, dynamic>.from(j['character'] as Map? ?? {})),
        classId: newClassId(j['classId'] as String? ?? ''),
        difficultyId: j['difficultyId'] as String? ?? '',
        areaId: newAreaId(j['areaId'] as String? ?? ''),
        schemaVersion: (j['schemaVersion'] as num?)?.toInt() ?? 1,
        createdAt: j['createdAt'] as String? ?? '',
      );
}

/// SESSION_EXERCISE: one exercise with sets on a day (no targets, D52).
/// The weight and reps of one set (D84, docs/moodboard/today-logging/
/// MINIMAL.md). Log only: they never change XP. Each value is typed (the
/// lifter set it) or carried (copied from the set before); only typed
/// values count as real numbers.
class SetLog {
  const SetLog({this.kg, this.reps, this.kgTyped = false, this.repsTyped = false});

  /// Weight in kg, in steps of 0.5; null: not known.
  final double? kg;

  /// Reps of the set; null: not known.
  final int? reps;
  final bool kgTyped, repsTyped;

  /// The next set starts with these values, carried (not typed).
  SetLog get carried => SetLog(kg: kg, reps: reps);

  bool get isEmpty => kg == null && reps == null;

  Map<String, dynamic> toJson() => {
        if (kg != null) 'kg': kg,
        if (reps != null) 'reps': reps,
        if (kgTyped) 'kgTyped': true,
        if (repsTyped) 'repsTyped': true,
      };

  factory SetLog.fromJson(Map<String, dynamic> j) {
    final kg = (j['kg'] as num?)?.toDouble();
    return SetLog(
      kg: kg == null ? null : (kg.clamp(0, 9999) * 2).round() / 2,
      reps: (j['reps'] as num?)?.toInt().clamp(0, 9999),
      kgTyped: j['kgTyped'] == true,
      repsTyped: j['repsTyped'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SetLog && other.kg == kg && other.reps == reps && other.kgTyped == kgTyped && other.repsTyped == repsTyped;

  @override
  int get hashCode => Object.hash(kg, reps, kgTyped, repsTyped);
}

class SessionExercise {
  const SessionExercise({required this.exerciseId, this.sets = 0, this.log = const []});

  final String exerciseId;

  /// Working sets done.
  final int sets;

  /// The weight and reps of the sets, in order (D84): one per set of a
  /// weighted exercise; shorter (or empty) for old sets and other moves.
  final List<SetLog> log;

  SessionExercise copyWith({int? sets, List<SetLog>? log}) =>
      SessionExercise(exerciseId: exerciseId, sets: sets ?? this.sets, log: log ?? this.log);

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'sets': sets,
        // Only when a set has a value: an all-empty log is not saved.
        if (log.any((l) => !l.isEmpty)) 'log': [for (final l in log) l.toJson()],
      };

  /// Old entries also had position, originalExerciseId, targetSets, added
  /// and removed (before D50); those fields are ignored. Entries from before
  /// D84 have no log.
  factory SessionExercise.fromJson(Map<String, dynamic> j) {
    final sets = (j['sets'] as num?)?.toInt().clamp(0, 9999) ?? 0;
    return SessionExercise(
      exerciseId: newExerciseId(j['exerciseId'] as String),
      sets: sets,
      log: [
        for (final l in (j['log'] as List? ?? const []).take(sets))
          if (l is Map) SetLog.fromJson(Map<String, dynamic>.from(l)),
      ],
    );
  }
}

/// SESSION: one calendar day.
class Session {
  const Session({
    required this.date,
    required this.classId,
    required this.difficultyId,
    required this.areaId,
    this.firstMarkAt,
    this.lastMarkAt,
    this.legacy = false,
    this.exercises = const [],
  });

  /// yyyy-MM-dd. One session per day.
  final String date;
  final String classId, difficultyId, areaId;
  final String? firstMarkAt, lastMarkAt;

  /// From the old app (no exercises, XP from a legacy XP event).
  final bool legacy;
  final List<SessionExercise> exercises;

  int get totalSets => exercises.fold(0, (a, e) => a + e.sets);

  /// A training day: a legacy workout, or at least one working set.
  bool get trained => legacy || totalSets > 0;

  Duration? get duration => firstMarkAt == null || lastMarkAt == null
      ? null
      : DateTime.parse(lastMarkAt!).difference(DateTime.parse(firstMarkAt!));

  Session copyWith({String? lastMarkAt, String? areaId, List<SessionExercise>? exercises}) => Session(
        date: date,
        classId: classId,
        difficultyId: difficultyId,
        areaId: areaId ?? this.areaId,
        firstMarkAt: firstMarkAt ?? lastMarkAt,
        lastMarkAt: lastMarkAt ?? this.lastMarkAt,
        legacy: legacy,
        exercises: exercises ?? this.exercises,
      );

  /// The session with each exercise id changed by [to] (an old id of a
  /// merged exercise goes to the one that replaces it, D90). Entries that
  /// get the same id become one: their sets add up, the logs follow in order.
  Session withExerciseIds(String Function(String id) to) {
    final out = <String, SessionExercise>{};
    var changed = false;
    for (final e in exercises) {
      final id = to(e.exerciseId);
      if (id != e.exerciseId) changed = true;
      final had = out[id];
      if (had == null) {
        out[id] = SessionExercise(exerciseId: id, sets: e.sets, log: e.log);
      } else {
        changed = true;
        // An old entry may have fewer logs than sets: pad, so each log stays on its set.
        final log = [...had.log, for (var i = had.log.length; i < had.sets; i++) const SetLog(), ...e.log];
        out[id] = SessionExercise(exerciseId: id, sets: had.sets + e.sets, log: log.any((l) => !l.isEmpty) ? log : const []);
      }
    }
    return changed ? copyWith(exercises: out.values.toList()) : this;
  }

  Map<String, dynamic> toJson() => {
        'classId': classId,
        'difficultyId': difficultyId,
        'areaId': areaId,
        if (firstMarkAt != null) 'firstMarkAt': firstMarkAt,
        if (lastMarkAt != null) 'lastMarkAt': lastMarkAt,
        'legacy': legacy,
        'exercises': [for (final e in exercises) e.toJson()],
      };

  factory Session.fromJson(String date, Map<String, dynamic> j) => Session(
        date: date,
        classId: newClassId(j['classId'] as String? ?? ''),
        difficultyId: j['difficultyId'] as String? ?? '',
        areaId: newAreaId(j['areaId'] as String? ?? ''),
        firstMarkAt: j['firstMarkAt'] as String?,
        lastMarkAt: j['lastMarkAt'] as String?,
        legacy: j['legacy'] as bool? ?? false,
        exercises: [
          for (final e in j['exercises'] as List? ?? const [])
            SessionExercise.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
      );
}

/// XP_EVENT.
class XpEvent {
  const XpEvent({required this.at, required this.source, required this.amount, required this.ref});

  final String at;

  /// sets | day | streak | achievement | legacy | workout
  final String source;
  final int amount;

  /// Session date (or, for an old achievement event, its id).
  final String ref;

  Map<String, dynamic> toJson() => {'at': at, 'source': source, 'amount': amount, 'ref': ref};

  factory XpEvent.fromJson(Map<String, dynamic> j) => XpEvent(
        at: j['at'] as String? ?? '',
        source: j['source'] as String? ?? '',
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        ref: j['ref'] as String? ?? '',
      );
}

// ------------------------------------------------ class id migration (D31)

/// Old class ids (before 22 Nov 2026) and the design ids that replace them.
const oldClassIds = {'speedy': 'scrapper', 'rogue': 'bruiser', 'warrior': 'paladin', 'mage': 'cablemancer'};

/// The current class id for a saved one. Unknown ids pass through.
String newClassId(String id) => oldClassIds[id] ?? id;

/// Exercise ids start with the class id: `warrior.squat` becomes `paladin.squat`.
String newExerciseId(String id) {
  final dot = id.indexOf('.');
  if (dot < 0) return id;
  final to = oldClassIds[id.substring(0, dot)];
  return to == null ? id : '$to${id.substring(dot)}';
}

// ------------------------------------------------- area id migration (D36)

/// Old area ids (before 22 Nov 2026) and the design ids that replace them.
const oldAreaIds = {'beach': 'riptide', 'castle': 'gainsgard', 'summit': 'frostbite'};

/// The current area id for a saved one. Unknown ids pass through.
String newAreaId(String id) => oldAreaIds[id] ?? id;
