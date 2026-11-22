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
  difficultyId: 'sweat', // 4 exercises, 3 target sets, ×1.4
  areaId: 'gainsgard',
);
const _d = 2; // difficulty index of 'sweat'

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

/// A set-up app on a phone, on the hub.
Future<(LogStore, SharedPreferences)> _openApp(WidgetTester t) async {
  _phone(t);
  final (store, prefs) = await _store(setUp: true);
  await t.pumpWidget(GymApp(store: store));
  await _frames(t);
  return (store, prefs);
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

  test('area id migration (D36): old ids become design ids once, old text kept', () async {
    const oldProfile = '{"classId":"scrapper","difficultyId":"sofa","areaId":"beach","character":{}}';
    const oldSessions = '{"2026-11-20":{"classId":"scrapper","difficultyId":"sofa","areaId":"summit",'
        '"exercises":[{"position":0,"exerciseId":"scrapper.pushup","originalExerciseId":"scrapper.pushup",'
        '"targetSets":2,"sets":1}]},"2026-11-19":{"classId":"scrapper","difficultyId":"sofa","areaId":"castle",'
        '"exercises":[{"position":0,"exerciseId":"scrapper.pushup","originalExerciseId":"scrapper.pushup",'
        '"targetSets":2,"sets":1}]}}';
    SharedPreferences.setMockInitialValues({'profile_v1': oldProfile, 'sessions_v3': oldSessions});
    final prefs = await SharedPreferences.getInstance();
    final store = LogStore(prefs, clock: () => _now);
    expect(store.profile!.areaId, 'riptide');
    expect({for (final s in store.history) s.date: s.areaId}, {'2026-11-20': 'frostbite', '2026-11-19': 'gainsgard'});
    for (final old in ['beach', 'castle', 'summit']) {
      expect('${prefs.getString('profile_v1')}${prefs.getString('sessions_v3')}', isNot(contains('"$old"')));
    }
    final backup = jsonDecode(prefs.getString(LogStore.areaIdBackupKey)!) as Map;
    expect((backup['profile'], backup['sessions']), (oldProfile, oldSessions));
    expect(prefs.containsKey(LogStore.classIdBackupKey), isFalse); // the class ids were new already
    expect(LogStore(prefs, clock: () => _now).profile!.areaId, 'riptide');
    expect(newAreaId('arcade'), 'arcade');
    expect(areas.map((a) => a.id), ['riptide', 'gainsgard', 'rustbelt', 'arcade', 'frostbite']);
  });

  test('no streak (D34): the old streak bonus is saved once as XP, nothing is lost', () async {
    // Sweat Mode: 2 training days a week made a streak week. 9 + 10 Nov is
    // a streak week, so the session on 16 Nov had +5% set XP.
    Map<String, Object> day(int sets) => {
          'classId': 'paladin',
          'difficultyId': 'sweat',
          'areaId': 'gainsgard',
          'exercises': [
            {'position': 0, 'exerciseId': 'paladin.squat', 'originalExerciseId': 'paladin.squat', 'targetSets': 3, 'sets': sets},
          ],
        };
    final sessions = {'2026-11-09': day(2), '2026-11-10': day(2), '2026-11-16': day(5)};
    SharedPreferences.setMockInitialValues({
      'profile_v1': jsonEncode(_profile.toJson()),
      'sessions_v3': jsonEncode(sessions),
      'achievements_v1': '{"first_set":"2026-11-09T10:00:00"}',
      'xp_events_v1': jsonEncode([
        {'at': '2026-11-09T10:00:00', 'source': 'achievement', 'amount': 25, 'ref': 'first_set'},
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final store = LogStore(prefs, clock: () => _now);
    var bonus = 0, sets = 0;
    for (var n = 1; n <= 5; n++) {
      final xp = setXp(setNumber: n, target: 3, difficulty: _d, critical: isCritical('2026-11-16', 'paladin.squat', n));
      bonus += (xp * 1.05).round() - xp.round();
      sets += xp.round();
    }
    expect(bonus, greaterThan(0));
    final streak = store.xpEvents.where((e) => e.source == 'streak').toList();
    expect((streak.single.ref, streak.single.amount), ('2026-11-16', bonus));
    expect(store.xpOfSession(store.sessions['2026-11-16']!), sets + xpFirstSetOfDay + bonus);
    // Achievement XP stays; the achievements list is gone (D35).
    expect(store.xpEvents.where((e) => e.source == 'achievement').single.amount, 25);
    expect(prefs.containsKey('achievements_v1'), isFalse);
    // A second launch adds nothing; new sessions get no streak bonus.
    final total = store.totalXp;
    final again = LogStore(prefs, clock: () => _now);
    expect(again.totalXp, total);
    expect(prefs.getBool(LogStore.streakFrozenKey), isTrue);
    again.addSet(0);
    expect(again.xpEvents.where((e) => e.source == 'streak').length, 1);

    // A version-3 backup (made before D34) gets its streak XP worked out on import.
    final v3 = jsonEncode({'app': 'pumplex', 'version': 3, 'sessions_v3': sessions, 'achievements_v1': {'first_set': 'x'}});
    await again.importBackup(v3);
    expect(again.xpEvents.where((e) => e.source == 'streak').single.amount, bonus);
    expect(jsonDecode(again.backupJson()), isNot(contains('achievements_v1')));
  });

  // ------------------------------------------------------------ fixed data

  test('rules table: set XP, over target, cap, critical, level curve', () {
    expect(difficultyRules.first.xpMultiplier, 1.0);
    expect(difficultyRules.last.xpMultiplier, 2.0);
    int set(int n, {bool crit = false, int d = 0}) => xpForSet(setNumber: n, target: 3, difficulty: d, critical: crit);
    expect(set(3), 10); // within the target
    expect(set(4), 15); // above the target: ×1.5
    expect(set(6), 15); // up to 2× the target
    expect(set(7), 0); // beyond 2× the target
    expect(set(1, crit: true), 20);
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
    expect([for (final r in difficultyRules) r.exercisesPerWorkout], [3, 3, 4, 5, 6, 8]); // D33
    expect(gameClasses.map((c) => c.equipment).toSet().length, gameClasses.length);
    expect(gameClasses.every((c) => c.exercises.length >= 8), isTrue); // enough for Nightmare Mode
    final ids = [for (final c in gameClasses) for (final e in c.exercises) e.id];
    expect(ids.toSet().length, ids.length);
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
    expect(defaultAreaFor('paladin').id, 'gainsgard');
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
    store.addSet(0); // level-ups happen here, not on screen
    store.addSet(0);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    expect(find.text('SCRATCH THE WALL'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('world-object'))); // 3rd set = target
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('CRUSHED!'), findsOneWidget);
    await _frames(t, 40);
    await t.tap(find.byKey(const ValueKey('exercise-dot-0'))); // back to the first exercise
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
    expect(allSpriteAssets.where((a) => a.contains('gear')), isEmpty); // no gear (D38)
  });

  test('head looks: saved, old data gets the defaults, layers pick the atlases', () {
    const c = Character(skin: 'deep', hair: 'blonde', facialHair: 'beard');
    expect(Character.fromJson(c.toJson()), c);
    final old = Character.fromJson({'sex': 'male', 'height': 10, 'muscle': 20, 'fat': 30});
    expect((old.skin, old.hair, old.facialHair), ('light', 'brown', 'none'));
    expect(Character.fromJson({'skin': 'green', 'hair': 7}).skin, 'light'); // unknown ids fall back
    expect(spriteLayers(const Character(), 'paladin'), [bodyAtlas, 'assets/outfits/paladin.png']);
    expect(spriteLayers(c, 'paladin'),
        ['assets/body/looks/body_deep_blonde.png', 'assets/body/looks/beard_blonde.png', 'assets/outfits/paladin.png']);
    expect(allSpriteAssets, containsAll(['assets/body/looks/body_light_blonde.png', 'assets/body/looks/beard_brown.png']));
    expect((heightMetres(0), heightMetres(100), weightKg(0), weightKg(100)), (1.5, 2.0, 50, 200));
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
    expect((s.classId, s.difficultyId, s.areaId, s.legacy), ('paladin', 'sweat', 'gainsgard', false));
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
    store.addSet(0); // a set taken back: a session with no sets
    store.removeSet(0);
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

  test('class, difficulty and area can change; each session keeps its own', () async {
    final (store, _) = await _store(setUp: true);
    store.addSet(0);
    final xp = store.totalXp;
    const gym = Profile(character: Character(), classId: 'cablemancer', difficultyId: 'nightmare', areaId: 'riptide');
    store.setProfile(gym);
    expect((store.todaySession!.classId, store.todaySession!.areaId), ('paladin', 'gainsgard'));
    expect(store.totalXp, xp);
    _now = _now.add(const Duration(days: 1));
    expect(store.todayExercises.length, 8);
    expect(store.todayExercises.first.exerciseId, startsWith('cablemancer.'));
    store.addSet(0);
    expect(store.todaySession!.areaId, 'riptide');
    expect(store.sessions['2026-11-21']!.difficultyId, 'sweat');

    // With no sets yet, a change makes today's workout again.
    final (fresh, _) = await _store(setUp: true);
    fresh.addSet(0);
    fresh.removeSet(0);
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

  test('XP: sets (over target, criticals) and the first set of the day; no streak', () async {
    final (store, _) = await _store(setUp: true);
    for (var i = 0; i < 7; i++) {
      store.addSet(0); // target 3: sets 4-6 ×1.5, set 7 gives 0
    }
    int expected(Session s) => [
          for (final e in s.exercises)
            for (var n = 1; n <= e.sets; n++)
              xpForSet(setNumber: n, target: e.targetSets, difficulty: _d, critical: isCritical(s.date, e.exerciseId, n)),
        ].fold(0, (a, b) => a + b);
    final sat = store.todaySession!;
    expect(store.xpEvents.where((e) => e.source == 'sets').single.amount, expected(sat));
    expect(store.xpEvents.where((e) => e.source == 'day').single.amount, xpFirstSetOfDay);
    expect(store.cardXp(0), expected(sat));

    // Training days in later weeks give no extra XP (D34).
    for (final d in [22, 23, 27, 30]) {
      _now = DateTime(2026, 11, d, 9);
      store.addSet(0);
    }
    final s = store.sessions.values;
    expect(store.totalXp, s.fold(0, (a, x) => a + expected(x)) + s.length * xpFirstSetOfDay);
    expect(store.xpEvents.where((e) => e.source == 'streak' || e.source == 'achievement'), isEmpty);
    for (final x in s) {
      expect(store.xpOfSession(x), expected(x) + xpFirstSetOfDay);
    }
  });

  test('removed features (D35, D38-D41): their saved keys are deleted on start', () async {
    SharedPreferences.setMockInitialValues({
      'profile_v1': jsonEncode(_profile.toJson()),
      'gear_v1': '{"owned":["head.crown"],"equipped":{"head":"head.crown"}}',
      'achievements_v1': '{}',
      'chaos': true,
      'cel': true,
      'sound': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final store = LogStore(prefs, clock: () => _now);
    expect(store.profile, isNotNull);
    for (final k in LogStore.removedKeys) {
      expect(prefs.containsKey(k), isFalse, reason: k);
    }
    expect(jsonDecode(store.backupJson()), isNot(contains('gear_v1')));
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

    await store.migrateOld(); // running it again changes nothing
    expect(store.xpEvents.where((e) => e.source == 'legacy').length, _oldWorkoutDates);
  });

  test('backups: everything round-trips; old version-2 backups go through the migration', () async {
    final (store, _) = await _store(setUp: true);
    store.setProfile(_profile);
    store.addSet(0);
    _now = _now.add(const Duration(days: 1));
    store.addSet(1);
    final backup = store.backupJson();
    final data = jsonDecode(backup) as Map;
    expect(data['version'], 5);
    expect(data.keys, containsAll(['profile_v1', 'body_history_v1', 'sessions_v3', 'xp_events_v1']));

    final (other, otherPrefs) = await _store(old: true); // un-migrated old data on this phone
    await other.importBackup(backup);
    expect(other.profile!.classId, 'paladin');
    expect(other.sessions.length, 2);
    expect(other.bodyHistory.length, 1);
    expect(other.todaySession!.exercises[1].sets, 1);
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
    expect(_spriteAsset(t), 'male/fat50_muscle50');
    expect(find.byKey(const ValueKey('menu-open')), findsNothing); // no menu on the first setup
    expect(find.byIcon(Icons.casino), findsNothing);
    expect(find.text('1.50 M · 2.00 M'), findsNothing); // only the current value
    expect(find.text('50 KG · 200 KG'), findsNothing);
    expect(find.textContaining('TAP THE HEAD'), findsNothing);
    expect(find.byKey(const ValueKey('head-outline')), findsOneWidget);
    expect(find.text('1.75 M'), findsOneWidget);
    expect(find.text('125 KG'), findsOneWidget);

    await t.drag(find.byKey(const ValueKey('slider-MUSCLE')), const Offset(400, 0));
    await _frames(t, 4);
    expect(_spriteAsset(t), 'male/fat50_muscle100');
    await t.drag(find.byKey(const ValueKey('slider-WEIGHT')), const Offset(-400, 0));
    await _frames(t, 4);
    expect(_spriteAsset(t), 'male/fat0_muscle100');
    await t.tap(find.byKey(const ValueKey('sex-female')));
    await _frames(t, 4);
    expect(_spriteAsset(t), 'female/fat0_muscle100');
    expect(find.text('50 KG'), findsOneWidget);
    final short = t.getSize(find.byKey(const ValueKey('character-sprite')));
    await t.drag(find.byKey(const ValueKey('slider-HEIGHT')), const Offset(400, 0));
    await _frames(t, 8);
    final tall = t.getSize(find.byKey(const ValueKey('character-sprite')));
    expect(find.text('2.00 M'), findsOneWidget);
    expect(tall.height, greaterThan(short.height));
    expect(tall.width / tall.height, closeTo(short.width / short.height, 0.01)); // scaled, not stretched

    // Tap the head: the camera zooms in, the panel has skin, hair and facial hair.
    await t.tap(find.byKey(const ValueKey('creator-head')));
    await _frames(t, 30);
    expect(find.text('YOUR HEAD'), findsOneWidget);
    expect(find.byKey(const ValueKey('head-outline')), findsNothing);
    expect(find.text('BUILD YOUR LIFTER'), findsNothing);
    for (final k in ['look-skin-deep', 'look-hair-blonde', 'look-facial-beard']) {
      await t.tap(find.byKey(ValueKey(k)));
      await _frames(t, 4);
    }
    final layers = t.widgetList<AtlasSprite>(find.byType(AtlasSprite)).map((a) => a.asset).toList();
    expect(layers, containsAll(['assets/body/looks/body_deep_blonde.png', 'assets/body/looks/beard_blonde.png']));
    await t.tap(find.text('DONE'));
    await _frames(t, 30);
    expect(find.text('BUILD YOUR LIFTER'), findsOneWidget);

    await t.tap(find.text('NEXT'));
    await t.pump(const Duration(milliseconds: 200));
    // Mid-transition: both scenes are on screen (no blank frame).
    expect(find.text('BUILD YOUR LIFTER'), findsOneWidget);
    expect(find.byKey(const ValueKey('class-card')), findsOneWidget);
    await _frames(t);
    expect(find.text('BUILD YOUR LIFTER'), findsNothing);
    expect(find.text('CLASS · STEP 2 OF 4'), findsOneWidget);

    // Class select (D46): one big card; swipe it to change the class, both
    // ways and round and round. No class buttons, no freeze-frame card.
    final classCard = find.byKey(const ValueKey('class-card'));
    String shown() => t.widgetList<Text>(find.descendant(of: classCard, matching: find.byType(Text)))
        .map((w) => w.data).firstWhere((s) => gameClasses.any((c) => c.name.toUpperCase() == s))!;
    expect(find.byKey(const ValueKey('path-paladin')), findsNothing);
    expect(shown(), 'SCRAPPER');
    expect(find.text('NO EQUIPMENT'), findsOneWidget);
    expect(find.text(classById('scrapper').style), findsOneWidget); // the description is in the card
    await t.fling(classCard, const Offset(-300, 0), 1000); // swipe left: next
    await _frames(t, 10);
    expect(shown(), 'BARGAIN BRUISER');
    expect(find.byKey(const ValueKey('intro-card')), findsNothing);
    await t.fling(classCard, const Offset(300, 0), 1000); // swipe right: back
    await _frames(t, 10);
    await t.fling(classCard, const Offset(300, 0), 1000); // and round to the last one
    await _frames(t, 10);
    expect(shown(), 'CABLEMANCER');
    await t.fling(classCard, const Offset(-300, 0), 1000); // and round to the first
    await _frames(t, 10);
    expect(shown(), 'SCRAPPER');
    await t.tap(find.byKey(const ValueKey('class-dot-paladin')));
    await _frames(t, 10);
    expect(shown(), 'PLATE PALADIN');
    expect(find.text('LOTS OF FREE WEIGHTS'), findsOneWidget);
    expect(find.text('A barbell, a rack and a wall of plates.'), findsOneWidget); // loadout
    expect(find.text('STRONGMAN'), findsOneWidget); // tags
    expect(find.byKey(const ValueKey('intro-card')), findsNothing);
    // Difficulty (D47): a slider on the class step, the mode name on the right.
    // No titles in the view, no freeze-frame card.
    expect(find.text('CHOOSE YOUR PATH'), findsNothing);
    expect(find.text('HOW HARD DO YOU GO?'), findsNothing);
    t.widget<Slider>(find.byKey(const ValueKey('slider-DIFFICULTY'))).onChanged!(2);
    await _frames(t, 4);
    expect(find.text('SWEAT MODE'), findsOneWidget);
    expect(find.byKey(const ValueKey('intro-card')), findsNothing);
    await t.tap(find.text('NEXT: STARTING AREA'));
    await _frames(t);
    expect(find.text('STARTING AREA · STEP 3 OF 4'), findsOneWidget);
    // Area (D47): one card like the class card; swipe it, round and round.
    // Plate Paladin's default area shows first.
    final areaCard = find.byKey(const ValueKey('area-card'));
    expect(find.text('GAINSGARD KEEP'), findsOneWidget);
    expect(find.text("YOUR PATH'S HOME"), findsOneWidget);
    expect(find.text('SCRATCH THE WALL'), findsOneWidget);
    await t.fling(areaCard, const Offset(-300, 0), 1000);
    await _frames(t, 10);
    expect(find.text('RUSTBELT FLATS'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('area-dot-riptide')));
    await _frames(t, 10);
    expect(find.text('RIPTIDE SHORE'), findsOneWidget);
    await t.fling(areaCard, const Offset(300, 0), 1000); // round to the last one
    await _frames(t, 10);
    expect(find.text('FROSTBITE SUMMIT'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('area-dot-gainsgard')));
    await _frames(t, 10);
    await t.tap(find.text('NEXT: READY?'));
    await _frames(t);
    expect(find.text('SWEAT MODE'), findsOneWidget);
    await t.tap(find.text("LET'S GO!!!"));
    await _frames(t, 70); // welcome burst

    final saved = Profile.fromJson(jsonDecode(prefs.getString('profile_v1')!) as Map<String, dynamic>);
    expect(saved.character,
        const Character(sex: 'female', height: 100, muscle: 100, fat: 0, skin: 'deep', hair: 'blonde', facialHair: 'beard'));
    expect((saved.classId, saved.difficultyId, saved.areaId, saved.schemaVersion), ('paladin', 'sweat', 'gainsgard', 1));
    expect(find.byKey(const ValueKey('world-object')), findsOneWidget); // the workout is home (D49)
    expect(find.text(exerciseName(store.todayExercises.first.exerciseId).toUpperCase()), findsOneWidget);
    expect(find.textContaining('THIS WEEK'), findsNothing); // no streak (D34)
    expect(pushes.pushes, 1); // only the home route: views never push routes
  });

  testWidgets('workout: tap adds a working set, long-press takes one away', (t) async {
    final (store, _) = await _openApp(t);
    expect(find.byKey(const ValueKey('world-object')), findsOneWidget); // the app opens on the workout
    expect(find.text('TRAIN'), findsNothing);
    expect(find.text('START TRAINING ▶'), findsNothing);
    expect(find.text('I WORKED 💪'), findsNothing);

    final card = find.byKey(const ValueKey('world-object'));
    await t.tap(card);
    await _frames(t, 70); // level-up intro card
    // A level-up card closes on the next tap: close it first.
    Future<void> closeCard() async {
      if (find.byKey(const ValueKey('intro-card')).evaluate().isNotEmpty) {
        await t.tap(find.byKey(const ValueKey('intro-card')));
        await t.pump(const Duration(milliseconds: 80));
      }
    }

    for (var i = 0; i < 5; i++) {
      await closeCard();
      await t.tap(card);
      await t.pump(const Duration(milliseconds: 80));
    }
    await closeCard();
    // At the target the strip moved on; go back to the first exercise.
    await _frames(t, 20);
    expect(find.byKey(const ValueKey('exercise-1')), findsOneWidget); // the carousel moved on
    await t.tap(find.byKey(const ValueKey('exercise-dot-0')));
    await _frames(t, 4);
    await t.longPress(card);
    await _frames(t, 70);
    expect(store.todayExercises[0].sets, 5);
    expect(find.textContaining('5/3'), findsOneWidget);
    expect(find.textContaining('+${store.cardXp(0)} XP'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('nav-hub')));
    await _frames(t);
    expect(find.text('KEEP GOING'), findsNothing); // no hub (D49)
    expect(store.todaySession!.totalSets, 5);

    await t.tap(find.byKey(const ValueKey('nav-history')));
    await _frames(t);
    expect(find.textContaining('TODAY · '), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('nav-hub')));
    await _frames(t, 70);
    expect(t.takeException(), isNull);
  });

  testWidgets('workout: no tools, no add card; the hub and profile show no streak or milestones', (t) async {
    await _openApp(t);
    expect(find.text('THIS WEEK'), findsNothing);
    for (final k in ['tool-swap', 'tool-first', 'tool-skip', 'tool-remove', 'strip-add']) {
      expect(find.byKey(ValueKey(k)), findsNothing, reason: k);
    }
    expect(find.byKey(const ValueKey('exercise-dot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('world-object')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('workout (D48): swipe the exercise carousel; the world adds to the one shown', (t) async {
    final (store, _) = await _openApp(t);
    final n = store.todayCards.length;
    expect(find.byKey(const ValueKey('exercise-0')), findsOneWidget);
    expect(find.text('EXERCISE 1 OF $n'), findsNothing); // no "x of y" (D49)
    // Filter tags with the defaults (D49).
    expect(find.descendant(of: find.byKey(const ValueKey('filter-class')), matching: find.text('PLATE PALADIN')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('filter-difficulty')), matching: find.text('SWEAT MODE')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('filter-body')), matching: find.text('ALL BODY PARTS')), findsOneWidget);
    // The level and XP bar sits in the PUMPLEX bar.
    expect(find.byKey(const ValueKey('top-level')), findsOneWidget);
    final carousel = find.byKey(const ValueKey('exercise-card'));
    await t.fling(carousel, const Offset(-300, 0), 1000); // next
    await _frames(t, 10);
    expect(find.byKey(const ValueKey('exercise-1')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('world-object')));
    await _frames(t, 70);
    if (find.byKey(const ValueKey('intro-card')).evaluate().isNotEmpty) {
      await t.tap(find.byKey(const ValueKey('intro-card')));
      await _frames(t, 4);
    }
    expect((store.todayExercises[0].sets, store.todayExercises[1].sets), (0, 1));
    await t.fling(carousel, const Offset(300, 0), 1000); // back
    await _frames(t, 10);
    await t.fling(carousel, const Offset(300, 0), 1000); // round to the last one
    await _frames(t, 10);
    expect(find.byKey(ValueKey('exercise-${store.todayCards.last}')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('tap the lifter on the workout to edit the body sliders', (t) async {
    final (store, _) = await _openApp(t);
    await t.tap(find.byKey(const ValueKey('workout-character')));
    await _frames(t);
    expect(find.text('CHARACTER · STEP 1 OF 4'), findsOneWidget);
    await t.drag(find.byKey(const ValueKey('slider-WEIGHT')), const Offset(400, 0));
    await t.tap(find.text('NEXT'));
    await _frames(t);
    await t.tap(find.text('SAVE'));
    await _frames(t);
    expect(store.profile!.character.fat, 100);
    expect(store.bodyHistory.last.character.fat, 100);
    expect(find.byKey(const ValueKey('world-object')), findsOneWidget); // the workout is home (D49)
  });

  testWidgets('a level-up shows the freeze-frame card', (t) async {
    final (store, _) = await _openApp(t);
    await t.tap(find.byKey(const ValueKey('world-object'))); // first set: +50 and more
    await t.pump(const Duration(milliseconds: 600));
    final level = levelFor(store.totalXp).level;
    expect(level, greaterThan(1));
    expect(find.byKey(const ValueKey('intro-card')), findsOneWidget);
    expect(find.text('LEVEL $level'), findsOneWidget);
    await _frames(t, 70);
    expect(find.byKey(const ValueKey('intro-card')), findsNothing);
    await t.tap(find.byKey(const ValueKey('nav-hub')));
    await _frames(t);
    expect(find.byKey(const ValueKey('hub-gear')), findsNothing); // no gear (D38)
  });

  testWidgets('android back goes one step back, to the workout', (t) async {
    await _openApp(t);
    await t.tap(find.byKey(const ValueKey('top-level'))); // the level bar opens the profile
    await _frames(t);
    expect(find.text('THE PATH'), findsOneWidget);
    await t.binding.handlePopRoute();
    await _frames(t);
    expect(find.text('THE PATH'), findsNothing);
    expect(find.byKey(const ValueKey('world-object')), findsOneWidget);
  });

  testWidgets('the menu has no look-and-feel toggles; EDIT CHARACTER keeps the body', (t) async {
    await _openApp(t);
    await t.tap(find.byKey(const ValueKey('menu-open')));
    await _frames(t, 10);
    for (final k in ['menu-chaos', 'menu-cel', 'menu-sound']) {
      expect(find.byKey(ValueKey(k)), findsNothing, reason: k);
    }
    await t.tap(find.byKey(const ValueKey('menu-edit')));
    await _frames(t);
    expect(find.text('CHARACTER · STEP 1 OF 4'), findsOneWidget);
    expect(_spriteAsset(t), spriteFrame(_profile.character));
    await t.pump(const Duration(seconds: 5));
  });

  for (final b in Brightness.values) {
    testWidgets('every scene renders on a phone ($b)', (t) async {
      _phone(t);
      final (store, _) = await _store(setUp: true);
      store.addSet(0);
      await t.pumpWidget(MaterialApp(theme: pumplexTheme(b), home: GameShell(store: store)));
      await _frames(t);
      Future<void> tapAndSettle(Finder f) async {
        await t.tap(f);
        await _frames(t);
        expect(t.takeException(), isNull);
      }

      await tapAndSettle(find.byKey(const ValueKey('nav-hub')));
      await tapAndSettle(find.byKey(const ValueKey('nav-history')));
      await tapAndSettle(find.byKey(const ValueKey('nav-hub')));
      // Profile (design screen 11): change one setup step, then back.
      await tapAndSettle(find.byKey(const ValueKey('nav-profile')));
      expect(find.text('THE PATH'), findsOneWidget);
      await tapAndSettle(find.byKey(const ValueKey('profile-difficulty')));
      expect(find.text('CLASS · STEP 2 OF 4'), findsOneWidget); // difficulty is on the class step (D47)
      await tapAndSettle(find.text('NEXT'));
      await tapAndSettle(find.text('SAVE'));
      await tapAndSettle(find.byKey(const ValueKey('nav-profile')));
      await tapAndSettle(find.byKey(const ValueKey('nav-hub')));
      // Menu (design screen 12).
      await tapAndSettle(find.byKey(const ValueKey('menu-open')));
      expect(find.text('GAINS INSURANCE'), findsOneWidget);
      await tapAndSettle(find.byKey(const ValueKey('menu-profile')));
      await tapAndSettle(find.byKey(const ValueKey('nav-hub')));
      await tapAndSettle(find.byKey(const ValueKey('menu-open')));
      await tapAndSettle(find.byKey(const ValueKey('menu-edit')));
      await tapAndSettle(find.text('NEXT')); // editing: straight to the summary
      await tapAndSettle(find.text('CLASS'));
      await tapAndSettle(find.byKey(const ValueKey('class-dot-bruiser')));
      await tapAndSettle(find.text('NEXT'));
      await tapAndSettle(find.text('DIFFICULTY'));
      await tapAndSettle(find.text('NEXT'));
      await tapAndSettle(find.text('AREA'));
      await tapAndSettle(find.text('NEXT'));
      await tapAndSettle(find.text('SAVE'));
      expect(find.byKey(const ValueKey('world-object')), findsOneWidget); // the workout is home (D49)
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
