// FORGE (D72, docs/moodboard/chalk/02-forge.html): when no exercise has all
// the CHALK words, the lifter forges their own from the same words. A
// forged move is a custom exercise: its name comes from the words (for
// example KETTLEBELL CURL), with an optional nickname. It has no angle and
// no grip: those are variations, set later on the exercise card (D81). It
// joins the exercise list like any card (sets and XP work the same), for
// every class with its gear, and CHALK finds it.
//
// When CHALK has no MOVE word for it, the lifter types the move (D83): the
// typed word is the move part of the name, kept as typed (user text, not
// translated).
//
// Kept on the phone as `custom_exercises_v1` (a list of [ForgedMove] JSON).
// A long-press on its Today card title edits it or melts (deletes) it
// (D78). Not in the backup file yet (still open).

import 'chalk.dart';
import 'content.dart';
import 'exercises.dart';

/// The tool word -> the database equipment and the equipment modifier.
const _toolFields = <String, (String, String?)>{
  'dumbbell': ('dumbbell', 'Dumbbell'),
  'barbell': ('barbell', 'Barbell'),
  'kettlebell': ('kettlebells', 'Kettlebell'),
  'cable': ('cable', 'Cable'),
  'machine': ('machine', 'Machine'),
  'smith': ('machine', 'Smith Machine'),
  'ezbar': ('e-z curl bar', 'EZ Bar'),
  'bands': ('bands', 'Bands'),
  // One Ball since D90 step 2 (an older forged ball move loads as this).
  'ball': ('ball', 'Ball'),
  'rings': ('rings', 'Rings'),
  // A towel is a second tool on Bodyweight (chalk.dart's chalkTowel).
  'towel': ('body only', 'Bodyweight'),
  'bodyweight': ('body only', 'Bodyweight'),
};

/// The tool word -> its name part value (`name.equip.<v>`, else
/// `name.<v>`; D80), as the exercise names use it.
const _toolPart = <String, String>{
  'dumbbell': 'Dumbbell',
  'barbell': 'Barbell',
  'kettlebell': 'Kettlebell',
  'cable': 'Cable',
  'machine': 'Machine',
  'smith': 'Smith Machine',
  'ezbar': 'EZ Bar',
  'bands': 'Bands',
  'ball': 'Ball',
  'rings': 'Rings',
  'towel': 'Towel',
  'bodyweight': 'Bodyweight',
};

/// The move word -> the body part and muscle it trains (the FORGE card's
/// first guess; the lifter can change them) and its movement pattern.
/// Every MOVE word of CHALK has a row (test: chalk_test.dart).
const _moveFields = <String, (String, String, String)>{
  'press': ('chest', 'chest', 'hpush'),
  'fly': ('chest', 'chest', 'fly'),
  'pullover': ('back', 'lats', 'vpull'),
  'curl': ('arms', 'biceps', 'biceps'),
  'wristcurl': ('arms', 'forearms', 'forearms'),
  'raise': ('shoulders', 'shoulders', 'raise'),
  'row': ('back', 'middle back', 'hpull'),
  'squat': ('legs', 'quadriceps', 'squat'),
  'lunge': ('legs', 'quadriceps', 'single'),
  'deadlift': ('legs', 'hamstrings', 'hinge'),
  'hipthrust': ('legs', 'glutes', 'hinge'),
  'bridge': ('legs', 'glutes', 'hinge'),
  'pullup': ('back', 'lats', 'vpull'),
  'pushup': ('chest', 'chest', 'hpush'),
  'dip': ('arms', 'triceps', 'triceps'),
  'extension': ('arms', 'triceps', 'triceps'),
  'pushdown': ('arms', 'triceps', 'triceps'),
  'kickback': ('arms', 'triceps', 'triceps'),
  'pulldown': ('back', 'lats', 'vpull'),
  'crunch': ('core', 'abdominals', 'flex'),
  'plank': ('core', 'abdominals', 'antiext'),
  'shrug': ('back', 'traps', 'shrug'),
};

/// The pattern word -> the body part and muscle it trains, when there is
/// no MOVE word (the guess). There is no "full body" part: carry is the
/// grip (forearms), cardio and jump are the legs.
const _patternBody = <String, (String, String)>{
  'push': ('chest', 'chest'),
  'pull': ('back', 'lats'),
  'squat': ('legs', 'quadriceps'),
  'hinge': ('legs', 'hamstrings'),
  'single': ('legs', 'quadriceps'),
  'core': ('core', 'abdominals'),
  'jump': ('legs', 'quadriceps'),
  'carry': ('arms', 'forearms'),
  'cardio': ('legs', 'quadriceps'),
};

