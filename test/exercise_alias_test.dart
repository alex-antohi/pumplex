// Frozen ids and aliases (D90): an exercise that the list clean-up merged or
// removed keeps its old id as an alias of the exercise that replaces it.
// Saved sets, favorites, Today and the picks read old ids through it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gym_app/game/chalk.dart';
import 'package:gym_app/game/exercises.dart';
import 'package:gym_app/game/forge.dart';
import 'package:gym_app/game/model.dart';
import 'package:gym_app/store.dart';

const _profile = Profile(
  character: Character(sex: 'female', height: 80, muscle: 100, fat: 0),
  classId: 'paladin',
  difficultyId: 'sweat',
  areaId: 'gainsgard',
);

void main() {
  setUpAll(() => exerciseCatalog = ExerciseCatalog.parse(File(ExerciseCatalog.asset).readAsStringSync()));

  test('an old id resolves to the exercise that replaces it', () {
    expect(exerciseCatalog.byId['Parallel_Bar_Dip'], isNull);
    expect(exerciseCatalog.resolveId('Parallel_Bar_Dip'), 'Dips_-_Triceps_Version');
    expect(exerciseCatalog.resolveId('Lying_Triceps_Press'), 'EZ-Bar_Skullcrusher');
    expect(exerciseCatalog.resolveId('Clean_and_Press'), 'Barbell_Push_Press');
    expect(exerciseCatalog.resolveId('Full_Range-Of-Motion_Lat_Pulldown'), 'lat pulldown|cable|medium grip');
    expect(exerciseCatalog.groupKeyOf('Standing_Bent-Over_Two-Arm_Dumbbell_Triceps_Extension'), 'move:triceps kickback');
    expect(exerciseName('Parallel_Bar_Dip'), exerciseCatalog.byId['Dips_-_Triceps_Version']!.name);
    // A current id and an unknown id stay as they are.
    expect(exerciseCatalog.resolveId('Pushups'), 'Pushups');
    expect(exerciseCatalog.resolveId('custom_3'), 'custom_3');
    // An old card key of a merged move follows too.
    expect(exerciseCatalog.groupKeyOf('move:triceps press'), 'move:skullcrusher');
    expect(exerciseCatalog.groupKeyOf('move:clean'), 'move:power clean');
  });

  test('every frozen id is in the list or an alias of an exercise in it', () {
    final frozen = File('tools/frozen_ids.txt').readAsLinesSync().map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    expect(frozen.length, 527);
    for (final id in frozen) {
      expect(exerciseCatalog.byId[exerciseCatalog.resolveId(id)], isNotNull, reason: id);
    }
    // An alias is never a current id, and points to one.
    for (final MapEntry(:key, :value) in exerciseCatalog.aliasOf.entries) {
      expect(exerciseCatalog.byId[key], isNull, reason: key);
      expect(exerciseCatalog.byId[value], isNotNull, reason: key);
    }
  });

  test('D90 step 2: band and chain rows, the folded jump cards and the one Ball keep their old ids', () {
    // Bands and Chains only on Bench Press, Squat and Deadlift.
    for (final (old, plain) in [
      ('Box_Squat_with_Bands', 'Box_Squat'),
      ('Box_Squat_with_Chains', 'Box_Squat'),
      ('Floor_Press_with_Chains', 'Floor_Press'),
      ('Rack_Pull_with_Bands', 'Rack_Pulls'),
      ('Sumo_Deadlift_with_Bands', 'Sumo_Deadlift'),
      ('Sumo_Deadlift_with_Chains', 'Sumo_Deadlift'),
    ]) {
      expect(exerciseCatalog.resolveId(old), plain, reason: old);
    }
    final banded = {for (final e in exerciseCatalog.all) if (e.mods['bands'] != null || e.mods['chains'] != null) e.base};
    expect(banded, {'Bench Press', 'Squat', 'Deadlift'});
    // The renamed ball variation.
    expect(exerciseCatalog.resolveId('russian twist|medicine ball'), 'russian twist|ball');
    // The jump cards: every old lift is a chip of a new card; old card keys follow.
    for (final (id, card) in [
      ('Freehand_Jump_Squat', 'jump squat'), ('Weighted_Jump_Squat', 'jump squat'), ('Knee_Tuck_Jump', 'jump squat'),
      ('Star_Jump', 'jump squat'), ('Rocket_Jump', 'jump squat'), ('Front_Box_Jump', 'jump squat'),
      ('Split_Jump', 'jumping lunge'), ('Scissors_Jump', 'jumping lunge'),
      ('Standing_Long_Jump', 'long jump'), ('Lateral_Bound', 'long jump'),
      ('Fast_Skipping', 'running drill'), ('Carioca_Quick_Step', 'running drill'),
      ('Double_Leg_Butt_Kick', 'running drill'), ('Single_Leg_Butt_Kick', 'running drill'),
    ]) {
      expect(exerciseCatalog.groupKeyOf(id), 'move:$card', reason: id);
    }
    for (final (old, card) in [('move:star jump', 'jump squat'), ('move:box jump', 'jump squat'), ('move:split jump', 'jumping lunge'),
      ('move:lateral bound', 'long jump'), ('move:butt kick', 'running drill')]) {
      expect(exerciseCatalog.groupKeyOf(old), 'move:$card', reason: old);
    }
    expect(exerciseCatalog.byKey['move:jump squat']!.variants.length, 6);
  });

  test('D90 step 2: a forged move with the old ball or towel word still loads', () {
    final ball = ForgedMove.fromJson({'id': 'custom_1', 'words': ['tool.ball', 'move.crunch'], 'muscle': 'abdominals'});
    expect(ball.words, {'tool.ball', 'move.crunch'});
    expect(ball.toExercise().equipment, 'ball');
    expect(ball.toExercise().mods, {'equip': 'Ball'});
    final towel = ForgedMove.fromJson({'id': 'custom_2', 'words': ['tool.towel', 'move.row'], 'muscle': 'middle back'});
    expect(towel.words, {'tool.towel', 'move.row'});
    expect(towel.name, 'Towel Row');
    final cat = catalogWithForged(exerciseCatalog, [ball, towel]);
    final index = ChalkIndex(cat);
    expect(index.words['custom_1'], containsAll(['tool.ball', 'move.crunch']));
    expect(index.words['custom_2'], containsAll(['tool.towel', 'tool.bodyweight', 'move.row']));
    // An older forged move with only an English name gets its words back.
    expect(ForgedMove.fromJson({'id': 'custom_3', 'name': 'Ball Crunch', 'muscle': 'abdominals'}).words, {'tool.ball', 'move.crunch'});
  });

  test('D90 step 2: Rings/TRX is a tool; the class gear (D50, the lit rule of D89)', () {
    expect(chalkWordByKey('tool.rings'), isNotNull);
    expect(chalkRackTools.length, 11);
    final rings = [for (final e in exerciseCatalog.all) if (e.mods['equip'] == 'Rings') e.id]..sort();
    // D90 step 3 part B added the ring plank, L-sit, muscle-up, tuck front lever and the feet-up ring row.
    expect(rings, [
      'Ring_Dips', 'ab rollout|rings', 'front lever|rings', 'front lever|rings|tuck', 'inverted row|rings',
      'inverted row|rings|decline', 'l-sit|rings', 'muscle-up|rings', 'plank|rings', 'pull-up|rings', 'push-up|rings',
      'push-up|rings|decline', 'support hold|rings',
    ]);
    expect(classGear['scrapper'], ['bodyweight', 'rings']);
    expect(classGear['bruiser'], ['dumbbell', 'kettlebell', 'bands', 'ball', 'bodyweight']);
    expect(classGear['paladin'], ['barbell', 'ezbar', 'dumbbell', 'kettlebell', 'bodyweight']);
    expect(classGear['cablemancer'], ['machine', 'cable', 'smith', 'bodyweight']);
    // The tools of the class's equipment (D50) are its gear; every class has Bodyweight.
    final index = ChalkIndex.of(exerciseCatalog);
    for (final MapEntry(key: c, value: gear) in classGear.entries) {
      expect(gear, contains('bodyweight'), reason: c);
      for (final e in exerciseCatalog.all.where((e) => classEquipment[c]!.contains(e.equipment))) {
        final tool = index.words[e.id]!.firstWhere((k) => k.startsWith('tool.') && k != 'tool.towel').substring(5);
        // A Smith machine is a machine in the database: only the Cablemancer has it.
        if (tool == 'smith' && c != 'cablemancer') continue;
        expect(gear, contains(tool), reason: '$c ${e.id}');
      }
    }
    // Trap Bar and Landmine lifts are Plate Paladin gear.
    for (final id in ['Trap_Bar_Deadlift', 'Landmine_Linear_Jammer']) {
      expect(classEquipment['paladin'], contains(exerciseCatalog.byId[id]!.equipment), reason: id);
    }
  });

  test('a session joins the entries that get one id', () {
    const s = Session(date: '2026-11-20', classId: 'paladin', difficultyId: 'sweat', areaId: 'gainsgard', exercises: [
      SessionExercise(exerciseId: 'Dips_-_Triceps_Version', sets: 2, log: [SetLog(kg: 10)]),
      SessionExercise(exerciseId: 'Parallel_Bar_Dip', sets: 1, log: [SetLog(kg: 20)]),
      SessionExercise(exerciseId: 'Pushups', sets: 3),
    ]);
    final out = s.withExerciseIds(exerciseCatalog.resolveId);
    expect(out.exercises.map((e) => e.exerciseId), ['Dips_-_Triceps_Version', 'Pushups']);
    expect(out.exercises.first.sets, 3);
    expect(out.exercises.first.log, const [SetLog(kg: 10), SetLog(), SetLog(kg: 20)]); // each log on its set
    expect(out.totalSets, s.totalSets);
    final same = Session(date: s.date, classId: s.classId, difficultyId: s.difficultyId, areaId: s.areaId);
    expect(identical(same.withExerciseIds(exerciseCatalog.resolveId), same), isTrue);
  });

  test('saved sets, favorites, Today and the picked card read old ids', () async {
    final now = DateTime(2026, 11, 21, 10);
    SharedPreferences.setMockInitialValues({
      'profile_v1': jsonEncode(_profile.toJson()),
      'sessions_v3': jsonEncode({
        '2026-11-21': {
          'classId': 'paladin',
          'difficultyId': 'sweat',
          'areaId': 'gainsgard',
          'legacy': false,
          'exercises': [
            {'exerciseId': 'Lying_Triceps_Press', 'sets': 2},
            {'exerciseId': 'EZ-Bar_Skullcrusher', 'sets': 1},
          ],
        },
      }),
      'favorites_v1': jsonEncode(['Clean_and_Press', 'Pushups']),
      LogStore.todayKey: jsonEncode({
        'date': '2026-11-21',
        'exercises': ['Lying_Triceps_Press', 'EZ-Bar_Skullcrusher', 'Parallel_Bar_Dip'],
      }),
      LogStore.pickedCardKey: 'Parallel_Bar_Dip',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = LogStore(prefs, clock: () => now);
    final day = store.todaySession!;
    expect(day.exercises.map((e) => e.exerciseId), ['EZ-Bar_Skullcrusher']);
    expect(day.totalSets, 3);
    expect(store.favorites, {'Barbell_Push_Press', 'Pushups'});
    expect(store.todayIds, ['EZ-Bar_Skullcrusher', 'Dips_-_Triceps_Version']);
    expect(store.pickedCard, 'Dips_-_Triceps_Version');
  });
}
