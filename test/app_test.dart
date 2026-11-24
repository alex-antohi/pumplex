import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gym_app/dates.dart';
import 'package:gym_app/game/content.dart';
import 'package:gym_app/game/exercises.dart';
import 'package:gym_app/game/model.dart';
import 'package:gym_app/game/rules.dart';
import 'package:gym_app/i18n.dart';
import 'package:gym_app/main.dart';
import 'package:gym_app/pumplex.dart';
import 'package:gym_app/store.dart';
import 'package:gym_app/views/area_scene.dart';
import 'package:gym_app/views/scene.dart';
import 'package:gym_app/views/sprite.dart';

/// The cards of the class and mode, in the Suggested order: the cards the
/// carousel keeps (D82). The old filter list (store.cards) is gone.
List<ExerciseGroup> _cards(LogStore s) => s.defaultFilter.apply(exerciseCatalog, s.favorites);

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
  difficultyId: 'sweat', // ×1.4, up to intermediate exercises
  areaId: 'gainsgard',
);
const _d = 2; // difficulty index of 'sweat'

// Two Plate Paladin exercises from the list.
const _squat = 'Barbell_Squat';
const _bench = 'Barbell_Bench_Press_-_Medium_Grip';

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
/// The app on the workout, with the first [today] cards of the catalog in
/// Today (the carousel shows only Today, D82), on the first one.
Future<(LogStore, SharedPreferences)> _openApp(WidgetTester t, {int today = 3}) async {
  _phone(t);
  final (store, prefs) = await _store(setUp: true);
  final first = _cards(store).take(today).map((g) => store.variantFor(g).id).toList();
  first.forEach(store.addToToday);
  if (first.isNotEmpty) store.selectExercise(first.first);
  await t.pumpWidget(GymApp(store: store));
  await _frames(t);
  return (store, prefs);
}