/// The pattern word -> a movement pattern (D69), when there is no move word.
const _patternFields = <String, String>{
  'push': 'hpush',
  'pull': 'hpull',
  'squat': 'squat',
  'hinge': 'hinge',
  'single': 'single',
  'core': 'flex',
  'jump': 'plyo',
  'carry': 'carry',
  'cardio': 'cardio',
};

/// The word of [row] in the chalk [line], if any.
String? chalkIdOf(Iterable<String> line, String row) =>
    line.where((k) => k.startsWith('$row.')).map((k) => k.substring(row.length + 1)).firstOrNull;

/// The name the words give (D80 rules): the move (the typed word, else the
/// MOVE word, else the PATTERN word) and the tool's name part, in the word
/// order of `name.order` ("Kettlebell Curl", "Flexii cu kettlebell").
/// [look] reads the current language (key -> text, null when missing);
/// without it the name is English, from the words' labels. A [typed] move
/// word (D83) is kept as typed. Bodyweight adds no part.
String forgeName(Iterable<String> line, {String? typed, String? Function(String key)? look}) {
  String? get(String key) => look?.call(key);
  String label(String key) => get('chalk.$key') ?? chalkWordByKey(key)!.label;
  final tool = chalkIdOf(line, 'tool');
  final move = chalkIdOf(line, 'move');
  final pattern = chalkIdOf(line, 'pattern');
  final own = cleanTyped(typed);
  final moveWord = own ??
      (move != null
          ? label('move.$move')
          : pattern != null
              ? label('pattern.$pattern')
              : null);
  String? toolWord;
  if (tool != null && tool != 'bodyweight') {
    if (look == null) {
      toolWord = chalkWordByKey('tool.$tool')!.label;
    } else {
      final v = _toolPart[tool]!;
      var w = get('name.equip.$v') ?? get('name.$v') ?? v;
      if (w.contains('|')) {
        // An agreeing part (D80) agrees with the move word (a typed word: 0).
        final forms = w.split('|');
        final form = own == null ? nameForm(get('name.form.${move ?? pattern}')) : 0;
        w = forms[form.clamp(0, forms.length - 1)];
      }
      toolWord = w;
    }
  }
  final order = (get('name.order') ?? '').split(' ');
  final moveFirst = order.contains('move') && order.contains('equip') && order.indexOf('move') < order.indexOf('equip');
  final parts = [
    for (final w in moveFirst ? [moveWord, toolWord] : [toolWord, moveWord])
      if (w != null && w.isNotEmpty) w,
  ];
  if (parts.isEmpty) return get('forge.myMove') ?? 'My move';
  final name = parts.join(' ');
  if (own != null && parts.first == own) return name; // kept as typed
  return name[0].toUpperCase() + name.substring(1);
}

/// FORGE IT needs a move (D83): a MOVE word or a typed move. A PATTERN or a
/// TOOL alone is not a move.
bool forgeReady(Iterable<String> line, {String? typed}) =>
    cleanTyped(typed) != null || chalkIdOf(line, 'move') != null;

/// [typed] cleaned for keeping: one space between words, no end spaces;
/// null when nothing is left.
String? cleanTyped(String? typed) {
  final s = typed?.trim().replaceAll(RegExp(r'\s+'), ' ');
  return s == null || s.isEmpty ? null : s;
}

/// The body part and muscle the words point to: the BODY word, else the
/// MOVE word's, else the PATTERN word's. Null when no word tells.
(String, String)? forgeBody(Iterable<String> line) {
  final m = _moveFields[chalkIdOf(line, 'move')];
  final guess = m != null ? (m.$1, m.$2) : _patternBody[chalkIdOf(line, 'pattern')];
  final body = chalkIdOf(line, 'body');
  if (body != null) {
    final part = bodyPartById(body)!;
    return (body, guess != null && part.muscles.contains(guess.$2) ? guess.$2 : part.muscles.first);
  }
  return guess;
}

/// The database equipment the TOOL word of [line] gives (no tool: body only).
String forgeEquipment(Iterable<String> line) => (_toolFields[chalkIdOf(line, 'tool')] ?? ('body only', null)).$1;

