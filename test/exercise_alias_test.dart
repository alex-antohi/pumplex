// Frozen ids and aliases (D90): an exercise that the list clean-up merged or
// removed keeps its old id as an alias of the exercise that replaces it.
// Saved sets, favorites, Today and the picks read old ids through it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gym_app/game/exercises.dart';
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