/// Adds sets (in the store, not on screen) until one more set of [id] does
/// not level up, but two more do.
void _oneSetBeforeLevelUp(LogStore store, String id) {
  store.addSet(id); // the first set of the day holds the day bonus
  final others = _cards(store).skip(1).map((g) => store.variantFor(g).id).toList();
  for (var i = 0; i < 200; i++) {
    final xp = store.totalXp;
    store.addSet(id);
    final one = store.totalXp;
    store.addSet(id);
    final two = store.totalXp;
    store.removeSet(id);
    store.removeSet(id);
    final l = levelFor(xp).level;
    if (levelFor(one).level == l && levelFor(two).level > l) return;
    store.addSet(others[i % others.length]);
  }
  fail('no state one set before a level-up');
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
  setUpAll(() => exerciseCatalog = ExerciseCatalog.parse(File(ExerciseCatalog.asset).readAsStringSync()));
  // The tests read the English texts (D68).
  final langFiles = {for (final l in I18n.languages) l: File(I18n.asset(l)).readAsStringSync()};
  setUp(() {
    _now = DateTime(2026, 11, 21, 10);
    I18n.instance.useJson(langFiles);
  });

  test('languages (D68): the same keys in every file, plurals, placeholders, fallbacks', () {
    final en = I18n.parse(langFiles['en']!);
    for (final l in I18n.languages) {
      // `name.form.<base>`: only a language with agreement has them (D80).
      final keys = I18n.parse(langFiles[l]!).keys.where((k) => !k.startsWith('name.form.')).toSet();
      expect(keys, en.keys.toSet(), reason: l);
      // Romanian uses ș and ț with a comma below, not ş and ţ with a cedilla.
      expect(RegExp('[şţŞŢ]').hasMatch(langFiles[l]!), isFalse, reason: l);
    }
    // Every content name has a text.
    for (final c in gameClasses) {
      expect(en.containsKey('class.${c.id}.name'), isTrue, reason: c.id);
    }
    for (final k in [for (final d in difficulties) 'difficulty.${d.id}.name', for (final a in areas) 'area.${a.id}.name']) {
      expect(en.containsKey(k), isTrue, reason: k);
    }
    for (final a in modifierAxes) {
      expect(en['axis.${a.id}'], a.label);
      expect(en['axis.${a.id}.none'], a.none);
    }
    // Every modifier value of the list has a chip text (D55, D69).
    for (final v in {for (final e in exerciseCatalog.all) ...e.mods.values}) {
      expect(en.containsKey('mod.$v'), isTrue, reason: v);
    }
    for (final b in bodyParts) {
      expect(en['part.${b.id}'], b.name);
      for (final m in b.muscles) {
        expect(en['muscle.$m'], m);
      }
    }
    expect(t('level.up', {'n': 3}), 'LEVEL 3');
    expect([tn('sets', 1), tn('sets', 12)], ['1 SET', '12 SETS']);
    expect(shortDate(DateTime(2026, 11, 23)), 'Mon 23 Nov');
    // Exercise and move names (D68); unknown ones fall back to the English name.
    expect(exerciseLabel('Pushups', 'Pushups'), 'Push-Up');
    expect(groupLabel('move:bench press', 'Bench Press'), 'Bench Press');
    expect(exerciseLabel('No_Such_Exercise', 'No Such'), 'No Such');
    // A dropped exercise (the variation audit) keeps its name for saved sets.
    expect(exerciseCatalog.byId['Bodyweight_Flyes'], isNull);
    expect(exerciseLabel('Bodyweight_Flyes', exerciseName('Bodyweight_Flyes')), 'Bodyweight Fly');
    I18n.instance.useJson(langFiles, lang: 'ro');
    expect(groupLabel('move:bench press', 'Bench Press'), 'Împins la piept');
    expect(exerciseLabel('Incline_Dumbbell_Press', ''), 'Împins înclinat cu gantere');
    expect([tn('sets', 1), tn('sets', 12), tn('sets', 20), tn('sets', 101), tn('sets', 0)],
        ['1 SERIE', '12 SERII', '20 DE SERII', '101 SERII', '0 SERII']);
    expect(classById('paladin').name, 'Paladin de Discuri');
    expect(shortDate(DateTime(2026, 11, 23)), 'Lun 23 Noi');
    expect(decimal(1.75, 2), '1,75');
    I18n.instance.useJson({'en': '{"a": "A {x}"}', 'ro': '{}'}, lang: 'ro');
    expect(t('a', {'x': 1}), 'A 1'); // a key Romanian lacks: English
    expect(t('missing'), 'missing');
  });

  test('exercise names (D68): every exercise and move has a name key, search words are lists', () {
    final en = I18n.parse(langFiles['en']!);
    for (final e in exerciseCatalog.all) {
      expect(exerciseLabel(e.id, ''), e.name, reason: e.id); // special or composed (D80)
      expect(en.containsKey('move.${e.base.toLowerCase()}'), isTrue, reason: e.base);
    }
    for (final g in exerciseCatalog.groups.where((g) => g.key.startsWith('move:'))) {
      expect(en.containsKey('move.${g.key.substring(5)}'), isTrue, reason: g.key);
    }
    // CHALK search words (D72): move keys only, a list of words each.
    for (final l in I18n.languages) {
      final words = jsonDecode(File('assets/i18n/search_$l.json').readAsStringSync()) as Map<String, dynamic>;
      for (final w in words.entries) {
        expect(en.containsKey(w.key), isTrue, reason: '$l ${w.key}');
        expect(w.value, isA<List<dynamic>>());
      }
      expect(RegExp('[şţŞŢ]').hasMatch(File('assets/i18n/search_$l.json').readAsStringSync()), isFalse);
    }
  });

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
    // The old exercise list is dropped (D54); the day and its XP stay.
    expect(s.legacy, isTrue);
    expect(s.exercises, isEmpty);
    expect(store.xpEvents.where((e) => e.source == 'workout').single.ref, '2026-11-20');
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
      final xp = oldSetXp(setNumber: n, target: 3, difficulty: _d, critical: isCritical('2026-11-16', 'paladin.squat', n));
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
    again.addSet(_squat);
    expect(again.xpEvents.where((e) => e.source == 'streak').length, 1);

    // A version-3 backup (made before D34) gets its streak XP worked out on import.
    final v3 = jsonEncode({'app': 'pumplex', 'version': 3, 'sessions_v3': sessions, 'achievements_v1': {'first_set': 'x'}});
    await again.importBackup(v3);
    expect(again.xpEvents.where((e) => e.source == 'streak').single.amount, bonus);
    expect(jsonDecode(again.backupJson()), isNot(contains('achievements_v1')));
  });

  // ------------------------------------------------------------ fixed data

  test('rules table: set XP (no targets, D52), cap, critical, level curve', () {
    expect(difficultyRules.first.xpMultiplier, 1.0);
    expect(difficultyRules.last.xpMultiplier, 2.0);
    int set(int n, {bool crit = false, int d = 0}) => xpForSet(setNumber: n, difficulty: d, critical: crit);
    expect(set(1), 10);
    expect(set(xpSetsPerExercise), 10);
    expect(set(xpSetsPerExercise + 1), 0); // no farming
    expect(set(1, crit: true), 20);
    expect(set(1, d: 5), 20);
    // The old target rules, kept for the one-time freeze (D54).
    expect([for (final n in [3, 4, 6, 7]) oldSetXp(setNumber: n, target: 3, difficulty: 0)], [10, 15, 15, 0]);
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

  test('fixed data: difficulty numbers, classes, the exercise list', () {
    expect(difficultyRules.length, difficulties.length);
    expect(gameClasses.map((c) => c.equipment).toSet().length, gameClasses.length);
    final all = exerciseCatalog.all;
    // The common exercises only (D67, D69), with the added bench presses
    // (D57) and bodyweight exercises (D69), and the variation grids (D80).
    expect(all.length, 527);
    expect(exerciseCatalog.groups.length, 164);
    // The clean-up (D69): every card is a move, with a clean move name.
    expect(exerciseCatalog.groups.where((g) => !g.key.startsWith('move:')), isEmpty);
    expect(exerciseCatalog.groupKeyOf('Plank'), 'move:plank');
    expect(exerciseCatalog.groupKeyOf('Butt_Lift_Bridge'), 'move:glute bridge');
    expect(exerciseCatalog.byId['Butt_Lift_Bridge']!.name, 'Glute Bridge');
    expect(exerciseCatalog.groupKeyOf('Machine_Bench_Press'), 'move:chest press');
    expect(exerciseCatalog.groupKeyOf('Underhand_Cable_Pulldowns'), 'move:lat pulldown');
    expect(exerciseCatalog.groupKeyOf('Dumbbell_Farmers_Walk'), "move:farmer's walk");
    // Old move keys of renamed or split moves follow (saved favorites).
    expect(exerciseCatalog.groupKeyOf('move:row'), 'move:one-arm row');
    expect(exerciseCatalog.groupKeyOf('move:bent over row'), 'move:bent-over row');
    expect(exerciseCatalog.groupKeyOf('move:rear lateral raise'), 'move:reverse fly');
    expect(exerciseCatalog.groupKeyOf('move:bench press'), 'move:bench press');
    // Merged moves of the variation audit follow too.
    expect(exerciseCatalog.groupKeyOf('move:chin-up'), 'move:pull-up');
    expect(exerciseCatalog.groupKeyOf('move:butterfly'), 'move:fly');
    expect(exerciseCatalog.groupKeyOf('move:towel row'), 'move:inverted row');
    expect(exerciseCatalog.groupKeyOf('move:glute-ham raise'), 'move:nordic curl');
    expect(exerciseCatalog.groupKeyOf('move:walking lunge'), 'move:lunge');
    for (final k in ExerciseCatalog.movedMoves.keys) {
      expect(exerciseCatalog.byKey[k], isNull, reason: k);
      expect(exerciseCatalog.groupKeyOf(k), startsWith('move:'), reason: k);
      expect(exerciseCatalog.byKey[exerciseCatalog.groupKeyOf(k)], isNotNull, reason: k);
    }
    // One cardio machine card; gear `other` that is body only (D50).
    expect(exerciseCatalog.byKey['move:cardio machine']!.variants.length, 5);
    for (final id in ['Ring_Dips', 'Weighted_Pull_Ups', 'Ab_Roller', 'Muscle_Up', 'Front_Box_Jump']) {
      expect(exerciseCatalog.byId[id]?.equipment, 'body only', reason: id);
    }
    expect(exerciseCatalog.byId['Trap_Bar_Deadlift']!.mods['type'], 'Trap Bar');
    for (final id in ['Pike_Push-Up', 'Towel_Bicep_Curl', 'Bodyweight_Calf_Raise', 'Dead_Hang', 'Pistol_Squat', 'Burpee',
      'Towel_Row', 'Feet-Elevated_Inverted_Row', 'Chin-Up_Hold', 'Doorframe_Curl', 'Reverse_Snow_Angel']) {
      expect(exerciseCatalog.byId[id]?.equipment, 'body only', reason: id);
    }
    expect(exerciseCatalog.groupKeyOf('Towel_Bicep_Curl'), 'move:bicep curl'); // a bodyweight chip of the move
    // Level overrides (D69): pull-ups are not for beginners, face pulls are.
    expect(exerciseCatalog.byId['Pullups']!.level, 1);
    expect(exerciseCatalog.byId['Face_Pull']!.level, 0);
    for (final id in [
      'Incline_Close-Grip_Barbell_Bench_Press',
      'Incline_Wide-Grip_Barbell_Bench_Press',
      'Decline_Close-Grip_Barbell_Bench_Press'
    ]) {
      expect(exerciseCatalog.byId[id], isNotNull, reason: id);
    }
    // No stretching, olympic weightlifting, strongman or neck exercises (D56).
    expect(all.where((e) => {'stretching', 'olympic weightlifting', 'strongman'}.contains(e.category) || e.muscle == 'neck'),
        isEmpty);
    // Moves (D55): one card per move, with its exercises as modifiers.
    final push = exerciseCatalog.byKey['move:push-up']!;
    expect(push.name, 'Push-Up');
    expect(push.variants.first.id, 'Pushups'); // the simplest first
    expect(exerciseCatalog.groupKeyOf('Decline_Push-Up'), 'move:push-up');
    expect(push.axes.map((a) => a.$1.id), containsAll(['angle', 'width']));
    expect(push.axes.firstWhere((a) => a.$1.id == 'angle').$2, [null, 'Decline', 'Incline']);
    final bench = exerciseCatalog.byKey['move:bench press']!;
    expect(bench.axes.firstWhere((a) => a.$1.id == 'equip').$2, containsAll(['Barbell', 'Dumbbell', 'Smith Machine']));
    // A chip keeps the other modifiers when it can.
    final barbell = exerciseCatalog.byId['Barbell_Bench_Press_-_Medium_Grip']!;
    expect(pickVariant(bench, barbell, 'angle', 'Incline')!.id, 'Barbell_Incline_Bench_Press_-_Medium_Grip');
    expect(pickVariant(bench, barbell, 'equip', 'Dumbbell')!.mods['equip'], 'Dumbbell');
    expect(exerciseCatalog.groupOf('Pushups')!.variants.length, greaterThan(5));
    expect(exerciseCatalog.byKey['Leg_Press'], isNull); // Leg Press is a move with variations
    // Bands and chains are their own rows.
    final dead = exerciseCatalog.byKey['move:deadlift']!;
    expect(dead.axes.firstWhere((a) => a.$1.id == 'bands').$2, [null, 'Bands']); // no reverse bands (D67)
    expect(dead.axes.firstWhere((a) => a.$1.id == 'chains').$2, [null, 'Chains']);
    // A move with one exercise left keeps its move key (D67), so favorites stay.
    expect(exerciseCatalog.groupKeyOf('Pullups'), 'move:pull-up');
    expect(exerciseCatalog.byKey['move:pull-up']!.name, 'Pull-Up');
    // Bench press (D57): from any barbell press, Flat, bands and chains are
    // reachable; dumbbells have no grip width row; a barbell has no one-arm row.
    final incline = exerciseCatalog.byId['Barbell_Incline_Bench_Press_-_Medium_Grip']!;
    final flat = chipTarget(bench, incline, 'angle', null)!;
    expect((flat.v.id, flat.exact), ('Barbell_Bench_Press_-_Medium_Grip', true));
    final flatBar = flat.v;
    expect(chipTarget(bench, flatBar, 'bands', 'Bands')!.v.id, 'Bench_Press_-_With_Bands');
    expect(chipTarget(bench, flatBar, 'chains', 'Chains')!.v.id, 'Bench_Press_with_Chains');
    expect(chipTarget(bench, incline, 'width', 'Wide Grip')!.v.id, 'Incline_Wide-Grip_Barbell_Bench_Press');
    final rowsBar = bench.axesFor(flatBar).map((a) => a.$1.id).toList();
    expect(rowsBar, containsAll(['equip', 'angle', 'width', 'bands', 'chains']));
    expect(rowsBar, isNot(contains('side')));
    final db = exerciseCatalog.byId['Dumbbell_Bench_Press']!;
    final rowsDb = bench.axesFor(db).map((a) => a.$1.id).toList();
    expect(rowsDb, containsAll(['equip', 'angle', 'side']));
    expect(rowsDb, isNot(contains('width')));
    expect(exerciseCatalog.all.where((e) => e.mods['equip'] == 'Dumbbell' && e.mods.containsKey('width')), isEmpty);
    // The equipment row may change other modifiers; other rows stay in the equipment.
    expect(chipTarget(bench, flatBar, 'equip', 'Dumbbell')!.v.mods['equip'], 'Dumbbell');
    expect(chipTarget(bench, flatBar, 'side', 'One Arm'), isNull);
    // All dips are one move, with a Type row.
    final dip = exerciseCatalog.byKey['move:dip']!;
    expect(dip.variants.length, 9); // D80 adds weighted and band-assisted; dip bars and rings are body only (D50)
    expect(dip.axes.firstWhere((a) => a.$1.id == 'type').$2, containsAll(['Triceps', 'Bench']));
    expect(all.map((e) => e.id).toSet().length, all.length);
    expect(all.every((e) => !e.id.contains('.')), isTrue); // old ids have a dot (D54)
    expect(exerciseCatalog.byId['Pushups']!.equipment, 'body only');
    expect(exerciseName('Leg_Extensions'), 'Leg Extension');
    expect(exerciseName('Wrist_Roller'), 'Wrist Roller'); // not in the list (D67), still readable
    // Commonness and modes (D67): every class and mode covers every body
    // part; each mode shows more cards than the one before, and keeps them.
    for (final c in gameClasses) {
      var before = <String>{};
      for (var d = 0; d < difficulties.length; d++) {
        final f = ExerciseFilter(classId: c.id, difficulty: d);
        final keys = {for (final g in exerciseCatalog.groups) if (g.shownIn(c.id, d)) g.key};
        expect(keys.length, greaterThan(before.length), reason: '${c.id} $d');
        expect(keys.containsAll(before), isTrue, reason: '${c.id} $d');
        for (final b in bodyParts) {
          expect(f.apply(exerciseCatalog, const {}).any((g) => g.variants.any((e) => b.muscles.contains(e.muscle))), isTrue, reason: '${c.id} $d ${b.id}');
        }
        before = keys;
      }
    }
    // Movement patterns (D69): every card has one. Every class has the gear
    // for every core pattern, so each one is there from Sofa on (and so in
    // every mode, as a mode keeps the easier cards): a real workout.
    expect(exerciseCatalog.groups.where((g) => g.pattern == null), isEmpty);
    for (final c in gameClasses) {
      final sofa = {for (final g in ExerciseFilter(classId: c.id, difficulty: 0).apply(exerciseCatalog, const {})) g.pattern};
      for (final p in corePatterns) {
        expect(sofa, contains(p), reason: '${c.id} $p');
      }
      // From Sweat on, two cards or more per core pattern where the class has them.
      final sweat = ExerciseFilter(classId: c.id, difficulty: 2).apply(exerciseCatalog, const {});
      final thin = [for (final p in corePatterns) if (sweat.where((g) => g.pattern == p).length < 2) p];
      expect(thin.length, lessThanOrEqualTo(3), reason: '${c.id} $thin');
    }
    // The owner's spread (D69): Cablemancer machines from Sofa.
    for (final k in ['move:leg press', 'move:leg extension', 'move:fly', 'move:face pull', 'move:seated cable row']) {
      expect(exerciseCatalog.byKey[k]!.shownIn('cablemancer', 0), isTrue, reason: k);
    }
    // The class rules of the tool are the app's: a class in `unlock` sees an exercise of the card.
    for (final g in exerciseCatalog.groups) {
      for (final c in g.variants.first.unlock.keys) {
        expect(g.variants.any((e) => classEquipment[c]!.contains(e.equipment) && classCategories[c]!.contains(e.category)),
            isTrue, reason: '${g.key} $c');
      }
    }
    final ranked = ExerciseFilter(classId: 'paladin', difficulty: 5).apply(exerciseCatalog, const {});
    expect(ranked.first.key, 'move:bench press'); // the most common card first
    expect([for (final g in ranked) g.rank], [for (final g in ranked) g.rank]..sort());
    // Every muscle of the list is in exactly one body part (D52).
    for (final m in all.map((e) => e.muscle).toSet()) {
      expect(bodyParts.where((b) => b.muscles.contains(m)).length, 1, reason: m);
    }
    for (final c in gameClasses) {
      expect(classEquipment[c.id], contains('body only'), reason: c.id);
      expect(classCategories[c.id], isNotEmpty, reason: c.id);
    }
  });

  test('design data: 6 difficulty modes, 5 areas, one default area per class', () {
    expect(difficulties.map((d) => d.id), ['sofa', 'warmup', 'sweat', 'pain', 'brutal', 'nightmare']);
    expect(difficulties.every((d) => d.name.endsWith('Mode')), isTrue);
    expect([for (final r in difficultyRules) r.xpMultiplier], [1.0, 1.2, 1.4, 1.6, 1.8, 2.0]);
    expect(areas.length, 5);
    for (final c in gameClasses) {
      expect(areas.where((a) => a.defaultFor == c.id).length, 1, reason: c.id);
      expect(defaultAreaFor(c.id).defaultFor, c.id);
    }
    expect(defaultAreaFor('paladin').id, 'gainsgard');
    expect(areaById('nope').id, areas.first.id);
  });

  testWidgets('the workout: +1 SET, the area stamp on every 5th set, no CRUSHED (D52)', (t) async {
    _phone(t);
    final (store, _) = await _store(setUp: true); // Gainsgard Keep: SLASHED!
    final card = _cards(store).first;
    final first = store.variantFor(card).id;
    for (var i = 0; i < 3; i++) {
      store.addSet(first); // level-ups happen here, not on screen
    }
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    expect(find.text('SCRATCH THE WALL'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('world-object'))); // 4th set
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('+1 SET'), findsOneWidget);
    expect(find.text('CRUSHED!'), findsNothing);
    await _frames(t, 40);
    await t.tap(find.byKey(const ValueKey('world-object'))); // 5th set
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('SLASHED!'), findsOneWidget);
    expect(store.setsToday(first), 5);
    expect(find.byKey(ValueKey('exercise-${card.key}')), findsOneWidget); // no moving on
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
    _now = DateTime(2026, 11, 21, 7);
    store.addSet(_squat);
    _now = DateTime(2026, 11, 21, 18); // 11 h later: same day, same session
    store.addSet(_squat);
    store.addSet(_bench);
    final s = store.todaySession!;
    expect(store.sessions.keys, ['2026-11-21']);
    expect((s.classId, s.difficultyId, s.areaId, s.legacy), ('paladin', 'sweat', 'gainsgard', false));
    expect((s.firstMarkAt, s.lastMarkAt), ('2026-11-21T07:00:00', '2026-11-21T18:00:00'));
    // Only exercises with sets, in the order of the first set.
    expect(s.exercises.map((e) => e.exerciseId), [_squat, _bench]);
    expect([s.exercises[0].sets, s.exercises[1].sets], [2, 1]);
    // Saved under sessions_v3 as date -> session, and loads again.
    final raw = jsonDecode(prefs.getString('sessions_v3')!) as Map;
    expect(raw['2026-11-21']['exercises'][0], {'exerciseId': _squat, 'sets': 2});
    expect(LogStore(prefs, clock: () => _now).todaySession!.totalSets, 3);
  });

  test('a later day is a new session; a day with no sets does not count', () async {
    final (store, _) = await _store(setUp: true);
    _now = DateTime(2026, 11, 21, 23, 50);
    store.addSet(_squat);
    _now = DateTime(2026, 11, 22, 0, 10); // 20 min later, but a new day
    expect(store.todaySession, isNull);
    store.addSet(_squat);
    expect(store.sessions.keys.toSet(), {'2026-11-21', '2026-11-22'});
    _now = DateTime(2026, 11, 23, 9);
    store.addSet(_squat); // a set taken back: a session with no sets
    store.removeSet(_squat);
    expect(store.todaySession!.exercises, isEmpty);
    expect(store.sessions.length, 3);
    expect(store.history.map((s) => s.date), ['2026-11-22', '2026-11-21']);
  });

  // -------------------------------------------------------------- workouts

  test('the class cards (D50-D53, D70, D82): class, mode order, HARD, favorites first', () async {
    final (store, _) = await _store(setUp: true);
    final f = store.defaultFilter;
    expect(f, const ExerciseFilter(classId: 'paladin', difficulty: _d)); // your class and mode
    List<CatalogExercise> flat(List<ExerciseGroup> cards) => [for (final g in cards) ...g.variants];
    final cards = _cards(store);
    final list = flat(cards);
    expect(list, isNotEmpty);
    // One card per move; a card keeps only its exercises that pass (D55).
    expect(cards.map((g) => g.key).toSet().length, cards.length);
    final bench = cards.firstWhere((g) => g.key == 'move:bench press');
    expect(bench.variants.every((e) => e.equipment != 'machine'), isTrue); // no Smith machine for a Paladin
    // The carousel card keeps the class's exercises of the move (D82).
    store.addToToday(bench.variants.first.id);
    expect(store.carousel.single.card.variants.map((e) => e.id), bench.variants.map((e) => e.id));
    expect(store.variantFor(bench).id, bench.variants.first.id);
    store.pickVariant('Decline_Barbell_Bench_Press');
    expect(store.variantFor(bench).id, 'Decline_Barbell_Bench_Press');
    // Class: its equipment and categories only.
    expect(list.every((e) => classEquipment['paladin']!.contains(e.equipment)), isTrue);
    expect(list.every((e) => classCategories['paladin']!.contains(e.category)), isTrue);
    expect(list.any((e) => e.equipment == 'other' || e.equipment == 'foam roll'), isFalse);
    // Difficulty is not a filter (D70): every card of the class, your mode's
    // first (the most common first, D67); the rest get the HARD badge.
    expect([for (final d in [0, 1, 2, 3, 4, 5]) topLevelFor(d)], [0, 0, 1, 1, 2, 2]);
    expect(cards.first.key, 'move:bench press');
    expect(cards.length, exerciseCatalog.groups.where((g) => g.shownIn('paladin', 5)).length);
    final mine = cards.indexWhere((g) => !g.shownIn('paladin', _d));
    expect(mine, greaterThan(0));
    expect(cards.skip(mine).every((g) => !g.shownIn('paladin', _d)), isTrue); // your mode's cards first
    expect(cards.skip(mine).every((g) => store.isHard(g, g.variants.first)), isTrue);
    expect(cards.take(mine).any((g) => g.variants.any((e) => e.level == 2)), isTrue); // expert exercises show
    expect(store.isHard(bench, bench.variants.first), bench.variants.first.level > 1);
    // Favorites: the card with one comes first, and opens on it.
    final favCard = _cards(store).last;
    final fav = favCard.variants.last.id; // the star saves the exercise (D72)
    store.toggleFavorite(fav);
    expect(_cards(store).first.key, favCard.key);
    expect(store.variantFor(_cards(store).first).id, fav);
    store.toggleFavorite(fav);
    expect(store.favorites, isEmpty);
    // A favorite saved as a card (D55, before D72) becomes its simplest
    // exercise when the carousel is built.
    store.toggleFavorite('move:push-up');
    store.carousel;
    expect(store.favorites, {exerciseCatalog.byKey['move:push-up']!.variants.first.id});
  });

  test('class, difficulty and area can change; each session keeps its own', () async {
    final (store, _) = await _store(setUp: true);
    store.addSet(_squat);
    final xp = store.totalXp;
    const gym = Profile(character: Character(), classId: 'cablemancer', difficultyId: 'nightmare', areaId: 'riptide');
    store.setProfile(gym);
    // The class keeps today's workout once it has sets; the area shows at once (D64).
    expect((store.todaySession!.classId, store.todaySession!.areaId), ('paladin', 'riptide'));
    expect(store.totalXp, xp);
    expect(store.defaultFilter, const ExerciseFilter(classId: 'cablemancer', difficulty: 5)); // the class cards follow
    _now = _now.add(const Duration(days: 1));
    store.addSet(store.variantFor(_cards(store).first).id);
    expect(store.todaySession!.areaId, 'riptide');
    expect(store.sessions['2026-11-21']!.difficultyId, 'sweat');

    // With no sets yet, a change makes today's workout again.
    final (fresh, _) = await _store(setUp: true);
    fresh.addSet(_squat);
    fresh.removeSet(_squat);
    fresh.setProfile(gym);
    expect(fresh.todaySession, isNull);
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

  test('XP: sets (cap, criticals) and the first set of the day; no streak', () async {
    final (store, _) = await _store(setUp: true);
    for (var i = 0; i < 12; i++) {
      store.addSet(_squat); // sets 11 and 12 give 0
    }
    int expected(Session s) => [
          for (final e in s.exercises)
            for (var n = 1; n <= e.sets; n++)
              xpForSet(setNumber: n, difficulty: _d, critical: isCritical(s.date, exerciseCatalog.groupKeyOf(e.exerciseId), n)), // one entry per move here
        ].fold(0, (a, b) => a + b);
    final sat = store.todaySession!;
    expect(store.xpEvents.where((e) => e.source == 'sets').single.amount, expected(sat));
    expect(store.xpEvents.where((e) => e.source == 'day').single.amount, xpFirstSetOfDay);
    expect(store.groupXpToday('move:squat'), expected(sat));

    // Training days in later weeks give no extra XP (D34).
    for (final d in [22, 23, 27, 30]) {
      _now = DateTime(2026, 11, d, 9);
      store.addSet(_bench);
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
    store.addSet(_squat);
    _now = _now.add(const Duration(days: 1));
    store.addSet(_bench);
    store.toggleFavorite(_bench);
    final backup = store.backupJson();
    final data = jsonDecode(backup) as Map;
    expect(data['version'], 6);
    expect(data.keys, containsAll(['profile_v1', 'body_history_v1', 'sessions_v3', 'xp_events_v1', 'favorites_v1']));

    final (other, otherPrefs) = await _store(old: true); // un-migrated old data on this phone
    await other.importBackup(backup);
    expect(other.profile!.classId, 'paladin');
    expect(other.sessions.length, 2);
    expect(other.bodyHistory.length, 1);
    expect(other.setsToday(_bench), 1);
    expect(other.favorites, {_bench});
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

  testWidgets('language switch (D68): EN / RO on the body card, saved, every text changes', (t) async {
    _phone(t);
    final (store, prefs) = await _store();
    I18n.instance.useJson(langFiles, prefs: prefs);
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    expect(find.text('CHARACTER · STEP 1 OF 4'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('lang-ro')));
    await _frames(t);
    expect(find.text('PERSONAJ · PASUL 1 DIN 4'), findsOneWidget);
    expect(find.text('ÎNAINTE: CLASA'), findsOneWidget);
    expect(find.text('CREEAZĂ-ȚI ATLETUL'), findsOneWidget);
    expect(find.text('1,75 M'), findsOneWidget);
    expect(prefs.getString(I18n.prefsKey), 'ro');
    await t.tap(find.text('ÎNAINTE: CLASA'));
    await _frames(t);
    expect(find.text('HAIDUC'), findsOneWidget);
    expect(find.text('MOD CANAPEA'), findsOneWidget);
    await t.tap(find.text('ÎNAPOI'));
    await _frames(t);
    await t.tap(find.byKey(const ValueKey('lang-en')));
    await _frames(t);
    expect(find.text('CHARACTER · STEP 1 OF 4'), findsOneWidget);
    expect(prefs.getString(I18n.prefsKey), 'en');
    expect(t.takeException(), isNull);
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
    // A height model (D64): more pixel rows, same width, not a scaled picture.
    expect(tall.width, short.width);
    expect(heightRows(100).length - heightRows(50).length, 4);
    expect(heightRows(0).length, spriteHeight - 4);
    expect(heightRows(100).where((y) => y == 19).length, 2); // the chest row repeated

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

    expect(find.text('NEXT'), findsNothing);
    await t.tap(find.text('NEXT: CLASS')); // NEXT names the next screen (D65)
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
    expect(find.text(classById('scrapper').style), findsNothing); // no description under the tags (D63)
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
    expect(find.text('A barbell, a rack and a wall of plates.'), findsNothing); // no loadout
    expect(find.text('STRONGMAN'), findsNothing); // no tags
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
    expect(find.text('SCRATCH THE WALL'), findsNothing); // no hint on the area card
    expect(find.text(areaById('gainsgard').line), findsNothing); // and no line
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
    await _frames(t, 10);
    expect(find.text("LET'S\nGO!!!"), findsOneWidget); // the welcome burst: only LET'S GO (D65)
    expect(find.text('THE BAR IS WAITING.'), findsNothing);
    await _frames(t, 60);

    final saved = Profile.fromJson(jsonDecode(prefs.getString('profile_v1')!) as Map<String, dynamic>);
    expect(saved.character,
        const Character(sex: 'female', height: 100, muscle: 100, fat: 0, skin: 'deep', hair: 'blonde', facialHair: 'beard'));
    expect((saved.classId, saved.difficultyId, saved.areaId, saved.schemaVersion), ('paladin', 'sweat', 'gainsgard', 1));
    // The workout is home (D49); a new lifter's Today is empty: OPEN CHALK (D82).
    expect(find.byKey(const ValueKey('today-empty-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('world-object')), findsNothing); // no card to add a set to
    expect(find.textContaining('THIS WEEK'), findsNothing); // no streak (D34)
    expect(pushes.pushes, 1); // only the home route: views never push routes
  });

  testWidgets('workout: tap adds a working set, long-press takes one away', (t) async {
    final (store, _) = await _openApp(t);
    expect(find.byKey(const ValueKey('world-object')), findsOneWidget); // the app opens on the workout
    expect(find.text('TRAIN'), findsNothing);
    expect(find.text('START TRAINING ▶'), findsNothing);
    expect(find.text('I WORKED 💪'), findsNothing);
    final firstCard = _cards(store).first;
    final first = store.variantFor(firstCard).id;
    expect(find.text('NO SETS YET'), findsNothing); // no sets on the card (D74): they show in the world

    final card = find.byKey(const ValueKey('world-object'));
    await t.tap(card);
    await _frames(t, 70); // level-up intro card
    // A tap on a level-up card only closes it; let it close by itself.
    Future<void> closeCard() async {
      if (find.byKey(const ValueKey('intro-card')).evaluate().isNotEmpty) {
        await t.pump(const Duration(milliseconds: 1900)); // a tap would only close it: wait
        await t.pump(const Duration(milliseconds: 80));
      }
    }

    for (var i = 0; i < 5; i++) {
      await closeCard();
      await t.tap(card);
      await t.pump(const Duration(milliseconds: 80));
    }
    await closeCard();
    await _frames(t, 20);
    expect(find.byKey(ValueKey('exercise-${firstCard.key}')), findsOneWidget); // no targets: it stays
    await t.longPress(card);
    await _frames(t, 70);
    expect(store.setsToday(first), 5);
    expect(find.textContaining('SETS · +'), findsNothing); // no set line on the card (D74)

    expect(find.text('KEEP GOING'), findsNothing); // no hub (D49)
    expect(store.todaySession!.totalSets, 5);

    // The lifter profile (D59): today's session is the first page.
    await t.tap(find.byKey(const ValueKey('workout-character')));
    await _frames(t, 20);
    // D62: the session tile gives the sessions the space; the lifter becomes a tile.
    await t.tap(find.byKey(const ValueKey('tile-session')));
    await _frames(t, 20);
    expect(find.descendant(of: find.byKey(const ValueKey('session-card')), matching: find.textContaining('TODAY · ')), findsOneWidget);
    expect(find.byKey(const ValueKey('tile-lifter')), findsOneWidget);
    expect(find.text('BUILD YOUR LIFTER'), findsNothing);
    await t.tap(find.byKey(const ValueKey('mini-workout')));
    await _frames(t, 20);
    expect(find.byKey(const ValueKey('profile-sessions')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('workout: no tools, no add card; the hub and profile show no streak or milestones', (t) async {
    await _openApp(t);
    expect(find.text('THIS WEEK'), findsNothing);
    for (final k in ['tool-swap', 'tool-first', 'tool-skip', 'tool-remove', 'strip-add']) {
      expect(find.byKey(ValueKey(k)), findsNothing, reason: k);
    }
    expect(find.byKey(const ValueKey('exercise-counter')), findsOneWidget);
    expect(find.byKey(const ValueKey('world-object')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('workout (D48, D50): swipe the exercise carousel; the world adds to the one shown', (t) async {
    final (store, _) = await _openApp(t);
    final list = [for (final id in store.todayIds) exerciseCatalog.groupKeyOf(id)]; // 3 cards (D82: only Today shows)
    expect(find.byKey(ValueKey('exercise-${list[0]}')), findsOneWidget);
    // D79: no total, one dot per Today card, and no SUGGESTED label (D81).
    expect(find.text('1 / ${list.length}'), findsNothing);
    expect(find.byKey(const ValueKey('today-dot-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('today-dot-3')), findsNothing);
    expect(find.text('SUGGESTED'), findsNothing);
    // Up / down does nothing to the exercise carousel (D65).
    final before = t.getRect(find.byKey(const ValueKey('favorite-star')));
    await t.drag(find.byKey(const ValueKey('exercise-card')), const Offset(0, -200));
    await _frames(t, 10);
    expect(find.byKey(ValueKey('exercise-${list[0]}')), findsOneWidget);
    // A swipe up with a little sideways drift does nothing either (D66).
    await t.fling(find.byKey(const ValueKey('exercise-card')), const Offset(-60, -260), 1200);
    await _frames(t, 10);
    expect(find.byKey(ValueKey('exercise-${list[0]}')), findsOneWidget);
    expect(t.getRect(find.byKey(const ValueKey('favorite-star'))), before);
    // No tag row (D82): no class label, no difficulty, class, BODY PART or
    // star tags; the class shows in the outfit and the lifter profile.
    expect(find.byKey(const ValueKey('workout-filters')), findsNothing);
    expect(find.byKey(const ValueKey('class-label')), findsNothing);
    expect(find.text('PLATE PALADIN'), findsNothing);
    for (final k in ['filter-difficulty', 'filter-class', 'filter-body', 'filter-favorites']) {
      expect(find.byKey(ValueKey(k)), findsNothing, reason: k);
    }
    // "+ CHALK" sits at the right end of the dots row, at the bottom.
    final chalk = t.getRect(find.byKey(const ValueKey('filter-chalk')));
    final dots = t.getRect(find.byKey(const ValueKey('today-dot-2')));
    expect(find.descendant(of: find.byKey(const ValueKey('filter-chalk')), matching: find.text('+ CHALK')), findsOneWidget);
    expect((chalk.center.dy - dots.center.dy).abs(), lessThan(1));
    expect(chalk.left, greaterThan(dots.right));
    // The card has no muscle / level / equipment line.
    expect(find.byKey(const ValueKey('exercise-info')), findsNothing);
    // The level and XP bar sits in the PUMPLEX bar.
    expect(find.byKey(const ValueKey('top-level')), findsOneWidget);
    // Swipe on the title: a drag on a long chip row scrolls the row (D79).
    final carousel = find.byKey(const ValueKey('exercise-title'));
    await t.fling(carousel, const Offset(-300, 0), 1000); // next
    await _frames(t, 10);
    expect(find.byKey(ValueKey('exercise-${list[1]}')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('world-object')));
    await _frames(t, 70);
    if (find.byKey(const ValueKey('intro-card')).evaluate().isNotEmpty) {
      await t.pump(const Duration(milliseconds: 1900)); // a tap would go through it: wait
      await _frames(t, 4);
    }
    expect((store.groupSetsToday(list[0]), store.groupSetsToday(list[1])), (0, 1));
    expect(find.byKey(ValueKey('exercise-${list[1]}')), findsOneWidget);
    await t.fling(carousel, const Offset(-300, 0), 1000); // next: the last Today card
    await _frames(t, 10);
    expect(find.byKey(ValueKey('exercise-${list[2]}')), findsOneWidget);
    await t.fling(carousel, const Offset(-300, 0), 1000); // round to the first: no catalog after Today
    await _frames(t, 10);
    expect(find.byKey(ValueKey('exercise-${list[0]}')), findsOneWidget);
    expect(find.byKey(const ValueKey('suggested-line')), findsNothing);
    await t.fling(carousel, const Offset(300, 0), 1000); // back, round to the last one
    await _frames(t, 10);
    expect(find.byKey(ValueKey('exercise-${list.last}')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('workout (D55): modifier chips pick the exercise of a move', (t) async {
    final (store, _) = await _openApp(t);
    // The Bench Press card joins Today and shows (D79).
    final bench = exerciseCatalog.byKey['move:bench press']!;
    store.addToToday(store.variantFor(bench).id);
    await _frames(t, 8);
    expect(find.text(store.variantFor(bench).name.toUpperCase()), findsOneWidget); // the title (D75)
    expect(find.byKey(const ValueKey('exercise-variant')), findsNothing); // no subtitle (D74)
    // Rows for equipment and angle; no Smith machine for a Paladin (greyed).
    expect(find.text('EQUIPMENT'), findsOneWidget);
    expect(find.text('ANGLE'), findsOneWidget);
    final angle = find.byKey(const ValueKey('mod-angle-Incline'));
    await t.ensureVisible(angle);
    await t.tap(angle);
    await _frames(t, 6);
    final picked = store.variantFor(bench);
    expect(picked.mods['angle'], 'Incline');
    expect(find.text(picked.name.toUpperCase()), findsOneWidget); // the picked exercise is the title (D75)
    // The world adds the set to the exercise picked.
    await t.tap(find.byKey(const ValueKey('world-object')));
    await _frames(t, 70);
    expect(store.setsToday(picked.id), 1);
    expect(store.groupSetsToday('move:bench press'), 1);
    expect(t.takeException(), isNull);
  });

  testWidgets('workout: the star button (D53); no star tag (D82)', (t) async {
    final (store, _) = await _openApp(t);
    final carousel = find.byKey(const ValueKey('exercise-card'));
    await t.fling(carousel, const Offset(-300, 0), 1000);
    await _frames(t, 10);
    final second = _cards(store)[1].key;
    final shown = store.variantFor(_cards(store)[1]).id;
    await t.tap(find.byKey(const ValueKey('favorite-star')));
    await _frames(t, 10);
    expect(store.favorites, {shown}); // the exercise shown (D72)
    expect(find.byKey(ValueKey('exercise-$second')), findsOneWidget); // the card stays
    expect(find.byKey(const ValueKey('filter-favorites')), findsNothing); // no star tag (D82)
    // Unstar it: the card stays in Today.
    await t.tap(find.byKey(const ValueKey('favorite-star')));
    await _frames(t, 10);
    expect(store.favorites, isEmpty);
    expect(find.byKey(ValueKey('exercise-$second')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('marks (D74): a spot holds the newest set on it; laps start again at the first spot', () {
    // 10 spots: sets 1-10 are lap 0; set 11 lands on spot 0 in lap 1.
    expect([for (var i = 0; i < 3; i++) markLap(i, 10, 10)], [0, 0, 0]);
    expect([for (var i = 0; i < 3; i++) markLap(i, 12, 10)], [1, 1, 0]);
    expect(markLap(0, 21, 10), 2);
    expect(markLap(5, 3, 10), 0); // no set there yet
  });

  testWidgets('D75: no TM; the workout keeps the card picked after leaving', (t) async {
    final (store, prefs) = await _openApp(t);
    expect(find.text('PUMPLEX'), findsWidgets); // drawn in layers
    expect(find.textContaining('™'), findsNothing);
    await t.fling(find.byKey(const ValueKey('exercise-card')), const Offset(-300, 0), 1000);
    await _frames(t, 10);
    final second = _cards(store)[1].key;
    expect(prefs.getString(LogStore.pickedCardKey), store.variantFor(_cards(store)[1]).id); // the exercise (D82)
    // Leave and come back: a new app on the same data opens on that card.
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(GymApp(store: store));
    await _frames(t);
    expect(find.byKey(ValueKey('exercise-$second')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('D74: many sets show their number in the world; chips have no numbers; difficulty card', (t) async {
    final (store, _) = await _openApp(t);
    final first = store.variantFor(_cards(store).first).id;
    for (var i = 0; i < 25; i++) {
      store.addSet(first);
    }
    await _frames(t, 10);
    final spots = find.byKey(const ValueKey('scene-count'));
    if (store.profile!.areaId != 'arcade') {
      expect(spots, findsOneWidget);
      expect(find.descendant(of: spots, matching: find.text('25 SETS')), findsOneWidget);
      // Inside the screen, never cut off (D75).
      final r = t.getRect(spots);
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(t.view.physicalSize.width / t.view.devicePixelRatio));
    }
    // The class screen: the difficulty in a card with who it is for.
    await t.tap(find.byKey(const ValueKey('workout-character')));
    await _frames(t, 20);
    await t.fling(find.byKey(const ValueKey('lifter-editor')), const Offset(0, -300), 1000);
    await _frames(t, 20);
    expect(find.byKey(const ValueKey('difficulty-card')), findsOneWidget);
    expect(find.text(difficulties[store.difficulty].line), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('lifter profile (D59-D62): the BODY editor takes the space, the last session is a tile', (t) async {
    final (store, _) = await _openApp(t);
    for (final k in ['nav-hub', 'nav-history', 'nav-profile', 'menu-open']) {
      expect(find.byKey(ValueKey(k)), findsNothing, reason: k);
    }
    final full = t.getRect(find.byKey(const ValueKey('world-object')));
    await t.tap(find.byKey(const ValueKey('workout-character')));
    await _frames(t, 20);
    // The arena only, as a square tile; beside it the last session; under them the BODY editor.
    expect(t.getRect(find.byKey(const ValueKey('world-object'))).width, lessThan(full.width * 0.6));
    final win = t.getRect(find.byKey(const ValueKey('mini-workout')));
    expect(win.width, closeTo(win.height, 1));
    expect(find.byKey(const ValueKey('tile-session')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-sessions')), findsNothing);
    expect(find.text('BUILD YOUR LIFTER'), findsOneWidget);
    expect(find.text('NEXT'), findsNothing);
    expect(find.byKey(const ValueKey('profile-lifter')), findsNothing); // no lifter card (D62)
    expect(find.byKey(const ValueKey('body-card')), findsOneWidget); // BODY is a card (D63)
    // The vertical carousel (D63): BODY, CLASS, AREA. Down from BODY is AREA.
    final editor = find.byKey(const ValueKey('lifter-editor'));
    await t.fling(editor, const Offset(0, 300), 1000);
    await _frames(t, 20);
    expect(find.byKey(const ValueKey('area-card')), findsOneWidget);
    // Up from AREA is BODY, up from BODY is CLASS.
    await t.fling(editor, const Offset(0, -300), 1000);
    await _frames(t, 20);
    expect(find.text('BUILD YOUR LIFTER'), findsOneWidget);
    await t.fling(editor, const Offset(0, -300), 1000);
    await _frames(t, 20);
    expect(find.byKey(const ValueKey('class-card')), findsOneWidget);
    await t.fling(find.byKey(const ValueKey('class-card')), const Offset(-300, 0), 1000);
    await _frames(t, 10);
    expect(store.profile!.classId, 'cablemancer'); // saved at once
    // Down from CLASS is BODY.
    await t.fling(editor, const Offset(0, 300), 1000);
    await _frames(t, 20);
    expect(find.text('BUILD YOUR LIFTER'), findsOneWidget);
    // A slow drag that is let go early springs back.
    await t.drag(editor, const Offset(0, -40));
    await _frames(t, 20);
    expect(find.text('BUILD YOUR LIFTER'), findsOneWidget);
    final bodies = store.bodyHistory.length;
    await t.drag(find.byKey(const ValueKey('slider-WEIGHT')), const Offset(400, 0));
    await _frames(t, 4);
    expect(store.profile!.character.fat, 100); // saved when the drag ends
    expect(store.bodyHistory.length, bodies + 1);
    // The session tile gives the sessions the space; the lifter becomes a tile.
    await t.tap(find.byKey(const ValueKey('tile-session')));
    await _frames(t, 10);
    expect(find.byKey(const ValueKey('profile-sessions')), findsOneWidget);
    expect(find.byKey(const ValueKey('tile-lifter')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('tile-lifter')), matching: find.text('CABLEMANCER')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('tile-lifter')));
    await _frames(t, 10);
    expect(find.byKey(const ValueKey('lifter-editor')), findsOneWidget);
    // Back to the full-screen workout.
    await t.tap(find.byKey(const ValueKey('mini-workout')));
    await _frames(t, 20);
    expect(find.byKey(const ValueKey('profile-sessions')), findsNothing);
    expect(find.byKey(const ValueKey('world-object')), findsOneWidget);
  });

  testWidgets('3 quick world taps, the 2nd a level-up: 2 sets, the 3rd tap only closes the card', (t) async {
    final (store, _) = await _openApp(t);
    final id = store.pickedCard!;
    _oneSetBeforeLevelUp(store, id);
    final sets = store.setsToday(id);
    final level = levelFor(store.totalXp).level;
    await t.pump();
    final world = find.byKey(const ValueKey('world-object'));
    await t.tap(world); // no level-up
    await t.pump(const Duration(milliseconds: 80));
    expect(levelFor(store.totalXp).level, level);
    expect(find.byKey(const ValueKey('intro-card')), findsNothing);
    await t.tap(world); // the level-up
    await t.pump(const Duration(milliseconds: 80)); // the card is in its slam
    expect(levelFor(store.totalXp).level, greaterThan(level));
    expect(find.byKey(const ValueKey('intro-card')), findsOneWidget);
    await t.tap(world, warnIfMissed: false); // on the card: it only closes it
    await t.pump(const Duration(milliseconds: 80));
    expect(store.setsToday(id), sets + 2);
    expect(find.byKey(const ValueKey('intro-card')), findsNothing);
    await _frames(t, 20);
    expect(find.byKey(const ValueKey('tile-session')), findsNothing); // no lifter profile
    expect(t.takeException(), isNull);
  });

  testWidgets('a tap on the lifter during the level-up card only closes the card', (t) async {
    final (store, _) = await _openApp(t);
    final id = store.pickedCard!;
    final lifter = t.getCenter(find.byKey(const ValueKey('workout-character')));
    await t.tap(find.byKey(const ValueKey('world-object'))); // the first set: a level-up
    await t.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const ValueKey('intro-card')), findsOneWidget);
    await t.tapAt(lifter);
    await t.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const ValueKey('intro-card')), findsNothing);
    await _frames(t, 20);
    expect(find.byKey(const ValueKey('tile-session')), findsNothing); // the profile did not open
    expect(store.setsToday(id), 1);
  });

  testWidgets('a level-up shows the freeze-frame card', (t) async {
    final (store, _) = await _openApp(t);
    await t.tap(find.byKey(const ValueKey('world-object'))); // first set: +50 and more
    await t.pump(const Duration(milliseconds: 600));
    final level = levelFor(store.totalXp).level;
    expect(level, greaterThan(1));
    expect(find.byKey(const ValueKey('intro-card')), findsOneWidget);
    expect(find.text('LEVEL $level'), findsOneWidget);
    for (final line in levelUpLines) {
      expect(find.text(line.toUpperCase()), findsNothing); // no joke line (D74)
    }
    await _frames(t, 70);
    expect(find.byKey(const ValueKey('intro-card')), findsNothing);
    expect(find.byKey(const ValueKey('hub-gear')), findsNothing); // no gear (D38)
  });

  testWidgets('the phone back button leaves the app, even from the lifter profile (D60)', (t) async {
    await _openApp(t);
    await t.tap(find.byKey(const ValueKey('top-level'))); // the level bar opens the lifter profile too
    await _frames(t);
    expect(find.byKey(const ValueKey('tile-session')), findsOneWidget);
    expect(find.byType(PopScope), findsNothing); // nothing holds the back button
  });

  testWidgets('the phone bars are hidden (D81): immersive sticky at start and again on resume', (t) async {
    final modes = <Object?>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setEnabledSystemUIMode') modes.add(call.arguments);
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    hideSystemBars();
    await t.pump();
    expect(modes, ['SystemUiMode.immersiveSticky']);
    await _openApp(t);
    modes.clear();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    expect(modes, ['SystemUiMode.immersiveSticky']);
  });

  testWidgets('the BODY editor shows the saved body', (t) async {
    await _openApp(t);
    await t.tap(find.byKey(const ValueKey('workout-character')));
    await _frames(t, 20);
    expect(find.text('BUILD YOUR LIFTER'), findsOneWidget);
    final edit = t.widget<AtlasSprite>(find.descendant(of: find.byKey(const ValueKey('edit-lifter')), matching: find.byKey(const ValueKey('character-sprite'))));
    expect(edit.frame, spriteFrame(_profile.character));
    await t.pump(const Duration(seconds: 5));
  });

  for (final (b, lang) in [for (final b in Brightness.values) for (final l in I18n.languages) (b, l)]) {
    testWidgets('every scene renders on a phone ($b, $lang)', (t) async {
      _phone(t);
      I18n.instance.useJson(langFiles, lang: lang);
      final (store, _) = await _store(setUp: true);
      store.addSet(_squat);
      await t.pumpWidget(MaterialApp(theme: pumplexTheme(b), home: GameShell(store: store)));
      await _frames(t);
      Future<void> tapAndSettle(Finder f) async {
        await t.tap(f);
        await _frames(t);
        expect(t.takeException(), isNull);
      }

      // The lifter profile (D59): swipe the sessions, then back to the workout.
      await tapAndSettle(find.byKey(const ValueKey('workout-character')));
      await tapAndSettle(find.byKey(const ValueKey('tile-session')));
      await t.fling(find.byKey(const ValueKey('session-card')), const Offset(-300, 0), 1000);
      await _frames(t);
      await tapAndSettle(find.byKey(const ValueKey('mini-workout')));
      // The lifter editor (D63): swipe up for CLASS, then AREA, then BODY again.
      await tapAndSettle(find.byKey(const ValueKey('top-level')));
      await t.fling(find.byKey(const ValueKey('lifter-editor')), const Offset(0, -300), 1000);
      await _frames(t);
      await tapAndSettle(find.byKey(const ValueKey('class-dot-bruiser')));
      await t.fling(find.byKey(const ValueKey('lifter-editor')), const Offset(0, -300), 1000);
      await _frames(t);
      await tapAndSettle(find.byKey(const ValueKey('area-dot-arcade')));
      await t.fling(find.byKey(const ValueKey('lifter-editor')), const Offset(0, -300), 1000);
      await _frames(t);
      expect(find.byKey(const ValueKey('body-card')), findsOneWidget);
      // The remove dialog (D82), with its longest texts: KEEP closes it.
      await tapAndSettle(find.byKey(const ValueKey('mini-workout')));
      await tapAndSettle(find.byKey(const ValueKey('today-remove')));
      await tapAndSettle(find.byKey(const ValueKey('today-remove-cancel')));
      await tapAndSettle(find.byKey(const ValueKey('top-level')));
      expect((store.profile!.classId, store.profile!.areaId), ('bruiser', 'arcade'));
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
