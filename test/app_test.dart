import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// Seven days logged by the OLD app: 4 workouts, 3 rest days, and one
// date with two workouts.
const _workoutDays = {1, 2, 4, 6};
final _oldSessions = [
  for (var d = 1; d <= 7; d++)
    {
      'day': d,
      'date': '2026-11-0${d + 1}',
      'rested': !_workoutDays.contains(d),
      if (_workoutDays.contains(d)) ...{'startMs': 0, 'endMs': (50 + d) * 60000},
    },
  {'day': 1, 'date': '2026-11-07', 'rested': false}, // same date as day 6
];
const _oldWorkoutDates = 4;

// Data written by the old tracking system.
const _oldLogs = '{"S00001":{"lu1":{"name":"Bench","sets":[{"kg":100.0,"reps":5}]}}}';
const _oldSwaps = '{"hu1":{"S00004":"Floor Press"}}';

const _profile = Profile(
  character: Character(sex: 'female', height: 80, muscle: 100, fat: 0),
  classId: 'warrior',
  difficultyId: 'd03', // 4 exercises, 3 target sets, ×1.2, streak N 2
  areaId: 'castle',
);
const _d = 2; // difficulty index of d03

/// A test clock the store reads. 21 Nov 2026 is a Saturday.
var _now = DateTime(2026, 11, 21, 10);

