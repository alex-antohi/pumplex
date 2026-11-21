import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gym_app/game/content.dart';
import 'package:gym_app/game/model.dart';
import 'package:gym_app/game/rules.dart';
import 'package:gym_app/main.dart';
import 'package:gym_app/pumplex.dart';
import 'package:gym_app/store.dart';
import 'package:gym_app/views/scene.dart';
import 'package:gym_app/views/sprite.dart';

// Seven days logged by the OLD app (4 workouts, 3 rest days).
const _workoutDays = {1, 2, 4, 6};
final _oldSessions = [
  for (var d = 1; d <= 7; d++)
    {
      'day': d,
      'date': '2026-11-0${d + 1}',
      'rested': !_workoutDays.contains(d),
      if (_workoutDays.contains(d)) ...{'startMs': 0, 'endMs': (50 + d) * 60000},
    },
];

// Data written by the old tracking system: it must survive untouched.
const _oldLogs = '{"S00001":{"lu1":{"name":"Bench","sets":[{"kg":100.0,"reps":5}]}}}';
const _oldSwaps = '{"hu1":{"S00004":"Floor Press"}}';

const _profile = Profile(
  character: Character(sex: 'f', height: 80, muscle: 100, fat: 0),
  classId: 'warrior',
  difficultyId: 'd03', // ×1.2
  areaId: 'castle',
);

/// A test clock the store reads.
var _now = DateTime(2026, 11, 21, 10);

Future<(LogStore, SharedPreferences)> _store({bool fresh = false, bool setUp = false}) async {
  SharedPreferences.setMockInitialValues({
    if (!fresh) ...{
      'sessions_v2': jsonEncode(_oldSessions),
      'logs_v2': _oldLogs,
      'swaps_v2': _oldSwaps,
    },
    if (setUp) 'game_profile_v1': jsonEncode(_profile.toJson()),
  });
  final prefs = await SharedPreferences.getInstance();
  return (LogStore(prefs, clock: () => _now), prefs);
}

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 2340); // ~392 × 851 dp
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
}

