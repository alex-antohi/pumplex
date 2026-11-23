import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gym_app/i18n.dart';
import 'package:gym_app/game/area_art.dart';
import 'package:gym_app/game/exercises.dart';
import 'package:gym_app/game/model.dart';
import 'package:gym_app/main.dart';
import 'package:gym_app/store.dart';
import 'package:gym_app/views/workout.dart';

/// A test clock the store reads. 21 Nov 2026 is a Saturday.
final _now = DateTime(2026, 11, 21, 10);

Profile _profile(String areaId) => Profile(
  character: const Character(sex: 'female', height: 80, muscle: 100, fat: 0),
  classId: 'paladin',
  difficultyId: 'sweat',
  areaId: areaId,
);

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 2340); // ~392 × 851 dp
  t.view.devicePixelRatio = 2.75;
  t.view.padding = const FakeViewPadding(top: 110, bottom: 146);
  addTearDown(t.view.reset);
}

Future<void> _frames(WidgetTester t, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// A set-up app on a phone, in [areaId], on the workout.
Future<LogStore> _openApp(WidgetTester t, {String areaId = 'gainsgard'}) async {
  _phone(t);
  SharedPreferences.setMockInitialValues({'profile_v1': jsonEncode(_profile(areaId).toJson())});
  final prefs = await SharedPreferences.getInstance();
  final store = LogStore(prefs, clock: () => _now);
  await t.pumpWidget(GymApp(store: store));
  await _frames(t);
  return store;
}

/// The workout view's box (the content area under the top bar).
Rect _view(WidgetTester t) => t.getRect(find.byType(WorkoutView));

/// Swipes the exercise carousel to the next card.
Future<void> _swipe(WidgetTester t) async {
  await t.fling(find.byKey(const ValueKey('exercise-card')), const Offset(-300, 0), 1000);
  await _frames(t, 10);
}

void main() {
  final langFiles = {for (final l in I18n.languages) l: File(I18n.asset(l)).readAsStringSync()};
  setUp(() => I18n.instance.useJson(langFiles));
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => exerciseCatalog = ExerciseCatalog.parse(File(ExerciseCatalog.asset).readAsStringSync()));

  for (final id in areaArt.keys) {
    testWidgets('workout layout ($id): the set-count badge sits by the marks, in the world, off the object', (t) async {
      final store = await _openApp(t, areaId: id);
      final art = areaArt[id]!;
      final first = store.variantFor(store.cards.first).id;
      for (var i = 0; i < art.markPositions.length + 3; i++) {
        store.addSet(first);
      }
      await _frames(t, 10);
      final badge = find.byKey(const ValueKey('scene-count'));
      if (art.ledRect != null) {
        expect(badge, findsNothing); // the arcade has its own LED counter
        return;
      }
      expect(badge, findsOneWidget);
      final view = _view(t);
      final (scene0, scale) = workoutLayout(view.size, 146 / 2.75);
      final scene = scene0.shift(view.topLeft);
      final r = t.getRect(badge);
      // Fully in the screen and above the exercise part.
      expect(r.left, greaterThanOrEqualTo(view.left));
      expect(r.right, lessThanOrEqualTo(view.right));
      expect(r.top, greaterThanOrEqualTo(view.top));
      expect(r.bottom, lessThanOrEqualTo(t.getRect(find.byKey(const ValueKey('exercise-part'))).top));
      // Readable.
      expect(r.height, greaterThanOrEqualTo(16));
      // Off the object and the marks.
      final s = scale.toDouble();
      final hit = Rect.fromLTWH(
        scene.left + art.hitBox.left * s,
        scene.top + art.hitBox.top * s,
        art.hitBox.width * s,
        art.hitBox.height * s,
      );
      final marks = markBox(art, scene, scale);
      expect(r.overlaps(hit), isFalse, reason: 'covers the object');
      expect(r.overlaps(marks), isFalse, reason: 'covers the marks');
      // Near the marks: within 40 px of their box.
      final gapX = max(0.0, max(marks.left - r.right, r.left - marks.right));
      final gapY = max(0.0, max(marks.top - r.bottom, r.top - marks.bottom));
      expect(max(gapX, gapY), lessThanOrEqualTo(40));
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('workout layout: the exercise part is as tall as its content, counter at its bottom; the scene stays put', (t) async {
    final store = await _openApp(t);
    final view = _view(t);
    final inset = 146 / 2.75;
    final (scene, _) = workoutLayout(view.size, inset);
    // The lifter's place is where the scene is drawn.
    expect(workoutStage(view.size, inset).shift(view.topLeft).top, greaterThanOrEqualTo(scene.top + view.top));
    expect(scene.shift(view.topLeft).contains(workoutArena(view.size, inset).shift(view.topLeft).center), isTrue);
    final object = t.getRect(find.byKey(const ValueKey('world-object')));
    for (var i = 0; i < 8 && i < store.cards.length; i++) {
      final part = t.getRect(find.byKey(const ValueKey('exercise-part')));
      final counter = t.getRect(find.byKey(const ValueKey('exercise-counter')));
      final star = t.getRect(find.byKey(const ValueKey('favorite-star')));
      final filters = t.getRect(find.byKey(const ValueKey('workout-filters')));
      // At the bottom of the view, under the scene.
      expect(part.bottom, moreOrLessEquals(view.bottom));
      expect(part.top, greaterThanOrEqualTo(scene.bottom + view.top - 0.01));
      // The counter at the bottom, just above the navigation bar.
      expect(view.bottom - inset - counter.bottom, inInclusiveRange(0, 12));
      // No dead band: the part starts right above the tags.
      expect(filters.top - part.top, lessThan(20));
      expect(star.top, greaterThan(filters.bottom));
      // The scene does not move.
      expect(t.getRect(find.byKey(const ValueKey('world-object'))), object);
      await _swipe(t);
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('workout layout: a card taller than the room is cut off cleanly', (t) async {
    _phone(t);
    t.view.physicalSize = const Size(1080, 1500); // a short screen
    final store = await _openAppKeepView(t);
    for (var i = 0; i < 6 && i < store.cards.length; i++) {
      expect(t.takeException(), isNull);
      final part = t.getRect(find.byKey(const ValueKey('exercise-part')));
      final (scene, _) = workoutLayout(_view(t).size, 146 / 2.75);
      expect(part.top, greaterThanOrEqualTo(scene.bottom + _view(t).top - 0.01));
      await _swipe(t);
    }
    expect(t.takeException(), isNull);
  });
}

/// Like [_openApp] but keeps the view size already set.
Future<LogStore> _openAppKeepView(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({'profile_v1': jsonEncode(_profile('gainsgard').toJson())});
  final prefs = await SharedPreferences.getInstance();
  final store = LogStore(prefs, clock: () => _now);
  await t.pumpWidget(GymApp(store: store));
  await _frames(t);
  return store;
}
