// TODAY (D79, D81): the lifter's list for one day. The first set, FORGE IT
// and COPY add a card; a CHALK row only selects it (D81); the carousel
// shows Today first, then the rest; the list ends with the day; COPY A
// PAST DAY copies cards, not sets.

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

  test('the carousel: Today first, once, then the rest in Suggested order; filters order only the rest', () async {
    final (store, _) = await newStore();
    final cards = store.cards.map((g) => g.key).toList();
    store.addToToday(cards[5]);
    store.addToToday(cards[2]);
    expect(store.carousel.map((g) => g.key), [cards[5], cards[2], for (final k in cards) if (k != cards[5] && k != cards[2]) k]);
    // A Today card outside the filters still shows; the rest is filtered.
    final chestCard = exerciseCatalog.groups.firstWhere((g) => g.variants.every((e) => e.muscle == 'chest') && cards.contains(g.key));
    store.addToToday(chestCard.key);
    store.setFilter(store.filter.withBody('legs'));
    final list = store.carousel;
    expect(list.where((g) => g.key == chestCard.key).length, 1);
    expect(list.indexWhere((g) => g.key == chestCard.key), lessThan(3));
    expect(list.skip(3).every((g) => g.variants.every((e) => bodyPartById('legs')!.muscles.contains(e.muscle))), isTrue);
    // A CHALK search: Today first, then the results.
    store.setChalk({'move.press', 'tool.barbell'});
    final search = ChalkIndex.of(exerciseCatalog).search(store.chalk).map((g) => g.key).toList();
    expect(store.carousel.take(3).map((g) => g.key), store.todayCards);
    expect(store.carousel.skip(3).map((g) => g.key), [for (final k in search) if (!store.todayCards.contains(k)) k]);
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
    final results = ChalkIndex.of(exerciseCatalog).search(store.chalk);
    expect(results.length, greaterThan(2));
    final g = results[1];
    expect(find.text('RESULTS · ${results.length}'), findsOneWidget);
    await t.ensureVisible(find.byKey(ValueKey('chalk-result-${g.key}')));
    await t.tap(find.byKey(ValueKey('chalk-result-${g.key}')));
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
    await t.ensureVisible(find.byKey(ValueKey('chalk-result-${g.key}')));
    expect(find.byKey(ValueKey('chalk-result-on-${g.key}')), findsOneWidget);
    expect(find.byKey(ValueKey('chalk-result-on-${results.first.key}')), findsNothing);
    expect(find.byKey(ValueKey('chalk-result-today-${g.key}')), findsNothing);
    // The first set puts it in Today (D79): the row shows TODAY.
    store.addSet(store.variantFor(g).id);
    await _frames(t, 4);
    expect(store.todayCards, [g.key]);
    expect(find.byKey(ValueKey('chalk-result-today-${g.key}')), findsOneWidget);
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
}
