// The exercise list and the workout filters (D50-D53).
//
// The list is assets/exercises/exercises.json: free-exercise-db
// (github.com/yuhonas/free-exercise-db, Unlicense), cut down to the fields
// the filters use. Ids are the database ids; saved sets point to them.
//
// Filters, in cascade order: class -> difficulty -> body part (-> muscle),
// then favorites. Each filter's option counts use only the filters before
// it (and favorites), so an earlier choice greys out later options.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// One exercise of the list.
class CatalogExercise {
  const CatalogExercise({
    required this.id,
    required this.name,
    required this.category,
    required this.equipment,
    required this.level,
    required this.force,
    required this.mechanic,
    required this.muscle,
  });

  final String id, name, category;

  /// The database value; null in the database is 'body only'.
  final String equipment;

  /// 0 beginner, 1 intermediate, 2 expert.
  final int level;

  /// push, pull, static, or null.
  final String? force;

  /// compound, isolation, or null.
  final String? mechanic;

  /// The first primary muscle (all but one exercise have exactly one).
  final String muscle;

  factory CatalogExercise.fromJson(Map<String, dynamic> j) => CatalogExercise(
        id: j['id'] as String,
        name: j['name'] as String,
        category: j['category'] as String? ?? '',
        equipment: j['equipment'] as String? ?? 'body only',
        level: levels.indexOf(j['level'] as String? ?? '').clamp(0, 2),
        force: j['force'] as String?,
        mechanic: j['mechanic'] as String?,
        muscle: ((j['primaryMuscles'] as List?) ?? const []).cast<String>().firstOrNull ?? '',
      );
}

/// The database levels, easiest first.
const levels = ['beginner', 'intermediate', 'expert'];

/// The hardest level a difficulty mode sees (D51): Sofa and Warm-up see
/// beginner, Sweat and Pain also intermediate, Brutal and Nightmare all.
int topLevelFor(int difficulty) => (difficulty.clamp(0, 5)) ~/ 2;

/// The exercise list, loaded once at start (main.dart).
class ExerciseCatalog {
  ExerciseCatalog(this.all) : byId = {for (final e in all) e.id: e};

  static final empty = ExerciseCatalog(const []);

  final List<CatalogExercise> all;
  final Map<String, CatalogExercise> byId;

  static const asset = 'assets/exercises/exercises.json';

  factory ExerciseCatalog.parse(String json) => ExerciseCatalog([
        for (final e in jsonDecode(json) as List) CatalogExercise.fromJson(Map<String, dynamic>.from(e as Map)),
      ]);

  static Future<ExerciseCatalog> load() async => ExerciseCatalog.parse(await rootBundle.loadString(asset));
}

/// The app's exercise list (set in main.dart before the app starts).
ExerciseCatalog exerciseCatalog = ExerciseCatalog.empty;

/// Display name of an exercise id (the id itself if it is unknown).
String exerciseName(String id) => exerciseCatalog.byId[id]?.name ?? id;

// ---------------------------------------------------------------- class

/// The equipment each class trains with (D50). Every class also gets
/// 'body only'. 'other' (mixed gear) and 'foam roll' are not shown.
const classEquipment = <String, Set<String>>{
  'scrapper': {'body only'},
  'bruiser': {'body only', 'dumbbell', 'kettlebells', 'bands', 'medicine ball', 'exercise ball'},
  'paladin': {'body only', 'barbell', 'e-z curl bar', 'dumbbell', 'kettlebells'},
  'cablemancer': {'body only', 'machine', 'cable'},
};

/// The categories each class shows (D50).
const classCategories = <String, Set<String>>{
  'scrapper': {'strength', 'plyometrics', 'cardio', 'stretching'},
  'bruiser': {'strength', 'plyometrics', 'cardio', 'stretching'},
  'paladin': {'strength', 'powerlifting', 'olympic weightlifting', 'strongman'},
  'cablemancer': {'strength', 'cardio'},
};

// ------------------------------------------------------------ body part

class BodyPart {
  const BodyPart(this.id, this.name, this.muscles);

  final String id, name;
  final List<String> muscles;
}

/// The 17 database muscles in 6 groups (D52).
const bodyParts = <BodyPart>[
  BodyPart('chest', 'Chest', ['chest']),
  BodyPart('back', 'Back', ['lats', 'middle back', 'lower back', 'traps']),
  BodyPart('shoulders', 'Shoulders', ['shoulders', 'neck']),
  BodyPart('arms', 'Arms', ['biceps', 'triceps', 'forearms']),
  BodyPart('legs', 'Legs', ['quadriceps', 'hamstrings', 'glutes', 'calves', 'abductors', 'adductors']),
  BodyPart('core', 'Core', ['abdominals']),
];

