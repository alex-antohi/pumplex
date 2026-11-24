// MINIMAL weight and reps (D84, docs/moodboard/today-logging/MINIMAL.md):
// a strip after a set on a weighted move; values carry over (marked
// carried), steppers and the keypad mark them typed; the trail edits an
// older set; the undo takes the set and its values; XP never changes.

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
  Future<(LogStore, SharedPreferences)> newStore() async {
    now = DateTime(2026, 11, 21, 10);
    SharedPreferences.setMockInitialValues({'profile_v1': jsonEncode(_profile.toJson())});
    final prefs = await SharedPreferences.getInstance();
    return (LogStore(prefs, clock: () => now), prefs);
  }

  String firstWith(String equipment) =>
      exerciseCatalog.all.firstWhere((e) => e.equipment == equipment && e.category != 'cardio').id;

  test('weighted moves only; values carry (carried), typed when set; undo; XP unchanged; kept', () async {
    final (store, prefs) = await newStore();
    final db = firstWith('dumbbell'), body = firstWith('body only');
    expect(store.isWeighted(db), isTrue);
    expect(store.isWeighted(firstWith('barbell')), isTrue);
    expect(store.isWeighted(body), isFalse);
    expect(store.isWeighted(firstWith('bands')), isFalse);
    // No history: empty values.
    store.addSet(db);
    expect(store.setLogs(db), [const SetLog()]);
    store.setSetLog(db, 0, kg: 22, reps: 10);
    expect(store.setLogs(db).single, const SetLog(kg: 22, reps: 10, kgTyped: true, repsTyped: true));
    // A new set carries the values, marked carried.
    store.addSet(db);
    expect(store.setLogs(db)[1], const SetLog(kg: 22, reps: 10));
    store.setSetLog(db, 1, kg: 24);
    expect(store.setLogs(db)[1], const SetLog(kg: 24, reps: 10, kgTyped: true));
    store.addSet(db);
    expect(store.setLogs(db)[2], const SetLog(kg: 24, reps: 10));
    // An older set can be fixed.
    store.setSetLog(db, 0, reps: 12);
    expect(store.setLogs(db)[0].reps, 12);
    // XP is the same with and without weight and reps.
    final xp = store.xpToday(db);
    store.setSetLog(db, 2, kg: 200, reps: 1);
    expect(store.xpToday(db), xp);
    // The undo takes the last set and its values.
    store.removeSet(db);
    expect(store.setLogs(db).length, 2);
    store.addSet(db);
    expect(store.setLogs(db)[2], const SetLog(kg: 24, reps: 10)); // carried from set 2, not the undone one
    // A bodyweight move has no log.
    store.addSet(body);
    expect(store.todaySession!.exercises.firstWhere((e) => e.exerciseId == body).log, isEmpty);
    // The next day starts from the last day's last set.
    now = now.add(const Duration(days: 1));
    store.addSet(db);
    expect(store.setLogs(db).single, const SetLog(kg: 24, reps: 10));
    // Kept on the phone, and in the session JSON.
    final again = LogStore(prefs, clock: () => now);
    expect(again.setLogs(db).single, const SetLog(kg: 24, reps: 10));
    expect(SessionExercise.fromJson({'exerciseId': db, 'sets': 2}).log, isEmpty); // old sets stay valid
  });

  testWidgets('the strip: there from the start (D85), edits the newest, steppers, hold by 5, keypad, trail', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    t.view.padding = const FakeViewPadding(top: 110, bottom: 146);
    addTearDown(t.view.reset);
    final (store, _) = await newStore();
    final db = firstWith('dumbbell');
    store.addToToday(db);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    // There before the first set (D85): it sets the coming set 1.
    expect(find.byKey(const ValueKey('log-strip')), findsOneWidget);
    expect(find.text('SET 1'), findsOneWidget);
    expect(find.text('OPTIONAL'), findsNothing); // no text in the corner (D85)
    await t.tap(find.byKey(const ValueKey('log-kg-plus')));
    await t.pump();
    expect(store.nextSetLog(db), const SetLog(kg: 2.5, kgTyped: true));
    store.addSet(db);
    await _frames(t, 4);
    expect(store.setLogs(db).single, const SetLog(kg: 2.5, kgTyped: true)); // the set took it
    expect(find.text('SET 1'), findsOneWidget);
    // Steppers: 2.5 kg and 1 rep, saved as typed.
    for (var i = 0; i < 3; i++) {
      await t.tap(find.byKey(const ValueKey('log-kg-plus')));
    }
    await t.tap(find.byKey(const ValueKey('log-reps-plus')));
    await t.pump();
    final l = store.setLogs(db).single;
    expect((l.kg, l.reps, l.kgTyped, l.repsTyped), (10.0, 1, true, true));
    // A tap on the number: the arcade keypad.
    await t.tap(find.byKey(const ValueKey('log-reps-value')));
    await _frames(t, 10);
    expect(find.byKey(const ValueKey('pad-point')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('pad-del')));
    await t.tap(find.byKey(const ValueKey('pad-8')));
    await t.tap(find.byKey(const ValueKey('pad-ok')));
    await _frames(t, 10);
    expect(store.setLogs(db).single.reps, 8);
    // A hold steps by 5 (D85), kg and reps, and repeats.
    final g = await t.startGesture(t.getCenter(find.byKey(const ValueKey('log-reps-plus'))));
    await t.pump(const Duration(milliseconds: 600));
    await g.up();
    await t.pump();
    expect(store.setLogs(db).single.reps, 13);
    final h = await t.startGesture(t.getCenter(find.byKey(const ValueKey('log-kg-minus'))));
    await t.pump(const Duration(milliseconds: 600));
    await h.up();
    await t.pump();
    expect(store.setLogs(db).single.kg, 5);
    store.setSetLog(db, 0, kg: 10);
    store.setSetLog(db, 0, reps: 8);
    await t.pump();
    // The next set: carried.
    store.addSet(db);
    await _frames(t, 4);
    expect(find.text('SET 2'), findsOneWidget);
    expect(find.text('2 · 10×8'), findsOneWidget);
    // A tap on the first pip edits set 1; the last pip goes back.
    await t.tap(find.byKey(const ValueKey('log-pip-0')));
    await t.pump();
    expect(find.text('SET 1'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('log-reps-minus')));
    await t.pump();
    expect(store.setLogs(db).map((l) => l.reps), [7, 8]);
    await t.tap(find.byKey(const ValueKey('log-pip-1')));
    await t.pump();
    expect(find.text('SET 2'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
