// CHALK, the exercise search (D72, D81): word tiles narrow the list over ALL
// exercises (no class, no filters); a second tap unpicks a tile; the
// results sit at the bottom; a tap selects a card; BACK TO TODAY; 0
// matches offers FORGE. No ANGLE or GRIP (chips on the card).

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

/// Words no exercise has all of: CHALK offers FORGE.
const _noMove = {'tool.kettlebell', 'move.pulldown'};

void main() {
  final langFiles = {for (final l in I18n.languages) l: File(I18n.asset(l)).readAsStringSync()};
  setUp(() => I18n.instance.useJson(langFiles));
  setUpAll(() => exerciseCatalog = ExerciseCatalog.parse(File(ExerciseCatalog.asset).readAsStringSync()));

  test('the word index: every word finds something; words narrow; one word per row', () {
    final index = ChalkIndex.of(exerciseCatalog);
    for (final w in chalkWords) {
      expect(index.count({w.key}), greaterThan(0), reason: w.key);
    }
    final line = {'tool.dumbbell', 'move.press'};
    final found = index.search(line);
    expect(found, isNotEmpty);
    for (final g in found) {
      for (final e in g.variants) {
        expect(e.mods['equip'] ?? e.equipment, anyOf('Dumbbell', 'dumbbell'));
        expect(e.name.toLowerCase(), contains('press'));
      }
    }
    expect(index.count(line), lessThan(index.count({'move.press'})));
    // A word takes the place of its row's word, or comes out again.
    final dumbbell = chalkWordByKey('tool.dumbbell')!, barbell = chalkWordByKey('tool.barbell')!;
    expect(chalkToggle(line, barbell), {'tool.barbell', 'move.press'});
    expect(chalkToggle(line, dumbbell), {'move.press'});
    // No ANGLE and no GRIP (D81): those are chips on the exercise card.
    expect(chalkRows, ['pattern', 'move', 'tool', 'body']);
    expect(chalkWords.where((w) => w.row == 'angle' || w.row == 'grip'), isEmpty);
    expect(index.words.values.expand((w) => w).where((k) => k.startsWith('angle.') || k.startsWith('grip.')), isEmpty);
    // Every word has an English and a Romanian label.
    for (final w in chalkWords) {
      expect(langFiles['en']!.contains('"chalk.${w.key}"'), isTrue, reason: w.key);
      expect(langFiles['ro']!.contains('"chalk.${w.key}"'), isTrue, reason: w.key);
    }
    expect(index.count(_noMove), 0);
  });

  test('the word index: every card is found by at least one single word', () {
    final index = ChalkIndex.of(exerciseCatalog);
    final found = {
      for (final w in chalkWords)
        for (final g in index.search({w.key})) g.key,
    };
    for (final g in exerciseCatalog.groups) {
      expect(found, contains(g.key), reason: g.name);
    }
    // Every card has a PATTERN or a MOVE word, except the few odd ones
    // that only BODY (and TOOL) find.
    final what = {
      for (final w in chalkWords.where((w) => w.row == 'pattern' || w.row == 'move'))
        for (final g in index.search({w.key})) g.key,
    };
    final odd = [for (final g in exerciseCatalog.groups) if (!what.contains(g.key)) g.name]..sort();
    expect(odd.length, lessThanOrEqualTo(10), reason: '$odd');
  });

  test('the word index: the user-test gaps (towel, rowing machine, null gear, isolation moves)', () {
    final index = ChalkIndex.of(exerciseCatalog);
    Set<String> cards(Set<String> line) => index.search(line).map((g) => g.key).toSet();
    Set<String> names(Set<String> line) => {for (final g in index.search(line)) for (final e in g.variants) e.name};
    // A Scrapper finds the Towel Row (no forged copy).
    expect(names({'tool.towel', 'move.row'}), {'Towel Row'});
    // No equipment in the database is Bodyweight.
    expect(index.words['Inverted_Row'], contains('tool.bodyweight'));
    // The Rowing Machine is CARDIO, not ROW.
    expect(names({'pattern.cardio'}), contains('Rowing Machine'));
    expect(names({'move.row'}), isNot(contains('Rowing Machine')));
    expect(names({'pattern.carry'}), contains("Dumbbell Farmer's Walk"));
    // The isolation moves.
    expect(cards({'move.pushdown'}), {'move:triceps pushdown'});
    expect(cards({'move.kickback', 'body.arms'}), {'move:triceps kickback'});
    expect(cards({'move.pullover'}), {'move:pullover'});
    expect(cards({'move.hipthrust'}), {'move:hip thrust'});
    expect(cards({'move.bridge'}), {'move:glute bridge'});
    expect(cards({'move.wristcurl'}), {'move:wrist curl'});
    expect(cards({'move.curl', 'body.legs'}), {'move:leg curl', 'move:nordic curl'});
    expect(cards({'move.raise', 'body.legs'}), contains('move:calf raise'));
    expect(cards({'move.extension'}), contains('move:skullcrusher'));
    expect(cards({'pattern.push'}), contains('move:fly'));
    expect(cards({'pattern.pull'}), containsAll(['move:face pull', 'move:shrug']));
  });

  testWidgets('CHALK sheet (D81): tiles with no counts, no ANGLE / GRIP, results at the bottom, FORGE at 0', (t) async {
    final store = await _openApp(t);
    expect(store.cards.any((g) => g.variants.any((e) => e.equipment == 'barbell')), isFalse); // a Scrapper has no barbell
    await t.tap(find.byKey(const ValueKey('filter-chalk')));
    await _frames(t, 10);
    // No chalk line, no hints, no WIPE and no SHOW n EXERCISES.
    expect(find.byKey(const ValueKey('chalk-line')), findsNothing);
    expect(find.byKey(const ValueKey('chalk-tip')), findsNothing);
    expect(find.byKey(const ValueKey('chalk-wipe')), findsNothing);
    expect(find.byKey(const ValueKey('chalk-show')), findsNothing);
    expect(find.textContaining('WIPE'), findsNothing);
    expect(find.textContaining('TAP ONE'), findsNothing);
    expect(find.textContaining('CHALK:'), findsNothing);
    expect(find.byKey(const ValueKey('chalk-back-today')), findsOneWidget);
    // No ANGLE and no GRIP rows.
    expect(find.byKey(const ValueKey('chalk-row-angle')), findsNothing);
    expect(find.byKey(const ValueKey('chalk-row-grip')), findsNothing);
    expect(find.byKey(const ValueKey('chalk-angle.incline')), findsNothing);
    expect(find.byKey(const ValueKey('chalk-grip.wide')), findsNothing);
    expect(find.text('ANGLE'), findsNothing);
    expect(find.text('GRIP'), findsNothing);
    // The sheet scrolls: bring a tile into view before the tap.
    Future<void> tapTile(String key) async {
      await t.ensureVisible(find.byKey(ValueKey('chalk-$key')));
      await t.pump();
      await t.tap(find.byKey(ValueKey('chalk-$key')));
      await _frames(t, 4);
    }

    // A tile shows only its word: no count.
    final tile = find.byKey(const ValueKey('chalk-tool.barbell'));
    expect(find.descendant(of: tile, matching: find.byType(Text)).evaluate().map((e) => (e.widget as Text).data), ['BARBELL']);
    expect(find.byKey(const ValueKey('chalk-results')), findsNothing); // no words: no list
    await tapTile('tool.barbell');
    await tapTile('move.press');
    expect(store.chalk, {'tool.barbell', 'move.press'});
    // A second tap on a tile unpicks it; then put it back.
    await tapTile('move.press');
    expect(store.chalk, {'tool.barbell'});
    await tapTile('move.press');
    expect(store.chalk, {'tool.barbell', 'move.press'});
    for (final e in find.descendant(of: find.byKey(const ValueKey('chalk-row-tool')), matching: find.byType(Text)).evaluate()) {
      expect((e.widget as Text).data, isNot(matches(RegExp(r'^\d+$'))));
    }
    // The results sit at the bottom, under the tiles (which scroll).
    final tiles = find.ancestor(of: find.byKey(const ValueKey('chalk-row-body')), matching: find.byType(SingleChildScrollView));
    expect(find.byKey(const ValueKey('chalk-results')), findsOneWidget);
    expect(t.getRect(find.byKey(const ValueKey('chalk-results'))).top, greaterThanOrEqualTo(t.getRect(tiles).bottom));
    expect(store.cards.every((g) => g.variants.every((e) => e.name.toLowerCase().contains('press'))), isTrue);
    // No exercise has all the words: the bottom shows NO SUCH MOVE. FORGE IT?
    await tapTile('move.press'); // out
    await tapTile('move.pulldown');
    await tapTile('tool.kettlebell');
    expect(store.chalk, _noMove);
    expect(find.byKey(const ValueKey('chalk-results')), findsNothing);
    expect(find.byKey(const ValueKey('chalk-forge')), findsOneWidget);
    expect(find.text('NO SUCH MOVE. FORGE IT?'), findsOneWidget);
    expect(t.getRect(find.byKey(const ValueKey('chalk-forge'))).top, greaterThanOrEqualTo(t.getRect(tiles).bottom));
    expect(t.takeException(), isNull);
  });

  testWidgets('BACK TO TODAY (D81): wipes the words, closes CHALK, the carousel goes to the first Today card', (t) async {
    final store = await _openApp(t);
    final a = store.cards[2], b = store.cards[5];
    store.addToToday(a.key);
    store.addToToday(b.key);
    store.setChalk({'tool.barbell', 'move.press'});
    await _frames(t, 4);
    await t.tap(find.byKey(const ValueKey('filter-chalk')));
    await _frames(t, 10);
    final g = ChalkIndex.of(exerciseCatalog).search(store.chalk).first;
    await t.ensureVisible(find.byKey(ValueKey('chalk-result-${g.key}')));
    await t.tap(find.byKey(ValueKey('chalk-result-${g.key}')));
    await _frames(t, 20);
    expect(find.byKey(ValueKey('exercise-${g.key}')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('filter-chalk')));
    await _frames(t, 10);
    await t.tap(find.byKey(const ValueKey('chalk-back-today')));
    await _frames(t, 20);
    expect(find.byKey(const ValueKey('chalk-back-today')), findsNothing); // closed
    expect(store.chalk, isEmpty);
    expect(store.pickedCard, a.key);
    expect(find.byKey(ValueKey('exercise-${a.key}')), findsOneWidget);
    expect(find.text('CHALK'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('BACK TO TODAY with an empty Today: the start of the list', (t) async {
    final store = await _openApp(t);
    store.setChalk({'tool.barbell', 'move.press'});
    store.selectCard(ChalkIndex.of(exerciseCatalog).search(store.chalk)[1].key);
    await _frames(t, 4);
    await t.tap(find.byKey(const ValueKey('filter-chalk')));
    await _frames(t, 10);
    await t.tap(find.byKey(const ValueKey('chalk-back-today')));
    await _frames(t, 20);
    expect(store.chalk, isEmpty);
    expect(store.todayCards, isEmpty);
    expect(find.byKey(ValueKey('exercise-${store.carousel.first.key}')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('FORGE: the name and body from the words, no angle or grip; a forged move is found and kept', () async {
    final line = {'tool.kettlebell', 'move.curl'};
    expect(forgeName(line), 'Kettlebell Curl');
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
    expect((e.name, e.nick, e.equipment, e.muscle), ('Kettlebell Curl', 'Benchy McPressface', 'kettlebells', 'biceps'));
    // No angle and no grip (D81): only the tool in the mods.
    expect(e.mods, {'equip': 'Kettlebell'});
    // CHALK finds it with the words it came from; the workout shows it.
    expect(ChalkIndex.of(exerciseCatalog).search(line).map((g) => g.key), contains(move.id));
    expect(store.cards.map((g) => g.key), contains(move.id));
    expect(store.pickedCard, move.id);
    store.addSet(move.id);
    expect(store.groupSetsToday(move.id), 1);
    // Kept on the phone: a new start has it again (once).
    final again = LogStore(prefs, clock: () => DateTime(2026, 11, 21, 11));
    expect(again.forged.map((f) => f.id), [move.id]);
    expect(exerciseCatalog.all.where((x) => x.id == move.id).length, 1);
    // An older forged move with ANGLE or GRIP words loses them.
    final old = ForgedMove.fromJson({
      'id': 'custom_9',
      'words': ['angle.decline', 'grip.wide', 'tool.kettlebell', 'move.curl'],
      'muscle': 'biceps',
    });
    expect(old.words, line);
    expect(old.name, 'Kettlebell Curl');
    expect(old.toExercise().mods, {'equip': 'Kettlebell'});
  });

  testWidgets('FORGE card: no ANGLE or GRIP; a nickname on the arcade keyboard, FORGE IT', (t) async {
    final store = await _openApp(t);
    store.setChalk(_noMove);
    await t.pump();
    await t.tap(find.byKey(const ValueKey('filter-chalk')));
    await _frames(t, 10);
    await t.ensureVisible(find.byKey(const ValueKey('chalk-forge')));
    await t.tap(find.byKey(const ValueKey('chalk-forge')));
    await _frames(t, 20);
    expect(find.byKey(const ValueKey('forge-card')), findsOneWidget);
    expect(find.text('KETTLEBELL PULLDOWN'), findsOneWidget);
    expect(find.byKey(const ValueKey('forge-tool.kettlebell')), findsOneWidget);
    expect(find.byKey(const ValueKey('forge-angle.incline')), findsNothing);
    expect(find.byKey(const ValueKey('forge-grip.wide')), findsNothing);
    expect(find.text('ANGLE'), findsNothing);
    expect(find.text('GRIP'), findsNothing);
    expect(find.byKey(const ValueKey('forge-muscle-lats')), findsOneWidget);
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
    expect((f.nickname, f.muscle), ('BENCH', 'lats'));
    expect(f.words, _noMove);
    expect(exerciseCatalog.byId[f.id]!.mods.keys, ['equip']);
    expect(store.todayCards, [f.id]); // FORGE IT still adds to Today (D79)
    expect(find.byKey(const ValueKey('forge-card')), findsNothing);
    expect(find.text('BENCH'), findsOneWidget); // the nickname is the card's title
    expect(t.takeException(), isNull);
  });
}
