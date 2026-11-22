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
//   saved in xp_events_v1: `legacy` (old-app days), and `streak` and
//   `achievement` (kept from before D34 and D35 removed them). The total
//   is the sum of both.
// - A removed exercise stays in the session with `removed: true`.
// - An added exercise has `added: true` and originalExerciseId = its own id.

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

  Profile copyWith({Character? character, String? createdAt}) => Profile(
        character: character ?? this.character,
        classId: classId,
        difficultyId: difficultyId,
        areaId: areaId,
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

/// SESSION_EXERCISE: one card of a day's workout.
class SessionExercise {
  const SessionExercise({
    required this.position,
    required this.exerciseId,
    required this.originalExerciseId,
    required this.targetSets,
    this.sets = 0,
    this.added = false,
    this.removed = false,
  });

  final int position;
  final String exerciseId;

  /// The exercise the workout first gave (for the back button).
  final String originalExerciseId;
  final int targetSets;

  /// Working sets done.
  final int sets;
  final bool added;
  final bool removed;

  bool get switched => !added && exerciseId != originalExerciseId;

  SessionExercise copyWith({String? exerciseId, int? sets, bool? removed}) => SessionExercise(
        position: position,
        exerciseId: exerciseId ?? this.exerciseId,
        originalExerciseId: originalExerciseId,
        targetSets: targetSets,
        sets: sets ?? this.sets,
        added: added,
        removed: removed ?? this.removed,
      );

  Map<String, dynamic> toJson() => {
        'position': position,
        'exerciseId': exerciseId,
        'originalExerciseId': originalExerciseId,
        'targetSets': targetSets,
        'sets': sets,
        'added': added,
        'removed': removed,
      };

  factory SessionExercise.fromJson(Map<String, dynamic> j) => SessionExercise(
        position: (j['position'] as num?)?.toInt() ?? 0,
        exerciseId: newExerciseId(j['exerciseId'] as String),
        originalExerciseId: newExerciseId(j['originalExerciseId'] as String? ?? j['exerciseId'] as String),
        targetSets: (j['targetSets'] as num?)?.toInt() ?? 0,
        sets: (j['sets'] as num?)?.toInt().clamp(0, 9999) ?? 0,
        added: j['added'] as bool? ?? false,
        removed: j['removed'] as bool? ?? false,
      );
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

  /// The cards on screen (not removed).
  Iterable<SessionExercise> get active => exercises.where((e) => !e.removed);

  int get totalSets => exercises.fold(0, (a, e) => a + e.sets);

  /// A training day: a legacy workout, or at least one working set.
  bool get trained => legacy || totalSets > 0;

  Duration? get duration => firstMarkAt == null || lastMarkAt == null
      ? null
      : DateTime.parse(lastMarkAt!).difference(DateTime.parse(firstMarkAt!));

  Session copyWith({String? lastMarkAt, List<SessionExercise>? exercises}) => Session(
        date: date,
        classId: classId,
        difficultyId: difficultyId,
        areaId: areaId,
        firstMarkAt: firstMarkAt ?? lastMarkAt,
        lastMarkAt: lastMarkAt ?? this.lastMarkAt,
        legacy: legacy,
        exercises: exercises ?? this.exercises,
      );

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

  /// sets | day | streak | achievement | legacy
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
