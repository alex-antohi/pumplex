import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gym_app/day_page.dart';
import 'package:gym_app/export.dart';
import 'package:gym_app/main.dart';
import 'package:gym_app/movements.dart';
import 'package:gym_app/program.dart';
import 'package:gym_app/pumplex.dart';
import 'package:gym_app/stats.dart';
import 'package:gym_app/store.dart';

String k(int n) => sessionKey(n);

// One full program week done (sessions 1-7 on 2-8 Nov), session 8 is current.
final _sessions = [
  for (var d = 1; d <= 7; d++)
    {'day': d, 'date': '2026-11-0${d + 1}', 'rested': program[d] == null},
];

final _logs = {
  k(1): {
    'lu1': {
      'name': 'Bench',
      'sets': [for (var i = 0; i < 5; i++) {'kg': 100, 'reps': 5}],
    },
    'lu3': {
      'name': 'BB Row',
      'sets': [
        {'kg': 60, 'reps': 8},
      ],
    },
  },
  k(2): {
    'hl1': {
      'name': 'LB Squat',
      'sets': [
        {'kg': 140, 'reps': 3},
      ],
    },
  },
};

Future<LogStore> _store({bool fresh = false}) async {
  SharedPreferences.setMockInitialValues(fresh
      ? {}
      : {
          'logs_v2': jsonEncode(_logs),
          'sessions_v2': jsonEncode(_sessions),
        });
  return LogStore(await SharedPreferences.getInstance());
}

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 2340); // ~392 × 851 dp
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
}

Widget _host(LogStore store, int n, {Brightness b = Brightness.light, VoidCallback? onComplete}) =>
    MaterialApp(
      theme: pumplexTheme(b),
      home: Scaffold(body: DayPage(n: n, store: store, onComplete: onComplete ?? () {})),
    );

/// Press I WORKED / I RESTED until session [n] is the current one.
void _advanceTo(LogStore store, int n) {
  while (store.currentN < n) {
    store.complete(rested: program[store.dayOf(store.currentN)] == null);
  }
}

