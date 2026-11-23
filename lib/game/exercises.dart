// The exercise list, its moves with modifiers, and the workout filters
// (D50-D53, D55, D67).
//
// The list is assets/exercises/exercises.json: free-exercise-db
// (github.com/yuhonas/free-exercise-db, Unlicense), cut down to the fields
// the filters use and to the most common exercises
// (tools/exercise_select.mjs, D67). Ids are the database ids; saved sets
// point to them.
//
// Commonness (D67): each card has a `rank` (1 = the most common) and, per
// class, the first difficulty mode that shows it (`unlock`). The tool sets
// both, so every class and mode covers the whole body and each mode has
// more cards than the one before.
//
// Moves (D55): exercises that are one move with different equipment,
// angle, grip, stance and so on share a `base` name and list their
// `mods` (tools/exercise_variants.mjs writes both). The workout shows one
// card per move, with modifier chips that pick the exercise.
//
// Filters, in cascade order: class -> difficulty -> body part (-> muscle),
// then favorites. Each filter's option counts use only the filters before
// it (and favorites), so an earlier choice greys out later options. A move
// passes when the mode shows it for the class and at least one of its
// exercises passes.

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
    String? base,
    this.mods = const {},
    this.rank = 1 << 20,
    this.unlock = const {},
  })  : isMove = base != null,
        base = base ?? name;

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

  /// The move's name (D55); the exercise's own name when it has no variations.
  final String base;

  /// Modifier axis id -> value (see [modifierAxes]); empty without variations.
  final Map<String, String> mods;

  /// Part of a move (the list has a `base`), also when the move has only
  /// this one exercise left (D67), so its card key stays `move:<name>`.
  final bool isMove;

  /// Commonness of the card (D67): 1 = the most common card. The same for
  /// all exercises of a move.
  final int rank;

  /// Class id -> the first difficulty mode (0-5) that shows the card (D67).
  /// A class that is not here does not show it.
  final Map<String, int> unlock;

  factory CatalogExercise.fromJson(Map<String, dynamic> j) => CatalogExercise(
        id: j['id'] as String,
        name: j['name'] as String,
        category: j['category'] as String? ?? '',
        equipment: j['equipment'] as String? ?? 'body only',
        level: levels.indexOf(j['level'] as String? ?? '').clamp(0, 2),
        force: j['force'] as String?,
        mechanic: j['mechanic'] as String?,
        muscle: ((j['primaryMuscles'] as List?) ?? const []).cast<String>().firstOrNull ?? '',
        base: j['base'] as String?,
        mods: Map<String, String>.from(j['mods'] as Map? ?? const {}),
        rank: j['rank'] as int? ?? 1 << 20,
        unlock: Map<String, int>.from(j['unlock'] as Map? ?? const {}),
      );
}

/// A modifier axis on a move's card (D55): its id in `mods`, its label,
/// and the label of "no value" (for example a flat bench).
class ModifierAxis {
  const ModifierAxis(this.id, this.label, this.none);

  final String id, label, none;
}

/// The axes, in the order the card shows them. The values are normalized
/// by tools/exercise_variants.mjs ("Close Grip", "Medium Grip", "Wide Grip").
const modifierAxes = <ModifierAxis>[
  ModifierAxis('equip', 'Equipment', 'Any'),
  ModifierAxis('type', 'Type', 'Standard'),
  ModifierAxis('angle', 'Angle', 'Flat'),
  ModifierAxis('width', 'Grip width', 'Standard'),
  ModifierAxis('hand', 'Grip', 'Standard'),
  ModifierAxis('stance', 'Stance', 'Standard'),
  ModifierAxis('side', 'Arms / legs', 'Both'),
  ModifierAxis('position', 'Position', 'Standard'),
  ModifierAxis('attach', 'Attachment', 'Standard'),
  ModifierAxis('bands', 'Bands', 'No Bands'),
  ModifierAxis('chains', 'Chains', 'No Chains'),
];

/// One card of the workout: a move and its exercises (one, for an
/// exercise with no variations).
class ExerciseGroup {
  const ExerciseGroup(this.key, this.name, this.variants);

  /// `move:<name>` for a move with variations, else the exercise id.
  /// Favorites point to it.
  final String key;
  final String name;

  /// Simplest first: fewest modifiers, then the shortest name.
  final List<CatalogExercise> variants;

  /// Commonness (D67): 1 = the most common card.
  int get rank => variants.first.rank;

  /// Whether [classId] in difficulty mode [difficulty] shows this card (D67).
  bool shownIn(String classId, int difficulty) => (variants.first.unlock[classId] ?? 99) <= difficulty;

