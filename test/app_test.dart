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

  test('one session per calendar day: every mark that day goes in it', () async {
    final (store, prefs) = await _store(fresh: true, setUp: true);
    expect(store.open, isNull);
    final plan = store.todaySlots.map((s) => s.exerciseId).toList();
    _now = DateTime(2026, 11, 21, 7);
    store.addSet(0);
    _now = DateTime(2026, 11, 21, 18); // 11 h later: same day, same session
    store.addSet(0);
    store.addSet(1);
    expect(store.onAppOpened(), isNull);
    expect(store.sessions, isEmpty);
    expect(store.open!.day, '2026-11-21');
    expect(store.open!.sets, {plan[0]: 2, plan[1]: 1});
    expect(store.open!.slots.map((s) => s.exerciseId), plan); // the list is stored
    expect((store.open!.classId, store.open!.difficultyId), ('warrior', 'd03'));
    expect(store.totalXp, xpForSets(3, 2));
    // Saved, and loads again.
    expect(LogStore(prefs, clock: () => _now).open!.sets, {plan[0]: 2, plan[1]: 1});
  });

  test('a later day closes the session, on open or on the next mark', () async {
    final (store, _) = await _store(fresh: true, setUp: true);
    _now = DateTime(2026, 11, 21, 23, 50);
    store.addSet(0);
    _now = DateTime(2026, 11, 22, 0, 10); // 20 min later, but a new day
    store.addSet(0);
    expect(store.sessions.single.totalSets, 1);
    expect(store.open!.day, '2026-11-22');
    _now = DateTime(2026, 11, 25, 9);
    expect(store.onAppOpened()!.day, '2026-11-22');
    expect(store.open, isNull);
    expect(store.sessions.length, 2);
  });

  test('a day with no sets is not kept (skipping = doing no sets)', () async {
    final (store, _) = await _store(fresh: true, setUp: true);
    store.removeSet(0); // nothing to remove
    expect(store.open, isNull);
    store.addSet(0);
    store.removeSet(0);
    store.swap(1, 1); // a plan change opens the day too
    expect(store.open!.totalSets, 0);
    _now = _now.add(const Duration(days: 1));
    expect(store.onAppOpened(), isNull);
    expect(store.sessions, isEmpty);
  });

  // -------------------------------------------------------------- workouts

  test('a workout takes a set number of exercises from the class pool', () async {
    final (store, _) = await _store(fresh: true, setUp: true);
    final pool = classById('warrior').exercises.map((e) => e.id).toSet();
    expect(store.todaySlots.length, workoutSize(2));
    expect(store.todaySlots.every((s) => pool.contains(s.exerciseId) && !s.switched), isTrue);
    expect(store.todaySlots.map((s) => s.exerciseId).toSet().length, workoutSize(2));
    expect(LogStore.planFor(classById('warrior'), 11, '2026-11-21').length,
        workoutSize(11).clamp(1, pool.length));
    expect(gameClasses.every((c) => c.exercises.length > workoutSize(0)), isTrue);
  });

  test('swipe switches an exercise, ↺ brings it back, add and remove cards', () async {
    final (store, _) = await _store(fresh: true, setUp: true);
    final first = store.todaySlots[0].exerciseId;
    final others = store.todaySlots.skip(1).map((s) => s.exerciseId).toSet();
    expect(store.swap(0, 1), isTrue);
    final switched = store.todaySlots[0];
    expect(switched.switched, isTrue);
    expect(switched.initialId, first);
    expect(others.contains(switched.exerciseId), isFalse); // never a duplicate
    expect(store.swap(0, 1), isTrue);
    expect(store.todaySlots[0].exerciseId, isNot(anyOf(first, switched.exerciseId)));
    expect(store.todaySlots[0].initialId, first);
    expect(store.resetSlot(0), isTrue);
    expect(store.todaySlots[0].exerciseId, first);
    expect(store.resetSlot(0), isFalse);

    // A card with sets cannot be switched or removed.
    store.addSet(0);
    expect(store.swap(0, 1), isFalse);
    expect(store.removeSlot(0), isFalse);

    final extra = store.unusedExercises.first.id;
    store.addExercise(extra);
    expect(store.todaySlots.last.exerciseId, extra);
    expect(store.todaySlots.last.initialId, isNull);
    expect(store.unusedExercises.any((e) => e.id == extra), isFalse);
    expect(store.removeSlot(store.todaySlots.length - 1), isTrue);
    expect(store.removeSlot(1), isTrue);
    expect(store.todaySlots.length, workoutSize(2) - 1);
  });

  test('class and difficulty can change; each session keeps its own', () async {
    final (store, _) = await _store(fresh: true, setUp: true);
    store.addSet(0);
    store.addSet(0);
    final xp = store.totalXp;
    // A session with sets keeps its class and difficulty today.
    const gym = Profile(character: Character(), classId: 'mage', difficultyId: 'd12', areaId: 'beach');
    store.setProfile(gym);
    expect(store.open!.classId, 'warrior');
    expect(store.totalXp, xp);
    // The next day uses the new class and difficulty.
    _now = _now.add(const Duration(days: 1));
    store.onAppOpened();
    expect(store.todaySlots.length, workoutSize(11));
    expect(exercisesById[store.todaySlots.first.exerciseId], isNotNull);
    expect(store.todaySlots.first.exerciseId, startsWith('mage.'));
    store.addSet(0);
    expect(store.totalXp, xp + xpForSets(1, 11));
    expect(store.sessions.single.difficultyId, 'd03');

    // With no sets yet, a change remakes today's plan.
    final (fresh, _) = await _store(fresh: true, setUp: true);
    fresh.swap(0, 1);
    fresh.setProfile(gym);
    expect(fresh.todaySlots.first.exerciseId, startsWith('mage.'));
  });

  test('body sliders keep a history of changes', () async {
    final (store, prefs) = await _store(fresh: true);
    store.setProfile(_profile);
    store.setProfile(_profile); // no change, no new entry
    _now = _now.add(const Duration(days: 30));
    store.setProfile(Profile(
      character: _profile.character.copyWith(fat: 40),
      classId: 'warrior',
      difficultyId: 'd03',
      areaId: 'castle',
    ));
    expect(store.bodyHistory.length, 2);
    expect(store.bodyHistory.first.character, _profile.character);
    expect(store.bodyHistory.last.character.fat, 40);
    expect(store.bodyHistory.last.at, _now);
    expect(LogStore(prefs, clock: () => _now).bodyHistory.length, 2);
  });

  // ------------------------------------------------------------- old data

  test('old sessions become beta XP; old keys are never touched', () async {
    final (store, prefs) = await _store(setUp: true);
    final oldRaw = prefs.getString('sessions_v2');
    expect(store.oldXp, 4 * xpPerOldWorkout + 3 * xpPerOldRestDay);
    expect(store.totalXp, store.oldXp);
    store.addSet(0);
    _now = _now.add(const Duration(days: 1));
    store.onAppOpened();
    store.setProfile(_profile);
    expect(prefs.getString('sessions_v2'), oldRaw);
    expect(prefs.getString('logs_v2'), _oldLogs);
    expect(prefs.getString('swaps_v2'), _oldSwaps);
    expect(store.totalXp, store.oldXp + xpForSets(1, 2));
  });

  test('backups: everything round-trips, old version-2 backups still load', () async {
    final (store, _) = await _store(setUp: true);
    store.setProfile(_profile); // one body entry
    store.addSet(0);
    _now = _now.add(const Duration(days: 1));
    store.addSet(1); // one closed, one open
    final backup = store.backupJson();
    final data = jsonDecode(backup) as Map;
    expect(data['version'], 3);
    expect(data['logs'], jsonDecode(_oldLogs));
    expect(data['swaps'], jsonDecode(_oldSwaps));

    final (other, otherPrefs) = await _store(fresh: true);
    await other.importBackup(backup);
    expect(other.profile!.classId, 'warrior');
    expect(other.sessions.length, 1);
    expect(other.open!.totalSets, 1);
    expect(other.bodyHistory.length, 1);
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
    expect(find.text(exerciseName(store.todaySlots.first.exerciseId).toUpperCase()), findsOneWidget);
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
    final squats = find.byKey(const ValueKey('card-0'));
    for (var i = 0; i < 6; i++) {
      await t.tap(squats);
      await t.pump(const Duration(milliseconds: 80));
    }
    await t.longPress(squats);
    await _frames(t, 10);
    expect(store.setsAt(0), 5);
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

  testWidgets('workout: swipe a card to switch, ↺ back, add and remove exercises', (t) async {
    _phone(t);
    final (store, _) = await _store(fresh: true, setUp: true);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    await t.tap(find.byKey(const ValueKey('hub-workout')));
    await _frames(t);
    final first = store.todaySlots[0].exerciseId;
    final card = find.byKey(const ValueKey('card-0'));

    await t.drag(card, const Offset(-200, 0));
    await _frames(t, 10);
    expect(store.todaySlots[0].switched, isTrue);
    final now = store.todaySlots[0].exerciseId;
    expect(find.text(exerciseName(now).toUpperCase()), findsOneWidget);
    await t.tap(find.descendant(of: card, matching: find.text('↺')));
    await _frames(t, 10);
    expect(store.todaySlots[0].exerciseId, first);

    // A card with sets does not switch; a message says why.
    await t.tap(card);
    await t.pump(const Duration(milliseconds: 100));
    await t.drag(card, const Offset(-200, 0));
    await _frames(t, 10);
    expect(store.todaySlots[0].exerciseId, first);
    expect(find.textContaining('SETS ALREADY DONE HERE'), findsOneWidget);

    final n = store.todaySlots.length;
    await t.dragUntilVisible(find.text('+ ADD EXERCISE'), find.byType(ListView).last, const Offset(0, -300));
    await t.tap(find.text('+ ADD EXERCISE'));
    await _frames(t, 10);
    final extra = store.unusedExercises.first;
    await t.tap(find.byKey(ValueKey('add-${extra.id}')));
    await _frames(t, 10);
    expect(store.todaySlots.length, n + 1);
    expect(store.todaySlots.last.exerciseId, extra.id);

    await t.dragUntilVisible(find.byKey(ValueKey('card-$n')), find.byType(ListView).last, const Offset(0, -300));
    await t.tap(find.descendant(of: find.byKey(ValueKey('card-$n')), matching: find.text('✕')));
    await _frames(t, 10);
    expect(store.todaySlots.length, n);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('tap the character on the hub to edit the body sliders', (t) async {
    _phone(t);
    final (store, _) = await _store(fresh: true, setUp: true);
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

  testWidgets('enough sets level you up with a burst', (t) async {
    _phone(t);
    final (store, _) = await _store(fresh: true, setUp: true);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    await t.tap(find.byKey(const ValueKey('hub-workout')));
    await _frames(t);
    final card = find.byKey(const ValueKey('card-1'));
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
    store.addSet(0);
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
      store.addSet(0);
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
      await tapAndSettle(find.text('NEXT ▶')); // editing: straight to the summary
      await tapAndSettle(find.text('DIFFICULTY'));
      await tapAndSettle(find.text('NEXT ▶'));
      await tapAndSettle(find.text('AREA'));
      await tapAndSettle(find.text('NEXT ▶'));
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
