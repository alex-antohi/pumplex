// CHALK, the exercise search (D72, docs/moodboard/chalk/HANDOFF.md). The
// lifter never types: they tap word tiles, and each word narrows the list.
// CHALK searches ALL exercises: it ignores the class and the filters.
//
// The words come in rows: PATTERN, MOVE, TOOL, BODY. ANGLE and GRIP are
// variations, picked on the exercise card's chips (D55, D57), not here. A
// word is `<row>.<id>` (for example `tool.dumbbell`); its label is the translation
// key `chalk.<row>.<id>`. An exercise has a word when it matches it.
// The one rule, for the tiles, the count, the cards and the results list:
// an EXERCISE matches when it has every word of the chalk line (one word
// per row); a card matches when some exercise of it matches, and the
// results list shows each matching exercise (not only the card's first).

import 'exercises.dart';

/// The rows of the CHALK sheet, top to bottom.
const chalkRows = ['pattern', 'move', 'tool', 'body'];

/// One word tile: its row, its id and its English label (the fallback of
/// the translation key `chalk.<row>.<id>`).
class ChalkWord {
  const ChalkWord(this.row, this.id, this.label);

  final String row, id, label;

  /// `<row>.<id>`, as kept in the chalk line.
  String get key => '$row.$id';
}

/// The movement patterns (D69) as words: several patterns can share one.
/// Fly goes with push; rear delt and shrug go with pull. The other isolation
/// patterns (biceps, triceps, forearms, raise, calves, hamcurl, abductor,
/// adductor) get no PATTERN word, so the row stays short: a MOVE word
/// (curl, extension, raise, ...) or the BODY word finds them.
const chalkPatternWords = <String, List<String>>{
  'push': ['hpush', 'vpush', 'fly'],
  'pull': ['hpull', 'vpull', 'rear', 'shrug'],
  'squat': ['squat'],
  'hinge': ['hinge'],
  'single': ['single'],
  'core': ['flex', 'antiext', 'rotation'],
  'jump': ['plyo', 'power'],
  'carry': ['carry'],
  'cardio': ['cardio'],
};

/// The moves, found in the exercise's name (English, from the database).
/// Leg Curl is CURL + LEGS and Calf Raise is RAISE + LEGS (no tile of their
/// own). ROW is the strength row only: the Rowing Machine is CARDIO.
final chalkMoveWords = <String, RegExp>{
  'press': RegExp(r'\bpress', caseSensitive: false),
  'fly': RegExp(r'\bfly|\bflye', caseSensitive: false),
  'pullover': RegExp(r'pullover', caseSensitive: false),
  'curl': RegExp(r'\bcurl', caseSensitive: false),
  'wristcurl': RegExp(r'wrist curl', caseSensitive: false),
  'raise': RegExp(r'\braise', caseSensitive: false),
  'row': RegExp(r'\brow\b|\brows\b', caseSensitive: false),
  'squat': RegExp(r'\bsquat', caseSensitive: false),
  'lunge': RegExp(r'\blunge', caseSensitive: false),
  'deadlift': RegExp(r'deadlift', caseSensitive: false),
  'hipthrust': RegExp(r'hip thrust', caseSensitive: false),
  'bridge': RegExp(r'\bbridge', caseSensitive: false),
  'pullup': RegExp(r'pull-?up|chin-?up', caseSensitive: false),
  'pushup': RegExp(r'push-?up', caseSensitive: false),
  // A support hold is the top of a dip (D90 step 3 part B).
  'dip': RegExp(r'\bdips?\b|support hold', caseSensitive: false),
  // A skullcrusher is a lying triceps extension.
  'extension': RegExp(r'extension|skull ?crusher', caseSensitive: false),
  'pushdown': RegExp(r'push-?down', caseSensitive: false),
  'kickback': RegExp(r'kickback', caseSensitive: false),
  'pulldown': RegExp(r'pulldown|pull-down', caseSensitive: false),
  'crunch': RegExp(r'crunch', caseSensitive: false),
  'plank': RegExp(r'plank', caseSensitive: false),
  'shrug': RegExp(r'shrug', caseSensitive: false),
};