  /// The axes where the variants differ, with the values in order of use.
  List<(ModifierAxis, List<String?>)> get axes => _axes(variants, modifierAxes);

  /// The rows the card shows for [current] (D57): equipment first, then
  /// only the ways the exercises with [current]'s equipment differ (so a
  /// dumbbell press has no grip width row).
  List<(ModifierAxis, List<String?>)> axesFor(CatalogExercise current) => [
        ..._axes(variants, modifierAxes.take(1)),
        ..._axes([for (final v in variants) if (v.mods['equip'] == current.mods['equip']) v], modifierAxes.skip(1)),
      ];

  static List<(ModifierAxis, List<String?>)> _axes(List<CatalogExercise> vs, Iterable<ModifierAxis> axes) => [
        for (final a in axes)
          if ({for (final v in vs) v.mods[a.id]}.length > 1) (a, {for (final v in vs) v.mods[a.id]}.toList()..sort(_noneFirst)),
      ];

  ExerciseGroup only(List<CatalogExercise> keep) => ExerciseGroup(key, name, keep);
}

int _noneFirst(String? a, String? b) => a == null ? -1 : b == null ? 1 : a.compareTo(b);

/// The database levels, easiest first.
const levels = ['beginner', 'intermediate', 'expert'];

/// The hardest level a difficulty mode sees (D51): Sofa and Warm-up see
/// beginner, Sweat and Pain also intermediate, Brutal and Nightmare all.
/// Which cards a mode shows is in the list (`unlock`, D67); inside a card,
/// the mode shows only the exercises of its levels.
int topLevelFor(int difficulty) => (difficulty.clamp(0, 5)) ~/ 2;

/// The exercise list, loaded once at start (main.dart).
class ExerciseCatalog {
  ExerciseCatalog(this.all) : byId = {for (final e in all) e.id: e} {
    final byBase = <String, List<CatalogExercise>>{};
    for (final e in all) {
      (byBase[e.base.toLowerCase()] ??= []).add(e);
    }
    for (final list in byBase.values) {
      list.sort((a, b) => a.mods.length != b.mods.length ? a.mods.length - b.mods.length : a.name.length - b.name.length);
      final g = list.length == 1 && !list.single.isMove
          ?ExerciseGroup(list.single.id, list.single.name, list)
          : ExerciseGroup('move:${list.first.base.toLowerCase()}', list.first.base, list);
      groups.add(g);
      for (final e in list) {
        _groupOf[e.id] = g;
      }
    }
    byKey.addAll({for (final g in groups) g.key: g});
  }

  static final empty = ExerciseCatalog(const []);

  final List<CatalogExercise> all;
  final Map<String, CatalogExercise> byId;

  /// One per card (D55).
  final List<ExerciseGroup> groups = [];
  final Map<String, ExerciseGroup> byKey = {};
  final Map<String, ExerciseGroup> _groupOf = {};

  /// The move an exercise belongs to.
  ExerciseGroup? groupOf(String id) => _groupOf[id];

  /// The group key of an exercise id (the id itself if it is unknown).
  String groupKeyOf(String id) => _groupOf[id]?.key ?? id;

  static const asset = 'assets/exercises/exercises.json';

  factory ExerciseCatalog.parse(String json) => ExerciseCatalog([
        for (final e in jsonDecode(json) as List) CatalogExercise.fromJson(Map<String, dynamic>.from(e as Map)),
      ]);

  static Future<ExerciseCatalog> load() async => ExerciseCatalog.parse(await rootBundle.loadString(asset));
}

/// The app's exercise list (set in main.dart before the app starts).
ExerciseCatalog exerciseCatalog = ExerciseCatalog.empty;

/// Display name of an exercise id. An id that is no longer in the list
/// (D67) shows as the id with spaces.
String exerciseName(String id) => exerciseCatalog.byId[id]?.name ?? id.replaceAll('_', ' ');

/// What a modifier chip picks (D57): the exercise, and whether it keeps
/// all of [current]'s other modifiers (`exact`). The equipment row may
/// change the others; every other row stays within [current]'s equipment.
/// Null: no exercise of [g] has that value there.
({CatalogExercise v, bool exact})? chipTarget(ExerciseGroup g, CatalogExercise current, String axis, String? value) {
  final v = pickVariant(g, current, axis, value, sameEquip: axis != 'equip');
  if (v == null) return null;
  final exact = axis == 'equip' || modifierAxes.every((a) => a.id == axis || v.mods[a.id] == current.mods[a.id]);
  return (v: v, exact: exact);
}

