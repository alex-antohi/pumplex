import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gym_app/day_page.dart';
import 'package:gym_app/main.dart';
import 'package:gym_app/program.dart';
import 'package:gym_app/pumplex.dart';
import 'package:gym_app/stats.dart';
import 'package:gym_app/store.dart';

// One full program week done (sessions 1-7 on 2-8 Nov), session 8 is current.
final _sessions = [
  for (var d = 1; d <= 7; d++)
    {
      'day': d,
      'date': '2026-11-0${d + 1}',
      'rested': program[d] == null,
      if (program[d] != null) ...{'startMs': 0, 'endMs': (50 + d) * 60000},
    },
];

// Data written by the old tracking system: it must survive untouched.
const _oldLogs = '{"S00001":{"lu1":{"name":"Bench","sets":[{"kg":100.0,"reps":5}]}}}';
const _oldSwaps = '{"hu1":{"S00004":"Floor Press"}}';

Future<(LogStore, SharedPreferences)> _store({bool fresh = false}) async {
  SharedPreferences.setMockInitialValues(fresh
      ? {}
      : {
          'sessions_v2': jsonEncode(_sessions),
          'logs_v2': _oldLogs,
          'swaps_v2': _oldSwaps,
        });
  final prefs = await SharedPreferences.getInstance();
  return (LogStore(prefs), prefs);
}

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 2340); // ~392 × 851 dp
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
}

