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
import 'package:gym_app/pumplex.dart';
import 'package:gym_app/store.dart';
import 'package:gym_app/views/chalk.dart' show kChalkResultsHeight, kChalkSheetFraction;
import 'package:gym_app/views/play.dart' show SessionPage;

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

/// The scrollable of the CHALK results list (rows are built lazily).
final _resultsList = find.descendant(of: find.byKey(const ValueKey('chalk-results-scroll')), matching: find.byType(Scrollable));

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

  test('PUSH + FLY: the results list has the Dumbbell Fly, not only the Cable Fly (owner bug)', () {
    final index = ChalkIndex.of(exerciseCatalog);
    final names = index.results({'pattern.push', 'move.fly'}).map((r) => r.exercise.name).toList();
    expect(names, containsAll(['Cable Fly', 'Dumbbell Fly', 'Incline Dumbbell Fly', 'Decline Cable Fly']));
    expect(names, isNot(contains('Dumbbell Reverse Fly'))); // a PULL (rear delt) move
    // Adding DUMBBELL only narrows: the dumbbell flies stay.
    final dumbbell = index.results({'pattern.push', 'move.fly', 'tool.dumbbell'}).map((r) => r.exercise.name).toSet();
    expect(names.toSet().containsAll(dumbbell), isTrue);
    expect(dumbbell, contains('Dumbbell Fly'));
  });

  test('every move has one pattern and one rank for all its exercises (the data tools check it too)', () {
    final raw = (jsonDecode(File(ExerciseCatalog.asset).readAsStringSync()) as List).cast<Map<String, dynamic>>();
    final byBase = <String, List<Map<String, dynamic>>>{};
    for (final e in raw) {
      (byBase[(e['base'] as String).toLowerCase()] ??= []).add(e);
    }
    for (final MapEntry(:key, :value) in byBase.entries) {
      expect(value.map((e) => e['pattern']).toSet().length, 1, reason: key);
      expect(value.map((e) => e['rank']).toSet().length, 1, reason: key);
    }
  });

  test('every pair of words: the results equal a brute-force reference read straight from exercises.json', () {
    // The reference: the CHALK rule applied to the raw JSON, exercise by
    // exercise, with no cards: an exercise matches when it has every word.
    final raw = (jsonDecode(File(ExerciseCatalog.asset).readAsStringSync()) as List).cast<Map<String, dynamic>>();
    Set<String> wordsOf(Map<String, dynamic> j) {
      final name = j['name'] as String, pattern = j['pattern'] as String?;
      final mods = Map<String, String>.from(j['mods'] as Map? ?? const {});
      final equipment = (j['equipment'] as String?) ?? '';
      final muscle = ((j['primaryMuscles'] as List?) ?? const []).cast<String>().firstOrNull ?? '';
      final tool = mods['equip'] != null ? chalkToolOfMod[mods['equip']] : chalkToolOfEquipment[equipment.isEmpty ? 'body only' : equipment];
      return {
        for (final MapEntry(:key, :value) in chalkPatternWords.entries)
          if (value.contains(pattern)) 'pattern.$key',
        for (final MapEntry(:key, :value) in chalkMoveWords.entries)
          if (value.hasMatch(name)) 'move.$key',
        if (tool != null) 'tool.$tool',
        if (mods['type'] == 'Towel' || chalkTowel.hasMatch(name)) 'tool.towel',
        for (final b in bodyParts)
          if (b.muscles.contains(muscle)) 'body.${b.id}',
      };
    }

    final ref = {for (final j in raw) j['id'] as String: wordsOf(j)};
    final baseOf = {for (final j in raw) j['id'] as String: 'move:${(j['base'] as String).toLowerCase()}'};
    final index = ChalkIndex(ExerciseCatalog.parse(File(ExerciseCatalog.asset).readAsStringSync()));
    var lines = 0, nonEmpty = 0;
    for (var a = 0; a < chalkRows.length; a++) {
      for (var b = a + 1; b < chalkRows.length; b++) {
        for (final x in chalkWords.where((w) => w.row == chalkRows[a])) {
          for (final y in chalkWords.where((w) => w.row == chalkRows[b])) {
            final line = {x.key, y.key};
            final want = {for (final MapEntry(:key, :value) in ref.entries) if (value.containsAll(line)) key};
            final rows = index.results(line);
            final got = rows.map((r) => r.exercise.id).toList();
            final why = '$line';
            // The list shows each matching exercise once, no more and no less.
            expect(got.toSet(), want, reason: why);
            expect(got.length, want.length, reason: '$why: a row twice');
            expect(index.count(line), want.length, reason: why);
            // Each row sits on its own card, and the cards are the matching moves.
            for (final r in rows) {
              expect(r.card.key, baseOf[r.exercise.id], reason: why);
              expect(r.card.variants, contains(r.exercise), reason: why);
            }
            expect(index.search(line).map((g) => g.key).toSet(), {for (final id in want) baseOf[id]}, reason: why);
            lines++;
            if (want.isNotEmpty) nonEmpty++;
          }
        }
      }
    }
    expect(lines, greaterThan(700));
    expect(nonEmpty, greaterThan(200));
  });

  testWidgets('CHALK PUSH + FLY lists every fly of the Fly card, the Dumbbell Fly too (owner bug)', (t) async {
    final store = await _openApp(t);
    store.setChalk({'pattern.push', 'move.fly'});
    await _frames(t, 4);
    await t.tap(find.byKey(const ValueKey('filter-chalk')));
    await _frames(t, 10);
    for (final name in ['CABLE FLY', 'DUMBBELL FLY']) {
      expect(find.descendant(of: find.byKey(const ValueKey('chalk-results')), matching: find.text(name, skipOffstage: false)),
          findsOneWidget,
          reason: name);
    }
    final rows = ChalkIndex.of(exerciseCatalog).results(store.chalk);
    expect(find.text('RESULTS · ${rows.length}'), findsOneWidget);
    // A tap on the Dumbbell Fly row picks that exercise on the Fly card.
    final row = find.byKey(const ValueKey('chalk-result-Dumbbell_Flyes'));
    await t.ensureVisible(row);
    await t.pump();
    await t.tap(row, warnIfMissed: false);
    await _frames(t, 20);
    expect(store.pickedCard, 'move:fly');
    expect(store.variantFor(store.cards.firstWhere((g) => g.key == 'move:fly')).id, 'Dumbbell_Flyes');
    await t.tap(find.byKey(const ValueKey('filter-chalk')));
    await _frames(t, 10);
    await t.ensureVisible(find.byKey(const ValueKey('chalk-result-Dumbbell_Flyes')));
    await t.pump();
    expect(find.byKey(const ValueKey('chalk-result-on-Dumbbell_Flyes')), findsOneWidget);
    expect(find.byKey(const ValueKey('chalk-result-on-Flat_Bench_Cable_Flyes')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('FORGE IT sits under every results list and opens FORGE with the words; 0 results keep NO SUCH MOVE', (t) async {
    final store = await _openApp(t);
    store.setChalk({'pattern.push', 'move.fly'});
    await _frames(t, 4);
    await t.tap(find.byKey(const ValueKey('filter-chalk')));
    await _frames(t, 10);
    final forgeIt = find.byKey(const ValueKey('chalk-forge-it'), skipOffstage: false);
    expect(find.byKey(const ValueKey('chalk-forge')), findsNothing);
    await t.scrollUntilVisible(find.byKey(const ValueKey('chalk-forge-it')), 80,
        scrollable: find.descendant(of: find.byKey(const ValueKey('chalk-results-scroll')), matching: find.byType(Scrollable)));
    await t.ensureVisible(forgeIt);
    await _frames(t, 4);
    expect(forgeIt, findsOneWidget);
    expect(find.text('FORGE IT'), findsOneWidget);
    // It is the last thing in the list: under the last result row.
    final last = ChalkIndex.of(exerciseCatalog).results(store.chalk).last.exercise.id;
    expect(t.getRect(forgeIt).top, greaterThan(t.getRect(find.byKey(ValueKey('chalk-result-$last'))).bottom));
    await t.tap(forgeIt);
    await _frames(t, 20);
    expect(find.byKey(const ValueKey('forge-card')), findsOneWidget);
    // From the picked words.
    expect(t.widget<Text>(find.byKey(const ValueKey('forge-name'))).data, forgeName(store.chalk).toUpperCase());
    expect(find.byKey(const ValueKey('chalk-sheet')), findsNothing);
    // 0 results: NO SUCH MOVE. FORGE IT?, and no list.
    await t.tap(find.byKey(const ValueKey('forge-back')));
    await _frames(t, 20);
    store.setChalk(_noMove);
    await _frames(t, 4);
    await t.tap(find.byKey(const ValueKey('filter-chalk')));
    await _frames(t, 10);
    expect(find.byKey(const ValueKey('chalk-forge')), findsOneWidget);
    expect(find.byKey(const ValueKey('chalk-forge-it')), findsNothing);
    expect(t.takeException(), isNull);
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

  testWidgets('CHALK sheet: a fixed height and a fixed results area with 0, 3 and 30 results', (t) async {
    final store = await _openApp(t);
    final index = ChalkIndex.of(exerciseCatalog);
    // A line with a few results (1 to 3) and a line with 30 or more.
    final few = [
      for (final a in chalkWords)
        for (final b in chalkWords)
          if (a.row != b.row) {a.key, b.key},
    ].firstWhere((l) => index.results(l).length == 3);
    final many = chalkWords.map((w) => {w.key}).firstWhere((l) => index.results(l).length >= 30);
    await t.tap(find.byKey(const ValueKey('filter-chalk')));
    await _frames(t, 10);
    final sheet = find.byKey(const ValueKey('chalk-sheet'));
    final area = find.byKey(const ValueKey('chalk-results-area'));
    final tiles = find.byKey(const ValueKey('chalk-tiles'));
    final sizes = <String, (Rect, Rect, Rect)>{};
    Future<void> measure(String name, Set<String> line) async {
      store.setChalk(line);
      await _frames(t, 4);
      sizes[name] = (t.getRect(sheet), t.getRect(area), t.getRect(tiles));
    }

    await measure('no words', {});
    await measure('0', _noMove);
    expect(find.byKey(const ValueKey('chalk-forge')), findsOneWidget);
    await measure('3', few);
    expect(find.byKey(const ValueKey('chalk-forge')), findsNothing);
    await measure('30', many);
    final first = sizes.values.first;
    for (final e in sizes.entries) {
      expect(e.value, first, reason: e.key); // nothing moves
    }
    expect(first.$1.height, closeTo(t.view.physicalSize.height / t.view.devicePixelRatio * kChalkSheetFraction, 0.5));
    expect(first.$2.height, kChalkResultsHeight);
    // Many results scroll inside the area, with a visible scrollbar and a fade.
    final list = find.byKey(const ValueKey('chalk-results-scroll'));
    final bar = find.descendant(of: list, matching: find.byType(Scrollbar));
    expect(bar, findsOneWidget);
    expect(t.widget<Scrollbar>(bar).thumbVisibility, isTrue);
    expect(find.descendant(of: list, matching: find.byKey(const ValueKey('chalk-fade'))), findsOneWidget);
    // Three results fit: no fade.
    store.setChalk(few);
    await _frames(t, 4);
    expect(find.descendant(of: list, matching: find.byKey(const ValueKey('chalk-fade'))), findsNothing);
    // The tiles area has its own scrollbar too.
    expect(t.widget<Scrollbar>(find.descendant(of: tiles, matching: find.byType(Scrollbar))).thumbVisibility, isTrue);
    expect(t.takeException(), isNull);
  });

  testWidgets('CHALK results: "+" adds to Today, a row tap selects without adding, the selected row is lime', (t) async {
    final store = await _openApp(t);
    store.setChalk({'tool.barbell', 'move.press'});
    await _frames(t, 4);
    await t.tap(find.byKey(const ValueKey('filter-chalk')));
    await _frames(t, 10);
    final rows = ChalkIndex.of(exerciseCatalog).results(store.chalk);
    final a = rows[0], b = rows.firstWhere((r) => r.card.key != a.card.key);
    // "+" is at least 44 px; a tap adds the card to Today and the sheet stays.
    final add = find.byKey(ValueKey('chalk-result-add-${a.exercise.id}'));
    expect(t.getSize(add).width, greaterThanOrEqualTo(44));
    expect(t.getSize(add).height, greaterThanOrEqualTo(44));
    await t.tap(add);
    await _frames(t, 4);
    expect(store.todayCards, [a.card.key]);
    expect(find.byKey(const ValueKey('chalk-sheet')), findsOneWidget);
    expect(add, findsNothing);
    expect(find.byKey(ValueKey('chalk-result-today-${a.exercise.id}')), findsOneWidget);
    // The picked exercise's row is filled with the lime (the app's yellow).
    final p = Theme.of(t.element(find.byKey(const ValueKey('chalk-sheet')))).extension<Pal>()!;
    Color fill(String id) => ((t.widget<Container>(find.byKey(ValueKey('chalk-result-on-$id'))).decoration!) as BoxDecoration).color!;
    expect(fill(a.exercise.id), p.lime);
    // A picked tile is lime too.
    final tile = find.descendant(of: find.byKey(const ValueKey('chalk-tool.barbell')), matching: find.byType(Container));
    expect((t.widget<Container>(tile).decoration! as BoxDecoration).color, p.lime);
    // A tap on the rest of a row selects that card and closes the sheet; it
    // does not add it to Today.
    await t.scrollUntilVisible(find.byKey(ValueKey('chalk-result-${b.exercise.id}')), 60, scrollable: _resultsList);
    await t.pump();
    await t.tap(find.byKey(ValueKey('chalk-result-${b.exercise.id}')), warnIfMissed: false);
    await _frames(t, 20);
    expect(store.pickedCard, b.card.key);
    expect(store.todayCards, [a.card.key]);
    expect(find.byKey(const ValueKey('chalk-sheet')), findsNothing);
    await t.tap(find.byKey(const ValueKey('filter-chalk')));
    await _frames(t, 10);
    await t.scrollUntilVisible(find.byKey(ValueKey('chalk-result-${b.exercise.id}')), 60, scrollable: _resultsList);
    await t.pump();
    expect(fill(b.exercise.id), p.lime);
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
    final r = ChalkIndex.of(exerciseCatalog).results(store.chalk).first;
    await t.ensureVisible(find.byKey(ValueKey('chalk-result-${r.exercise.id}')));
    await t.tap(find.byKey(ValueKey('chalk-result-${r.exercise.id}')));
    await _frames(t, 20);
    expect(find.byKey(ValueKey('exercise-${r.card.key}')), findsOneWidget);
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
    expect(store.carousel, isEmpty); // the preview went too (D82)
    expect(find.byKey(const ValueKey('today-empty-card')), findsOneWidget);
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

  testWidgets('past sessions show a forged move by its nickname', (t) async {
    SharedPreferences.setMockInitialValues({'profile_v1': jsonEncode(_profile.toJson())});
    final prefs = await SharedPreferences.getInstance();
    final store = LogStore(prefs, clock: () => DateTime(2026, 11, 21, 10));
    final move = store.forge({'tool.kettlebell', 'move.curl'}, 'biceps', 'Benchy');
    store.addSet(move.id);
    await t.pumpWidget(MaterialApp(
      theme: pumplexTheme(Brightness.light),
      home: Scaffold(body: SessionPage(session: store.todaySession!, xp: 0, live: true)),
    ));
    expect(find.text('BENCHY  1'), findsOneWidget);
    expect(find.textContaining('KETTLEBELL CURL'), findsNothing);
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
