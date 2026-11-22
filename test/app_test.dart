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
import 'package:gym_app/views/intro.dart';
import 'package:gym_app/views/scene.dart';
import 'package:gym_app/views/sprite.dart';
import 'package:gym_app/views/workout.dart';

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
  classId: 'paladin',
  difficultyId: 'sweat', // 4 exercises, 3 target sets, ×1.4, streak N 2
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

String _spriteAsset(WidgetTester t) => t.widget<AtlasSprite>(find.byKey(const ValueKey('character-sprite'))).frame;

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

  test('class id migration (D31): old ids become design ids once, old text kept', () async {
    const oldProfile = '{"classId":"warrior","difficultyId":"sweat","areaId":"gainsgard","character":{}}';
    const oldSessions = '{"2026-11-20":{"classId":"warrior","difficultyId":"sweat","areaId":"gainsgard",'
        '"exercises":[{"position":0,"exerciseId":"warrior.squat","originalExerciseId":"warrior.bench",'
        '"targetSets":3,"sets":2}]}}';
    SharedPreferences.setMockInitialValues({'profile_v1': oldProfile, 'sessions_v3': oldSessions});
    final prefs = await SharedPreferences.getInstance();
    final store = LogStore(prefs, clock: () => _now);
    expect(store.profile!.classId, 'paladin');
    final s = store.history.single;
    expect(s.classId, 'paladin');
    expect(s.exercises.single.exerciseId, 'paladin.squat');
    expect(s.exercises.single.originalExerciseId, 'paladin.bench');
    expect(s.exercises.single.sets, 2);
    expect(prefs.getString('profile_v1'), isNot(contains('warrior')));
    expect(prefs.getString('sessions_v3'), isNot(contains('warrior')));
    final backup = jsonDecode(prefs.getString(LogStore.classIdBackupKey)!) as Map;
    expect(backup['profile'], oldProfile);
    expect(backup['sessions'], oldSessions);
    // A second launch changes nothing.
    final again = LogStore(prefs, clock: () => _now);
    expect(again.profile!.classId, 'paladin');
    expect(newClassId('scrapper'), 'scrapper');
    expect(newExerciseId('custom'), 'custom');
  });

  // ------------------------------------------------------------ fixed data

  test('rules table: set XP, over target, cap, critical, streak, level curve', () {
    expect(difficultyRules.first.xpMultiplier, 1.0);
    expect(difficultyRules.last.xpMultiplier, 2.0);
    int set(int n, {bool crit = false, int streak = 0, int d = 0}) =>
        xpForSet(setNumber: n, target: 3, difficulty: d, critical: crit, streakWeeks: streak);
    expect(set(3), 10); // within the target
    expect(set(4), 15); // above the target: ×1.5
    expect(set(6), 15); // up to 2× the target
    expect(set(7), 0); // beyond 2× the target
    expect(set(1, crit: true), 20);
    expect(set(1, streak: 2), 11); // +10%
    expect(set(1, streak: 9), 13); // capped at +25% (12.5 rounds up)
    expect(set(1, d: 5), 20);
    expect(xpPerLegacySession, 150);
    // Repeatable criticals, about 3% of sets.
    expect(isCritical('2026-11-21', 'paladin.squat', 1), isCritical('2026-11-21', 'paladin.squat', 1));
    final crits = [for (var i = 1; i <= 10000; i++) isCritical('2026-11-21', 'x', i)].where((c) => c).length;
    expect(crits, inInclusiveRange(200, 400));
    // Habitica level curve.
    expect([for (final l in [1, 4, 5, 10, 20, 30, 40, 50]) xpToNext(l)], [25, 100, 150, 260, 440, 660, 940, 1260]); // rules.md says 670 at L30; its formula gives 660
    expect(levelFor(0), (level: 1, into: 0, need: 25));
    expect(levelFor(25 + 7), (level: 2, into: 7, need: 50));
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

  test('design data: 6 difficulty modes, 5 areas, one default area per class', () {
    expect(difficulties.map((d) => d.id), ['sofa', 'warmup', 'sweat', 'pain', 'brutal', 'nightmare']);
    expect(difficulties.every((d) => d.name.endsWith('Mode')), isTrue);
    expect([for (final r in difficultyRules) r.xpMultiplier], [1.0, 1.2, 1.4, 1.6, 1.8, 2.0]);
    expect(areas.length, 5);
    expect(areas.map((a) => a.marks).toSet(), MarkStyle.values.toSet()); // every mark style used
    for (final c in gameClasses) {
      expect(areas.where((a) => a.defaultFor == c.id).length, 1, reason: c.id);
      expect(defaultAreaFor(c.id).defaultFor, c.id);
    }
    expect(defaultAreaFor('paladin').id, 'castle');
    expect(areaById('nope').id, areas.first.id);
  });

  testWidgets('every area mark style draws, grouped in fives', (t) async {
    for (final style in MarkStyle.values) {
      for (final n in [0, 1, 5, 12]) {
        await t.pumpWidget(MaterialApp(
          theme: pumplexTheme(Brightness.light),
          home: Center(child: SetMarks(style: style, count: n, color: Colors.pink)),
        ));
        expect(t.takeException(), isNull, reason: '$style $n');
      }
    }
  });

  testWidgets('the workout: CRUSHED! at the target, the area stamp on every 5th set', (t) async {
    _phone(t);
    final (store, _) = await _store(setUp: true); // Gainsgard Keep: SLASHED!
    store.addSet(0); // level-ups and achievements happen here, not on screen
    store.addSet(0);
    store.takeUnlocks();
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    await t.tap(find.byKey(const ValueKey('hub-workout')));
    await _frames(t);
    expect(find.text('SCRATCH THE WALL'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('world-object'))); // 3rd set = target
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('CRUSHED!'), findsOneWidget);
    await _frames(t, 40);
    await t.tap(find.byKey(const ValueKey('strip-0'))); // back to the first exercise
    await _frames(t, 4);
    await t.tap(find.byKey(const ValueKey('world-object')));
    await _frames(t, 4);
    await t.tap(find.byKey(const ValueKey('world-object'))); // 5th set
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('SLASHED!'), findsOneWidget);
    expect(store.todayExercises[0].sets, 5);
    await _frames(t, 80);
  });

  test('sprites: nearest drawn frame for slider values', () {
    expect([nearestStop(0), nearestStop(12), nearestStop(13), nearestStop(62), nearestStop(90)],
        [0, 0, 25, 50, 100]);
    const c = Character(sex: 'female', fat: 90, muscle: 10);
    expect(spriteFrame(c), 'female/fat100_muscle0');
    expect(spriteCell(c), (4, 5)); // atlas column 4, row 5 (first female row)
    expect(spriteCell(const Character(fat: 50, muscle: 75)), (2, 3));
    expect(allSpriteAssets.first, bodyAtlas);
    expect(allSpriteAssets, contains('assets/outfits/paladin.png'));
    expect(allSpriteAssets, contains('assets/gear/head/head.crown.png'));
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
    expect((s.classId, s.difficultyId, s.areaId, s.legacy), ('paladin', 'sweat', 'castle', false));
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
    final pool = classById('paladin').exercises.map((e) => e.id).toSet();
    final list = store.todayExercises;
    expect(list.length, rulesFor(_d).exercisesPerWorkout);
    expect(list.every((e) => pool.contains(e.exerciseId) && e.targetSets == rulesFor(_d).targetSets), isTrue);
    expect(list.map((e) => e.exerciseId).toSet().length, list.length);
    expect(LogStore.planFor(classById('cablemancer'), 5, '2026-11-21').length, 8);
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
    const gym = Profile(character: Character(), classId: 'cablemancer', difficultyId: 'nightmare', areaId: 'beach');
    store.setProfile(gym);
    expect((store.todaySession!.classId, store.todaySession!.areaId), ('paladin', 'castle'));
    expect(store.totalXp, xp);
    _now = _now.add(const Duration(days: 1));
    expect(store.todayExercises.length, 8);
    expect(store.todayExercises.first.exerciseId, startsWith('cablemancer.'));
    store.addSet(0);
    expect(store.todaySession!.areaId, 'beach');
    expect(store.sessions['2026-11-21']!.difficultyId, 'sweat');

    // With no sets yet, a change makes today's workout again.
    final (fresh, _) = await _store(setUp: true);
    fresh.swap(0, 1);
    fresh.setProfile(gym);
    expect(fresh.todayExercises.first.exerciseId, startsWith('cablemancer.'));
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

  test('XP: sets (over target, criticals), first set of the day, streak bonus', () async {
    final (store, _) = await _store(setUp: true);
    for (var i = 0; i < 7; i++) {
      store.addSet(0); // target 3: sets 4-6 ×1.5, set 7 gives 0
    }
    int expected(Session s, int streak) => [
          for (final e in s.exercises)
            for (var n = 1; n <= e.sets; n++)
              xpForSet(
                  setNumber: n,
                  target: e.targetSets,
                  difficulty: _d,
                  critical: isCritical(s.date, e.exerciseId, n),
                  streakWeeks: streak),
        ].fold(0, (a, b) => a + b);
    final sat = store.todaySession!;
    expect(store.xpEvents.where((e) => e.source == 'sets').single.amount, expected(sat, 0));
    expect(store.xpEvents.where((e) => e.source == 'day').single.amount, xpFirstSetOfDay);
    expect(store.cardXp(0), expected(sat, 0));
    expect(store.thisWeek, (days: 1, n: 2));
    expect(store.streakWeeks, 0);

    // Sunday: 2nd training day this week -> a streak week.
    _now = DateTime(2026, 11, 22, 9);
    store.addSet(0);
    expect(store.thisWeek, (days: 2, n: 2));
    expect(store.streakWeeks, 1);

    // Next week: Monday and Friday (missed days in between do not matter).
    // Their sets get the +5% bonus for one streak week in a row.
    _now = DateTime(2026, 11, 23, 9);
    expect(store.streakBonusWeeks, 1);
    for (var i = 0; i < 4; i++) {
      store.addSet(0);
    }
    expect(store.streakWeeks, 1); // last week still stands
    _now = DateTime(2026, 11, 27, 9);
    store.addSet(0);
    expect(store.streakWeeks, 2);

    final s = store.sessions;
    final achievementXp = store.xpEvents.where((e) => e.source == 'achievement').fold(0, (a, e) => a + e.amount);
    expect(
        store.totalXp,
        expected(s['2026-11-21']!, 0) +
            expected(s['2026-11-22']!, 0) +
            expected(s['2026-11-23']!, 1) +
            expected(s['2026-11-27']!, 1) +
            4 * xpFirstSetOfDay +
            achievementXp);
    final streakXp = store.xpEvents.where((e) => e.source == 'streak').fold(0, (a, e) => a + e.amount);
    expect(streakXp, expected(s['2026-11-23']!, 1) + expected(s['2026-11-27']!, 1)
        - expected(s['2026-11-23']!, 0) - expected(s['2026-11-27']!, 0));

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

    for (var i = 1; levelFor(store.totalXp).level < 3; i = i % 3 + 1) {
      store.addSet(i); // spread over cards: sets beyond 2× target give no XP
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
    expect(other.profile!.classId, 'paladin');
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
    expect(find.text('CHARACTER · STEP 1 OF 5'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('old data: NOT NOW keeps it and goes to the setup', (t) async {
    _phone(t);
    final (store, prefs) = await _store(old: true);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    await t.tap(find.text('NOT NOW'));
    await _frames(t);
    expect(find.text('CHARACTER · STEP 1 OF 5'), findsOneWidget);
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
    expect(find.text('CHARACTER · STEP 1 OF 5'), findsOneWidget);
    expect(_spriteAsset(t), 'male/fat50_muscle50');

    await t.drag(find.byKey(const ValueKey('slider-MUSCLE')), const Offset(400, 0));
    await _frames(t, 4);
    expect(_spriteAsset(t), 'male/fat50_muscle100');
    await t.drag(find.byKey(const ValueKey('slider-FAT %')), const Offset(-400, 0));
    await _frames(t, 4);
    expect(_spriteAsset(t), 'male/fat0_muscle100');
    await t.tap(find.byKey(const ValueKey('sex-female')));
    await _frames(t, 4);
    expect(_spriteAsset(t), 'female/fat0_muscle100');
    final short = t.getSize(find.byKey(const ValueKey('character-sprite'))).height;
    await t.drag(find.byKey(const ValueKey('slider-HEIGHT')), const Offset(400, 0));
    await _frames(t, 8);
    expect(t.getSize(find.byKey(const ValueKey('character-sprite'))).height, greaterThan(short));

    await t.tap(find.text('NEXT'));
    await t.pump(const Duration(milliseconds: 200));
    // Mid-transition: both scenes are on screen (no blank frame).
    expect(find.text('BUILD YOUR LIFTER'), findsOneWidget);
    expect(find.text('CHOOSE YOUR PATH'), findsWidgets);
    await _frames(t);
    expect(find.text('BUILD YOUR LIFTER'), findsNothing);
    expect(find.text('CLASS · STEP 2 OF 5'), findsOneWidget);

    // Class select: one class per equipment type; a pick shows the
    // freeze-frame intro card and the frozen (greyscale) character.
    expect(find.text('LOTS OF FREE WEIGHTS'), findsOneWidget);
    await t.ensureVisible(find.byKey(const ValueKey('path-paladin')));
    await _frames(t, 4);
    await t.tap(find.byKey(const ValueKey('path-paladin')));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('intro-card')), findsOneWidget);
    expect(find.text('OATH-SWORN TO THE BARBELL'), findsOneWidget);
    expect(
      find.ancestor(of: find.byKey(const ValueKey('character-sprite')), matching: find.byType(ColorFiltered)).evaluate()
          .any((e) => (e.widget as ColorFiltered).colorFilter == freezeFilter),
      isTrue,
    );
    await t.pump(introHold);
    await _frames(t, 4);
    expect(find.byKey(const ValueKey('intro-card')), findsNothing); // closes by itself
    expect(find.text('A BARBELL, A RACK AND A WALL OF PLATES.'.toLowerCase()), findsNothing);
    expect(find.text('A barbell, a rack and a wall of plates.'), findsOneWidget); // loadout
    expect(find.text('STRONGMAN'), findsOneWidget); // tags
    await t.ensureVisible(find.byKey(const ValueKey('path-cablemancer')));
    await t.tap(find.byKey(const ValueKey('path-cablemancer')));
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.byKey(const ValueKey('intro-card'))); // closes on a tap
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('intro-card')), findsNothing);
    await t.tap(find.byKey(const ValueKey('path-paladin')));
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.text('NEXT: DIFFICULTY'));
    await _frames(t);
    expect(find.byKey(const ValueKey('intro-card')), findsNothing);
    expect(find.text('HOW HARD DO YOU GO?'), findsWidgets);
    await t.tap(find.byKey(const ValueKey('difficulty-sweat')));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('TOWEL STRONGLY RECOMMENDED'), findsOneWidget); // title card
    expect(find.text('DIFFICULTY 3 OF 6'), findsOneWidget);
    await t.tap(find.text('NEXT: STARTING AREA'));
    await _frames(t);
    expect(find.text("YOUR PATH'S HOME"), findsOneWidget); // Plate Paladin -> Gainsgard Keep
    await t.tap(find.byKey(const ValueKey('area-castle')));
    await t.tap(find.text('NEXT: READY?'));
    await _frames(t);
    expect(find.text('SWEAT MODE'), findsOneWidget);
    await t.tap(find.text("LET'S GO!!!"));
    await _frames(t, 70); // welcome burst

    final saved = Profile.fromJson(jsonDecode(prefs.getString('profile_v1')!) as Map<String, dynamic>);
    expect(saved.character, const Character(sex: 'female', height: 100, muscle: 100, fat: 0));
    expect((saved.classId, saved.difficultyId, saved.areaId, saved.schemaVersion), ('paladin', 'sweat', 'castle', 1));
    expect(find.text('NEXT WORKOUT'), findsOneWidget);
    expect(find.text(exerciseName(store.todayExercises.first.exerciseId).toUpperCase()), findsOneWidget);
    expect(find.textContaining('THIS WEEK 0/2 DAYS'), findsOneWidget);
    expect(pushes.pushes, 1); // only the home route: views never push routes
  });

  testWidgets('workout: tap adds a working set, long-press takes one away', (t) async {
    _phone(t);
    final (store, _) = await _store(setUp: true);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    expect(find.text('TRAIN'), findsOneWidget);
    expect(find.text('START TRAINING ▶'), findsNothing);
    expect(find.text('I WORKED 💪'), findsNothing);

    await t.tap(find.byKey(const ValueKey('hub-workout')));
    await _frames(t);
    final card = find.byKey(const ValueKey('world-object'));
    await t.tap(card);
    await _frames(t, 70); // level-up intro card and achievement burst
    for (var i = 0; i < 5; i++) {
      // A level-up card closes on the next tap: close it first.
      if (find.byKey(const ValueKey('intro-card')).evaluate().isNotEmpty) {
        await t.tap(find.byKey(const ValueKey('intro-card')));
        await t.pump(const Duration(milliseconds: 80));
      }
      await t.tap(card);
      await t.pump(const Duration(milliseconds: 80));
    }
    if (find.byKey(const ValueKey('intro-card')).evaluate().isNotEmpty) {
      await t.tap(find.byKey(const ValueKey('intro-card')));
      await t.pump(const Duration(milliseconds: 80));
    }
    // At the target the strip moved on; go back to the first exercise.
    await _frames(t, 20);
    expect(find.descendant(of: find.byKey(const ValueKey('strip-1')), matching: find.text('NOW')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('strip-0')));
    await _frames(t, 4);
    await t.longPress(card);
    await _frames(t, 70);
    expect(store.todayExercises[0].sets, 5);
    expect(find.textContaining('5/3'), findsOneWidget);
    expect(find.textContaining('+${store.cardXp(0)} XP'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('workout-hub')));
    await _frames(t);
    expect(find.text('KEEP GOING'), findsOneWidget);
    expect(find.text('ON · 5 SETS'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('hub-past')));
    await _frames(t);
    expect(find.textContaining('TODAY · '), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('history-hub')));
    await _frames(t, 70);
    expect(t.takeException(), isNull);
  });

  testWidgets('workout tools: swap, back to first, skip, add and remove exercises', (t) async {
    _phone(t);
    final (store, _) = await _store(setUp: true);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    await t.tap(find.byKey(const ValueKey('hub-workout')));
    await _frames(t);
    final first = store.todayExercises[0].exerciseId;

    await t.tap(find.byKey(const ValueKey('tool-swap')));
    await _frames(t, 10);
    expect(store.todayExercises[0].switched, isTrue);
    expect(find.textContaining(exerciseName(store.todayExercises[0].exerciseId).toUpperCase()), findsWidgets);
    await t.tap(find.byKey(const ValueKey('tool-first')));
    await _frames(t, 10);
    expect(store.todayExercises[0].exerciseId, first);
    expect(find.byKey(const ValueKey('tool-first')), findsNothing);

    await t.tap(find.byKey(const ValueKey('world-object')));
    await _frames(t, 70); // achievement burst
    await t.tap(find.byKey(const ValueKey('tool-swap')));
    await _frames(t, 10);
    expect(store.todayExercises[0].exerciseId, first);
    expect(find.textContaining('SETS ALREADY DONE HERE'), findsOneWidget);
    await _frames(t, 110); // the message goes away

    // Skip the second exercise: the next open one becomes active.
    await t.tap(find.byKey(const ValueKey('strip-1')));
    await _frames(t, 4);
    await t.tap(find.byKey(const ValueKey('tool-skip')));
    await _frames(t, 4);
    expect(find.descendant(of: find.byKey(const ValueKey('strip-1')), matching: find.text('SKIPPED')), findsOneWidget);
    expect(store.todayExercises[1].sets, 0);

    final n = store.todayCards.length;
    await t.dragUntilVisible(find.byKey(const ValueKey('strip-add')), find.byKey(const ValueKey('strip-0')), const Offset(-150, 0));
    await _frames(t, 4);
    await t.tap(find.byKey(const ValueKey('strip-add')));
    await _frames(t, 20);
    final extra = store.unusedExercises.first;
    await t.tap(find.byKey(ValueKey('add-${extra.id}')));
    await _frames(t, 20);
    expect(store.todayCards.length, n + 1);

    // The added card is active; remove it.
    await t.tap(find.byKey(const ValueKey('tool-remove')));
    await _frames(t, 10);
    expect(store.todayCards.length, n);
    expect(find.textContaining('REMOVED'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('tap the character on the hub to edit the body sliders', (t) async {
    _phone(t);
    final (store, _) = await _store(setUp: true);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    await t.tap(find.byKey(const ValueKey('hub-character')));
    await _frames(t);
    expect(find.text('CHARACTER · STEP 1 OF 5'), findsOneWidget);
    await t.drag(find.byKey(const ValueKey('slider-FAT %')), const Offset(400, 0));
    await t.tap(find.text('NEXT'));
    await _frames(t);
    await t.tap(find.text('SAVE'));
    await _frames(t);
    expect(store.profile!.character.fat, 100);
    expect(store.bodyHistory.last.character.fat, 100);
    expect(find.text('NEXT WORKOUT'), findsOneWidget);
  });

  testWidgets('a level-up shows the freeze-frame card; gear unlocks and can be equipped', (t) async {
    _phone(t);
    final (store, _) = await _store(setUp: true);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    await t.tap(find.byKey(const ValueKey('hub-workout')));
    await _frames(t);
    await t.tap(find.byKey(const ValueKey('world-object'))); // first set: +50 and more
    await t.pump(const Duration(milliseconds: 600));
    final level = levelFor(store.totalXp).level;
    expect(level, greaterThan(1));
    expect(find.byKey(const ValueKey('intro-card')), findsOneWidget);
    expect(find.text('LEVEL $level'), findsOneWidget);
    await _frames(t, 70);
    expect(find.byKey(const ValueKey('intro-card')), findsNothing);
    expect(store.gear.owned, contains('head.sweatband'));

    await t.tap(find.byKey(const ValueKey('workout-hub')));
    await _frames(t);
    await t.tap(find.byKey(const ValueKey('hub-gear')));
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
    expect(find.byKey(const ValueKey('workout-hub')), findsOneWidget);
    await t.binding.handlePopRoute();
    await _frames(t);
    expect(find.byKey(const ValueKey('workout-hub')), findsNothing);
    expect(find.text('TRAIN'), findsOneWidget);
  });

  testWidgets('CEL SHADER toggles from the menu, is remembered, keeps the scene', (t) async {
    _phone(t);
    final (store, prefs) = await _store(setUp: true);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);

    Future<void> menu(String key, {bool close = true}) async {
      await t.tap(find.byKey(const ValueKey('menu-open')));
      await _frames(t, 10); // let the menu slide in
      // Scroll the item clear of a snack bar at the bottom.
      await t.ensureVisible(find.byKey(ValueKey(key)));
      await t.drag(find.byType(ListView).last, const Offset(0, -200));
      await _frames(t, 4);
      await t.tap(find.byKey(ValueKey(key)));
      await _frames(t, 10);
      if (close) {
        await t.tap(find.byKey(const ValueKey('menu-open'))); // the top-bar ✕
        await _frames(t, 10);
      }
    }

    await menu('menu-cel');
    expect(store.cel.value, isTrue);
    expect(prefs.getBool('cel'), isTrue);
    expect(find.byType(CelFilter), findsOneWidget);
    expect(find.text('NEXT WORKOUT'), findsOneWidget);
    await menu('menu-cel');
    expect(store.cel.value, isFalse);
    await menu('menu-chaos');
    expect(store.chaos.value, isTrue);
    await menu('menu-edit', close: false);
    expect(find.text('CHARACTER · STEP 1 OF 5'), findsOneWidget);
    expect(_spriteAsset(t), spriteFrame(_profile.character));
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
      await tapAndSettle(find.byKey(const ValueKey('workout-hub')));
      await tapAndSettle(find.byKey(const ValueKey('hub-past')));
      await tapAndSettle(find.byKey(const ValueKey('history-hub')));
      await tapAndSettle(find.byKey(const ValueKey('hub-gear')));
      await tapAndSettle(find.byKey(const ValueKey('gear-hub')));
      // Profile (design screen 11): change one setup step, then back.
      await tapAndSettle(find.byKey(const ValueKey('hub-profile')));
      expect(find.text('THE PATH'), findsOneWidget);
      await tapAndSettle(find.byKey(const ValueKey('profile-difficulty')));
      expect(find.text('DIFFICULTY · STEP 3 OF 5'), findsOneWidget);
      await tapAndSettle(find.text('NEXT'));
      await tapAndSettle(find.text('SAVE'));
      await tapAndSettle(find.byKey(const ValueKey('hub-profile')));
      await tapAndSettle(find.byKey(const ValueKey('profile-back')));
      // Menu (design screen 12).
      await tapAndSettle(find.byKey(const ValueKey('menu-open')));
      expect(find.text('GAINS INSURANCE'), findsOneWidget);
      await tapAndSettle(find.byKey(const ValueKey('menu-profile')));
      await tapAndSettle(find.byKey(const ValueKey('profile-back')));
      await tapAndSettle(find.byKey(const ValueKey('menu-open')));
      await tapAndSettle(find.byKey(const ValueKey('menu-edit')));
      await tapAndSettle(find.text('NEXT')); // editing: straight to the summary
      await tapAndSettle(find.text('CLASS'));
      await tapAndSettle(find.byKey(const ValueKey('path-bruiser')));
      await t.pump(introHold);
      await tapAndSettle(find.text('NEXT'));
      await tapAndSettle(find.text('DIFFICULTY'));
      await tapAndSettle(find.text('NEXT'));
      await tapAndSettle(find.text('AREA'));
      await tapAndSettle(find.text('NEXT'));
      await tapAndSettle(find.text('SAVE'));
      expect(find.text('NEXT WORKOUT'), findsOneWidget);
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