BodyPart? bodyPartById(String? id) => bodyParts.where((b) => b.id == id).firstOrNull;

/// The body part of a muscle.
BodyPart? bodyPartOf(String muscle) => bodyParts.where((b) => b.muscles.contains(muscle)).firstOrNull;

// --------------------------------------------------------------- filter

/// The workout filters. Null body or muscle = all.
class ExerciseFilter {
  const ExerciseFilter({
    required this.classId,
    required this.difficulty,
    this.body,
    this.muscle,
    this.favorites = false,
  });

  final String classId;
  final int difficulty;
  final String? body, muscle;

  /// Show favorites only (combined with the other filters, D53).
  final bool favorites;

  ExerciseFilter copyWith({String? classId, int? difficulty, bool? favorites}) => ExerciseFilter(
        classId: classId ?? this.classId,
        difficulty: difficulty ?? this.difficulty,
        body: body,
        muscle: muscle,
        favorites: favorites ?? this.favorites,
      );

  /// A new body part (null = all) clears the muscle.
  ExerciseFilter withBody(String? id) =>
      ExerciseFilter(classId: classId, difficulty: difficulty, body: id, favorites: favorites);

  /// A muscle of the current body part (null = the whole body part).
  ExerciseFilter withMuscle(String? m) =>
      ExerciseFilter(classId: classId, difficulty: difficulty, body: body, muscle: m, favorites: favorites);

  bool _class(CatalogExercise e) =>
      (classEquipment[classId]?.contains(e.equipment) ?? false) &&
      (classCategories[classId]?.contains(e.category) ?? false);

  bool _level(CatalogExercise e) => e.level <= topLevelFor(difficulty);

  bool _body(CatalogExercise e) =>
      muscle != null ? e.muscle == muscle : body == null || (bodyPartById(body)?.muscles.contains(e.muscle) ?? false);

  /// The exercises that pass, sorted: favorites, then the hardest level
  /// first (the user's own level), compound before isolation, then by name.
  List<CatalogExercise> apply(ExerciseCatalog catalog, Set<String> favs) {
    final out = [
      for (final e in catalog.all)
        if (_class(e) && _level(e) && _body(e) && (!favorites || favs.contains(e.id))) e,
    ];
    int mech(CatalogExercise e) => e.mechanic == 'compound' ? 0 : 1;
    out.sort((a, b) {
      final f = (favs.contains(a.id) ? 0 : 1) - (favs.contains(b.id) ? 0 : 1);
      if (f != 0) return f;
      if (a.level != b.level) return b.level - a.level;
      if (mech(a) != mech(b)) return mech(a) - mech(b);
      return a.name.compareTo(b.name);
    });
    return out;
  }

  /// Counts for the options of each filter (cascade: only earlier filters).
  int countClass(ExerciseCatalog c, Set<String> favs, String id) =>
      _count(c, favs, (e) => ExerciseFilter(classId: id, difficulty: difficulty)._class(e));

  int countDifficulty(ExerciseCatalog c, Set<String> favs, int d) =>
      _count(c, favs, (e) => _class(e) && e.level <= topLevelFor(d));

  int countBody(ExerciseCatalog c, Set<String> favs, String? id) =>
      _count(c, favs, (e) => _class(e) && _level(e) && withBody(id)._body(e));

  int countMuscle(ExerciseCatalog c, Set<String> favs, String? m) =>
      _count(c, favs, (e) => _class(e) && _level(e) && withMuscle(m)._body(e));

  int _count(ExerciseCatalog c, Set<String> favs, bool Function(CatalogExercise) test) =>
      c.all.where((e) => test(e) && (!favorites || favs.contains(e.id))).length;

  /// After an earlier filter changed: a body part or muscle with no
  /// exercises left goes back to all.
  ExerciseFilter settle(ExerciseCatalog c, Set<String> favs) {
    var f = this;
    if (f.muscle != null && f.countMuscle(c, favs, f.muscle) == 0) f = f.withMuscle(null);
    if (f.body != null && f.countBody(c, favs, f.body) == 0) f = f.withBody(null);
    return f;
  }

  @override
  bool operator ==(Object other) =>
      other is ExerciseFilter &&
      other.classId == classId &&
      other.difficulty == difficulty &&
      other.body == body &&
      other.muscle == muscle &&
      other.favorites == favorites;

  @override
  int get hashCode => Object.hash(classId, difficulty, body, muscle, favorites);
}
