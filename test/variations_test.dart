// Composed variations (D80): a move's grid of axes makes the variations,
// their names are composed from translated parts, old ids keep working.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:gym_app/game/exercises.dart';
import 'package:gym_app/i18n.dart';

/// The words of a name that carry meaning (filler words out, the first five
/// letters, so "înclinat" and "înclinate" are one word).
const _fill = {
  'with', 'the', 'a', 'on', 'of', 'medium', 'grip', 'standing', 'two', 'la', 'cu', 'pe', 'de', 'priză', 'medie', 'și', 'din', //
  'în', 'version', 'attachment', 'flat', 'bench',
};
const _syn = {'single': 'one', 'alternate': 'alter', '1': 'un', 'curls': 'curl', 'dumbbells': 'dumbb', 'db': 'dumbb', 'dips': 'dip'};
Set<String> _stems(String s) => {
      for (final w in s.toLowerCase().replaceAll(RegExp(r'[-,()]'), ' ').split(RegExp(r'\s+')))
        if (w.isNotEmpty && !_fill.contains(w)) _syn[w] ?? (w.length > 5 ? w.substring(0, 5) : w),
    };

/// The id of a grid variation: the move and its modifier values, lower case
/// (tools/exercise_names.mjs variationId).
String _variationId(CatalogExercise e) =>
    [e.base, for (final a in modifierAxes) if (e.mods[a.id] != null) e.mods[a.id]!].join('|').toLowerCase();

