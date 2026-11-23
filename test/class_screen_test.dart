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

Future<LogStore> _store({bool setUp = false}) async {
  SharedPreferences.setMockInitialValues({
    if (setUp) 'profile_v1': jsonEncode(_profile.toJson()),
  });
  final prefs = await SharedPreferences.getInstance();
  return LogStore(prefs, clock: () => DateTime(2026, 11, 21, 10));
}

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 2.75;
  t.view.padding = const FakeViewPadding(top: 110, bottom: 146);
  addTearDown(t.view.reset);
}

Future<void> _frames(WidgetTester t, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// The class screen: the difficulty card on top (label, line, slider), the
/// class card under it with the lifter inside, the dots under the card.
void _checkClassScreen(WidgetTester t) {
  final diff = t.getRect(find.byKey(const ValueKey('difficulty-card')));
  final card = t.getRect(find.byKey(const ValueKey('class-card')));
  expect(diff.bottom, lessThanOrEqualTo(card.top));
  final label = t.getRect(find.byKey(const ValueKey('value-DIFFICULTY')));
  final line = t.getRect(find.byKey(const ValueKey('difficulty-line')));
  final slider = t.getRect(find.byKey(const ValueKey('slider-DIFFICULTY')));
  expect(label.bottom, lessThanOrEqualTo(line.top));
  expect(line.bottom, lessThanOrEqualTo(slider.top));
  expect(slider.bottom, lessThanOrEqualTo(diff.bottom));
  final dot = t.getRect(find.byKey(const ValueKey('class-dot-paladin')));
  expect(dot.top, greaterThanOrEqualTo(card.bottom));
  // The lifter the shell draws stands inside the card.
  final lifters = t.widgetList(find.byType(CharacterSprite)).map((w) => t.getRect(find.byWidget(w)));
  expect(lifters.any((r) => card.inflate(1).contains(r.topLeft) && card.inflate(1).contains(r.bottomRight)), isTrue,
      reason: '$lifters in $card');
  // Name and equipment only: no loadout, no tags.
  final cls = classById('paladin');
  expect(find.text(cls.equipment.toUpperCase()), findsOneWidget);
  expect(find.text(cls.loadout), findsNothing);
  for (final tag in cls.tags) {
    expect(find.descendant(of: find.byKey(const ValueKey('class-card')), matching: find.text(tag.toUpperCase())), findsNothing);
  }
}

void main() {
  final langFiles = {for (final l in I18n.languages) l: File(I18n.asset(l)).readAsStringSync()};
  setUp(() => I18n.instance.useJson(langFiles));
  setUpAll(() {
    exerciseCatalog = ExerciseCatalog.parse(File(ExerciseCatalog.asset).readAsStringSync());
  });

  testWidgets('first setup: difficulty on top, then the class card, then the dots', (t) async {
    _phone(t);
    final store = await _store();
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    await t.tap(find.text('NEXT: CLASS'));
    await _frames(t, 30);
    await t.tap(find.byKey(const ValueKey('class-dot-paladin')));
    await _frames(t, 10);
    _checkClassScreen(t);
    // The carousel still swipes.
    await t.fling(find.byKey(const ValueKey('class-card')), const Offset(-300, 0), 1000);
    await _frames(t, 10);
    expect(find.text(classById('cablemancer').name.toUpperCase()), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('lifter editor: the class screen fits under the tile row', (t) async {
    _phone(t);
    final store = await _store(setUp: true);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    await t.tap(find.byKey(const ValueKey('workout-character')));
    await _frames(t, 20);
    await t.fling(find.byKey(const ValueKey('lifter-editor')), const Offset(0, -300), 1000);
    await _frames(t, 20);
    _checkClassScreen(t);
    expect(t.takeException(), isNull);
  });
}
