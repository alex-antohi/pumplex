// CHALK, the exercise search (D72): word tiles narrow the list over ALL
// exercises (no class, no filters); WIPE clears it; 0 matches offers FORGE.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gym_app/i18n.dart';
import 'package:gym_app/game/chalk.dart';
import 'package:gym_app/game/exercises.dart';
import 'package:gym_app/game/forge.dart';
import 'package:gym_app/game/model.dart';
import 'package:gym_app/main.dart';
import 'package:gym_app/store.dart';

const _profile = Profile(
  character: Character(sex: 'female', height: 80, muscle: 100, fat: 0),
  classId: 'scrapper', // no gear: CHALK still finds barbell moves
  difficultyId: 'sweat',
  areaId: 'gainsgard',
);

Future<void> _frames(WidgetTester t, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<LogStore> _openApp(WidgetTester t) async {
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 2.75;
  t.view.padding = const FakeViewPadding(top: 110, bottom: 146);
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({'profile_v1': jsonEncode(_profile.toJson())});
  final prefs = await SharedPreferences.getInstance();
  final store = LogStore(prefs, clock: () => DateTime(2026, 11, 21, 10));
  await t.pumpWidget(GymApp(store: store));
  await _frames(t);
  return store;
}

void main() {
  final langFiles = {for (final l in I18n.languages) l: File(I18n.asset(l)).readAsStringSync()};
  setUp(() => I18n.instance.useJson(langFiles));
  setUpAll(() => exerciseCatalog = ExerciseCatalog.parse(File(ExerciseCatalog.asset).readAsStringSync()));

  test('the word index: every word finds something; words narrow; one word per row', () {
    final index = ChalkIndex.of(exerciseCatalog);
    for (final w in chalkWords) {
      expect(index.count({w.key}), greaterThan(0), reason: w.key);
    }
    final line = {'angle.incline', 'tool.dumbbell', 'move.press'};
    final found = index.search(line);
    expect(found, isNotEmpty);
    for (final g in found) {
      for (final e in g.variants) {
        expect(e.mods['angle'], 'Incline');
        expect(e.mods['equip'] ?? e.equipment, anyOf('Dumbbell', 'dumbbell'));
        expect(e.name.toLowerCase(), contains('press'));
      }
    }
    expect(index.count(line), lessThan(index.count({'move.press'})));
    // A word takes the place of its row's word, or comes out again.
    final dumbbell = chalkWordByKey('tool.dumbbell')!, barbell = chalkWordByKey('tool.barbell')!;
    expect(chalkToggle(line, barbell), {'angle.incline', 'tool.barbell', 'move.press'});
    expect(chalkToggle(line, dumbbell), {'angle.incline', 'move.press'});
    // Flat: a move with angles, with none picked.
    expect(index.search({'angle.flat', 'move.press', 'tool.barbell'}).map((g) => g.key), contains('move:bench press'));
    // Every word has an English and a Romanian label.
    for (final w in chalkWords) {
      expect(langFiles['en']!.contains('"chalk.${w.key}"'), isTrue, reason: w.key);
      expect(langFiles['ro']!.contains('"chalk.${w.key}"'), isTrue, reason: w.key);
    }
  });

  testWidgets('CHALK: tap words, the workout shows all matches (any class); WIPE; FORGE at 0', (t) async {
    final store = await _openApp(t);
    expect(store.cards.any((g) => g.variants.any((e) => e.equipment == 'barbell')), isFalse); // a Scrapper has no barbell
    await t.tap(find.byKey(const ValueKey('filter-chalk')));
    await _frames(t, 10);
    expect(find.byKey(const ValueKey('chalk-line')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('chalk-tool.barbell')));
    await _frames(t, 4);
    await t.tap(find.byKey(const ValueKey('chalk-move.press')));
    await _frames(t, 4);
    expect(store.chalk, {'tool.barbell', 'move.press'});
    expect(find.byKey(const ValueKey('chalk-word-tool.barbell')), findsOneWidget);
    final n = ChalkIndex.of(exerciseCatalog).count(store.chalk);
    expect(find.text('SHOW $n EXERCISES'), findsOneWidget);
    // Tap a word in the chalk line to wipe it, then put it back.
    await t.tap(find.byKey(const ValueKey('chalk-word-move.press')));
    await _frames(t, 4);
    expect(store.chalk, {'tool.barbell'});
    await t.tap(find.byKey(const ValueKey('chalk-move.press')));
    await _frames(t, 4);
    await t.tap(find.byKey(const ValueKey('chalk-show')));
    await _frames(t, 20);
    expect(store.cards, isNotEmpty);
    expect(store.cards.every((g) => g.variants.every((e) => e.name.toLowerCase().contains('press'))), isTrue);
    expect(find.text('CHALK · 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('hard-badge')), findsNothing); // other gear: no badge
    // No exercise has all the words: NO SUCH MOVE. FORGE IT?
    await t.tap(find.byKey(const ValueKey('filter-chalk')));
    await _frames(t, 10);
    await t.tap(find.byKey(const ValueKey('chalk-move.plank')));
    await _frames(t, 4);
    expect(find.byKey(const ValueKey('chalk-forge')), findsOneWidget);
    expect(find.text('NO EXERCISE HAS ALL THESE WORDS'), findsOneWidget);
    // WIPE: back to the class's cards.
    await t.tap(find.byKey(const ValueKey('chalk-wipe')));
    await _frames(t, 4);
    expect(store.chalk, isEmpty);
    await t.tap(find.byKey(const ValueKey('chalk-show')));
    await _frames(t, 20);
    expect(find.text('CHALK'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('FORGE: the name and body from the words; a forged move is found and kept', () async {
    final line = {'angle.decline', 'tool.kettlebell', 'move.curl'};
    expect(forgeName(line), 'Decline Kettlebell Curl');
    expect(forgeBody(line), ('arms', 'biceps'));
    expect(forgeBody({'body.legs', 'move.curl'}), ('legs', 'quadriceps'));
    expect(forgeName({'pattern.hinge', 'tool.bodyweight'}), 'Hinge');
    SharedPreferences.setMockInitialValues({'profile_v1': jsonEncode(_profile.toJson())});
    final prefs = await SharedPreferences.getInstance();
    final store = LogStore(prefs, clock: () => DateTime(2026, 11, 21, 10));
    final before = exerciseCatalog.all.length;
    final move = store.forge(line, 'biceps', 'Benchy McPressface');
    expect(exerciseCatalog.all.length, before + 1);
    final e = exerciseCatalog.byId[move.id]!;
    expect((e.name, e.nick, e.equipment, e.muscle, e.mods['angle']), ('Decline Kettlebell Curl', 'Benchy McPressface', 'kettlebells', 'biceps', 'Decline'));
    // CHALK finds it with the words it came from; the workout shows it.
    expect(ChalkIndex.of(exerciseCatalog).search(line).map((g) => g.key), [move.id]);
    expect(store.cards.map((g) => g.key), contains(move.id));
    expect(store.pickedCard, move.id);
    store.addSet(move.id);
    expect(store.groupSetsToday(move.id), 1);
    // Kept on the phone: a new start has it again (once).
    final again = LogStore(prefs, clock: () => DateTime(2026, 11, 21, 11));
    expect(again.forged.map((f) => f.id), [move.id]);
    expect(exerciseCatalog.all.where((x) => x.id == move.id).length, 1);
  });

  testWidgets('FORGE card: from NO SUCH MOVE, a nickname on the arcade keyboard, FORGE IT', (t) async {
    final store = await _openApp(t);
    store.setChalk({'angle.decline', 'tool.kettlebell', 'move.curl'});
    await t.pump();
    await t.tap(find.byKey(const ValueKey('filter-chalk')));
    await _frames(t, 10);
    await t.tap(find.byKey(const ValueKey('chalk-forge')));
    await _frames(t, 20);
    expect(find.byKey(const ValueKey('forge-card')), findsOneWidget);
    expect(find.text('DECLINE KETTLEBELL CURL'), findsOneWidget);
    expect(find.byKey(const ValueKey('forge-muscle-biceps')), findsOneWidget);
    await t.ensureVisible(find.byKey(const ValueKey('forge-nickname')));
    await t.tap(find.byKey(const ValueKey('forge-nickname')));
    await _frames(t, 4);
    expect(find.byKey(const ValueKey('arcade-keyboard')), findsOneWidget);
    expect(find.byKey(const ValueKey('key-1')), findsNothing); // no digits
    for (final k in ['B', 'E', 'N', 'C', 'H', 'Ș']) {
      await t.tap(find.byKey(ValueKey('key-$k')));
    }
    await t.tap(find.byKey(const ValueKey('key-del')));
    await t.pump();
    expect(find.text('BENCH_'), findsOneWidget);
    // FORGE IT works before OK.
    await t.tap(find.byKey(const ValueKey('forge-it')));
    await _frames(t, 30);
    final f = store.forged.single;
    expect((f.nickname, f.muscle), ('BENCH', 'biceps'));
    expect(find.byKey(const ValueKey('forge-card')), findsNothing);
    expect(find.text('BENCH'), findsOneWidget); // the nickname is the card's title
    expect(t.takeException(), isNull);
  });
}