/// The tools: the equipment modifier, else the database equipment. Since
/// D90 step 2 the two balls are one tool (equipment `ball`, modifier Ball)
/// and Rings/TRX is a tool (equipment `rings`, modifier Rings). The old
/// ball values stay here, so nothing older loses its tool.
const chalkToolOfEquipment = {
  'body only': 'bodyweight',
  'dumbbell': 'dumbbell',
  'barbell': 'barbell',
  'cable': 'cable',
  'machine': 'machine',
  'kettlebells': 'kettlebell',
  'bands': 'bands',
  'e-z curl bar': 'ezbar',
  'ball': 'ball',
  'exercise ball': 'ball',
  'medicine ball': 'ball',
  'rings': 'rings',
};
const chalkToolOfMod = {
  'Bodyweight': 'bodyweight',
  'Dumbbell': 'dumbbell',
  'Barbell': 'barbell',
  'Cable': 'cable',
  'Machine': 'machine',
  'Smith Machine': 'smith',
  'Kettlebell': 'kettlebell',
  'Bands': 'bands',
  'EZ Bar': 'ezbar',
  'Ball': 'ball',
  'Exercise Ball': 'ball',
  'Medicine Ball': 'ball',
  'Rings': 'rings',
};

/// A towel is a second tool on top of Bodyweight (Towel Row, Towel Hang).
/// Since D90 step 2 it is a word only, not a gear-rack slot
/// ([chalkRackTools]): CHALK and FORGE still know it.
final chalkTowel = RegExp(r'\btowel', caseSensitive: false);

/// Every word tile, row by row, in the order the sheet shows them.
const chalkWords = <ChalkWord>[
  ChalkWord('pattern', 'push', 'Push'),
  ChalkWord('pattern', 'pull', 'Pull'),
  ChalkWord('pattern', 'squat', 'Squat'),
  ChalkWord('pattern', 'hinge', 'Hinge'),
  ChalkWord('pattern', 'single', 'Single leg'),
  ChalkWord('pattern', 'core', 'Core'),
  ChalkWord('pattern', 'jump', 'Jump'),
  ChalkWord('pattern', 'carry', 'Carry'),
  ChalkWord('pattern', 'cardio', 'Cardio'),
  ChalkWord('move', 'press', 'Press'),
  ChalkWord('move', 'fly', 'Fly'),
  ChalkWord('move', 'pullover', 'Pullover'),
  ChalkWord('move', 'curl', 'Curl'),
  ChalkWord('move', 'wristcurl', 'Wrist curl'),
  ChalkWord('move', 'raise', 'Raise'),
  ChalkWord('move', 'row', 'Row'),
  ChalkWord('move', 'squat', 'Squat'),
  ChalkWord('move', 'lunge', 'Lunge'),
  ChalkWord('move', 'deadlift', 'Deadlift'),
  ChalkWord('move', 'hipthrust', 'Hip thrust'),
  ChalkWord('move', 'bridge', 'Bridge'),
  ChalkWord('move', 'pullup', 'Pull-up'),
  ChalkWord('move', 'pushup', 'Push-up'),
  ChalkWord('move', 'dip', 'Dip'),
  ChalkWord('move', 'extension', 'Extension'),
  ChalkWord('move', 'pushdown', 'Pushdown'),
  ChalkWord('move', 'kickback', 'Kickback'),
  ChalkWord('move', 'pulldown', 'Pulldown'),
  ChalkWord('move', 'crunch', 'Crunch'),
  ChalkWord('move', 'plank', 'Plank'),
  ChalkWord('move', 'shrug', 'Shrug'),
  ChalkWord('tool', 'dumbbell', 'Dumbbell'),
  ChalkWord('tool', 'barbell', 'Barbell'),
  ChalkWord('tool', 'kettlebell', 'Kettlebell'),
  ChalkWord('tool', 'cable', 'Cable'),
  ChalkWord('tool', 'machine', 'Machine'),
  ChalkWord('tool', 'smith', 'Smith machine'),
  ChalkWord('tool', 'ezbar', 'EZ bar'),
  ChalkWord('tool', 'bands', 'Bands'),
  ChalkWord('tool', 'ball', 'Ball'),
  ChalkWord('tool', 'rings', 'Rings / TRX'),
  ChalkWord('tool', 'towel', 'Towel'),
  ChalkWord('tool', 'bodyweight', 'Bodyweight'),
  ChalkWord('body', 'chest', 'Chest'),
  ChalkWord('body', 'back', 'Back'),
  ChalkWord('body', 'shoulders', 'Shoulders'),
  ChalkWord('body', 'arms', 'Arms'),
  ChalkWord('body', 'legs', 'Legs'),
  ChalkWord('body', 'core', 'Core'),
];

ChalkWord? chalkWordByKey(String key) => chalkWords.where((w) => w.key == key).firstOrNull;

/// The gear rack (D87, D90 step 2): one slot per tool, 11 slots. The towel
/// is a TOOL word but not a slot.
final chalkRackTools = [for (final w in chalkWords) if (w.row == 'tool' && w.id != 'towel') w];

