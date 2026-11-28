// The exercise list, its moves with modifiers, and the class filter
// (D50-D53, D55, D67).
//
// The list is assets/exercises/exercises.json: free-exercise-db
// (github.com/yuhonas/free-exercise-db, Unlicense), cut down to the fields
// the filters use and to the most common exercises
// (tools/exercise_select.mjs, D67). Ids are the database ids; saved sets
// point to them. Since D80 a move's grid of axes adds the variations the
// database lacks (tools/exercise_variants.mjs GRID); their ids are the move
// and its modifier values (`push-up|bodyweight|knee|close grip`), and their
// names are composed from translated parts (composeName), not translated
// one by one.
//
// Aliases (D90): a merged or removed exercise keeps its old id as an alias
// of the exercise that replaces it (`aliases` in the list). The app reads
// saved sets, favorites, Today and the picks through [ExerciseCatalog.resolveId],
// so no old id is lost (tools/frozen_ids.txt; the data tools check it).
//
// Commonness (D67): each card has a `rank` (1 = the most common) and a
// movement pattern (`pattern`, D69: a push, a pull, a squat, a hinge and so
// on). There is no `unlock` and no class filter (D89): no lift is hidden by
// class or mode. The class lights its gear (lib/game/chalk.dart).
//
// Moves (D55): exercises that are one move with different equipment,
// angle, grip, stance and so on share a `base` name and list their
// `mods` (tools/exercise_variants.mjs writes both). The workout shows one
// card per move, with modifier chips that pick the exercise.

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
    this.pattern,
    this.nick,
    this.aliases = const [],
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

  /// The movement pattern of the card (D69), for example `hpush`
  /// (horizontal push); see [corePatterns]. The same for all exercises of
  /// a move.
  final String? pattern;

  /// A forged move's nickname (D72, lib/game/forge.dart): the big name.
  final String? nick;

  /// Old ids that now mean this exercise (merged or removed, D90).
  final List<String> aliases;

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
        pattern: j['pattern'] as String?,
        aliases: ((j['aliases'] as List?) ?? const []).cast<String>(),
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
  // Split out of Type (D90): Weighted, Band Assisted; the station or extra
  // gear (Bench, Rings, Towel, Trap Bar ...). Right after Type, as in the
  // generated ids (tools/exercise_names.mjs AXIS_ORDER).
  ModifierAxis('load', 'Load', 'Standard'),
  ModifierAxis('setup', 'Setup', 'Standard'),
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

  /// `move:<name>`; every exercise of the list has a move (D69 clean-up).
  /// An exercise with no `base` (an old list) has its id. Favorites point
  /// to it.
  final String key;
  final String name;

  /// Simplest first: fewest modifiers (Rings/TRX counts as one more), then
  /// the shortest name.
  final List<CatalogExercise> variants;

  /// Commonness (D67): 1 = the most common card.
  int get rank => variants.first.rank;

  /// The movement pattern (D69).
  String? get pattern => variants.first.pattern;

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

/// The movement patterns that every class and mode shows from Sofa on,
/// where the class has the gear (D69): pushes, pulls, legs, arms, rear
/// delts and core. tools/exercise_select.mjs fills them first.
const corePatterns = [
  'hpush', 'vpush', 'hpull', 'vpull', 'squat', 'hinge', 'single', 'calves', 'biceps', 'triceps', 'rear', 'flex', 'antiext',
];

/// The database levels, easiest first.
const levels = ['beginner', 'intermediate', 'expert'];

/// The hardest level a difficulty mode sees (D51): Sofa and Warm-up see
/// beginner, Sweat and Pain also intermediate, Brutal and Nightmare all.
/// Nothing is hidden (D70, D89): it only sets the HARD badge.
int topLevelFor(int difficulty) => (difficulty.clamp(0, 5)) ~/ 2;

/// The HARD badge (D89): exercise [e] is above difficulty mode
/// [difficulty] by its level. Nothing is hidden or locked.
bool isHardFor(CatalogExercise e, int difficulty) => e.level > topLevelFor(difficulty);

