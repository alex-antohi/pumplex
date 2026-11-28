import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gym_app/i18n.dart';
import 'package:gym_app/game/exercises.dart';
import 'package:gym_app/game/model.dart';
import 'package:gym_app/main.dart';
import 'package:gym_app/store.dart';
import 'package:gym_app/views/area_scene.dart';
import 'package:gym_app/views/sprite.dart';

const _profile = Profile(
  character: Character(sex: 'female', height: 50, muscle: 100, fat: 0),
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

/// A real phone: 411 x 903 dp, DPR 2.625.
void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(411 * 2.625, 903 * 2.625);
  t.view.devicePixelRatio = 2.625;
  t.view.padding = const FakeViewPadding(top: 80, bottom: 63);
  addTearDown(t.view.reset);
}

Future<void> _frames(WidgetTester t, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// The lifter on the area card is as big as the lifter spot of the scene
/// (52 x 64 art px at the scene scale) and its feet stand where the scene
/// puts them.
void _checkLifterMatchesScene(WidgetTester t, String key, Finder sprite) {
  final inCard = find.descendant(of: find.byKey(const ValueKey('area-card')), matching: find.byType(AreaScene));
  final sceneWidget = t.widget<AreaScene>(inCard);
  final scale = sceneWidget.scale.toDouble();
  final scene = t.getRect(inCard);
  final spot = sceneLifterRect(sceneWidget.art, scene, scale);
  expect(sprite, findsOneWidget, reason: key);
  final box = t.getRect(sprite);
  // The sprite the player sees.
  final drawn = t.getRect(find.descendant(of: sprite, matching: find.byKey(const ValueKey('character-sprite'))));
  // The box is the lifter spot of the scene.
  expect(box.left, closeTo(spot.left, 1), reason: '$key: box left');
  expect(box.bottom, closeTo(spot.bottom, 1), reason: '$key: box bottom');
  // The sprite is a 52 px wide body cell at the scene scale, feet on the spot.
  expect(drawn.width, closeTo(52 * scale, 1), reason: '$key: lifter width');
  expect(drawn.bottom, closeTo(spot.bottom, 1), reason: '$key: feet');
  expect(drawn.center.dx, closeTo(spot.center.dx, 1), reason: '$key: centre');
}

void main() {
  final langFiles = {for (final l in I18n.languages) l: File(I18n.asset(l)).readAsStringSync()};
  setUp(() => I18n.instance.useJson(langFiles));
  setUpAll(() {
    exerciseCatalog = ExerciseCatalog.parse(File(ExerciseCatalog.asset).readAsStringSync());
  });

  testWidgets('lifter editor: the lifter matches the area scene', (t) async {
    _phone(t);
    final store = await _store(setUp: true);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    await t.tap(find.byKey(const ValueKey('workout-character')));
    await _frames(t, 20);
    for (var i = 0; i < 2; i++) {
      await t.fling(find.byKey(const ValueKey('lifter-editor')), const Offset(0, -300), 1000);
      await _frames(t, 20);
    }
    _checkLifterMatchesScene(t, 'editor', find.byKey(const ValueKey('edit-lifter')));
    expect(t.takeException(), isNull);
  });

  testWidgets('first setup: the lifter matches the area scene', (t) async {
    _phone(t);
    final store = await _store();
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    await t.tap(find.text('NEXT: CLASS'));
    await _frames(t, 30);
    await t.tap(find.textContaining('NEXT'));
    await _frames(t, 30);
    _checkLifterMatchesScene(t, 'setup', find.byType(CharacterSprite));
    expect(t.takeException(), isNull);
  });
}