/// The classes with the gear for a move forged from [line] (the FORGE
/// card's "shows for" line).
List<GameClass> forgeClasses(Iterable<String> line) {
  final equipment = forgeEquipment(line);
  return [for (final c in gameClasses) if (classEquipment[c.id]!.contains(equipment)) c];
}

/// A forged move, as kept on the phone.
class ForgedMove {
  const ForgedMove({required this.id, required this.words, required this.muscle, this.nickname, this.typed});

  /// `custom_<n>`; saved sets use it like any exercise id.
  final String id;

  /// The chalk words it was forged from (`<row>.<id>`). Only words the
  /// CHALK rows have: an older move's ANGLE or GRIP word is dropped (D81).
  final Set<String> words;

  /// The muscle it trains (its body part follows from it).
  final String muscle;

  /// The big name when set (D72); the words' name sits small under it.
  final String? nickname;

  /// The move word the lifter typed (D83), when CHALK had none: then
  /// [words] has no MOVE word. Shown as typed, never translated.
  final String? typed;

  /// The name in English (the exercise list's language).
  String get name => forgeName(words, typed: typed);

  /// The name in the language [look] reads (i18n.dart's forgedLabel).
  String nameIn(String? Function(String key) look) => forgeName(words, typed: typed, look: look);

  /// A forged move is kept as its words, never as a name, so its name
  /// follows the language. An older entry with an English `name` and no
  /// words gets its words back from that name, where the name has them.
  factory ForgedMove.fromJson(Map<String, dynamic> j) {
    var words = {for (final w in j['words'] as List? ?? const []) if (w is String && chalkWordByKey(w) != null) w};
    final old = j['name'];
    if (words.isEmpty && old is String) words = wordsFromName(old);
    return ForgedMove(
      id: j['id'] as String,
      words: words,
      muscle: j['muscle'] as String? ?? 'chest',
      nickname: j['nickname'] as String?,
      typed: cleanTyped(j['typed'] as String?),
    );
  }

  /// The chalk words (one per row) whose English labels are in [name]
  /// ("Kettlebell Curl" -> tool.kettlebell, move.curl), the longest label
  /// first ("Wrist curl" before "Curl").
  static Set<String> wordsFromName(String name) {
    final out = <String>{};
    final words = [for (final w in chalkWords) if (w.row != 'body') w]
      ..sort((a, b) => b.label.length - a.label.length);
    for (final w in words) {
      if (out.any((k) => k.startsWith('${w.row}.'))) continue;
      if (RegExp('\\b${RegExp.escape(w.label)}\\b', caseSensitive: false).hasMatch(name)) out.add(w.key);
    }
    return out;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'words': words.toList(),
        'muscle': muscle,
        if (nickname != null) 'nickname': nickname,
        if (typed != null) 'typed': typed,
      };

  /// The exercise for the list: every class with its gear sees it from
  /// the first mode, last in the Suggested order.
  CatalogExercise toExercise() {
    final tool = _toolFields[chalkIdOf(words, 'tool')] ?? ('body only', null);
    final pattern = (typed == null ? _moveFields[chalkIdOf(words, 'move')]?.$3 : null) ??
        _patternFields[chalkIdOf(words, 'pattern')];
    return CatalogExercise(
      id: id,
      name: name,
      nick: nickname,
      category: 'strength',
      equipment: tool.$1,
      level: 0,
      force: null,
      mechanic: null,
      muscle: muscle,
      // No angle and no grip (D81): only the tool (a towel: its setup too, D90).
      mods: {
        if (tool.$2 != null) 'equip': tool.$2!,
        if (chalkIdOf(words, 'tool') == 'towel') 'setup': 'Towel',
      },
      pattern: pattern,
      unlock: const {'scrapper': 0, 'bruiser': 0, 'paladin': 0, 'cablemancer': 0},
    );
  }
}

/// The forged moves of the exercise list by id (set by [catalogWithForged]),
/// so a name can be composed in the current language (i18n.dart).
Map<String, ForgedMove> forgedMoves = const {};

/// [base] with the forged moves added (any older forged ones taken out first).
ExerciseCatalog catalogWithForged(ExerciseCatalog base, List<ForgedMove> forged) {
  forgedMoves = {for (final f in forged) f.id: f};
  return ExerciseCatalog([
    for (final e in base.all)
      if (!e.id.startsWith('custom_')) e,
    for (final f in forged) f.toExercise(),
  ]);
}