/// The exercise of [g] to show for the chosen [value] on [axis], keeping as
/// many of [current]'s other modifiers as it can (and its equipment, with
/// [sameEquip]). Null: no such variant.
CatalogExercise? pickVariant(ExerciseGroup g, CatalogExercise current, String axis, String? value, {bool sameEquip = false}) {
  CatalogExercise? best;
  var bestScore = -1;
  for (final v in g.variants) {
    if (v.mods[axis] != value) continue;
    if (sameEquip && v.mods['equip'] != current.mods['equip']) continue;
    var score = 0;
    for (final a in modifierAxes) {
      if (a.id != axis && v.mods[a.id] == current.mods[a.id]) score++;
    }
    if (score > bestScore) {
      best = v;
      bestScore = score;
    }
  }
  return best;
}

// ---------------------------------------------------------------- class

/// The equipment each class trains with (D50). Every class also gets
/// 'body only'. 'other' (mixed gear) and 'foam roll' are not shown.
const classEquipment = <String, Set<String>>{
  'scrapper': {'body only'},
  'bruiser': {'body only', 'dumbbell', 'kettlebells', 'bands', 'medicine ball', 'exercise ball'},
  'paladin': {'body only', 'barbell', 'e-z curl bar', 'dumbbell', 'kettlebells'},
  'cablemancer': {'body only', 'machine', 'cable'},
};

/// The categories each class shows (D50). Stretching, olympic
/// weightlifting and strongman are not in the list (D56).
const classCategories = <String, Set<String>>{
  'scrapper': {'strength', 'plyometrics', 'cardio'},
  'bruiser': {'strength', 'plyometrics', 'cardio'},
  'paladin': {'strength', 'powerlifting'},
  'cablemancer': {'strength', 'cardio'},
};

// ------------------------------------------------------------ body part

class BodyPart {
  const BodyPart(this.id, this.name, this.muscles);

  final String id, name;
  final List<String> muscles;
}

/// The database muscles in 6 groups (D52). Neck exercises are not in the
/// list (D56).
const bodyParts = <BodyPart>[
  BodyPart('chest', 'Chest', ['chest']),
  BodyPart('back', 'Back', ['lats', 'middle back', 'lower back', 'traps']),
  BodyPart('shoulders', 'Shoulders', ['shoulders']),
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

  /// The cards that pass, each with only its exercises that pass, sorted:
  /// favorites, then the most common first (D67), then by name.
  List<ExerciseGroup> apply(ExerciseCatalog catalog, Set<String> favs) {
    final out = <ExerciseGroup>[];
    for (final g in catalog.groups) {
      if (favorites && !favs.contains(g.key)) continue;
      if (!_shown(g)) continue;
      final keep = [for (final e in g.variants) if (_class(e) && _level(e) && _body(e)) e];
      if (keep.isNotEmpty) out.add(g.only(keep));
    }
    out.sort((a, b) {
      final f = (favs.contains(a.key) ? 0 : 1) - (favs.contains(b.key) ? 0 : 1);
      if (f != 0) return f;
      if (a.rank != b.rank) return a.rank - b.rank;
      return a.name.compareTo(b.name);
    });
    return out;
  }

  /// Card counts for the options of each filter (cascade: only earlier
  /// filters). A class counts all its cards, of every mode.
  int countClass(ExerciseCatalog c, Set<String> favs, String id) => _count(
      c, favs, (g) => g.shownIn(id, 5), (e) => ExerciseFilter(classId: id, difficulty: difficulty)._class(e));

  int countDifficulty(ExerciseCatalog c, Set<String> favs, int d) =>
      _count(c, favs, (g) => g.shownIn(classId, d), (e) => _class(e) && e.level <= topLevelFor(d));

  int countBody(ExerciseCatalog c, Set<String> favs, String? id) =>
      _count(c, favs, _shown, (e) => _class(e) && _level(e) && withBody(id)._body(e));

  int countMuscle(ExerciseCatalog c, Set<String> favs, String? m) =>
      _count(c, favs, _shown, (e) => _class(e) && _level(e) && withMuscle(m)._body(e));

  bool _shown(ExerciseGroup g) => g.shownIn(classId, difficulty);

  int _count(ExerciseCatalog c, Set<String> favs, bool Function(ExerciseGroup) shown,
          bool Function(CatalogExercise) test) =>
      c.groups.where((g) => (!favorites || favs.contains(g.key)) && shown(g) && g.variants.any(test)).length;

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