void main() {
  final langFiles = {for (final l in I18n.languages) l: File(I18n.asset(l)).readAsStringSync()};
  final legacy = (jsonDecode(File('test/legacy_exercise_names.json').readAsStringSync()) as Map<String, dynamic>)
      .map((k, v) => MapEntry(k, (v as List).cast<String>()));
  setUpAll(() => exerciseCatalog = ExerciseCatalog.parse(File(ExerciseCatalog.asset).readAsStringSync()));

  String label(String id, String lang) {
    I18n.instance.useJson(langFiles, lang: lang);
    return exerciseLabel(id, exerciseName(id));
  }

  test('old ids keep their exercise, their move and a name close to the old one', () {
    expect(legacy.length, greaterThan(250));
    for (final MapEntry(key: id, value: old) in legacy.entries) {
      final e = exerciseCatalog.byId[id];
      expect(e, isNotNull, reason: id); // saved sets and favorites still find it
      expect(exerciseCatalog.groupKeyOf(id), 'move:${e!.base.toLowerCase()}', reason: id);
      for (final (lang, before) in [('en', old[0]), ('ro', old[1])]) {
        final now = label(id, lang);
        expect(_stems(now).containsAll(_stems(before)), isTrue, reason: '$id $lang: $before -> $now');
        expect(now.length <= 32 || now.length <= before.length, isTrue, reason: '$id $lang: $now');
      }
    }
    // Old names that no rule makes stay special names.
    expect(label('Chin-Up', 'en'), 'Chin-Up');
    expect(label('Running_Treadmill', 'ro'), 'Alergare pe bandă');
    // Ids dropped from the list (D67, the variation audit) keep their names.
    expect(label('Bodyweight_Flyes', 'en'), 'Bodyweight Fly');
  });

  test('composed names: English is the list name; the parts follow the language', () {
    final en = I18n.parse(langFiles['en']!);
    for (final e in exerciseCatalog.all) {
      if (en.containsKey('exercise.${e.id}')) continue;
      expect(composeName(e, exerciseCatalog.groupOf(e.id)!, (k) => en[k]), e.name, reason: e.id);
    }
    expect(label('Knee_Push-Up', 'en'), 'Knee Push-Up');
    expect(label('push-up|bodyweight|knee|close grip', 'en'), 'Close-Grip Knee Push-Up');
    expect(label('push-up|bodyweight|knee|close grip', 'ro'), 'Flotări din genunchi priză îngustă');
    expect(label('push-up|bodyweight|decline|wide grip', 'ro'), 'Flotări declinate priză largă'); // plural form
    expect(label('Incline_Dumbbell_Press', 'ro'), 'Împins înclinat cu gantere'); // short move word, neuter form
    expect(label('Barbell_Squat', 'en'), 'Barbell Squat'); // more than one equipment: it shows
    expect(label('Pushups', 'en'), 'Push-Up'); // one equipment, Medium Grip: no parts
    // Names are unique on each card, in every language.
    for (final lang in I18n.languages) {
      for (final g in exerciseCatalog.groups) {
        final names = [for (final v in g.variants) label(v.id, lang).toLowerCase()];
        expect(names.toSet().length, names.length, reason: '$lang ${g.key} $names');
      }
    }
  });

  test('grid variations: a stable id, no name to translate, sensible levels', () {
    final grid = [for (final e in exerciseCatalog.all) if (e.id.contains('|')) e];
    expect(grid.length, greaterThanOrEqualTo(40));
    for (final e in grid) {
      expect(e.id, _variationId(e), reason: e.id);
      expect(langFiles.values.any((f) => f.contains('"exercise.${e.id}"')), isFalse, reason: e.id);
    }
    int level(String id) => exerciseCatalog.byId[id]!.level;
    expect(level('push-up|bodyweight|knee|close grip'), 0); // Knee lowers, Close Grip raises
    expect(level('push-up|bodyweight|decline|close grip'), 1);
    expect(level('pull-up|bodyweight|band assisted|medium grip|reverse grip'), 0);
    expect(level('pull-up|bodyweight|weighted|medium grip|reverse grip'), 2);
    // The completed grids of the owner's example.
    final push = exerciseCatalog.byKey['move:push-up']!;
    for (final mods in [
      {'type': 'Knee', 'width': 'Close Grip'},
      {'type': 'Knee', 'width': 'Wide Grip'},
      {'angle': 'Decline', 'width': 'Close Grip'},
      {'angle': 'Decline', 'width': 'Wide Grip'},
    ]) {
      expect(push.variants.where((v) => mods.entries.every((m) => v.mods[m.key] == m.value)), isNotEmpty, reason: '$mods');
    }
  });

  test('no nonsense combinations', () {
    bool any(String move, bool Function(Map<String, String> m) bad) =>
        exerciseCatalog.byKey['move:$move']!.variants.any((v) => bad(v.mods));
    expect(any('push-up', (m) => m['type'] == 'Knee' && m['angle'] != null), isFalse); // no knee incline or decline
    expect(any('pull-up', (m) => m['width'] == 'Wide Grip' && m['hand'] != null), isFalse); // no wide chin-up
    expect(any('pull-up', (m) => m['type'] != null && m['width'] != 'Medium Grip'), isFalse);
    expect(any('bench press', (m) => m['type'] == 'Squeeze' && (m['hand'] != null || m['angle'] == 'Decline')), isFalse);
    // Dumbbells and kettlebells have no grip width (D57).
    expect(exerciseCatalog.all.where((e) => {'Dumbbell', 'Kettlebell'}.contains(e.mods['equip']) && e.mods['width'] != null),
        isEmpty);
    // One variation per set of modifiers.
    for (final g in exerciseCatalog.groups) {
      final keys = [for (final v in g.variants) jsonEncode(v.mods)];
      expect(keys.toSet().length, keys.length, reason: g.key);
    }
  });

  test('every variation is reachable with the chips from the first one (D57)', () {
    for (final g in exerciseCatalog.groups) {
      final seen = {g.variants.first.id};
      final todo = [g.variants.first];
      while (todo.isNotEmpty) {
        final v = todo.removeLast();
        for (final (axis, values) in g.axesFor(v)) {
          for (final value in values) {
            final t = chipTarget(g, v, axis.id, value);
            if (t != null && seen.add(t.v.id)) todo.add(t.v);
          }
        }
      }
      expect(seen.length, g.variants.length, reason: '${g.key}: ${g.variants.map((v) => v.id).where((id) => !seen.contains(id))}');
    }
  });
}
