// TODAY (D79, D81, D82): the lifter's list for one day, one entry per
// exercise (variation), not per card. The first set, the CHALK "+", FORGE
// IT and COPY add an exercise; a CHALK row only selects it (D81); the
// carousel shows only Today, plus a selected exercise as a preview (D82);
// the delete button removes an exercise and its sets; the list ends with the
// day; COPY A PAST DAY copies the variations done, not the sets. The old
// Today (card keys) changes to exercises once.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gym_app/i18n.dart';
import 'package:gym_app/game/chalk.dart';
import 'package:gym_app/game/exercises.dart';
import 'package:gym_app/game/model.dart';
import 'package:gym_app/main.dart';
import 'package:gym_app/store.dart';

/// The cards of the class and mode, in the Suggested order: the cards the
/// carousel keeps (D82). The old filter list (store.cards) is gone.
List<ExerciseGroup> _cards(LogStore s) => s.chalkCards(const {}); // every card, my gear first (D89)

const _profile = Profile(
  character: Character(sex: 'female', height: 80, muscle: 100, fat: 0),
  classId: 'paladin',
  difficultyId: 'sweat',
  areaId: 'gainsgard',
);

Future<void> _frames(WidgetTester t, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// The first exercise of card [g] (what a fresh store shows on it).
String _first(ExerciseGroup g) => g.variants.first.id;

void main() {
  final langFiles = {for (final l in I18n.languages) l: File(I18n.asset(l)).readAsStringSync()};
  setUp(() => I18n.instance.useJson(langFiles));
  setUpAll(() => exerciseCatalog = ExerciseCatalog.parse(File(ExerciseCatalog.asset).readAsStringSync()));

  var now = DateTime(2026, 11, 21, 10);
  Future<(LogStore, SharedPreferences)> newStore([Map<String, Object> more = const {}]) async {
    now = DateTime(2026, 11, 21, 10);
    SharedPreferences.setMockInitialValues({'profile_v1': jsonEncode(_profile.toJson()), ...more});
    final prefs = await SharedPreferences.getInstance();
    return (LogStore(prefs, clock: () => now), prefs);
  }

  ExerciseGroup bench() => exerciseCatalog.byKey['move:bench press']!;

  /// The first exercises of the cards that are not Bench Press.
  List<String> others(LogStore store) => [for (final g in _cards(store)) if (g.key != bench().key) _first(g)];

  test('the first set adds that exercise; a CHALK row only selects; one exercise once; kept on the phone', () async {
    final (store, prefs) = await newStore();
    expect(store.todayIds, isEmpty);
    final a = _first(_cards(store)[3]), b = _first(_cards(store)[7]), c = _first(_cards(store)[9]);
    store.addSet(a);
    store.addSet(a);
    expect(store.todayIds, [a]);
    store.selectExercise(c); // a CHALK row: selected, not in Today (D81)
    expect(store.pickedCard, c);
    expect(store.todayIds, [a]);
    store.addToToday(b);
    store.addToToday(a); // already there
    expect(store.todayIds, [a, b]);
    expect(store.pickedCard, a);
    // Taking the sets back does not drop it (no remove gesture).
    store.removeSet(a);
    store.removeSet(a);
    expect(store.todayIds, [a, b]);
    // Saved with its day.
    expect(jsonDecode(prefs.getString(LogStore.todayKey)!), {'date': '2026-11-21', 'exercises': [a, b]});
    final again = LogStore(prefs, clock: () => now);
    expect(again.todayIds, [a, b]);
  });

  test('two variations of one move are both in Today, each its own carousel card; sets, XP cap and critical stay per move', () async {
    final (store, _) = await newStore();
    final g = bench(), x = g.variants[0].id, y = g.variants[1].id;
    store.addToToday(x);
    store.addToToday(y);
    expect(store.todayIds, [x, y]);
    expect(store.inToday(x) && store.inToday(y), isTrue);
    expect(store.inToday(g.variants[2].id), isFalse);
    expect(store.carousel.map((e) => e.id), [x, y]);
    expect(store.carousel.map((e) => e.card.key), [g.key, g.key]);
    // Sets go to each variation; the card count of the move is the sum.
    for (var i = 0; i < 7; i++) {
      store.addSet(x);
    }
    for (var i = 0; i < 6; i++) {
      store.addSet(y);
    }
    expect((store.setsToday(x), store.setsToday(y), store.groupSetsToday(g.key)), (7, 6, 13));
    // The 10-set XP cap is per move (D52, D55): the two cards share it.
    expect(store.xpToday(x) + store.xpToday(y), store.groupXpToday(g.key));
    expect(store.xpToday(y), lessThan(store.xpToday(x)));
    store.addSet(y);
    expect(store.lastSetCritical(y), isFalse); // set 14 of the move: over the cap
  });

  test('"+" on one variation marks only that one; the others stay out of Today', () async {
    final (store, _) = await newStore();
    store.setChalk({'pattern.pull', 'move.fly'});
    final rows = ChalkIndex.of(exerciseCatalog).results(store.chalk);
    final card = rows.first.card;
    final same = rows.where((r) => r.card.key == card.key).toList();
    expect(same.length, greaterThan(1), reason: 'pull + fly gives several variations of one move');
    store.addToToday(same[1].exercise.id);
    expect([for (final r in rows) store.inToday(r.exercise.id)], [for (final r in rows) r.exercise.id == same[1].exercise.id]);
  });

  test('a chip changes the variation of a Today card: it replaces the id, no duplicates; a done one stays', () async {
    final (store, _) = await newStore();
    final g = bench(), x = g.variants[0].id, y = g.variants[1].id, z = g.variants[2].id;
    final other = others(store)[0];
    store.addToToday(x);
    store.addToToday(other);
    store.changeVariant(x, y); // in its place
    expect(store.todayIds, [y, other]);
    expect(store.pickedCard, y);
    expect(store.variantFor(g).id, y); // remembered on the move
    store.addToToday(z);
    store.changeVariant(y, z); // z is there already: no duplicate, go there
    expect(store.todayIds, [other, z]);
    expect(store.pickedCard, z);
    // With sets the old one stays (its sets are done); the new one comes after it.
    store.addSet(z);
    store.changeVariant(z, x);
    expect(store.todayIds, [other, z, x]);
    expect((store.setsToday(z), store.setsToday(x)), (1, 0));
    // The first set adds the variation shown.
    store.addSet(x);
    expect(store.setsToday(x), 1);
    // On the CHALK preview, the preview becomes the new variation.
    // (A move with no exercise in Today: the Squat is `other` since D90 made it rank 2.)
    final p = exerciseCatalog.byKey['move:deadlift']!;
    expect(p.variants.any((e) => store.todayIds.contains(e.id)), isFalse);
    store.selectExercise(p.variants[0].id);
    store.changeVariant(p.variants[0].id, p.variants[1].id);
    expect(store.previewId, p.variants[1].id);
    expect(store.todayIds, [other, z, x]);
  });

  test('FORGE IT adds the forged move to Today', () async {
    final (store, _) = await newStore();
    final move = store.forge({'tool.kettlebell', 'move.pulldown'}, 'lats', null);
    expect(store.todayIds, [move.id]);
    expect(store.carousel.first.id, move.id);
  });

  test('the carousel (D82): only the Today exercises, with all their card\'s exercises; no catalog, filters or search after them', () async {
    final (store, _) = await newStore();
    expect(store.carousel, isEmpty);
    final cards = _cards(store).map((g) => g.key).toList();
    final a = _first(_cards(store)[5]), b = _first(_cards(store)[2]);
    store.addToToday(a);
    store.addToToday(b);
    expect(store.carousel.map((e) => e.card.key), [cards[5], cards[2]]);
    // A CHALK search changes nothing.
    store.setChalk({'move.press', 'tool.barbell'});
    expect(store.carousel.map((e) => e.id), [a, b]);
    // A card keeps all the exercises of its move: none is greyed by class (D89).
    final mine = exerciseCatalog.byKey[cards[5]]!;
    expect(store.carousel.first.card.variants.map((e) => e.id), mine.variants.map((e) => e.id));
  });

  test('a CHALK row on an exercise not in Today (D82): a preview at the end until the carousel leaves it; its first set adds it; per variation', () async {
    final (store, _) = await newStore();
    final ids = [for (final g in _cards(store).take(10)) _first(g)];
    store.addToToday(ids[0]);
    store.addToToday(ids[1]);
    store.selectExercise(ids[7]); // the CHALK row
    expect(store.todayIds, [ids[0], ids[1]]);
    expect(store.previewId, ids[7]);
    expect(store.carousel.map((e) => e.id), [ids[0], ids[1], ids[7]]);
    // Swiping away drops it.
    store.setPickedCard(ids[1]);
    expect(store.previewId, isNull);
    expect(store.carousel.map((e) => e.id), [ids[0], ids[1]]);
    // Another row, then a set: it joins Today, at the end.
    store.selectExercise(ids[9]);
    store.addSet(ids[9]);
    expect(store.previewId, isNull);
    expect(store.todayIds, [ids[0], ids[1], ids[9]]);
    // A row on a Today exercise is no preview; another variation of its move is.
    store.selectExercise(ids[0]);
    expect(store.previewId, isNull);
    final g = bench();
    store.addToToday(g.variants[0].id);
    store.selectExercise(g.variants[1].id);
    expect(store.previewId, g.variants[1].id);
    expect(store.carousel.last.id, g.variants[1].id);
    // BACK TO TODAY drops a preview.
    store.backToToday();
    expect(store.previewId, isNull);
  });

  test('delete (D82): the exercise leaves Today; with sets, its sets and their XP go too; another variation keeps its sets', () async {
    final (store, prefs) = await newStore();
    final a = others(store)[0], b = others(store)[1];
    final g = bench(), x = g.variants[0].id, y = g.variants[1].id;
    store.addToToday(a);
    store.addToToday(b);
    store.addToToday(x);
    store.addToToday(y);
    // No sets: straight out; the carousel goes to the card in its place.
    store.selectExercise(b);
    store.removeFromToday(b);
    expect(store.todayIds, [a, x, y]);
    expect(store.pickedCard, x);
    // With sets: only that variation's sets go, and their XP.
    store.addSet(a);
    store.addSet(x);
    final xp = store.totalXp;
    store.addSet(y);
    store.addSet(y);
    expect(store.totalXp, greaterThan(xp));
    store.selectExercise(y);
    store.removeFromToday(y);
    expect(store.todayIds, [a, x]);
    expect((store.setsToday(y), store.setsToday(x), store.setsToday(a)), (0, 1, 1));
    expect(store.totalXp, xp);
    expect(store.pickedCard, x); // the one before
    // Saved: a new app has the same Today.
    expect(LogStore(prefs, clock: () => now).todayIds, [a, x]);
    // The last ones: Today is empty, no XP from today, nothing picked.
    store.removeFromToday(x);
    store.removeFromToday(a);
    expect(store.todayIds, isEmpty);
    expect(store.todaySession?.totalSets ?? 0, 0);
    expect(store.xpEvents.where((e) => e.ref == '2026-11-21'), isEmpty);
    expect(store.pickedCard, isNull);
  });

  test('the day ends: a new day starts empty, 0-set exercises do not stay, COPY copies the variations done and not sets', () async {
    final (store, prefs) = await newStore();
    final a = others(store)[0], b = others(store)[1];
    final g = bench(), x = g.variants[0].id, y = g.variants[1].id;
    store.addSet(a);
    store.addToToday(b); // 0 sets
    store.addSet(x);
    store.addSet(y);
    store.addSet(y);
    expect(store.todayIds, [a, b, x, y]);
    now = DateTime(2026, 11, 22, 7); // the next day
    expect(store.todayIds, isEmpty);
    expect(LogStore(prefs, clock: () => now).todayIds, isEmpty);
    expect(store.pastDays, ['2026-11-21']);
    expect(store.dayMoves('2026-11-21').map((e) => e.id), [a, x, y]); // b had no sets; both bench variations
    store.copyDay('2026-11-21');
    expect(store.todayIds, [a, x, y]);
    expect(store.todaySession?.totalSets ?? 0, 0); // no sets copied
    expect(store.sessions['2026-11-21']!.totalSets, 4); // the past day is untouched
    expect(store.carousel.map((e) => e.id), [a, x, y]);
    expect(store.pickedCard, a);
  });

  test('the old Today (card keys) changes once to exercises: the ones with sets, else the picked one, else the first', () async {
    final g = bench(), sq = exerciseCatalog.byKey['move:squat']!, third = exerciseCatalog.groups[3];
    final picked = g.variants[2].id, done = sq.variants[1].id;
    // Today's session has 2 sets of one squat; the old app saved card keys.
    final (seed, prefs) = await newStore();
    seed.addSet(done);
    seed.addSet(done);
    await prefs.remove(LogStore.todayKey);
    await prefs.setString(LogStore.oldTodayKey, jsonEncode({'date': '2026-11-21', 'cards': [g.key, sq.key, 'move:gone', third.key]}));
    await prefs.setString(LogStore.pickedVariantsKey, jsonEncode({g.key: [picked]}));
    await prefs.setString(LogStore.pickedCardKey, sq.key);
    final store = LogStore(prefs, clock: () => now);
    final want = [picked, done, _first(third)];
    expect(store.todayIds.take(3), want);
    expect(prefs.containsKey(LogStore.oldTodayKey), isFalse); // once
    expect(jsonDecode(prefs.getString(LogStore.todayKey)!)['exercises'], want);
    expect(prefs.getString(LogStore.pickedCardKey), done);
    // A second start reads the new list.
    expect(LogStore(prefs, clock: () => now).todayIds.take(3), want);
  });

  testWidgets('the TRAS + FLUTURĂRI bug: "+" on one fly marks only that row TODAY; its card shows that variation', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    t.view.padding = const FakeViewPadding(top: 110, bottom: 146);
    addTearDown(t.view.reset);
    final (store, _) = await newStore();
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    store.setChalk({'pattern.pull', 'move.fly'});
    await t.pump();
    await t.tap(find.byKey(const ValueKey('filter-chalk')));
    await _frames(t, 10);
    final rows = ChalkIndex.of(exerciseCatalog).results(store.chalk);
    final card = rows.first.card;
    final same = rows.where((r) => r.card.key == card.key).toList();
    expect(same.length, greaterThan(1));
    final pick = same[1].exercise.id;
    await t.ensureVisible(find.byKey(ValueKey('chalk-result-add-$pick')));
    await t.tap(find.byKey(ValueKey('chalk-result-add-$pick')));
    await _frames(t, 6);
    final list = find.descendant(of: find.byKey(const ValueKey('chalk-results-scroll')), matching: find.byType(Scrollable));
    for (final r in same) {
      t.state<ScrollableState>(list).position.jumpTo(0);
      await t.pump();
      await t.scrollUntilVisible(find.byKey(ValueKey('chalk-result-${r.exercise.id}')), 60, scrollable: list);
      await t.pump();
      expect(find.byKey(ValueKey('chalk-result-today-${r.exercise.id}')), r.exercise.id == pick ? findsOneWidget : findsNothing,
          reason: r.exercise.id);
      expect(find.byKey(ValueKey('chalk-result-add-${r.exercise.id}')), r.exercise.id == pick ? findsNothing : findsOneWidget,
          reason: r.exercise.id);
    }
    // A second variation of the same move: both in Today.
    final also = same[0].exercise.id;
    t.state<ScrollableState>(list).position.jumpTo(0);
    await t.pump();
    await t.scrollUntilVisible(find.byKey(ValueKey('chalk-result-add-$also')), 60, scrollable: list);
    await t.pump();
    await t.tap(find.byKey(ValueKey('chalk-result-add-$also')));
    await _frames(t, 6);
    expect(store.todayIds, [pick, also]);
    expect(t.takeException(), isNull);
  });

  testWidgets('a CHALK result row selects the exercise (not in Today); the sheet closes on it; highlighted; TODAY mark after a set', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    t.view.padding = const FakeViewPadding(top: 110, bottom: 146);
    addTearDown(t.view.reset);
    final (store, _) = await newStore();
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    store.setChalk({'move.press', 'tool.dumbbell'});
    await t.pump();
    await t.tap(find.byKey(const ValueKey('filter-chalk')));
    await _frames(t, 10);
    final results = ChalkIndex.of(exerciseCatalog).results(store.chalk);
    expect(results.length, greaterThan(2));
    final r = results[1], g = r.card, id = r.exercise.id;
    expect(find.text('${ChalkIndex.of(exerciseCatalog).search(store.chalk).length} MOVES · + ADDS TO TODAY'), findsOneWidget);
    await t.ensureVisible(find.byKey(ValueKey('chalk-result-$id')));
    await t.tap(find.byKey(ValueKey('chalk-result-$id')));
    await _frames(t, 20);
    expect(find.byKey(const ValueKey('chalk-results')), findsNothing); // the sheet closed
    expect(store.todayIds, isEmpty); // selected, not added (D81)
    expect(store.pickedCard, id);
    expect(find.byKey(ValueKey('exercise-${g.key}')), findsOneWidget); // on that card
    expect(find.byKey(const ValueKey('today-dot-0')), findsNothing);
    expect(find.byKey(const ValueKey('suggested-label')), findsNothing); // no label after the dots
    expect(find.text('SUGGESTED'), findsNothing);
    // Open again: that row is highlighted, no TODAY mark yet.
    await t.tap(find.byKey(const ValueKey('filter-chalk')));
    await _frames(t, 10);
    await t.ensureVisible(find.byKey(ValueKey('chalk-result-$id')));
    expect(find.byKey(ValueKey('chalk-result-on-$id')), findsOneWidget);
    expect(find.byKey(ValueKey('chalk-result-on-${results.first.exercise.id}')), findsNothing);
    expect(find.byKey(ValueKey('chalk-result-today-$id')), findsNothing);
    // The first set puts it in Today (D79): the row shows TODAY.
    store.addSet(id);
    await _frames(t, 4);
    expect(store.todayIds, [id]);
    expect(find.byKey(ValueKey('chalk-result-today-$id')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('COPY A PAST DAY: the first card of an empty Today; ◀ ▶ step days; COPY', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    t.view.padding = const FakeViewPadding(top: 110, bottom: 146);
    addTearDown(t.view.reset);
    final (seed, prefs) = await newStore();
    final a = _first(_cards(seed)[0]), b = _first(_cards(seed)[4]), c = _first(_cards(seed)[6]);
    seed.addSet(a); // 21 Nov: a
    now = DateTime(2026, 11, 22, 9);
    seed.addSet(b); // 22 Nov: b, c
    seed.addSet(c);
    now = DateTime(2026, 11, 23, 9); // today: empty
    final store = LogStore(prefs, clock: () => now);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    if (find.byKey(const ValueKey('intro-card')).evaluate().isNotEmpty) {
      await t.pump(const Duration(milliseconds: 1900)); // a tap would go through it: wait
      await _frames(t, 4);
    }
    expect(find.byKey(const ValueKey('copy-day-card')), findsOneWidget);
    expect(find.text('SUN 22 NOV'), findsOneWidget); // the newest first
    expect(find.text('COPY 2 CARDS'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('copy-older')));
    await _frames(t, 4);
    expect(find.text('SAT 21 NOV'), findsOneWidget);
    expect(find.text('COPY 1 CARD'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('copy-newer')));
    await _frames(t, 4);
    await t.tap(find.byKey(const ValueKey('copy-day-button')));
    await _frames(t, 20);
    expect(store.todayIds, [b, c]);
    expect(store.todaySession?.totalSets ?? 0, 0);
    expect(find.byKey(const ValueKey('copy-day-card')), findsNothing);
    expect(find.byKey(ValueKey('exercise-${_cards(seed)[4].key}')), findsOneWidget);
    expect(find.byKey(const ValueKey('today-dot-1')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  Future<LogStore> openApp(WidgetTester t, [void Function(LogStore store)? seed]) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    t.view.padding = const FakeViewPadding(top: 110, bottom: 146);
    addTearDown(t.view.reset);
    final (store, _) = await newStore();
    seed?.call(store);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    if (find.byKey(const ValueKey('intro-card')).evaluate().isNotEmpty) {
      await t.pump(const Duration(milliseconds: 1900)); // a tap would go through it: wait
      await _frames(t, 4);
    }
    return store;
  }

  testWidgets('an empty Today (D82): no catalog card, OPEN CHALK opens CHALK; no tag row', (t) async {
    final store = await openApp(t);
    expect(find.byKey(const ValueKey('today-empty-card')), findsOneWidget);
    expect(find.text('OPEN CHALK TO ADD EXERCISES'), findsOneWidget);
    expect(find.byKey(ValueKey('exercise-${_cards(store).first.key}')), findsNothing);
    expect(find.byKey(const ValueKey('world-object')), findsNothing); // nothing to add a set to
    // No floor band: the panel takes all the room under the world, like a
    // full card (at least the 240 px the layout keeps for it).
    expect(t.getRect(find.byKey(const ValueKey('exercise-part'))).height, greaterThanOrEqualTo(240));
    for (final k in ['filter-body', 'filter-favorites', 'class-label', 'workout-filters']) {
      expect(find.byKey(ValueKey(k)), findsNothing, reason: k);
    }
    // A swipe stays on it: it is the only card.
    await t.fling(find.byKey(const ValueKey('exercise-card')), const Offset(-300, 0), 1000);
    await _frames(t, 10);
    expect(find.byKey(const ValueKey('today-empty-card')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('today-open-chalk')));
    await _frames(t, 10);
    expect(find.byKey(const ValueKey('chalk-back-today')), findsOneWidget); // the CHALK sheet
    expect(t.takeException(), isNull);
  });

  testWidgets('"+ CHALK" by the dots opens CHALK (D82); "+ CRETĂ" in Romanian', (t) async {
    final store = await openApp(t, (s) => s.addToToday(_first(_cards(s)[0])));
    final button = find.byKey(const ValueKey('filter-chalk'));
    expect(find.descendant(of: button, matching: find.text('+ CHALK')), findsOneWidget);
    expect(t.getSize(button).height, greaterThanOrEqualTo(48));
    await t.tap(button);
    await _frames(t, 10);
    expect(find.byKey(const ValueKey('chalk-back-today')), findsOneWidget);
    expect(store.todayIds.length, 1);
    expect(I18n.parse(langFiles['ro']!)['chalk.add'], '+ CRETĂ');
    expect(t.takeException(), isNull);
  });

  testWidgets('Today shows only its cards: the swipe goes round them, no catalog after them', (t) async {
    late List<String> keys;
    final store = await openApp(t, (s) {
      keys = [_cards(s)[3].key, _cards(s)[8].key];
      for (final g in [_cards(s)[3], _cards(s)[8]]) {
        s.addToToday(_first(g));
      }
      s.selectExercise(_first(_cards(s)[3]));
    });
    for (final k in [keys[1], keys[0], keys[1]]) {
      await t.fling(find.byKey(const ValueKey('exercise-card')), const Offset(-300, 0), 1000);
      await _frames(t, 10);
      expect(find.byKey(ValueKey('exercise-$k')), findsOneWidget);
    }
    expect(store.carousel.length, 2);
    expect(find.byKey(const ValueKey('today-empty-card')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('two variations of one move: two cards; a chip changes only the card shown', (t) async {
    final g = bench(), x = g.variants[0].id, y = g.variants[1].id;
    final store = await openApp(t, (s) {
      s.addToToday(x);
      s.addToToday(y);
      s.selectExercise(x);
    });
    expect(find.byKey(const ValueKey('today-dot-1')), findsOneWidget);
    expect(find.byKey(ValueKey('exercise-${g.key}')), findsOneWidget);
    await t.fling(find.byKey(const ValueKey('exercise-card')), const Offset(-300, 0), 1000);
    await _frames(t, 10);
    expect(find.byKey(ValueKey('exercise-${g.key}#2')), findsOneWidget);
    expect(store.pickedCard, y);
    // A chip on the second card: only it changes.
    final angle = find.byKey(const ValueKey('mod-angle-Incline'));
    await t.ensureVisible(angle);
    await t.tap(angle);
    await _frames(t, 10);
    final now = store.todayIds;
    expect(now.first, x);
    expect(now.length, 2);
    expect(exerciseCatalog.byId[now[1]]!.mods['angle'], 'Incline');
    expect(store.pickedCard, now[1]);
    // The world adds the set to the card shown.
    await t.tap(find.byKey(const ValueKey('world-object')));
    await _frames(t, 70);
    expect((store.setsToday(x), store.setsToday(now[1])), (0, 1));
    expect(t.takeException(), isNull);
  });

  testWidgets('a selected exercise not in Today: a preview after Today (a line, no delete); the first set adds it', (t) async {
    late String a, g, gKey;
    final store = await openApp(t, (s) {
      a = _first(_cards(s)[0]);
      g = _first(_cards(s)[6]);
      gKey = _cards(s)[6].key;
      s.addToToday(a);
      s.selectExercise(g); // a CHALK row
    });
    expect(find.byKey(ValueKey('exercise-$gKey')), findsOneWidget);
    expect(find.byKey(const ValueKey('suggested-line')), findsOneWidget);
    expect(find.byKey(const ValueKey('today-remove')), findsNothing);
    await t.tap(find.byKey(const ValueKey('world-object')));
    await _frames(t, 70);
    if (find.byKey(const ValueKey('intro-card')).evaluate().isNotEmpty) {
      await t.pump(const Duration(milliseconds: 1900)); // a tap would go through it: wait
      await _frames(t, 4);
    }
    expect(store.todayIds, [a, g]);
    expect(find.byKey(ValueKey('exercise-$gKey')), findsOneWidget);
    expect(find.byKey(const ValueKey('suggested-line')), findsNothing);
    expect(find.byKey(const ValueKey('today-remove')), findsOneWidget);
    expect(find.byKey(const ValueKey('today-dot-1')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('delete (D82): no sets, straight out; with sets, a dialog first (KEEP keeps all, REMOVE takes the sets and XP)', (t) async {
    late String a, b, aKey;
    final store = await openApp(t, (s) {
      a = _first(_cards(s)[0]);
      aKey = _cards(s)[0].key;
      b = _first(_cards(s)[1]);
      s.addToToday(a);
      s.addToToday(b);
      s.selectExercise(b);
    });
    // b has no sets: no dialog.
    await t.tap(find.byKey(const ValueKey('today-remove')));
    await _frames(t, 10);
    expect(find.byKey(const ValueKey('today-remove-dialog')), findsNothing);
    expect(store.todayIds, [a]);
    expect(find.byKey(ValueKey('exercise-$aKey')), findsOneWidget);
    // a has 2 sets: the dialog asks.
    final xp0 = store.totalXp;
    store.addSet(a);
    store.addSet(a);
    await _frames(t, 4);
    // The card shows its set count (the world's badge only past the marks).
    expect(find.descendant(of: find.byKey(const ValueKey('card-set-count')), matching: find.text('2 SETS')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('today-remove')));
    await _frames(t, 10);
    expect(find.byKey(const ValueKey('today-remove-dialog')), findsOneWidget);
    expect(find.text('2 SETS GO TOO, WITH THEIR XP.'), findsOneWidget);
    // KEEP is the secondary button: readable night ink on sky, in both themes.
    final keep = find.byKey(const ValueKey('today-remove-cancel'));
    final keepText = t.widget<Text>(find.descendant(of: keep, matching: find.byType(Text)));
    final style = DefaultTextStyle.of(t.element(find.descendant(of: keep, matching: find.byType(Text)))).style.merge(keepText.style);
    final fill = (t.widget<AnimatedContainer>(find.descendant(of: keep, matching: find.byType(AnimatedContainer))).decoration! as BoxDecoration).color!;
    final l1 = fill.computeLuminance(), l2 = style.color!.computeLuminance();
    expect((max(l1, l2) + 0.05) / (min(l1, l2) + 0.05), greaterThan(4.5));
    await t.tap(find.byKey(const ValueKey('today-remove-cancel')));
    await _frames(t, 10);
    expect(store.todayIds, [a]);
    expect(store.setsToday(a), 2);
    await t.tap(find.byKey(const ValueKey('today-remove')));
    await _frames(t, 10);
    await t.tap(find.byKey(const ValueKey('today-remove-confirm')));
    await _frames(t, 10);
    expect(find.byKey(const ValueKey('today-remove-dialog')), findsNothing);
    expect(store.todayIds, isEmpty);
    expect(store.setsToday(a), 0);
    expect(store.totalXp, xp0);
    expect(find.byKey(const ValueKey('today-empty-card')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
