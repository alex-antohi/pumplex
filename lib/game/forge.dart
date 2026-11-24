// FORGE (D72, docs/moodboard/chalk/02-forge.html): when no exercise has all
// the CHALK words, the lifter forges their own from the same words. A
// forged move is a custom exercise: its name comes from the words (for
// example KETTLEBELL CURL), with an optional nickname. It has no angle and
// no grip: those are variations, set later on the exercise card (D81). It
// joins the exercise list like any card (sets and XP work the same), for
// every class with its gear, and CHALK finds it.
//
// Kept on the phone as `custom_exercises_v1` (a list of [ForgedMove] JSON).
// Not in the backup file yet, and there is no edit or delete yet: both are
// still open (HANDOFF.md "Still open").

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
  'ball': ('exercise ball', null),
  'bodyweight': ('body only', 'Bodyweight'),
};

/// The move word -> the body part and muscle it trains (the FORGE card's
/// first guess; the lifter can change them) and its movement pattern.
const _moveFields = <String, (String, String, String)>{
  'press': ('chest', 'chest', 'hpush'),
  'fly': ('chest', 'chest', 'fly'),
  'curl': ('arms', 'biceps', 'biceps'),
  'raise': ('shoulders', 'shoulders', 'raise'),
  'row': ('back', 'middle back', 'hpull'),
  'squat': ('legs', 'quadriceps', 'squat'),
  'lunge': ('legs', 'quadriceps', 'single'),
  'deadlift': ('legs', 'hamstrings', 'hinge'),
  'pullup': ('back', 'lats', 'vpull'),
  'pushup': ('chest', 'chest', 'hpush'),
  'dip': ('arms', 'triceps', 'triceps'),
  'extension': ('arms', 'triceps', 'triceps'),
  'pulldown': ('back', 'lats', 'vpull'),
  'crunch': ('core', 'abdominals', 'flex'),
  'plank': ('core', 'abdominals', 'antiext'),
  'shrug': ('back', 'traps', 'shrug'),
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
};

/// The word of [row] in the chalk [line], if any.
String? chalkIdOf(Iterable<String> line, String row) =>
    line.where((k) => k.startsWith('$row.')).map((k) => k.substring(row.length + 1)).firstOrNull;

/// The name the words give, in English (the exercise list's language):
/// the tool, then the move (or the pattern), for example "Kettlebell
/// Curl". Bodyweight is left out.
String forgeName(Iterable<String> line) {
  final parts = <String>[];
  for (final row in ['tool', 'move']) {
    final id = chalkIdOf(line, row);
    if (id == null || id == 'bodyweight') continue;
    parts.add(chalkWordByKey('$row.$id')!.label);
  }
  if (chalkIdOf(line, 'move') == null) {
    final pat = chalkIdOf(line, 'pattern');
    if (pat != null) parts.add(chalkWordByKey('pattern.$pat')!.label);
  }
  if (parts.isEmpty) return 'My Move';
  return parts.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
}

/// The body part and muscle the words point to: the BODY word, else the
/// move's. Null when no word tells.
(String, String)? forgeBody(Iterable<String> line) {
  final move = _moveFields[chalkIdOf(line, 'move')];
  final body = chalkIdOf(line, 'body');
  if (body != null) {
    final part = bodyPartById(body)!;
    return (body, move != null && part.muscles.contains(move.$2) ? move.$2 : part.muscles.first);
  }
  return move == null ? null : (move.$1, move.$2);
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
  const ForgedMove({required this.id, required this.words, required this.muscle, this.nickname});

  /// `custom_<n>`; saved sets use it like any exercise id.
  final String id;

  /// The chalk words it was forged from (`<row>.<id>`). Only words the
  /// CHALK rows have: an older move's ANGLE or GRIP word is dropped (D81).
  final Set<String> words;

  /// The muscle it trains (its body part follows from it).
  final String muscle;

  /// The big name when set (D72); the words' name sits small under it.
  final String? nickname;

  String get name => forgeName(words);

  factory ForgedMove.fromJson(Map<String, dynamic> j) => ForgedMove(
        id: j['id'] as String,
        words: {for (final w in j['words'] as List? ?? const []) if (w is String && chalkWordByKey(w) != null) w},
        muscle: j['muscle'] as String? ?? 'chest',
        nickname: j['nickname'] as String?,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'words': words.toList(),
        'muscle': muscle,
        if (nickname != null) 'nickname': nickname,
      };

  /// The exercise for the list: every class with its gear sees it from
  /// the first mode, last in the Suggested order.
  CatalogExercise toExercise() {
    final tool = _toolFields[chalkIdOf(words, 'tool')] ?? ('body only', null);
    final pattern = _moveFields[chalkIdOf(words, 'move')]?.$3 ?? _patternFields[chalkIdOf(words, 'pattern')];
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
      // No angle and no grip (D81): only the tool.
      mods: {if (tool.$2 != null) 'equip': tool.$2!},
      pattern: pattern,
      unlock: const {'scrapper': 0, 'bruiser': 0, 'paladin': 0, 'cablemancer': 0},
    );
  }
}

/// [base] with the forged moves added (any older forged ones taken out first).
ExerciseCatalog catalogWithForged(ExerciseCatalog base, List<ForgedMove> forged) => ExerciseCatalog([
      for (final e in base.all)
        if (!e.id.startsWith('custom_')) e,
      for (final f in forged) f.toExercise(),
    ]);