/// The gear each class lights (D50, the lit rule of D89; D90 step 2), as
/// TOOL word ids, the class's tools first. Bodyweight is lit for every class.
/// Trap Bar and Landmine lifts are barbell lifts, so they are Plate Paladin
/// gear. Data only: the order of the rack and the results (D89) is not built.
const classGear = <String, List<String>>{
  'scrapper': ['bodyweight', 'rings'],
  'bruiser': ['dumbbell', 'kettlebell', 'bands', 'ball', 'bodyweight'],
  'paladin': ['barbell', 'ezbar', 'dumbbell', 'kettlebell', 'bodyweight'],
  'cablemancer': ['machine', 'cable', 'smith', 'bodyweight'],
};

/// The words of exercise [e].
Set<String> _wordsOf(CatalogExercise e) {
  final w = <String>{};
  for (final MapEntry(:key, :value) in chalkPatternWords.entries) {
    if (value.contains(e.pattern)) w.add('pattern.$key');
  }
  for (final MapEntry(:key, :value) in chalkMoveWords.entries) {
    if (value.hasMatch(e.name)) w.add('move.$key');
  }
  // No equipment in the database (null, or empty) is Bodyweight.
  final equipment = e.equipment.isEmpty ? 'body only' : e.equipment;
  final tool = e.mods['equip'] != null ? chalkToolOfMod[e.mods['equip']] : chalkToolOfEquipment[equipment];
  if (tool != null) w.add('tool.$tool');
  if (e.mods['setup'] == 'Towel' || chalkTowel.hasMatch(e.name)) w.add('tool.towel');
  for (final b in bodyParts) {
    if (b.muscles.contains(e.muscle)) w.add('body.${b.id}');
  }
  return w;
}

/// The words of every exercise of [catalog], worked out once.
class ChalkIndex {
  ChalkIndex(this.catalog)
      : words = {
          for (final g in catalog.groups)
            for (final e in g.variants) e.id: _wordsOf(e),
        };

  final ExerciseCatalog catalog;
  final Map<String, Set<String>> words;

  static ChalkIndex? _last;

  /// The index of [catalog] (made again only when the list changes).
  static ChalkIndex of(ExerciseCatalog catalog) =>
      identical(_last?.catalog, catalog) ? _last! : (_last = ChalkIndex(catalog));

  bool _has(CatalogExercise e, Iterable<String> line) => (words[e.id] ?? const {}).containsAll(line);

  /// The cards with an exercise that has every word of [line], each with only
  /// those exercises, the most common first (D67), then by name.
  List<ExerciseGroup> search(Iterable<String> line) {
    final out = <ExerciseGroup>[];
    for (final g in catalog.groups) {
      final keep = [for (final e in g.variants) if (_has(e, line)) e];
      if (keep.isNotEmpty) out.add(g.only(keep));
    }
    out.sort((a, b) => a.rank != b.rank ? a.rank - b.rank : a.name.compareTo(b.name));
    return out;
  }

  /// The CHALK results list: one row per exercise that has every word of
  /// [line], card by card in [search] order. A card can give several rows
  /// (PUSH + FLY: Cable Fly, Dumbbell Fly, ...): the list never hides a
  /// match behind the card's first exercise. Each row keeps its card, with
  /// the matching exercises only, as the carousel shows it.
  List<ChalkResult> results(Iterable<String> line) => [
        for (final g in search(line))
          for (final e in g.variants) ChalkResult(g, e),
      ];

  /// What a results row shows under the name: the body part of [e] (by its
  /// muscle) and its TOOL word, when it has them.
  ({BodyPart? part, ChalkWord? tool}) tagsOf(CatalogExercise e) => (
        part: bodyParts.where((b) => b.muscles.contains(e.muscle)).firstOrNull,
        tool: (words[e.id] ?? const <String>{}).where((k) => k.startsWith('tool.')).map(chalkWordByKey).firstOrNull,
      );

  /// How many exercises have every word of [line] (the rows of [results]).
  int count(Iterable<String> line) => catalog.groups.fold(0, (n, g) => n + g.variants.where((e) => _has(e, line)).length);
}

/// One CHALK result row: an [exercise] with every picked word, and its
/// [card] (the card's matching exercises, as the carousel shows it).
class ChalkResult {
  const ChalkResult(this.card, this.exercise);

  final ExerciseGroup card;
  final CatalogExercise exercise;
}

/// The chalk line with [word] put in: it takes the place of the word of its
/// row, or comes out when it is there already.
Set<String> chalkToggle(Set<String> line, ChalkWord word) {
  if (line.contains(word.key)) return {...line}..remove(word.key);
  return {for (final k in line) if (!k.startsWith('${word.row}.')) k, word.key};
}