Widget _host(LogStore store, int n, {Brightness b = Brightness.light}) => MaterialApp(
      theme: pumplexTheme(b),
      home: Scaffold(body: DayPage(n: n, store: store, onComplete: () {})),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a fresh install starts on Day 1', () async {
    final (store, _) = await _store(fresh: true);
    expect((store.currentN, store.dayOf(1)), (1, 1));
    expect(program[1]!.title, 'Light Upper');
  });

  test('days only move on with I WORKED / I RESTED, and can be undone', () async {
    final (store, _) = await _store(fresh: true);
    store.complete(rested: false);
    store.complete(rested: false);
    expect(program[store.dayOf(store.currentN)], isNull); // Day 3 is rest
    store.complete(rested: true);
    expect(store.dayOf(store.currentN), 4);
    expect(store.undoComplete(), isTrue);
    expect(store.currentN, 3);

    final (full, _) = await _store();
    expect((full.currentN, full.dayOf(8), full.dayOf(9)), (8, 1, 2)); // wraps after Day 7
  });

  test('START TRAINING times the session; undo keeps the clock', () async {
    final (store, _) = await _store(fresh: true);
    expect(store.startedAt, isNull);
    store.startTraining();
    final started = store.startedAt!;
    store.complete(rested: false);
    expect(store.sessions.last.startMs, started.millisecondsSinceEpoch);
    expect(store.sessions.last.duration, isNotNull);
    expect(store.startedAt, isNull);
    expect(store.undoComplete(), isTrue);
    expect(store.startedAt, started);
    store.complete(rested: false);
    store.complete(rested: false); // never started: no time
    expect(store.sessions.last.duration, isNull);
  });

  test('stats count work, not numbers', () async {
    final (store, _) = await _store();
    final s = computeStats(store);
    expect((s.workouts, s.rests, s.weekWorkouts), (4, 3, 4));
    expect(s.totalTime, const Duration(minutes: 51 + 52 + 54 + 56));
    expect(s.longestTime, const Duration(minutes: 56));
  });

  test('old tracking data stays in storage and in backups', () async {
    final (store, prefs) = await _store();
    store.complete(rested: false); // saving sessions must not touch the old data
    expect(prefs.getString('logs_v2'), _oldLogs);
    expect(prefs.getString('swaps_v2'), _oldSwaps);

    final backup = store.backupJson();
    final data = jsonDecode(backup) as Map;
    expect(data['logs'], jsonDecode(_oldLogs));
    expect(data['swaps'], jsonDecode(_oldSwaps));

    final (other, otherPrefs) = await _store(fresh: true);
    await other.importBackup(backup);
    expect(other.currentN, 9);
    expect(jsonDecode(otherPrefs.getString('logs_v2')!), jsonDecode(_oldLogs));
    expect(other.backupJson(), backup);
    await expectLater(other.importBackup('not json'), throwsA(anything));
    await expectLater(other.importBackup('{"some": "json"}'), throwsA(anything));
    expect(other.backupJson(), backup); // bad imports left data alone
  });

  testWidgets('app: swipe back and ahead, top bar keeps its height, I WORKED moves on', (t) async {
    _phone(t);
    final (store, _) = await _store();
    await t.pumpWidget(GymApp(store: store));
    await t.pump(const Duration(seconds: 3));
    Future<void> settle([int frames = 30]) async {
      for (var i = 0; i < frames; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
    }

    expect(find.text('SESSION 8 · DAY 1/7 · NOW'), findsOneWidget);
    final top = t.getTopLeft(find.byType(PageView)).dy;

    final swipe = await t.startGesture(t.getCenter(find.byType(PageView)));
    await swipe.moveBy(const Offset(120, 0));
    await t.pump(const Duration(milliseconds: 50));
    await swipe.moveBy(const Offset(210, 0));
    await t.pump(const Duration(milliseconds: 50));
    expect(t.getTopLeft(find.byType(PageView)).dy, top);
    await swipe.up();
    await settle();
    expect(find.textContaining('SESSION 7 · DAY 7/7'), findsOneWidget);
    await t.tap(find.text('↩ NOW'));
    await settle();

    await t.drag(find.byType(PageView), const Offset(-330, 0));
    await settle();
    expect(find.text('SESSION 9 · DAY 2/7 · PREVIEW'), findsOneWidget);
    expect(t.getTopLeft(find.byType(PageView)).dy, top);
    await t.tap(find.text('↩ NOW'));
    await settle();

    final button = find.text('I WORKED 💪');
    await t.dragUntilVisible(button, find.byType(ListView), const Offset(0, -600));
    await settle(6);
    await t.tap(button);
    await t.pump();
    expect(store.currentN, 9);
    await settle(60);
    expect(find.text('SESSION 9 · DAY 2/7 · NOW'), findsOneWidget);
    await t.tap(find.text('UNDO'));
    await settle();
    expect(store.currentN, 8);
    await t.pump(const Duration(seconds: 7));
  });

  testWidgets('START TRAINING button, live clock, time on past sessions', (t) async {
    _phone(t);
    final (store, _) = await _store(fresh: true);
    await t.pumpWidget(_host(store, 1));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('NO SETS. NO REPS.'), findsOneWidget);
    await t.tap(find.text('START TRAINING ▶'));
    await t.pump(const Duration(milliseconds: 300));
    expect(store.startedAt, isNotNull);
    expect(find.textContaining('⏱ 0:0'), findsOneWidget);

    store.complete(rested: false);
    await t.pumpWidget(_host(store, 1));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('⏱ TOOK 0:0'), findsOneWidget);
    expect(find.text('START TRAINING ▶'), findsNothing);
  });

  for (final b in Brightness.values) {
    testWidgets('every session page renders on a phone ($b)', (t) async {
      _phone(t);
      final (store, _) = await _store();
      for (var n = 1; n <= 14; n++) { // past, current, previews
        await t.pumpWidget(_host(store, n, b: b));
        await t.pump(const Duration(milliseconds: 400));
        for (var s = 0; s < 4; s++) {
          await t.drag(find.byType(ListView), const Offset(0, -700));
          await t.pump(const Duration(milliseconds: 200));
        }
        expect(t.takeException(), isNull);
      }
      await t.pumpWidget(const SizedBox());
    });
  }

  testWidgets('rest day shows the stats and I RESTED', (t) async {
    _phone(t);
    final (store, _) = await _store(fresh: true);
    store.complete(rested: false);
    store.complete(rested: false); // Day 3 = rest
    await t.pumpWidget(_host(store, 3));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('REST DAY'), findsWidgets);
    expect(find.text('THE STATS™'), findsOneWidget);
    await t.dragUntilVisible(find.text('I RESTED 😴'), find.byType(ListView), const Offset(0, -600));
    expect(find.text('I RESTED 😴'), findsOneWidget);
  });
}