Future<void> _frames(WidgetTester t, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

String _spriteAsset(WidgetTester t) =>
    (t.widget<Image>(find.byKey(const ValueKey('character-sprite'))).image as AssetImage).assetName;

class _PushCounter extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => _now = DateTime(2026, 11, 21, 10));

  // ------------------------------------------------------------------ rules

  test('XP: sets × XP per set × difficulty multiplier; level curve', () {
    expect(xpForSets(3, 0), 3 * xpPerSet);
    expect(xpForSets(10, 2), (10 * xpPerSet * difficultyMultipliers[2]).round());
    expect(difficultyMultipliers.length, difficulties.length);
    expect(levelFor(0), (level: 1, into: 0, need: levelBaseXp));
    expect(levelFor(levelBaseXp).level, 2);
    expect(levelFor(levelBaseXp + xpToNext(2)).level, 3);
    expect(levelFor(levelBaseXp + 7), (level: 2, into: 7, need: xpToNext(2)));
  });

  test('every class has exercises and its own equipment; ids are unique', () {
    expect(gameClasses.map((c) => c.id).toSet().length, gameClasses.length);
    expect(gameClasses.map((c) => c.equipment).toSet().length, gameClasses.length);
    final ids = [for (final c in gameClasses) for (final e in c.exercises) e.id];
    expect(ids.toSet().length, ids.length);
    expect(gameClasses.every((c) => c.exercises.isNotEmpty), isTrue);
    expect(difficulties.length, greaterThanOrEqualTo(10));
  });

  test('sprites: nearest drawn frame for slider values', () {
    expect([nearestStop(0), nearestStop(24), nearestStop(26), nearestStop(74), nearestStop(76)],
        [0, 0, 50, 50, 100]);
    expect(spriteAsset(const Character(sex: 'f', fat: 90, muscle: 10)),
        'assets/body/female/fat100_muscle0.png');
    expect(allSpriteAssets.length, 18);
    expect(heightScale(0), minHeightScale);
    expect(heightScale(100), maxHeightScale);
  });

  // --------------------------------------------------------- session rule

  test('a session starts on the first mark and stays open while you train', () async {
    final (store, _) = await _store(fresh: true, setUp: true);
    expect(store.open, isNull);
    store.addSet('warrior.squat');
    final start = _now;
    expect(store.open!.start, start);
    _now = _now.add(const Duration(minutes: 40));
    store.addSet('warrior.squat');
    _now = _now.add(sessionTimeout - const Duration(minutes: 1)); // just under the limit
    store.addSet('warrior.bench');
    expect(store.onAppOpened(), isNull);
    expect(store.sessions, isEmpty);
    expect(store.open!.sets, {'warrior.squat': 2, 'warrior.bench': 1});
    expect(store.open!.start, start);
    expect(store.open!.end, _now);
    expect(store.totalXp, xpForSets(3, 2) + 0);
  });

  test('a session closes after the timeout with no new mark', () async {
    final (store, prefs) = await _store(fresh: true, setUp: true);
    store.addSet('warrior.squat');
    _now = _now.add(sessionTimeout);
    // The next mark closes the old session and starts a new one.
    store.addSet('warrior.deadlift');
    expect(store.sessions.single.sets, {'warrior.squat': 1});
    expect(store.open!.sets, {'warrior.deadlift': 1});
    // Saved, and loads again.
    final again = LogStore(prefs, clock: () => _now);
    expect(again.sessions.single.sets, {'warrior.squat': 1});
    expect(again.open!.sets, {'warrior.deadlift': 1});

    _now = _now.add(sessionTimeout);
    expect(again.onAppOpened()!.sets, {'warrior.deadlift': 1});
    expect(again.open, isNull);
    expect(again.sessions.length, 2);
  });

  test('opening the app on a later day closes the session', () async {
    final (store, _) = await _store(fresh: true, setUp: true);
    _now = DateTime(2026, 11, 21, 23, 0);
    store.addSet('warrior.squat');
    _now = DateTime(2026, 11, 22, 0, 30); // 1.5 h later, but a new day
    expect(store.onAppOpened(), isNotNull);
    expect(store.open, isNull);
  });

  test('a mark after midnight in the same workout does not split it', () async {
    final (store, _) = await _store(fresh: true, setUp: true);
    _now = DateTime(2026, 11, 21, 23, 40);
    store.addSet('warrior.squat');
    _now = DateTime(2026, 11, 22, 0, 10);
    store.addSet('warrior.squat'); // app stayed open: only the timeout applies
    expect(store.sessions, isEmpty);
    expect(store.open!.sets['warrior.squat'], 2);
  });

  test('long-press takes a set away; no sets left = no session', () async {
    final (store, _) = await _store(fresh: true, setUp: true);
    store.removeSet('warrior.squat'); // nothing to remove
    store.addSet('warrior.squat');
    store.addSet('warrior.bench');
    store.removeSet('warrior.squat');
    expect(store.open!.sets, {'warrior.bench': 1});
    store.removeSet('warrior.bench');
    expect(store.open, isNull);
    expect(store.sessions, isEmpty);
  });

  // ------------------------------------------------------------- old data

  test('old sessions become beta XP; old keys are never touched', () async {
    final (store, prefs) = await _store(setUp: true);
    final oldRaw = prefs.getString('sessions_v2');
    expect(store.oldXp, 4 * xpPerOldWorkout + 3 * xpPerOldRestDay);
    expect(store.totalXp, store.oldXp);
    store.addSet('warrior.squat');
    _now = _now.add(sessionTimeout);
    store.onAppOpened();
    store.setProfile(_profile);
    expect(prefs.getString('sessions_v2'), oldRaw);
    expect(prefs.getString('logs_v2'), _oldLogs);
    expect(prefs.getString('swaps_v2'), _oldSwaps);
    expect(store.totalXp, store.oldXp + xpForSets(1, 2));
  });

  test('backups: everything round-trips, old version-2 backups still load', () async {
    final (store, _) = await _store(setUp: true);
    store.addSet('warrior.squat');
    _now = _now.add(sessionTimeout);
    store.addSet('warrior.bench'); // one closed, one open
    final backup = store.backupJson();
    final data = jsonDecode(backup) as Map;
    expect(data['version'], 3);
    expect(data['logs'], jsonDecode(_oldLogs));
    expect(data['swaps'], jsonDecode(_oldSwaps));

    final (other, otherPrefs) = await _store(fresh: true);
    await other.importBackup(backup);
    expect(other.profile!.classId, 'warrior');
    expect(other.sessions.length, 1);
    expect(other.open!.sets, {'warrior.bench': 1});
    expect(other.oldSessions.length, 7);
    expect(jsonDecode(otherPrefs.getString('logs_v2')!), jsonDecode(_oldLogs));
    expect(other.backupJson(), backup);
    await expectLater(other.importBackup('not json'), throwsA(anything));
    await expectLater(other.importBackup('{"some": "json"}'), throwsA(anything));
    expect(other.backupJson(), backup); // bad imports left data alone

    // A backup made by the old app (version 2, before the game).
    final v2 = jsonEncode({
      'app': 'pumplex',
      'version': 2,
      'sessions': _oldSessions,
      'logs': jsonDecode(_oldLogs),
      'swaps': jsonDecode(_oldSwaps),
    });
    await other.importBackup(v2);
    expect(other.profile, isNull); // setup runs again
    expect(other.sessions, isEmpty);
    expect(other.open, isNull);
    expect(other.oldSessions.length, 7);
    expect(otherPrefs.getString('swaps_v2'), _oldSwaps);
  });

  // -------------------------------------------------------------- widgets

  testWidgets('first launch: WoW-style character screen, live sprite, setup to the hub', (t) async {
    _phone(t);
    final pushes = _PushCounter();
    final (store, prefs) = await _store(); // old data, no profile yet
    await t.pumpWidget(MaterialApp(
      theme: pumplexTheme(Brightness.light),
      navigatorObservers: [pushes],
      home: GameShell(store: store),
    ));
    await _frames(t);
    expect(find.text('CHARACTER · STEP 1 OF 4'), findsOneWidget);
    expect(_spriteAsset(t), 'assets/body/male/fat50_muscle50.png');

    // Sliders and the sex toggle change the character live.
    await t.drag(find.byKey(const ValueKey('slider-MUSCLE')), const Offset(400, 0));
    await _frames(t, 4);
    expect(_spriteAsset(t), 'assets/body/male/fat50_muscle100.png');
    await t.drag(find.byKey(const ValueKey('slider-FAT %')), const Offset(-400, 0));
    await _frames(t, 4);
    expect(_spriteAsset(t), 'assets/body/male/fat0_muscle100.png');
    await t.tap(find.text('♀'));
    await _frames(t, 4);
    expect(_spriteAsset(t), 'assets/body/female/fat0_muscle100.png');
    final short = t.getSize(find.byKey(const ValueKey('character-sprite'))).height;
    await t.drag(find.byKey(const ValueKey('slider-HEIGHT')), const Offset(400, 0));
    await _frames(t, 8);
    expect(t.getSize(find.byKey(const ValueKey('character-sprite'))).height, greaterThan(short));

    // Class row: one class per equipment type.
    await t.tap(find.text('FREE WEIGHTS'));
    await _frames(t, 8);
    expect(find.text('WARRIOR'), findsOneWidget);

    await t.tap(find.text('NEXT ▶'));
    await t.pump(const Duration(milliseconds: 200));
    // Mid-transition: both scenes are on screen (no blank frame).
    expect(find.text('FREE WEIGHTS'), findsOneWidget);
    expect(find.text('HOW HARD?'), findsWidgets);
    await _frames(t);
    expect(find.text('FREE WEIGHTS'), findsNothing);
    await t.tap(find.byKey(const ValueKey('difficulty-d03')));
    await t.tap(find.text('NEXT ▶'));
    await _frames(t);
    await t.tap(find.byKey(const ValueKey('area-castle')));
    await t.tap(find.text('NEXT ▶'));
    await _frames(t);
    expect(find.text('SNACK PALADIN'), findsOneWidget);
    await t.tap(find.text("LET'S GO!!!"));
    await _frames(t, 70); // welcome burst

    final saved = Profile.fromJson(jsonDecode(prefs.getString('game_profile_v1')!) as Map<String, dynamic>);
    expect(saved.character, const Character(sex: 'f', height: 100, muscle: 100, fat: 0));
    expect((saved.classId, saved.difficultyId, saved.areaId), ('warrior', 'd03', 'castle'));
    expect(find.text("TODAY'S WORKOUT"), findsOneWidget);
    expect(find.text('BACK SQUATS'), findsOneWidget);
    expect(find.text('LVL ${levelFor(store.oldXp).level}'), findsOneWidget);
    expect(pushes.pushes, 1); // only the home route: views never push routes
  });

  testWidgets('workout: tap adds a working set, long-press takes one away', (t) async {
    _phone(t);
    final (store, _) = await _store(fresh: true, setUp: true);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    expect(find.text('TRAIN ▶'), findsOneWidget);
    expect(find.text('START TRAINING ▶'), findsNothing);
    expect(find.text('I WORKED 💪'), findsNothing);

    await t.tap(find.byKey(const ValueKey('hub-workout')));
    await _frames(t);
    final squats = find.byKey(const ValueKey('card-warrior.squat'));
    for (var i = 0; i < 6; i++) {
      await t.tap(squats);
      await t.pump(const Duration(milliseconds: 80));
    }
    await t.longPress(squats);
    await _frames(t, 10);
    expect(store.setsOf('warrior.squat'), 5);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('+${5 * xpForSets(1, 2)} XP'), findsOneWidget);
    expect(find.byType(TallyMarks), findsOneWidget);

    await t.tap(find.text('◀ HUB'));
    await _frames(t);
    expect(find.text('KEEP GOING ▶'), findsOneWidget);
    expect(find.text('ON · 5 SETS'), findsOneWidget);

    await t.tap(find.text('◀ PAST'));
    await _frames(t);
    expect(find.textContaining('NOW · '), findsOneWidget);
    await t.tap(find.text('HUB ▶'));
    await _frames(t, 70);
    expect(t.takeException(), isNull);
  });

  testWidgets('enough sets level you up with a burst', (t) async {
    _phone(t);
    final (store, _) = await _store(fresh: true, setUp: true);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    await t.tap(find.byKey(const ValueKey('hub-workout')));
    await _frames(t);
    final card = find.byKey(const ValueKey('card-warrior.bench'));
    while (levelFor(store.totalXp).level == 1) {
      await t.tap(card);
      await t.pump(const Duration(milliseconds: 60));
    }
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('LEVEL\nUP!!!'), findsOneWidget);
    await _frames(t, 70);
  });

  testWidgets('android back goes one step back, not out of the app', (t) async {
    _phone(t);
    final (store, _) = await _store(fresh: true, setUp: true);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    await t.tap(find.byKey(const ValueKey('hub-workout')));
    await _frames(t);
    expect(find.text('◀ HUB'), findsOneWidget);
    await t.binding.handlePopRoute();
    await _frames(t);
    expect(find.text('◀ HUB'), findsNothing);
    expect(find.text('TRAIN ▶'), findsOneWidget);
  });

  testWidgets('a stale session closes when the app opens', (t) async {
    _phone(t);
    final (store, _) = await _store(fresh: true, setUp: true);
    store.addSet('warrior.squat');
    _now = _now.add(const Duration(days: 1));
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    expect(store.open, isNull);
    expect(find.textContaining('LAST SESSION BANKED: 1 SETS'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('CEL SHADER toggles from the menu, is remembered, keeps the scene', (t) async {
    _phone(t);
    final (store, prefs) = await _store(setUp: true);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    expect(store.cel.value, isFalse);

    Future<void> menu(String item) async {
      await t.tap(find.byIcon(Icons.more_vert));
      await _frames(t, 10); // let the menu open
      await t.tap(find.text(item));
      await _frames(t, 10);
    }

    await menu('🖍️  CEL SHADER: OFF');
    expect(store.cel.value, isTrue);
    expect(prefs.getBool('cel'), isTrue);
    expect(find.byType(CelFilter), findsOneWidget);
    expect(find.text("TODAY'S WORKOUT"), findsOneWidget);
    await menu('🖍️  CEL SHADER: ON!!!');
    expect(store.cel.value, isFalse);
    await menu('🌀  CHAOS MODE: OFF');
    expect(store.chaos.value, isTrue);
    await menu('🧬  EDIT CHARACTER');
    expect(find.text('CHARACTER · STEP 1 OF 4'), findsOneWidget);
    expect(_spriteAsset(t), spriteAsset(_profile.character));
    await t.pump(const Duration(seconds: 5));
  });

  for (final b in Brightness.values) {
    testWidgets('every scene renders on a phone ($b)', (t) async {
      _phone(t);
      final (store, _) = await _store(setUp: true);
      store.addSet('warrior.squat');
      await t.pumpWidget(MaterialApp(
        theme: pumplexTheme(b),
        home: GameShell(store: store),
      ));
      await _frames(t);
      Future<void> tapAndSettle(Finder f) async {
        await t.tap(f);
        await _frames(t);
        expect(t.takeException(), isNull);
      }

      await tapAndSettle(find.byKey(const ValueKey('hub-workout')));
      await tapAndSettle(find.text('◀ HUB'));
      await tapAndSettle(find.text('◀ PAST'));
      await tapAndSettle(find.text('HUB ▶'));
      await t.tap(find.byIcon(Icons.more_vert));
      await _frames(t, 10);
      await tapAndSettle(find.text('🧬  EDIT CHARACTER'));
      for (var i = 0; i < 3; i++) {
        await tapAndSettle(find.text('NEXT ▶'));
      }
      expect(find.text('SAVE ✔'), findsOneWidget);
      await tapAndSettle(find.text('SAVE ✔'));
      expect(find.text("TODAY'S WORKOUT"), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  }

  testWidgets('scenes cross-fade with a camera zoom, never a blank frame', (t) async {
    var scene = 0;
    late StateSetter set;
    await t.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, s) {
        set = s;
        return SceneSwitcher(scene: scene, motion: Motion.zoomIn, child: Text('scene $scene'));
      }),
    ));
    set(() => scene = 1);
    for (var ms = 0; ms < sceneDuration.inMilliseconds; ms += 60) {
      await t.pump(const Duration(milliseconds: 60));
      // Something is always on screen during the change.
      expect(find.text('scene 0').evaluate().isNotEmpty || find.text('scene 1').evaluate().isNotEmpty, isTrue);
    }
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('scene 0'), findsNothing);
    expect(find.text('scene 1'), findsOneWidget);
  });
}
