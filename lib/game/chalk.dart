// CHALK, the exercise search (D72, docs/moodboard/chalk/HANDOFF.md). The
// lifter never types: they tap word tiles, and each word narrows the list.
// CHALK searches ALL exercises: it ignores the class and the filters.
//
// The words come in rows: PATTERN, MOVE, TOOL, BODY, ANGLE, GRIP. A word is
// `<row>.<id>` (for example `tool.dumbbell`); its label is the translation
// key `chalk.<row>.<id>`. An exercise has a word when it matches it; the
// search keeps the exercises with every word of the chalk line (one word
// per row).

import 'exercises.dart';

/// The rows of the CHALK sheet, top to bottom.
const chalkRows = ['pattern', 'move', 'tool', 'body', 'angle', 'grip'];

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
const _patternWords = <String, List<String>>{
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
final _moveWords = <String, RegExp>{
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
  'dip': RegExp(r'\bdips?\b', caseSensitive: false),
  // A skullcrusher is a lying triceps extension.
  'extension': RegExp(r'extension|skull ?crusher', caseSensitive: false),
  'pushdown': RegExp(r'push-?down', caseSensitive: false),
  'kickback': RegExp(r'kickback', caseSensitive: false),
  'pulldown': RegExp(r'pulldown|pull-down', caseSensitive: false),
  'crunch': RegExp(r'crunch', caseSensitive: false),
  'plank': RegExp(r'plank', caseSensitive: false),
  'shrug': RegExp(r'shrug', caseSensitive: false),
};

/// The tools: the equipment modifier, else the database equipment.
const _toolOfEquipment = {
  'body only': 'bodyweight',
  'dumbbell': 'dumbbell',
  'barbell': 'barbell',
  'cable': 'cable',
  'machine': 'machine',
  'kettlebells': 'kettlebell',
  'bands': 'bands',
  'e-z curl bar': 'ezbar',
  'exercise ball': 'ball',
  'medicine ball': 'ball',
};
const _toolOfMod = {
  'Bodyweight': 'bodyweight',
  'Dumbbell': 'dumbbell',
  'Barbell': 'barbell',
  'Cable': 'cable',
  'Machine': 'machine',
  'Smith Machine': 'smith',
  'Kettlebell': 'kettlebell',
  'Bands': 'bands',
  'EZ Bar': 'ezbar',
  'Exercise Ball': 'ball',
  'Medicine Ball': 'ball',
};

/// A towel is a second tool on top of Bodyweight (Towel Row, Towel Hang).
final _towel = RegExp(r'\btowel', caseSensitive: false);

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
  ChalkWord('tool', 'towel', 'Towel'),
  ChalkWord('tool', 'bodyweight', 'Bodyweight'),
  ChalkWord('body', 'chest', 'Chest'),
  ChalkWord('body', 'back', 'Back'),
  ChalkWord('body', 'shoulders', 'Shoulders'),
  ChalkWord('body', 'arms', 'Arms'),
  ChalkWord('body', 'legs', 'Legs'),
  ChalkWord('body', 'core', 'Core'),
  ChalkWord('angle', 'incline', 'Incline'),
  ChalkWord('angle', 'flat', 'Flat'),
  ChalkWord('angle', 'decline', 'Decline'),
  ChalkWord('grip', 'close', 'Close grip'),
  ChalkWord('grip', 'medium', 'Medium grip'),
  ChalkWord('grip', 'wide', 'Wide grip'),
  ChalkWord('grip', 'neutral', 'Neutral grip'),
  ChalkWord('grip', 'overhand', 'Overhand grip'),
  ChalkWord('grip', 'reverse', 'Reverse grip'),
];

ChalkWord? chalkWordByKey(String key) => chalkWords.where((w) => w.key == key).firstOrNull;

const _gripOfMod = {
  'Close Grip': 'close',
  'Medium Grip': 'medium',
  'Wide Grip': 'wide',
  'Neutral Grip': 'neutral',
  'Overhand Grip': 'overhand',
  'Reverse Grip': 'reverse',
};

/// The words of exercise [e] on card [g].
Set<String> _wordsOf(CatalogExercise e, ExerciseGroup g) {
  final w = <String>{};
  for (final MapEntry(:key, :value) in _patternWords.entries) {
    if (value.contains(e.pattern)) w.add('pattern.$key');
  }
  for (final MapEntry(:key, :value) in _moveWords.entries) {
    if (value.hasMatch(e.name)) w.add('move.$key');
  }
  // No equipment in the database (null, or empty) is Bodyweight.
  final equipment = e.equipment.isEmpty ? 'body only' : e.equipment;
  final tool = e.mods['equip'] != null ? _toolOfMod[e.mods['equip']] : _toolOfEquipment[equipment];
  if (tool != null) w.add('tool.$tool');
  if (e.mods['type'] == 'Towel' || _towel.hasMatch(e.name)) w.add('tool.towel');
  for (final b in bodyParts) {
    if (b.muscles.contains(e.muscle)) w.add('body.${b.id}');
  }
  final angle = e.mods['angle'];
  if (angle != null) {
    w.add('angle.${angle.toLowerCase()}');
  } else if (g.variants.any((v) => v.mods['angle'] != null)) {
    w.add('angle.flat'); // a move with angles: no angle is flat (D57)
  }
  for (final m in [e.mods['width'], e.mods['hand']]) {
    if (_gripOfMod[m] case final grip?) w.add('grip.$grip');
  }
  return w;
}

/// The words of every exercise of [catalog], worked out once.
class ChalkIndex {
  ChalkIndex(this.catalog)
      : words = {
          for (final g in catalog.groups)
            for (final e in g.variants) e.id: _wordsOf(e, g),
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

  /// How many exercises have every word of [line].
  int count(Iterable<String> line) => catalog.groups.fold(0, (n, g) => n + g.variants.where((e) => _has(e, line)).length);
}

/// The chalk line with [word] put in: it takes the place of the word of its
/// row, or comes out when it is there already.
Set<String> chalkToggle(Set<String> line, ChalkWord word) {
  if (line.contains(word.key)) return {...line}..remove(word.key);
  return {for (final k in line) if (!k.startsWith('${word.row}.')) k, word.key};
}