Reminder? _reminder(LogStore store, int day, String id, int n) {
  final w = program[day]!, e = w.byId(id)!;
  return reminderFor(store, e, k(n), movementOn(store, w, e, k(n)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('schemes from the sheet parse', () {
    final a = Scheme.parse('3x6');
    expect((a.sets, a.reps, a.badge), (3, 6, '3×6'));
    final rm = Scheme.parse('3-5 Rep Max');
    expect((rm.sets, rm.repsHint), (1, '3-5'));
    final ro = Scheme.parse('-25% Rep Out');
    expect((ro.sets, ro.percent, ro.badge), (1, 0.75, '-25%'));
    expect(Scheme.parse('WORK').badge, 'WORK');
  });

  test("Anca's program matches her sheet and Alex's slot layout", () {
    expect(ancaProgram.keys, alexProgram.keys); // same training and rest days
    for (final day in ancaProgram.keys) {
      final a = ancaProgram[day]!, b = alexProgram[day]!;
      expect(a.title, b.title);
      expect(a.exercises.map((e) => (e.id, e.scheme, e.percentOf)).toList(),
          b.exercises.map((e) => (e.id, e.scheme, e.percentOf)).toList());
      for (final e in a.exercises) {
        expect(Scheme.parse(e.scheme).description, isNot(e.scheme)); // every scheme understood
      }
    }
    String names(int day) => ancaProgram[day]!.exercises.map((e) => e.name).join(', ');
    expect(names(1), 'Bench Press, Close Grip Bench, Barbell Rows, Lat Pulldowns, '
        'Side Delt Raises, Bicep Curls, Rear Delt Fly');
    expect(names(2), 'Front Squat, Front Squat, Stiffies, Lunges, Leg Curls, Abs');
    expect(names(4), 'Bench Press, Bench Press, Bench Press, Close Grip Pushups, Dumbbell Rows, '
        'Lat Pulldowns Reverse Grip, Front Delt Raises, Hammer Curls, High Rows');
    expect(names(6), 'Box Squat, Stiffies, Bulgarian Split Squats, Leg Raises, Abs');
    expect(person, 'alex'); // tests (and the default build) use Alex's program
    expect(identical(program, alexProgram), isTrue);
  });

  test('a fresh install starts today on Day 1', () async {
    final store = await _store(fresh: true);
    expect(store.currentN, 1);
    expect(store.dayOf(1), 1);
    expect(program[store.dayOf(1)]!.title, 'Light Upper');
  });

  test('days only move on with I WORKED / I RESTED, and can be undone', () async {
    final store = await _store(fresh: true);
    store.complete(rested: false); // Light Upper done
    expect((store.currentN, store.dayOf(2)), (2, 2));
    store.complete(rested: false); // Heavy Lower done
    expect(program[store.dayOf(3)], isNull); // Day 3 is rest
    store.complete(rested: true);
    expect(store.dayOf(store.currentN), 4);
    expect(store.undoComplete(), isTrue);
    expect(store.currentN, 3);

    // No undo once the next session has sets in it.
    store.complete(rested: true);
    store.edit(k(store.currentN), 'hu1', 'Bench').sets.add(SetEntry(kg: 100, reps: 3));
    expect(store.undoComplete(), isFalse);

    // After Day 7 it wraps to Day 1.
    final full = await _store();
    expect((full.currentN, full.dayOf(8), full.dayOf(9)), (8, 1, 2));
  });

  test('csv export covers only the chosen period', () async {
    final store = await _store();
    final out = buildCsv(store, DateTime(2026, 11, 2), DateTime(2026, 11, 2));
    expect(out.sets, 6);
    expect(out.csv.startsWith(bom), isTrue);
    final lines = out.csv.substring(1).trim().split('\r\n');
    expect(lines.first, 'date,session,program_day,workout,exercise,slot,scheme,set,kg,reps');
    expect(lines[1], '2026-11-02,1,1,Light Upper,Bench,Overhead or Bench Press,5x5,1,100,5');
    expect(lines.last, '2026-11-02,1,1,Light Upper,BB Row,Horizontal Pull,3x8,1,60,8');
    expect(buildCsv(store, DateTime(2026, 11, 2), DateTime(2026, 11, 3)).sets, 7);
    expect(buildCsv(store, DateTime(2026, 11, 4), DateTime(2026, 11, 8)).sets, 0);
  });

  test('backup round-trips sessions, logs and swaps', () async {
    final store = await _store();
    store.setSwap('hu1', k(4), 'Floor Press');
    final json = store.backupJson();
    final other = await _store(fresh: true);
    await other.importBackup(json);
    expect(other.backupJson(), json);
    expect(other.currentN, 8);
    expect(other.swapOn('hu1', k(11)), 'Floor Press');
    await expectLater(other.importBackup('not json'), throwsA(anything));
    await expectLater(other.importBackup('{"some": "json"}'), throwsA(anything));
    expect(other.backupJson(), json); // bad imports left data alone
  });

  test('stats add up', () async {
    final s = computeStats(await _store());
    expect(s.totalKg, 5 * 500 + 480 + 420);
    expect((s.sets, s.reps, s.workouts, s.rests), (7, 36, 4, 3));
    expect(s.heaviest.first, ('LB Squat', 140.0));
    expect(inThings(s.totalKg), startsWith('≈ 2.3 CARS'));
  });

  test('first exercise: heads-up in week 2, swap due in week 3', () async {
    final store = await _store(); // LB Squat in session 2
    expect(_reminder(store, 2, 'hl1', 9)!.due, isFalse);
    store.edit(k(9), 'hl1', 'LB Squat').sets.add(SetEntry(kg: 150, reps: 3));
    expect(_reminder(store, 2, 'hl1', 16)!.due, isTrue);

    store.setSwap('hl1', k(16), 'SSB Squat');
    final w = program[2]!;
    expect(movementOn(store, w, w.byId('hl1')!, k(16)).name, 'SSB Squat');
    expect(movementOn(store, w, w.byId('hl2')!, k(16)).name, 'SSB Squat'); // rep-out follows
    expect(movementOn(store, w, w.byId('hl1')!, k(9)).name, 'LB Squat'); // history untouched
    expect(_reminder(store, 2, 'hl1', 16), isNull);
  });

  test('second movement: heads-up in week 4, swap due in week 5', () async {
    final store = await _store();
    for (final n in [2, 9, 16]) {
      store.edit(k(n), 'hl3', 'Good Morning').sets.add(SetEntry(kg: 60.0 + n, reps: 6));
    }
    expect(_reminder(store, 2, 'hl3', 23)!.due, isFalse);
    store.edit(k(23), 'hl3', 'Good Morning').sets.add(SetEntry(kg: 90, reps: 6));
    expect(_reminder(store, 2, 'hl3', 30)!.due, isTrue);
  });

  test('box squat does not rotate: only no progress swaps it', () async {
    final store = await _store();
    for (final n in [6, 13, 20, 27]) {
      store.edit(k(n), 'll1', 'Box Squat').sets.add(SetEntry(kg: 100.0 + n, reps: 5));
    }
    expect(_reminder(store, 6, 'll1', 34), isNull);
    for (final n in [34, 41]) {
      store.edit(k(n), 'll1', 'Box Squat').sets.add(SetEntry(kg: 100, reps: 5));
    }
    expect(_reminder(store, 6, 'll1', 48)!.due, isTrue);
  });

  test('max-effort upper: swap due after 2 weeks, snooze hides it', () async {
    final store = await _store();
    store.setSwap('hu1', k(4), 'Floor Press');
    for (final n in [4, 11]) {
      store.edit(k(n), 'hu1', 'Floor Press').sets.add(SetEntry(kg: 120, reps: 3));
    }
    expect(_reminder(store, 4, 'hu1', 11)!.due, isFalse);
    expect(_reminder(store, 4, 'hu1', 18)!.due, isTrue);
    store.snooze('hu1', k(24));
    expect(_reminder(store, 4, 'hu1', 18), isNull);
  });

  test('accessories: swap after 2 weeks without progress', () async {
    final store = await _store(); // BB Row 60×8 in session 1
    store.edit(k(8), 'lu3', 'BB Row').sets.add(SetEntry(kg: 60, reps: 8));
    expect(_reminder(store, 1, 'lu3', 15), isNull);
    store.edit(k(15), 'lu3', 'BB Row').sets.add(SetEntry(kg: 60, reps: 8));
    expect(_reminder(store, 1, 'lu3', 22)!.due, isTrue);
    store.edit(k(22), 'lu3', 'BB Row').sets.add(SetEntry(kg: 62.5, reps: 8));
    expect(_reminder(store, 1, 'lu3', 29), isNull);
  });

  test('START TRAINING times the session; undo keeps the clock', () async {
    final store = await _store(fresh: true);
    expect(store.startedAt, isNull);
    store.startTraining();
    final started = store.startedAt!;
    store.complete(rested: false);
    final done = store.sessions.last;
    expect(done.startMs, started.millisecondsSinceEpoch);
    expect(done.duration, isNotNull);
    expect(store.startedAt, isNull); // the next session starts fresh

    expect(store.undoComplete(), isTrue);
    expect(store.startedAt, started); // back on the session, clock still running

    store.complete(rested: false);
    store.complete(rested: false); // never started: no time
    expect(store.sessions.last.duration, isNull);
    expect(computeStats(store).avgTime, isNotNull);
  });

  testWidgets('START TRAINING button, live clock, and the time on past sessions', (t) async {
    _phone(t);
    final store = await _store(fresh: true);
    await t.pumpWidget(_host(store, 1));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('START TRAINING ▶'));
    await t.pump(const Duration(milliseconds: 300));
    expect(store.startedAt, isNotNull);
    expect(find.text('START TRAINING ▶'), findsNothing);
    expect(find.textContaining('⏱ 0:0'), findsOneWidget);

    store.complete(rested: false);
    await t.pumpWidget(_host(store, 1)); // now a past session
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('⏱ TOOK 0:0'), findsOneWidget);
    expect(find.text('START TRAINING ▶'), findsNothing);
    await t.pumpWidget(_host(store, 3)); // previews and rest days: no button
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('START TRAINING ▶'), findsNothing);
  });

  testWidgets('second rep-out, first time: -25% on top of the first rep-out', (t) async {
    _phone(t);
    final store = await _store();
    _advanceTo(store, 11); // Heavy Upper
    store.edit(k(11), 'hu1', 'Bench').sets.add(SetEntry(kg: 100, reps: 3, done: true));
    store.edit(k(11), 'hu2', 'Bench').sets.add(SetEntry(kg: 75, reps: 10, done: true));
    final w = program[4]!;
    expect(movementOn(store, w, w.byId('hu3')!, k(11)).name, 'Bench'); // follows the chain
    await t.pumpWidget(_host(store, 11));
    await t.pump(const Duration(milliseconds: 300));
    final target = find.textContaining('FIRST TIME: 57.5 KG (75% OF 75) · MAX REPS');
    await t.dragUntilVisible(target, find.byType(ListView), const Offset(0, -400));
    expect(target, findsOneWidget);
    expect(find.textContaining('75% OF THE REP-OUT ABOVE'), findsOneWidget);
  });

  testWidgets('fresh install: swipe ahead to preview the week, then back', (t) async {
    _phone(t);
    final store = await _store(fresh: true);
    await t.pumpWidget(GymApp(store: store));
    await t.pump(const Duration(seconds: 3));
    Future<void> settle() async {
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
    }

    expect(find.text('SESSION 1 · DAY 1/7 · NOW'), findsOneWidget);
    await t.drag(find.byType(PageView), const Offset(-330, 0));
    await settle();
    expect(find.text('SESSION 2 · DAY 2/7 · PREVIEW'), findsOneWidget);
    expect(find.text('PREVIEW · COMING UP'), findsOneWidget);
    expect(find.text('I WORKED 💪'), findsNothing);
    // Preview cards can't be logged into.
    await t.tap(find.text('✔').first, warnIfMissed: false);
    await t.pump();
    expect(store.get(k(2), 'hl1'), isNull);

    await t.drag(find.byType(PageView), const Offset(330, 0));
    await settle();
    expect(find.text('SESSION 1 · DAY 1/7 · NOW'), findsOneWidget);
    expect(store.currentN, 1);
  });

  testWidgets('app opens on the current session, swipes back, I WORKED moves on', (t) async {
    _phone(t);
    final store = await _store();
    await t.pumpWidget(GymApp(store: store));
    await t.pump(const Duration(seconds: 3));
    expect(find.text('SESSION 8 · DAY 1/7 · NOW'), findsOneWidget);
    final pagesTop = t.getTopLeft(find.byType(PageView)).dy;

    // Page animations need real frames; the endless decorations rule out
    // pumpAndSettle.
    Future<void> settle([int frames = 30]) async {
      for (var i = 0; i < frames; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
    }

    // Mid-swipe and after it, the top bar keeps its height (one info line).
    final swipe = await t.startGesture(t.getCenter(find.byType(PageView)));
    await swipe.moveBy(const Offset(120, 0));
    await t.pump(const Duration(milliseconds: 50));
    await swipe.moveBy(const Offset(210, 0));
    await t.pump(const Duration(milliseconds: 50));
    expect(t.getTopLeft(find.byType(PageView)).dy, pagesTop);
    await swipe.up();
    await settle();
    expect(find.textContaining('SESSION 7 · DAY 7/7'), findsOneWidget);
    expect(t.getTopLeft(find.byType(PageView)).dy, pagesTop);
    await t.tap(find.text('↩ NOW')); // floating button, not in the top bar
    await settle();
    expect(find.text('SESSION 8 · DAY 1/7 · NOW'), findsOneWidget);
    expect(t.getTopLeft(find.byType(PageView)).dy, pagesTop);

    final button = find.text('I WORKED 💪');
    await t.dragUntilVisible(button, find.byType(ListView), const Offset(0, -600));
    await settle(6);
    await t.tap(button);
    await t.pump();
    expect(store.currentN, 9);
    expect(store.sessions.last.rested, isFalse);
    await settle(60);
    expect(find.text('SESSION 9 · DAY 2/7 · NOW'), findsOneWidget);

    await t.tap(find.text('UNDO'));
    await settle();
    expect(store.currentN, 8);
    expect(find.text('SESSION 8 · DAY 1/7 · NOW'), findsOneWidget);
    await t.pump(const Duration(seconds: 7));
  });

  for (final b in Brightness.values) {
    testWidgets('every session page renders on a phone ($b)', (t) async {
      _phone(t);
      final store = await _store();
      for (var n = 1; n <= 14; n++) { // past, current, previews
        await t.pumpWidget(_host(store, n, b: b));
        await t.pump(const Duration(milliseconds: 400));
        for (var s = 0; s < 8; s++) {
          await t.drag(find.byType(ListView), const Offset(0, -700));
          await t.pump(const Duration(milliseconds: 200));
        }
        expect(t.takeException(), isNull);
      }
    });
  }

  testWidgets('rest day shows the stats and I RESTED', (t) async {
    _phone(t);
    final store = await _store(fresh: true);
    store.edit(k(1), 'lu1', 'Bench').sets.add(SetEntry(kg: 100, reps: 5));
    store.complete(rested: false);
    store.complete(rested: false); // now on Day 3 = rest
    await t.pumpWidget(_host(store, 3));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('REST DAY'), findsWidgets);
    expect(find.text('THE STATS™'), findsOneWidget);
    expect(find.text('500 KG'), findsWidgets); // total, and the Light Upper bar
    expect(find.textContaining('≈ 1.1 GRAND PIANOS'), findsOneWidget);
    await t.dragUntilVisible(find.text('I RESTED 😴'), find.byType(ListView), const Offset(0, -600));
    expect(find.text('I RESTED 😴'), findsOneWidget);
  });

  testWidgets('shows last week, then celebrates a PR', (t) async {
    _phone(t);
    final store = await _store();
    await t.pumpWidget(_host(store, 8));
    await t.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('LAST WEEK · MON 2 NOV:'), findsWidgets);
    expect(find.textContaining('100×5  100×5  100×5  100×5  100×5'), findsOneWidget);
    expect(find.textContaining('ALL-TIME BEST: 100 KG'), findsOneWidget);

    await t.enterText(find.byType(TextField).at(0), '102,5');
    await t.enterText(find.byType(TextField).at(1), '5');
    await t.pump();
    final set = store.get(k(8), 'lu1')!.sets.first;
    expect((set.kg, set.reps, set.done), (102.5, 5, false)); // typing doesn't tick
    expect(find.text('🔥 NEW PR 🔥'), findsNothing);

    // The PR counts once the set is ticked.
    final tick = find.descendant(of: find.byKey(const ValueKey('lu1')), matching: find.text('✔')).first;
    await t.ensureVisible(tick);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(tick);
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(set.done, isTrue);
    expect(find.text('NEW\nPR!!!'), findsOneWidget);
    await t.drag(find.byType(ListView), const Offset(0, 600)); // back to the top
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('🔥 NEW PR 🔥'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    expect(find.text('NEW\nPR!!!'), findsNothing);
  });

  testWidgets('tick copies last week in', (t) async {
    _phone(t);
    final store = await _store();
    await t.pumpWidget(_host(store, 8));
    await t.pump(const Duration(milliseconds: 300));
    await t.ensureVisible(find.text('✔').first);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('✔').first);
    await t.pump();
    final set = store.get(k(8), 'lu1')!.sets.first;
    expect((set.kg, set.reps, set.done), (100.0, 5, true));
    await t.pump(const Duration(seconds: 1)); // let the auto-save fire
  });

  testWidgets('✔ needs a weight; typing never ticks; ✔ again un-ticks', (t) async {
    _phone(t);
    final store = await _store(fresh: true); // no history, so no weight to copy
    await t.pumpWidget(_host(store, 1));
    await t.pump(const Duration(milliseconds: 300));
    final ticks = find.descendant(of: find.byKey(const ValueKey('lu1')), matching: find.text('✔'));
    await t.ensureVisible(ticks.first);
    await t.pump(const Duration(milliseconds: 300));

    await t.tap(ticks.first);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('KG?'), findsOneWidget);
    expect(store.get(k(1), 'lu1'), isNull);

    await t.enterText(find.byType(TextField).at(0), '80');
    await t.pump();
    final set = store.get(k(1), 'lu1')!.sets.first;
    expect((set.kg, set.reps, set.done), (80.0, null, false));

    await t.drag(find.byType(ListView), const Offset(0, 200)); // typing scrolled it to the top edge
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(ticks.first); // reps come from the 5×5
    await t.pump();
    expect((set.kg, set.reps, set.done), (80.0, 5, true));

    await t.tap(ticks.first);
    await t.pump();
    expect(set.done, isFalse);
    await t.pump(const Duration(seconds: 5)); // snackbar and auto-save
  });

  test('data saved by the version on the phone loads unchanged', () async {
    // Exactly what the installed version writes: no "done" flags yet.
    const saved = '{"S00001":{"lu1":{"name":"Bench","sets":[{"kg":100.0,"reps":5},{"kg":100.0,"reps":5}]}}}';
    const sessions = '[{"day":1,"date":"2026-11-11","rested":false}]';
    const swaps = '{"hu1":{"S00004":"Floor Press"}}';
    SharedPreferences.setMockInitialValues({
      'logs_v2': saved,
      'sessions_v2': sessions,
      'swaps_v2': swaps,
    });
    final prefs = await SharedPreferences.getInstance();
    final store = LogStore(prefs);
    expect(store.currentN, 2);
    expect(store.dayOf(2), 2);
    expect(store.swapOn('hu1', k(4)), 'Floor Press');
    final sets = store.get(k(1), 'lu1')!.sets;
    expect(sets.map((s) => (s.kg, s.reps, s.done)), [(100.0, 5, true), (100.0, 5, true)]);

    await store.flush(); // saving again keeps everything
    final again = jsonDecode(prefs.getString('logs_v2')!) as Map;
    expect(again['S00001']['lu1']['sets'], [
      {'kg': 100.0, 'reps': 5, 'done': true},
      {'kg': 100.0, 'reps': 5, 'done': true},
    ]);
    expect(prefs.getString('sessions_v2'), sessions);
  });

  testWidgets('a weight typed in set 1 carries down to the other sets', (t) async {
    _phone(t);
    final store = await _store(fresh: true); // no history: nothing greyed out
    await t.pumpWidget(_host(store, 1));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('102.5'), findsNothing);

    await t.enterText(find.byType(TextField).at(0), '102,5');
    await t.enterText(find.byType(TextField).at(1), '5');
    await t.pump();
    expect(find.text('102.5'), findsNWidgets(4)); // sets 2-5 of the 5×5
    expect(store.get(k(1), 'lu1')!.sets.first.done, isFalse);

    final ticks = find.descendant(of: find.byKey(const ValueKey('lu1')), matching: find.text('✔'));
    await t.ensureVisible(ticks.at(1));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(ticks.at(1));
    await t.pump();
    final s = store.get(k(1), 'lu1')!.sets[1];
    expect((s.kg, s.reps, s.done), (102.5, 5, true));
    await t.pump(const Duration(seconds: 1)); // let the auto-save fire
  });

  testWidgets('swap reminder shows on the card and in the header', (t) async {
    _phone(t);
    final store = await _store();
    for (final n in [9, 16, 23]) {
      store.edit(k(n), 'hl1', 'LB Squat').sets.add(SetEntry(kg: 140, reps: 3));
    }
    _advanceTo(store, 30); // Heavy Lower, week 5
    await t.pumpWidget(_host(store, 30));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('⚠ 1 SWAP DUE'), findsOneWidget);
    await t.drag(find.byType(ListView), const Offset(0, -500));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('SWAP TIME'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.tap(find.text('NOT YET'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('SWAP TIME'), findsNothing);
    expect(store.snoozed('hl1', k(36)), isTrue);
  });

  testWidgets('swap a movement from the card', (t) async {
    _phone(t);
    final store = await _store();
    await t.pumpWidget(_host(store, 8));
    await t.pump(const Duration(milliseconds: 300));
    final swapButton = find.text('⇄ SWAP').first;
    await t.ensureVisible(swapButton);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(swapButton);
    await t.pump(const Duration(milliseconds: 500));
    await t.enterText(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
      'Floor Press',
    );
    await t.tap(find.text('SWAP'));
    await t.pump(const Duration(milliseconds: 500));
    expect(store.swapOn('lu1', k(8)), 'Floor Press');
    // Week 2 of Bench showed a heads-up box, so scroll back up to the title.
    await t.drag(find.byType(ListView), const Offset(0, 2000));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('FLOOR PRESS'), findsOneWidget);
    expect(find.textContaining('NO HISTORY FOR FLOOR PRESS'), findsOneWidget);
    await t.pump(const Duration(seconds: 5)); // snackbar goes away
  });

  Future<void> showRepOut(WidgetTester t, LogStore store, int n) async {
    _advanceTo(store, n);
    await t.pumpWidget(_host(store, n));
    await t.pump(const Duration(milliseconds: 300));
    await t.drag(find.byType(ListView), const Offset(0, -900));
    await t.pump(const Duration(milliseconds: 300));
  }

  testWidgets('rep-out, first time: 75% of today\'s max', (t) async {
    _phone(t);
    final store = await _store();
    store.edit(k(9), 'hl1', 'LB Squat').sets.add(SetEntry(kg: 120, reps: 3));
    await showRepOut(t, store, 9);
    expect(find.textContaining('FIRST TIME: 90 KG (75% OF 120) · MAX REPS'), findsOneWidget);
  });

  testWidgets('rep-out, later weeks: same weight, beat the reps', (t) async {
    _phone(t);
    final store = await _store();
    store.edit(k(2), 'hl2', 'LB Squat').sets.add(SetEntry(kg: 105, reps: 11));
    // A heavier max this week must not move the rep-out weight.
    store.edit(k(9), 'hl1', 'LB Squat').sets.add(SetEntry(kg: 150, reps: 3));
    await showRepOut(t, store, 9);
    expect(find.textContaining('SAME WEIGHT: 105 KG · BEAT 11 REPS'), findsOneWidget);

    // The weight is offered, the reps are yours to beat: ✔ wants them typed.
    final card = find.byKey(const ValueKey('hl2'));
    final tick = find.descendant(of: card, matching: find.text('✔'));
    await t.ensureVisible(tick);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(tick);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('REPS?'), findsOneWidget);
    expect(store.get(k(9), 'hl2'), isNull);

    await t.enterText(find.descendant(of: card, matching: find.byType(TextField)).at(1), '12');
    await t.drag(find.byType(ListView), const Offset(0, 200)); // typing scrolled it to the top edge
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(tick);
    await t.pump(const Duration(milliseconds: 300));
    final s = store.get(k(9), 'hl2')!.sets.first;
    expect((s.kg, s.reps, s.done), (105.0, 12, true));
    expect(find.text('REP\nPR!!!'), findsOneWidget);
    await t.pump(const Duration(seconds: 5)); // burst, snackbar, auto-save
  });

  testWidgets('rep-out with a new movement starts over at 75%', (t) async {
    _phone(t);
    final store = await _store();
    store.edit(k(2), 'hl2', 'SSB Squat').sets.add(SetEntry(kg: 105, reps: 11));
    store.edit(k(9), 'hl1', 'LB Squat').sets.add(SetEntry(kg: 120, reps: 3));
    await showRepOut(t, store, 9);
    expect(find.textContaining('FIRST TIME: 90 KG'), findsOneWidget);
  });
}