/// The exercise list, loaded once at start (main.dart).
class ExerciseCatalog {
  ExerciseCatalog(this.all)
      : byId = {for (final e in all) e.id: e},
        aliasOf = {for (final e in all) for (final a in e.aliases) a: e.id} {
    final byBase = <String, List<CatalogExercise>>{};
    for (final e in all) {
      (byBase[e.base.toLowerCase()] ??= []).add(e);
    }
    for (final list in byBase.values) {
      // Rings/TRX counts as one modifier more (D90 step 2): a ring lift is
      // the bodyweight lift made harder, never the card's first.
      int plain(CatalogExercise e) => e.mods.length + (e.mods['equip'] == 'Rings' ? 1 : 0);
      list.sort((a, b) => plain(a) != plain(b) ? plain(a) - plain(b) : a.name.length - b.name.length);
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

  /// Old id of a merged or removed exercise -> the id that replaces it (D90).
  final Map<String, String> aliasOf;

  /// The id to use for a saved id: an alias goes to the exercise that
  /// replaces it; any other id stays (also an unknown one).
  String resolveId(String id) => byId.containsKey(id) ? id : aliasOf[id] ?? id;

  /// One per card (D55).
  final List<ExerciseGroup> groups = [];
  final Map<String, ExerciseGroup> byKey = {};
  final Map<String, ExerciseGroup> _groupOf = {};

  /// The move an exercise belongs to.
  ExerciseGroup? groupOf(String id) => _groupOf[id];

  /// The group key of an exercise id (the id itself if it is unknown). An
  /// old move key whose move was renamed or split (D69 clean-up) points to
  /// the move of its main exercise, so saved favorites follow.
  String groupKeyOf(String id) =>
      _groupOf[resolveId(id)]?.key ?? (byKey.containsKey(id) ? id : _groupOf[movedMoves[id]]?.key ?? id);

  /// Old move keys -> the exercise whose move now holds them (D69 clean-up
  /// and the variation audit). Cards that were one exercise had the
  /// exercise id as key, so they follow without an entry here. Favorites
  /// are per card; D72 makes them per variant later (not built yet).
  static const movedMoves = {
    'move:row': 'One-Arm_Dumbbell_Row',
    'move:bent over row': 'Bent_Over_Barbell_Row',
    'move:bent over long bar row': 'Bent_Over_Two-Arm_Long_Bar_Row',
    'move:rear lateral raise': 'Dumbbell_Lying_Rear_Lateral_Raise',
    // The variation audit: merged moves.
    'move:chin-up': 'Chin-Up',
    'move:butterfly': 'Butterfly',
    'move:low cable crossover': 'Low_Cable_Crossover',
    'move:sumo squat': 'Plie_Dumbbell_Squat',
    // ('move:power clean' is a card again since D90: the Power Clean is its only lift.)
    'move:leg press calf raise': 'Calf_Press_On_The_Leg_Press_Machine',
    'move:rocking calf raise': 'Rocking_Standing_Calf_Raise',
    'move:walking lunge': 'Barbell_Walking_Lunge',
    'move:stiff-legged deadlift': 'Stiff-Legged_Barbell_Deadlift',
    'move:bulgarian split squat': 'Bodyweight_Bulgarian_Split_Squat',
    'move:straight-arm pullover': 'Straight-Arm_Dumbbell_Pullover',
    'move:bent-arm pullover': 'Bent-Arm_Barbell_Pullover',
    'move:plyo push-up': 'Plyo_Push-up',
    'move:bodyweight triceps extension': 'Body_Tricep_Press',
    'move:towel row': 'Towel_Row',
    'move:feet-elevated inverted row': 'Feet-Elevated_Inverted_Row',
    'move:one-arm inverted row': 'One-Arm_Inverted_Row',
    'move:glute-ham raise': 'Natural_Glute_Ham_Raise',
    // The list clean-up of D90 (step 1): merged and removed moves.
    'move:bent-over triceps extension': 'Tricep_Dumbbell_Kickback',
    'move:triceps press': 'EZ-Bar_Skullcrusher',
    'move:close-grip dumbbell push-up': 'Push-Ups_-_Close_Triceps_Position',
    'move:bent-knee hip raise': 'Reverse_Crunch',
    'move:scissors jump': 'Split_Jump',
    'move:rope crunch': 'Cable_Crunch',
    'move:hip extension': 'Hip_Extension_with_Bands',
    'move:clean': 'Power_Clean',
    'move:clean and press': 'Barbell_Push_Press',
    'move:kettlebell sumo high pull': 'sumo deadlift|kettlebell',
    // D90 step 2: the jump cards fold into Jump Squat, Jumping Lunge, Long
    // Jump and Running Drill; each old card goes to its lift there.
    'move:star jump': 'Star_Jump',
    'move:knee tuck jump': 'Knee_Tuck_Jump',
    'move:rocket jump': 'Rocket_Jump',
    'move:box jump': 'Front_Box_Jump',
    'move:split jump': 'Split_Jump',
    'move:standing long jump': 'Standing_Long_Jump',
    'move:lateral bound': 'Lateral_Bound',
    'move:fast skipping': 'Fast_Skipping',
    'move:carioca quick step': 'Carioca_Quick_Step',
    'move:butt kick': 'Double_Leg_Butt_Kick',
  };

  static const asset = 'assets/exercises/exercises.json';

  factory ExerciseCatalog.parse(String json) => ExerciseCatalog([
        for (final e in jsonDecode(json) as List) CatalogExercise.fromJson(Map<String, dynamic>.from(e as Map)),
      ]);

  static Future<ExerciseCatalog> load() async => ExerciseCatalog.parse(await rootBundle.loadString(asset));
}

/// The app's exercise list (set in main.dart before the app starts).
ExerciseCatalog exerciseCatalog = ExerciseCatalog.empty;

/// Display name of an exercise id, in English. An id that is no longer in
/// the list (D67) shows as the id with spaces.
String exerciseName(String id) => exerciseCatalog.byId[exerciseCatalog.resolveId(id)]?.name ?? id.replaceAll('_', ' ');

/// The composed name of variation [e] of [group] (D80): the move's name and
/// the name parts of its modifiers, in the word order of the language that
/// [look] reads (key -> text, null when missing). The same rule as
/// tools/exercise_names.mjs, which writes the English names into the list:
/// - `name.order`: the slots in word order (`move` and the axis ids);
/// - `name.move.<base>.<value>`: the move's word for the variations with
///   that value ("Chin-Up" for a reverse-grip Pull-Up); the value's own part
///   is then left out;
/// - else `name.move.<base>`, else `move.<base>`: the move's word;
/// - `name.form.<base>`: the grammatical form of the move's word, in a
///   language with agreement (Romanian): `ms` `fs` `ns` `mp` `fp` `np`
///   (masculine, feminine, neuter; singular, plural);
/// - `name.<base>.<value>`, else `name.<axis>.<value>`, else `name.<value>`,
///   else the value: a part; an empty part is left out (Medium Grip); a part
///   `a|b|c|d` agrees with the move: masculine singular, feminine singular,
///   masculine plural, feminine plural (nameForm);
/// - the equipment part only when the move has more than one equipment.
/// A special name (`exercise.<id>`) is not looked at here (exerciseLabel).
String composeName(CatalogExercise e, ExerciseGroup group, String? Function(String key) look) {
  final b = e.base.toLowerCase();
  final slots = (look('name.order') ?? '').split(' ').where((s) => s.isNotEmpty).toList();
  String? moveSlot, move;
  for (final slot in slots) {
    final v = e.mods[slot];
    final m = v == null ? null : look('name.move.$b.$v');
    if (m != null) {
      (moveSlot, move) = (slot, m);
      break;
    }
  }
  move ??= look('name.move.$b') ?? look('move.$b') ?? e.base;
  final form = nameForm(look('name.form.$b'));
  final equipShown = {for (final v in group.variants) v.mods['equip']}.length > 1;
  final words = <String>[];
  for (final slot in slots) {
    if (slot == 'move') {
      words.add(move);
      continue;
    }
    final v = e.mods[slot];
    if (v == null || slot == moveSlot || (slot == 'equip' && !equipShown)) continue;
    var p = look('name.$b.$v') ?? look('name.$slot.$v') ?? look('name.$v') ?? v;
    if (p.contains('|')) {
      final forms = p.split('|');
      p = forms[form.clamp(0, forms.length - 1)];
    }
    if (p.isNotEmpty) words.add(p);
  }
  return words.join(' ');
}

/// The agreeing form of a name part (`a|b|c|d`) for a move's grammatical
/// [form] (`name.form.<base>`, D80): 0 masculine or neuter singular,
/// 1 feminine singular, 2 masculine plural, 3 feminine or neuter plural
/// (Romanian: "Împins înclinat", "Presă înclinată", "Îngeri înclinați",
/// "Flotări înclinate"). No form (English): 0.
int nameForm(String? form) => switch (form) {
      'fs' => 1,
      'mp' => 2,
      'fp' || 'np' => 3,
      _ => 0,
    };

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

/// The equipment each class trains with (D50): the gear it lights (D89),
/// never a filter. Every class also gets 'body only'. Since
/// D90 step 2 the two balls are one tool (`ball`) and rings are the
/// Scrapper's (`rings`); the same gear as TOOL words: chalk.dart's classGear.
const classEquipment = <String, Set<String>>{
  'scrapper': {'body only', 'rings'},
  'bruiser': {'body only', 'dumbbell', 'kettlebells', 'bands', 'ball'},
  'paladin': {'body only', 'barbell', 'e-z curl bar', 'dumbbell', 'kettlebells'},
  'cablemancer': {'body only', 'machine', 'cable'},
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