Future<(LogStore, SharedPreferences)> _store({bool old = false, bool setUp = false}) async {
  SharedPreferences.setMockInitialValues({
    if (old) ...{
      'sessions_v2': jsonEncode(_oldSessions),
      'logs_v2': _oldLogs,
      'swaps_v2': _oldSwaps,
      'session_started_ms': 123,
      'snooze2_lu1': true,
    },
    if (setUp) 'profile_v1': jsonEncode(_profile.toJson()),
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

/// Answers the Android "Save as" channel: [saved] = the user saved the file.
List<String> _fakeSaveDialog(bool saved) {
  final files = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('pumplex/files'),
    (call) async {
      if (call.method == 'saveText') {
        if (saved) files.add((call.arguments as Map)['content'] as String);
        return saved;
      }
      return null;
    },
  );
  return files;
}

class _PushCounter extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => _now = DateTime(2026, 11, 21, 10));

  // ------------------------------------------------------------ fixed data

  test('rules: XP per set, over-target bonus, level curve', () {
    expect(xpForExercise(3, 3, 0), 3 * xpPerSet);
    expect(xpForExercise(5, 3, 0), 5 * xpPerSet + 2 * xpPerExtraSet);
    expect(xpForExercise(2, 3, _d), (2 * xpPerSet * rulesFor(_d).xpMultiplier).round());
    expect(levelFor(0), (level: 1, into: 0, need: levelBaseXp));
    expect(levelFor(levelBaseXp + 7), (level: 2, into: 7, need: xpToNext(2)));
  });

  test('fixed data: difficulty numbers, pools, ids', () {
    expect(difficultyRules.length, difficulties.length);
    expect(difficultyRules.first.exercisesPerWorkout, 3);
    expect(difficultyRules.last.exercisesPerWorkout, 8);
    expect(gameClasses.map((c) => c.equipment).toSet().length, gameClasses.length);
    expect(gameClasses.every((c) => c.exercises.length > 8), isTrue); // room to swap at 8
    final ids = [for (final c in gameClasses) for (final e in c.exercises) e.id];
    expect(ids.toSet().length, ids.length);
    expect(items.map((i) => i.id).toSet().length, items.length);
    expect(achievements.map((a) => a.id).toSet().length, achievements.length);
    expect(GearSlot.values.every((s) => items.any((i) => i.slot == s)), isTrue);
  });

  test('sprites: nearest drawn frame for slider values', () {
    expect([nearestStop(0), nearestStop(24), nearestStop(26), nearestStop(74), nearestStop(76)],
        [0, 0, 50, 50, 100]);
    expect(spriteAsset(const Character(sex: 'female', fat: 90, muscle: 10)),
        'assets/body/female/fat100_muscle0.png');
    expect(allSpriteAssets.length, 18);
  });

  // --------------------------------------------------------- session rule

  test('one session per calendar day, with class, difficulty and area', () async {
    final (store, prefs) = await _store(setUp: true);
    expect(store.todaySession, isNull);
    final plan = store.todayExercises.map((e) => e.exerciseId).toList();
    _now = DateTime(2026, 11, 21, 7);
    store.addSet(0);
    _now = DateTime(2026, 11, 21, 18); // 11 h later: same day, same session
    store.addSet(0);
    store.addSet(1);
    final s = store.todaySession!;
    expect(store.sessions.keys, ['2026-11-21']);
    expect((s.classId, s.difficultyId, s.areaId, s.legacy), ('warrior', 'd03', 'castle', false));
    expect((s.firstMarkAt, s.lastMarkAt), ('2026-11-21T07:00:00', '2026-11-21T18:00:00'));
    expect(s.exercises.map((e) => e.exerciseId), plan);
    expect([s.exercises[0].sets, s.exercises[1].sets], [2, 1]);
    // Saved under sessions_v3 as date -> session, and loads again.
    final raw = jsonDecode(prefs.getString('sessions_v3')!) as Map;
    expect(raw['2026-11-21']['exercises'][0]['targetSets'], 3);
    expect(LogStore(prefs, clock: () => _now).todaySession!.totalSets, 3);
  });

  test('a later day is a new session; a day with no sets does not count', () async {
    final (store, _) = await _store(setUp: true);
    _now = DateTime(2026, 11, 21, 23, 50);
    store.addSet(0);
    _now = DateTime(2026, 11, 22, 0, 10); // 20 min later, but a new day
    expect(store.todaySession, isNull);
    store.addSet(0);
    expect(store.sessions.keys.toSet(), {'2026-11-21', '2026-11-22'});
    _now = DateTime(2026, 11, 23, 9);
    store.swap(0, 1); // a change without sets
    expect(store.sessions.length, 3);
    expect(store.history.map((s) => s.date), ['2026-11-22', '2026-11-21']);
  });

  // -------------------------------------------------------------- workouts

  test('a workout: N exercises from the pool, each with a target', () async {
    final (store, _) = await _store(setUp: true);
    final pool = classById('warrior').exercises.map((e) => e.id).toSet();
    final list = store.todayExercises;
    expect(list.length, rulesFor(_d).exercisesPerWorkout);
    expect(list.every((e) => pool.contains(e.exerciseId) && e.targetSets == rulesFor(_d).targetSets), isTrue);
    expect(list.map((e) => e.exerciseId).toSet().length, list.length);
    expect(LogStore.planFor(classById('mage'), 11, '2026-11-21').length, 8);
  });

  test('swipe switches, ↺ brings it back, add and remove keep the record', () async {
    final (store, _) = await _store(setUp: true);
    final first = store.todayExercises[0].exerciseId;
    final others = store.todayExercises.skip(1).map((e) => e.exerciseId).toSet();
    expect(store.swap(0, 1), isTrue);
    final sw = store.todayExercises[0];
    expect((sw.switched, sw.originalExerciseId), (true, first));
    expect(others.contains(sw.exerciseId), isFalse); // never a duplicate
    expect(store.swap(0, 1), isTrue);
    expect(store.todayExercises[0].exerciseId, isNot(anyOf(first, sw.exerciseId)));
    expect(store.resetSlot(0), isTrue);
    expect(store.todayExercises[0].exerciseId, first);

    store.addSet(0); // a card with sets cannot be switched or removed
    expect(store.swap(0, 1), isFalse);
    expect(store.removeSlot(0), isFalse);

    final extra = store.unusedExercises.first.id;
    store.addExercise(extra);
    expect((store.todayExercises.last.exerciseId, store.todayExercises.last.added), (extra, true));
    final n = store.todayExercises.length;
    expect(store.removeSlot(n - 1), isTrue);
    expect(store.todayExercises.length, n); // still there, marked removed
    expect(store.todayExercises.last.removed, isTrue);
    expect(store.todayCards.length, n - 1);
    store.addExercise(extra); // comes back
    expect(store.todayExercises.length, n);
    expect(store.todayExercises.last.removed, isFalse);
  });

  test('class, difficulty and area can change; each session keeps its own', () async {
    final (store, _) = await _store(setUp: true);
    store.addSet(0);
    final xp = store.totalXp;
    const gym = Profile(character: Character(), classId: 'mage', difficultyId: 'd12', areaId: 'beach');
    store.setProfile(gym);
    expect((store.todaySession!.classId, store.todaySession!.areaId), ('warrior', 'castle'));
    expect(store.totalXp, xp);
    _now = _now.add(const Duration(days: 1));
    expect(store.todayExercises.length, 8);
    expect(store.todayExercises.first.exerciseId, startsWith('mage.'));
    store.addSet(0);
    expect(store.todaySession!.areaId, 'beach');
    expect(store.sessions['2026-11-21']!.difficultyId, 'd03');

    // With no sets yet, a change makes today's workout again.
    final (fresh, _) = await _store(setUp: true);
    fresh.swap(0, 1);
    fresh.setProfile(gym);
    expect(fresh.todayExercises.first.exerciseId, startsWith('mage.'));
  });

  test('body sliders keep a history of changes', () async {
    final (store, prefs) = await _store();
    store.setProfile(_profile);
    store.setProfile(_profile); // no change, no new entry
    _now = _now.add(const Duration(days: 30));
    store.setProfile(_profile.copyWith(character: _profile.character.copyWith(fat: 40)));
    expect(store.bodyHistory.length, 2);
    expect(store.bodyHistory.last.character.fat, 40);
    expect(store.bodyHistory.last.at, '2026-12-21T10:00:00');
    expect(store.profile!.createdAt, '2026-11-21T10:00:00');
    expect(LogStore(prefs, clock: () => _now).bodyHistory.length, 2);
  });

  // ------------------------------------------------------------------- XP

  test('XP: sets (+ over target), training day, streak weeks', () async {
    final (store, _) = await _store(setUp: true);
    for (var i = 0; i < 5; i++) {
      store.addSet(0); // 2 over the target of 3
    }
    final setsXp = xpForExercise(5, 3, _d);
    final sources = {for (final e in store.xpEvents) e.source};
    expect(sources, containsAll(['sets', 'day']));
    expect(store.xpEvents.where((e) => e.source == 'sets').single.amount, setsXp);
    expect(store.thisWeek, (days: 1, n: 2));
    expect(store.streakWeeks, 0);

    // Sunday: 2nd training day this week -> streak week.
    _now = DateTime(2026, 11, 22, 9);
    store.addSet(0);
    expect(store.thisWeek, (days: 2, n: 2));
    expect(store.streakWeeks, 1);
    expect(store.xpEvents.where((e) => e.source == 'streak').single.ref, '2026-11-16');

    // Next week: Monday and Friday (days missed in between do not matter).
    _now = DateTime(2026, 11, 23, 9);
    store.addSet(0);
    expect(store.streakWeeks, 1); // last week still stands
    _now = DateTime(2026, 11, 27, 9);
    store.addSet(0);
    expect(store.streakWeeks, 2);

    final achievementXp = store.xpEvents.where((e) => e.source == 'achievement').fold(0, (a, e) => a + e.amount);
    expect(store.totalXp,
        setsXp + 3 * xpForExercise(1, 3, _d) + 4 * xpPerTrainingDay + 2 * xpPerStreakWeek + achievementXp);

    // A week below N breaks the run of weeks.
    _now = DateTime(2026, 12, 10, 9);
    expect(store.streakWeeks, 0);
  });

  test('achievements unlock once with saved XP; levels unlock and equip gear', () async {
    final (store, prefs) = await _store(setUp: true);
    store.addSet(0);
    expect(store.achievementsUnlocked.keys, contains('first_set'));
    final saved = jsonDecode(prefs.getString('xp_events_v1')!) as List;
    expect(saved.where((e) => e['source'] == 'achievement' && e['ref'] == 'first_set').length, 1);
    expect(store.takeUnlocks().map((u) => u.name), contains('First Blood'));
    expect(store.takeUnlocks(), isEmpty);
    store.addSet(0);
    expect(saved.length, (jsonDecode(prefs.getString('xp_events_v1')!) as List).length); // no repeat

    while (levelFor(store.totalXp).level < 3) {
      store.addSet(1);
    }
    expect(store.gear.owned, containsAll(['head.sweatband', 'top.tank']));
    expect(store.gear.equipped['head'], 'head.sweatband'); // empty slot: auto-equipped
    store.equip(GearSlot.head, null);
    expect(store.gear.equipped.containsKey('head'), isFalse);
    store.equip(GearSlot.weapon, 'weapon.kettlebell'); // not owned: ignored
    expect(store.gear.equipped.containsKey('weapon'), isFalse);
    expect(LogStore(prefs, clock: () => _now).gear.owned, store.gear.owned);
  });

  // ------------------------------------------------------------- migration

  test('migration: backup file first, then legacy sessions + XP, then delete', () async {
    final (store, prefs) = await _store(old: true);
    expect(store.hasOldData, isTrue);
    expect(store.oldWorkoutCount, _oldWorkoutDates);

    final backup = jsonDecode(store.oldBackupJson()) as Map;
    expect((backup['app'], backup['version']), ('pumplex', 2));
    expect(backup['logs'], jsonDecode(_oldLogs));
    expect(backup['swaps'], jsonDecode(_oldSwaps));
    expect((backup['raw'] as Map).keys.toSet(),
        {'sessions_v2', 'logs_v2', 'swaps_v2', 'session_started_ms', 'snooze2_lu1'});
    expect(prefs.getString('logs_v2'), _oldLogs); // nothing deleted yet

    await store.migrateOld();
    expect(store.hasOldData, isFalse);
    for (final k in ['sessions_v2', 'logs_v2', 'swaps_v2', 'session_started_ms', 'snooze2_lu1']) {
      expect(prefs.containsKey(k), isFalse, reason: k);
    }
    final legacy = store.sessions.values.where((s) => s.legacy).toList();
    expect(legacy.map((s) => s.date).toSet(), {'2026-11-02', '2026-11-03', '2026-11-05', '2026-11-07'});
    expect(store.sessions['2026-11-02']!.duration, const Duration(minutes: 51));
    final events = store.xpEvents.where((e) => e.source == 'legacy').toList();
    expect(events.length, _oldWorkoutDates);
    expect(store.totalXp, greaterThanOrEqualTo(_oldWorkoutDates * xpPerLegacySession));
    expect(store.history.length, _oldWorkoutDates);
    expect(store.streakWeeks, 0); // legacy days give their own XP only

    await store.migrateOld(); // running it again changes nothing
    expect(store.xpEvents.where((e) => e.source == 'legacy').length, _oldWorkoutDates);
  });

  test('backups: everything round-trips; old version-2 backups go through the migration', () async {
    final (store, _) = await _store(setUp: true);
    store.setProfile(_profile);
    store.addSet(0);
    _now = _now.add(const Duration(days: 1));
    store.addSet(1);
    store.removeSlot(2);
    final backup = store.backupJson();
    final data = jsonDecode(backup) as Map;
    expect(data['version'], 3);
    expect(data.keys, containsAll(['profile_v1', 'body_history_v1', 'sessions_v3', 'xp_events_v1', 'achievements_v1', 'gear_v1']));

    final (other, otherPrefs) = await _store(old: true); // un-migrated old data on this phone
    await other.importBackup(backup);
    expect(other.profile!.classId, 'warrior');
    expect(other.sessions.length, 2);
    expect(other.bodyHistory.length, 1);
    expect(other.todaySession!.exercises[2].removed, isTrue);
    expect(other.backupJson(), backup);
    expect(otherPrefs.getString('logs_v2'), _oldLogs); // only the migration deletes old keys
    await expectLater(other.importBackup('not json'), throwsA(anything));
    await expectLater(other.importBackup('{"some": "json"}'), throwsA(anything));
    await expectLater(other.importBackup('{"app": "pumplex", "version": 3, "sessions_v3": {"x": 1}}'),
        throwsA(anything));
    expect(other.backupJson(), backup); // bad imports left data alone

    // A backup made by the old app (version 2).
    await other.importBackup(jsonEncode({
      'app': 'pumplex',
      'version': 2,
      'sessions': _oldSessions,
      'logs': jsonDecode(_oldLogs),
      'swaps': jsonDecode(_oldSwaps),
    }));
    expect(other.profile, isNull); // setup runs again
    expect(other.sessions.values.every((s) => s.legacy), isTrue);
    expect(other.sessions.length, _oldWorkoutDates);
    expect(other.xpEvents.where((e) => e.source == 'legacy').length, _oldWorkoutDates);
    expect(other.backupJson().contains('kg'), isFalse); // kg / reps data is gone
  });

  // -------------------------------------------------------------- widgets

  testWidgets('old data: the app asks for a backup file before it upgrades', (t) async {
    _phone(t);
    final (store, prefs) = await _store(old: true);
    var files = _fakeSaveDialog(false);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    expect(find.text('OLD SAVE · ONE-TIME UPGRADE'), findsOneWidget);
    expect(find.textContaining('$_oldWorkoutDates OLD WORKOUT DAYS FOUND'), findsOneWidget);

    await t.tap(find.text('SAVE BACKUP & UPGRADE'));
    await _frames(t, 4);
    expect(find.textContaining('NO BACKUP, NO UPGRADE'), findsOneWidget);
    expect(prefs.getString('logs_v2'), _oldLogs); // cancelled: nothing changed

    await _frames(t, 110); // the message goes away
    files = _fakeSaveDialog(true);
    await t.tap(find.text('SAVE BACKUP & UPGRADE'));
    await _frames(t);
    expect(files.single, contains('Floor Press')); // the old data, saved first
    expect(prefs.containsKey('logs_v2'), isFalse);
    expect(find.text('CHARACTER · STEP 1 OF 4'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('old data: NOT NOW keeps it and goes to the setup', (t) async {
    _phone(t);
    final (store, prefs) = await _store(old: true);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    await t.tap(find.text('NOT NOW'));
    await _frames(t);
    expect(find.text('CHARACTER · STEP 1 OF 4'), findsOneWidget);
    expect(prefs.getString('logs_v2'), _oldLogs);
  });

  testWidgets('first launch: WoW-style character screen, live sprite, setup to the hub', (t) async {
    _phone(t);
    final pushes = _PushCounter();
    final (store, prefs) = await _store();
    await t.pumpWidget(MaterialApp(
      theme: pumplexTheme(Brightness.light),
      navigatorObservers: [pushes],
      home: GameShell(store: store),
    ));
    await _frames(t);
    expect(find.text('CHARACTER · STEP 1 OF 4'), findsOneWidget);
    expect(_spriteAsset(t), 'assets/body/male/fat50_muscle50.png');

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

    final saved = Profile.fromJson(jsonDecode(prefs.getString('profile_v1')!) as Map<String, dynamic>);
    expect(saved.character, const Character(sex: 'female', height: 100, muscle: 100, fat: 0));
    expect((saved.classId, saved.difficultyId, saved.areaId, saved.schemaVersion), ('warrior', 'd03', 'castle', 1));
    expect(find.text("TODAY'S WORKOUT"), findsOneWidget);
    expect(find.text(exerciseName(store.todayExercises.first.exerciseId).toUpperCase()), findsOneWidget);
    expect(find.textContaining('THIS WEEK 0/2 DAYS'), findsOneWidget);
    expect(pushes.pushes, 1); // only the home route: views never push routes
  });

  testWidgets('workout: tap adds a working set, long-press takes one away', (t) async {
    _phone(t);
    final (store, _) = await _store(setUp: true);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    expect(find.text('TRAIN ▶'), findsOneWidget);
    expect(find.text('START TRAINING ▶'), findsNothing);
    expect(find.text('I WORKED 💪'), findsNothing);

    await t.tap(find.byKey(const ValueKey('hub-workout')));
    await _frames(t);
    final card = find.byKey(const ValueKey('card-0'));
    for (var i = 0; i < 6; i++) {
      await t.tap(card);
      await t.pump(const Duration(milliseconds: 80));
    }
    await t.longPress(card);
    await _frames(t, 70); // first-set achievement burst
    expect(store.todayExercises[0].sets, 5);
    expect(find.text('5/3'), findsOneWidget);
    expect(find.text('+${xpForExercise(5, 3, _d)} XP 🔥'), findsOneWidget);

    await t.tap(find.text('◀ HUB'));
    await _frames(t);
    expect(find.text('KEEP GOING ▶'), findsOneWidget);
    expect(find.text('ON · 5 SETS'), findsOneWidget);

    await t.tap(find.text('◀ PAST'));
    await _frames(t);
    expect(find.textContaining('TODAY · '), findsOneWidget);
    await t.tap(find.text('HUB ▶'));
    await _frames(t, 70);
    expect(t.takeException(), isNull);
  });

  testWidgets('workout: swipe a card to switch, ↺ back, add and remove exercises', (t) async {
    _phone(t);
    final (store, _) = await _store(setUp: true);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    await t.tap(find.byKey(const ValueKey('hub-workout')));
    await _frames(t);
    final first = store.todayExercises[0].exerciseId;
    final card = find.byKey(const ValueKey('card-0'));

    await t.drag(card, const Offset(-200, 0));
    await _frames(t, 10);
    expect(store.todayExercises[0].switched, isTrue);
    expect(find.text(exerciseName(store.todayExercises[0].exerciseId).toUpperCase()), findsOneWidget);
    await t.tap(find.descendant(of: card, matching: find.text('↺')));
    await _frames(t, 10);
    expect(store.todayExercises[0].exerciseId, first);

    await t.tap(card);
    await _frames(t, 70); // achievement burst
    await t.drag(card, const Offset(-200, 0));
    await _frames(t, 10);
    expect(store.todayExercises[0].exerciseId, first);
    expect(find.textContaining('SETS ALREADY DONE HERE'), findsOneWidget);
    await _frames(t, 110); // the message goes away

    final n = store.todayCards.length;
    Future<void> show(Finder f) async {
      await t.ensureVisible(f);
      await _frames(t, 4);
    }

    await show(find.text('+ ADD EXERCISE'));
    await t.tap(find.text('+ ADD EXERCISE'));
    await _frames(t, 10);
    final extra = store.unusedExercises.first;
    await show(find.byKey(ValueKey('add-${extra.id}')));
    await t.tap(find.byKey(ValueKey('add-${extra.id}')));
    await _frames(t, 10);
    expect(store.todayCards.length, n + 1);

    final last = store.todayCards.last;
    await show(find.byKey(ValueKey('card-$last')));
    await t.tap(find.descendant(of: find.byKey(ValueKey('card-$last')), matching: find.text('✕')));
    await _frames(t, 10);
    expect(store.todayCards.length, n);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('tap the character on the hub to edit the body sliders', (t) async {
    _phone(t);
    final (store, _) = await _store(setUp: true);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    await t.tap(find.byKey(const ValueKey('hub-character')));
    await _frames(t);
    expect(find.text('CHARACTER · STEP 1 OF 4'), findsOneWidget);
    await t.drag(find.byKey(const ValueKey('slider-FAT %')), const Offset(400, 0));
    await t.tap(find.text('NEXT ▶'));
    await _frames(t);
    await t.tap(find.text('SAVE ✔'));
    await _frames(t);
    expect(store.profile!.character.fat, 100);
    expect(store.bodyHistory.last.character.fat, 100);
    expect(find.text("TODAY'S WORKOUT"), findsOneWidget);
  });

  testWidgets('levels up with a burst; gear unlocks and can be equipped', (t) async {
    _phone(t);
    final (store, _) = await _store(setUp: true);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    await t.tap(find.byKey(const ValueKey('hub-workout')));
    await _frames(t);
    final card = find.byKey(const ValueKey('card-1'));
    await t.tap(card);
    await _frames(t, 70);
    while (levelFor(store.totalXp).level == 1) {
      await t.tap(card);
      await t.pump(const Duration(milliseconds: 60));
    }
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('LEVEL\nUP!!!'), findsOneWidget);
    await _frames(t, 70);
    expect(store.gear.owned, contains('head.sweatband'));

    await t.tap(find.text('◀ HUB'));
    await _frames(t);
    await t.tap(find.text('⚔ GEAR'));
    await _frames(t);
    expect(find.text('GEAR · LVL ${levelFor(store.totalXp).level}'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('item-head.sweatband')));
    await _frames(t, 4);
    expect(store.gear.equipped['head'], isNull);
    await t.tap(find.byKey(const ValueKey('item-head.sweatband')));
    await _frames(t, 4);
    expect(store.gear.equipped['head'], 'head.sweatband');
  });

  testWidgets('android back goes one step back, not out of the app', (t) async {
    _phone(t);
    final (store, _) = await _store(setUp: true);
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

  testWidgets('CEL SHADER toggles from the menu, is remembered, keeps the scene', (t) async {
    _phone(t);
    final (store, prefs) = await _store(setUp: true);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);

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
      store.addSet(0);
      store.takeUnlocks();
      await t.pumpWidget(MaterialApp(theme: pumplexTheme(b), home: GameShell(store: store)));
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
      await tapAndSettle(find.text('⚔ GEAR'));
      await tapAndSettle(find.text('◀ HUB'));
      await t.tap(find.byIcon(Icons.more_vert));
      await _frames(t, 10);
      await tapAndSettle(find.text('🧬  EDIT CHARACTER'));
      await tapAndSettle(find.text('NEXT ▶')); // editing: straight to the summary
      await tapAndSettle(find.text('DIFFICULTY'));
      await tapAndSettle(find.text('NEXT ▶'));
      await tapAndSettle(find.text('AREA'));
      await tapAndSettle(find.text('NEXT ▶'));
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
      expect(find.text('scene 0').evaluate().isNotEmpty || find.text('scene 1').evaluate().isNotEmpty, isTrue);
    }
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('scene 0'), findsNothing);
    expect(find.text('scene 1'), findsOneWidget);
  });
}
