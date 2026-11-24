// TODAY (D79, D81, D82): the lifter's list for one day. The first set,
// FORGE IT and COPY add a card; a CHALK row only selects it (D81); the
// carousel shows only Today, plus a selected card as a preview (D82); the
// delete button removes a card and its sets; the list ends with the day;
// COPY A PAST DAY copies cards, not sets.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gym_app/i18n.dart';
import 'package:gym_app/game/chalk.dart';
import 'package:gym_app/game/exercises.dart';
import 'package:gym_app/game/model.dart';
import 'package:gym_app/main.dart';
import 'package:gym_app/store.dart';

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

  test('the first set on a card adds it; a CHALK row only selects; one card once; kept on the phone', () async {
    final (store, prefs) = await newStore();
    expect(store.todayCards, isEmpty);
    final a = store.cards[3], b = store.cards[7], c = store.cards[9];
    store.addSet(store.variantFor(a).id);
    store.addSet(store.variantFor(a).id);
    expect(store.todayCards, [a.key]);
    store.selectCard(c.key); // a CHALK row: selected, not in Today (D81)
    expect(store.pickedCard, c.key);
    expect(store.todayCards, [a.key]);
    store.addToToday(b.key);
    store.addToToday(a.key); // already there
    expect(store.todayCards, [a.key, b.key]);
    expect(store.pickedCard, a.key);
    // Taking the sets back does not drop the card (no remove gesture).
    store.removeSet(store.variantFor(a).id);
    store.removeSet(store.variantFor(a).id);
    expect(store.todayCards, [a.key, b.key]);
    // Saved with its day.
    expect(jsonDecode(prefs.getString(LogStore.todayKey)!), {'date': '2026-11-21', 'cards': [a.key, b.key]});
    final again = LogStore(prefs, clock: () => now);
    expect(again.todayCards, [a.key, b.key]);
  });

  test('FORGE IT adds the forged move to Today', () async {
    final (store, _) = await newStore();
    final move = store.forge({'tool.kettlebell', 'move.pulldown'}, 'lats', null);
    expect(store.todayCards, [move.id]);
    expect(store.carousel.first.key, move.id);
  });

  test('the carousel (D82): only the Today cards, with all their exercises; no catalog, filters or search after them', () async {
    final (store, _) = await newStore();
    expect(store.carousel, isEmpty);
    final cards = store.cards.map((g) => g.key).toList();
    store.addToToday(cards[5]);
    store.addToToday(cards[2]);
    expect(store.carousel.map((g) => g.key), [cards[5], cards[2]]);
    // Old saved filters and a CHALK search change nothing.
    store.setFilter(store.filter.withBody('legs'));
    store.setChalk({'move.press', 'tool.barbell'});
    expect(store.carousel.map((g) => g.key), [cards[5], cards[2]]);
    // A card keeps the exercises of your class and mode, not of the body filter.
    final mine = store.defaultFilter.apply(exerciseCatalog, store.favorites).firstWhere((g) => g.key == cards[5]);
    expect(store.carousel.first.variants.map((e) => e.id), mine.variants.map((e) => e.id));
  });

  test('a CHALK row on a card not in Today (D82): a preview at the end until the carousel leaves it; its first set adds it', () async {
    final (store, _) = await newStore();
    final cards = store.cards.map((g) => g.key).toList();
    store.addToToday(cards[0]);
    store.addToToday(cards[1]);
    store.selectCard(cards[7]); // the CHALK row
    expect(store.todayCards, [cards[0], cards[1]]);
    expect(store.previewCard, cards[7]);
    expect(store.carousel.map((g) => g.key), [cards[0], cards[1], cards[7]]);
    // Swiping away drops it.
    store.setPickedCard(cards[1]);
    expect(store.previewCard, isNull);
    expect(store.carousel.map((g) => g.key), [cards[0], cards[1]]);
    // Another row, then a set: it joins Today, at the end.
    store.selectCard(cards[9]);
    store.addSet(store.variantFor(exerciseCatalog.byKey[cards[9]]!).id);
    expect(store.previewCard, isNull);
    expect(store.todayCards, [cards[0], cards[1], cards[9]]);
    expect(store.carousel.map((g) => g.key), [cards[0], cards[1], cards[9]]);
    // A row on a Today card is no preview; BACK TO TODAY drops a preview.
    store.selectCard(cards[0]);
    expect(store.previewCard, isNull);
    store.selectCard(cards[4]);
    store.backToToday();
    expect(store.previewCard, isNull);
  });

  test('delete (D82): the card leaves Today; with sets, today\'s sets of it and their XP go too', () async {
    final (store, prefs) = await newStore();
    final cards = store.cards.map((g) => g.key).toList();
    final a = cards[0], b = cards[1], c = cards[2];
    store.addToToday(a);
    store.addToToday(b);
    store.addToToday(c);
    // No sets: straight out; the carousel goes to the card in its place.
    store.selectCard(b);
    store.removeFromToday(b);
    expect(store.todayCards, [a, c]);
    expect(store.pickedCard, c);
    // With sets: they go, and so does their XP. Other cards keep theirs.
    store.addSet(store.variantFor(exerciseCatalog.byKey[a]!).id);
    final xpA = store.totalXp;
    store.addSet(store.variantFor(exerciseCatalog.byKey[c]!).id);
    store.addSet(store.variantFor(exerciseCatalog.byKey[c]!).id);
    expect(store.totalXp, greaterThan(xpA));
    store.removeFromToday(c);
    expect(store.todayCards, [a]);
    expect(store.groupSetsToday(c), 0);
    expect(store.groupSetsToday(a), 1);
    expect(store.totalXp, xpA);
    expect(store.pickedCard, a); // the one before
    // Saved: a new app has the same Today.
    expect(LogStore(prefs, clock: () => now).todayCards, [a]);
    // The last card: Today is empty, no XP from today, nothing picked.
    store.removeFromToday(a);
    expect(store.todayCards, isEmpty);
    expect(store.todaySession?.totalSets ?? 0, 0);
    expect(store.xpEvents.where((e) => e.ref == '2026-11-21'), isEmpty);
    expect(store.pickedCard, isNull);
  });

  test('the day ends: a new day starts empty, 0-set cards do not stay, COPY copies cards and not sets', () async {
    final (store, prefs) = await newStore();
    final a = store.cards[0], b = store.cards[1], c = store.cards[2];
    store.addSet(store.variantFor(a).id);
    store.addToToday(b.key); // 0 sets
    store.addSet(store.variantFor(c).id);
    store.addSet(store.variantFor(c).id);
    expect(store.todayCards, [a.key, b.key, c.key]);
    now = DateTime(2026, 11, 22, 7); // the next day
    expect(store.todayCards, isEmpty);
    expect(LogStore(prefs, clock: () => now).todayCards, isEmpty);
    expect(store.pastDays, ['2026-11-21']);
    expect(store.dayMoves('2026-11-21').map((e) => exerciseCatalog.groupKeyOf(e.id)), [a.key, c.key]); // b had no sets
    store.copyDay('2026-11-21');
    expect(store.todayCards, [a.key, c.key]);
    expect(store.groupSetsToday(a.key) + store.groupSetsToday(c.key), 0); // no sets copied
    expect(store.sessions['2026-11-21']!.totalSets, 3); // the past day is untouched
    expect(store.carousel.take(2).map((g) => g.key), [a.key, c.key]);
  });

  testWidgets('a CHALK result row selects the card (not in Today); the sheet closes on it; highlighted; TODAY mark after a set', (t) async {
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
    expect(find.text('RESULTS · ${results.length}'), findsOneWidget);
    await t.ensureVisible(find.byKey(ValueKey('chalk-result-$id')));
    await t.tap(find.byKey(ValueKey('chalk-result-$id')));
    await _frames(t, 20);
    expect(find.byKey(const ValueKey('chalk-results')), findsNothing); // the sheet closed
    expect(store.todayCards, isEmpty); // selected, not added (D81)
    expect(store.pickedCard, g.key);
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
    store.addSet(store.variantFor(g).id);
    await _frames(t, 4);
    expect(store.todayCards, [g.key]);
    expect(find.byKey(ValueKey('chalk-result-today-$id')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('COPY A PAST DAY: the first card of an empty Today; ◀ ▶ step days; COPY', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    t.view.padding = const FakeViewPadding(top: 110, bottom: 146);
    addTearDown(t.view.reset);
    final (seed, prefs) = await newStore();
    final a = seed.cards[0], b = seed.cards[4], c = seed.cards[6];
    seed.addSet(seed.variantFor(a).id); // 21 Nov: a
    now = DateTime(2026, 11, 22, 9);
    seed.addSet(seed.variantFor(b).id); // 22 Nov: b, c
    seed.addSet(seed.variantFor(c).id);
    now = DateTime(2026, 11, 23, 9); // today: empty
    final store = LogStore(prefs, clock: () => now);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    if (find.byKey(const ValueKey('intro-card')).evaluate().isNotEmpty) {
      await t.tap(find.byKey(const ValueKey('intro-card')));
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
    expect(store.todayCards, [b.key, c.key]);
    expect(store.todaySession?.totalSets ?? 0, 0);
    expect(find.byKey(const ValueKey('copy-day-card')), findsNothing);
    expect(find.byKey(ValueKey('exercise-${b.key}')), findsOneWidget);
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
      await t.tap(find.byKey(const ValueKey('intro-card')));
      await _frames(t, 4);
    }
    return store;
  }

  testWidgets('an empty Today (D82): no catalog card, OPEN CHALK opens CHALK; no BODY PART or star tags', (t) async {
    final store = await openApp(t);
    expect(find.byKey(const ValueKey('today-empty-card')), findsOneWidget);
    expect(find.text('OPEN CHALK TO ADD EXERCISES'), findsOneWidget);
    expect(find.byKey(ValueKey('exercise-${store.cards.first.key}')), findsNothing);
    expect(find.byKey(const ValueKey('world-object')), findsNothing); // nothing to add a set to
    expect(find.byKey(const ValueKey('filter-body')), findsNothing);
    expect(find.byKey(const ValueKey('filter-favorites')), findsNothing);
    // A swipe stays on it: it is the only card.
    await t.fling(find.byKey(const ValueKey('exercise-card')), const Offset(-300, 0), 1000);
    await _frames(t, 10);
    expect(find.byKey(const ValueKey('today-empty-card')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('today-open-chalk')));
    await _frames(t, 10);
    expect(find.byKey(const ValueKey('chalk-back-today')), findsOneWidget); // the CHALK sheet
    expect(t.takeException(), isNull);
  });

  testWidgets('Today shows only its cards: the swipe goes round them, no catalog after them', (t) async {
    late List<String> keys;
    final store = await openApp(t, (s) {
      keys = [s.cards[3].key, s.cards[8].key];
      keys.forEach(s.addToToday);
      s.selectCard(keys.first);
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

  testWidgets('a selected card not in Today: a preview after Today (a line, no delete); the first set adds it', (t) async {
    late String a, g;
    final store = await openApp(t, (s) {
      a = s.cards[0].key;
      g = s.cards[6].key;
      s.addToToday(a);
      s.selectCard(g); // a CHALK row
    });
    expect(find.byKey(ValueKey('exercise-$g')), findsOneWidget);
    expect(find.byKey(const ValueKey('suggested-line')), findsOneWidget);
    expect(find.byKey(const ValueKey('today-remove')), findsNothing);
    await t.tap(find.byKey(const ValueKey('world-object')));
    await _frames(t, 70);
    if (find.byKey(const ValueKey('intro-card')).evaluate().isNotEmpty) {
      await t.tap(find.byKey(const ValueKey('intro-card')));
      await _frames(t, 4);
    }
    expect(store.todayCards, [a, g]);
    expect(find.byKey(ValueKey('exercise-$g')), findsOneWidget);
    expect(find.byKey(const ValueKey('suggested-line')), findsNothing);
    expect(find.byKey(const ValueKey('today-remove')), findsOneWidget);
    expect(find.byKey(const ValueKey('today-dot-1')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('delete (D82): no sets, straight out; with sets, a dialog first (KEEP keeps all, REMOVE takes the sets and XP)', (t) async {
    late String a, b;
    final store = await openApp(t, (s) {
      a = s.cards[0].key;
      b = s.cards[1].key;
      s.addToToday(a);
      s.addToToday(b);
      s.selectCard(b);
    });
    // b has no sets: no dialog.
    await t.tap(find.byKey(const ValueKey('today-remove')));
    await _frames(t, 10);
    expect(find.byKey(const ValueKey('today-remove-dialog')), findsNothing);
    expect(store.todayCards, [a]);
    expect(find.byKey(ValueKey('exercise-$a')), findsOneWidget);
    // a has 2 sets: the dialog asks.
    final id = store.variantFor(exerciseCatalog.byKey[a]!).id;
    final xp0 = store.totalXp;
    store.addSet(id);
    store.addSet(id);
    await _frames(t, 4);
    await t.tap(find.byKey(const ValueKey('today-remove')));
    await _frames(t, 10);
    expect(find.byKey(const ValueKey('today-remove-dialog')), findsOneWidget);
    expect(find.text('2 SETS GO TOO, WITH THEIR XP.'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('today-remove-cancel')));
    await _frames(t, 10);
    expect(store.todayCards, [a]);
    expect(store.groupSetsToday(a), 2);
    await t.tap(find.byKey(const ValueKey('today-remove')));
    await _frames(t, 10);
    await t.tap(find.byKey(const ValueKey('today-remove-confirm')));
    await _frames(t, 10);
    expect(find.byKey(const ValueKey('today-remove-dialog')), findsNothing);
    expect(store.todayCards, isEmpty);
    expect(store.groupSetsToday(a), 0);
    expect(store.totalXp, xp0);
    expect(find.byKey(const ValueKey('today-empty-card')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
