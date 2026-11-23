// The workout's CLASS and DIFFICULTY filter tags open the selection cards of
// the class screen (the class carousel card, the difficulty card), and they
// change the filter only, never the profile.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gym_app/i18n.dart';
import 'package:gym_app/game/content.dart';
import 'package:gym_app/game/exercises.dart';
import 'package:gym_app/game/model.dart';
import 'package:gym_app/main.dart';
import 'package:gym_app/store.dart';
import 'package:gym_app/views/sprite.dart';

const _profile = Profile(
  character: Character(sex: 'female', height: 80, muscle: 100, fat: 0),
  classId: 'paladin',
  difficultyId: 'sweat',
  areaId: 'gainsgard',
);
const _d = 2; // difficulty index of 'sweat'

Future<void> _frames(WidgetTester t, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// A set-up app on a phone, on the workout.
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

Finder _inTag(String tag, String text) =>
    find.descendant(of: find.byKey(ValueKey(tag)), matching: find.text(text));

void main() {
  final langFiles = {for (final l in I18n.languages) l: File(I18n.asset(l)).readAsStringSync()};
  setUp(() => I18n.instance.useJson(langFiles));
  setUpAll(() {
    exerciseCatalog = ExerciseCatalog.parse(File(ExerciseCatalog.asset).readAsStringSync());
  });

  testWidgets('CLASS tag: the class card; swipe and dots change the filter, not the profile', (t) async {
    final store = await _openApp(t);
    final ids = [for (final c in gameClasses) c.id];
    final at = ids.indexOf('paladin');
    String next(int d) => ids[(at + d) % ids.length];

    await t.tap(find.byKey(const ValueKey('filter-class')));
    await _frames(t, 10);
    final card = find.byKey(const ValueKey('class-card'));
    expect(card, findsOneWidget);
    expect(find.byKey(const ValueKey('difficulty-card')), findsNothing);
    expect(find.descendant(of: card, matching: find.text(classById('paladin').name.toUpperCase())), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text(classById('paladin').equipment.toUpperCase())), findsOneWidget);
    for (final id in ids) {
      expect(find.byKey(ValueKey('class-dot-$id')), findsOneWidget);
    }
    // Your lifter, in the picked class's gear, inside the card.
    final lifter = find.byKey(const ValueKey('filter-lifter'));
    expect(t.widget<CharacterSprite>(lifter).classId, 'paladin');
    final c = t.getRect(card);
    final l = t.getRect(lifter);
    expect(c.contains(l.topLeft) && c.contains(l.bottomRight), isTrue);

    // Swipe left: the next class.
    await t.fling(card, const Offset(-300, 0), 1000);
    await _frames(t, 10);
    expect(store.filter.classId, next(1));
    expect(t.widget<CharacterSprite>(lifter).classId, next(1));
    expect(store.profile!.classId, 'paladin');
    // Swipe right twice: round the other way.
    await t.fling(card, const Offset(300, 0), 1000);
    await _frames(t, 10);
    await t.fling(card, const Offset(300, 0), 1000);
    await _frames(t, 10);
    expect(store.filter.classId, next(-1));
    // A dot jumps straight there.
    await t.tap(find.byKey(ValueKey('class-dot-${next(2)}')));
    await _frames(t, 10);
    expect(store.filter.classId, next(2));
    expect(store.profile!.classId, 'paladin');
    // RESET TO MINE: your class again.
    await t.tap(find.byKey(const ValueKey('filter-reset')));
    await _frames(t, 10);
    expect(store.filter.classId, 'paladin');
    // Pick one and SHOW N EXERCISES closes the sheet; the tag shows it.
    await t.tap(find.byKey(ValueKey('class-dot-${next(1)}')));
    await _frames(t, 10);
    await t.tap(find.byKey(const ValueKey('filter-show')));
    await _frames(t, 20);
    expect(card, findsNothing);
    expect(_inTag('filter-class', classById(next(1)).name.toUpperCase()), findsOneWidget);
    expect(store.profile!.classId, 'paladin');
    expect(t.takeException(), isNull);
  });

  testWidgets('DIFFICULTY tag: the difficulty card; the slider changes the filter, not the profile', (t) async {
    final store = await _openApp(t);
    await t.tap(find.byKey(const ValueKey('filter-difficulty')));
    await _frames(t, 10);
    expect(find.byKey(const ValueKey('difficulty-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('class-card')), findsNothing);
    final label = t.getRect(find.byKey(const ValueKey('value-DIFFICULTY')));
    final line = t.getRect(find.byKey(const ValueKey('difficulty-line')));
    final slider = find.byKey(const ValueKey('slider-DIFFICULTY'));
    expect(label.bottom, lessThanOrEqualTo(line.top));
    expect(line.bottom, lessThanOrEqualTo(t.getRect(slider).top));
    expect(find.text(difficulties[_d].line), findsOneWidget);

    // Drag the slider to the far right: the hardest mode.
    await t.drag(slider, const Offset(400, 0));
    await _frames(t, 10);
    final last = difficulties.length - 1;
    expect(store.filter.difficulty, last);
    expect(find.text(difficulties[last].line), findsOneWidget);
    expect(_inTag('difficulty-card', difficulties[last].name.toUpperCase()), findsOneWidget);
    expect(store.profile!.difficultyId, 'sweat');
    // And to the far left: the easiest.
    await t.drag(slider, const Offset(-400, 0));
    await _frames(t, 10);
    expect(store.filter.difficulty, 0);
    // RESET TO MINE: your mode, only this tag.
    await t.tap(find.byKey(const ValueKey('filter-reset')));
    await _frames(t, 10);
    expect(store.filter.difficulty, _d);
    t.widget<Slider>(slider).onChanged!(4);
    await _frames(t, 4);
    await t.tap(find.byKey(const ValueKey('filter-show')));
    await _frames(t, 20);
    expect(find.byKey(const ValueKey('difficulty-card')), findsNothing);
    expect(_inTag('filter-difficulty', difficulties[4].name.toUpperCase()), findsOneWidget);
    expect(store.profile!.difficultyId, 'sweat');
    expect(t.takeException(), isNull);
  });

  testWidgets('BODY PART tag keeps its chips', (t) async {
    await _openApp(t);
    await t.tap(find.byKey(const ValueKey('filter-body')));
    await _frames(t, 10);
    expect(find.byKey(const ValueKey('chip-body-all')), findsOneWidget);
    expect(find.byKey(const ValueKey('class-card')), findsNothing);
    expect(find.byKey(const ValueKey('difficulty-card')), findsNothing);
    expect(find.byKey(const ValueKey('filter-reset')), findsOneWidget);
    expect(find.byKey(const ValueKey('filter-show')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
