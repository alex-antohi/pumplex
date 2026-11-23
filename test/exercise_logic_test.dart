// Modifier chips (D55-D57) with the real exercise list, and the workout
// state kept on the phone (the picked card, the picked exercise, the
// filters).

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

var _now = DateTime(2026, 11, 21, 10);

Future<(LogStore, SharedPreferences)> _store([Map<String, Object> extra = const {}]) async {
  SharedPreferences.setMockInitialValues({'profile_v1': jsonEncode(_profile.toJson()), ...extra});
  final prefs = await SharedPreferences.getInstance();
  return (LogStore(prefs, clock: () => _now), prefs);
}

CatalogExercise _x(String id) => exerciseCatalog.byId[id]!;

void main() {
  setUpAll(() => exerciseCatalog = ExerciseCatalog.parse(File(ExerciseCatalog.asset).readAsStringSync()));

  ExerciseGroup bench() => exerciseCatalog.byKey['move:bench press']!;

  group('modifier chips', () {
    test('every move: a row is judged against the equipment only, and an existing mix is picked exactly', () {
      for (final g in exerciseCatalog.groups) {
        for (final cur in g.variants) {
          for (final (axis, values) in g.axesFor(cur)) {
            for (final value in values) {
              if (value == cur.mods[axis.id]) continue;
              final t = chipTarget(g, cur, axis.id, value);
              final withEquip = g.variants.where((v) =>
                  v.mods[axis.id] == value && (axis.id == 'equip' || v.mods['equip'] == cur.mods['equip']));
              // Never greyed just because of another row's value.
              expect(t, isNotNull, reason: '${cur.id} $axis.id=$value');
              expect(withEquip, contains(t!.v));
              if (axis.id == 'equip') continue;
              final exact = withEquip.where((v) => modifierAxes.every((a) => a.id == axis.id || v.mods[a.id] == cur.mods[a.id]));
              expect(t.exact, exact.isNotEmpty, reason: '${cur.id} ${axis.id}=$value');
              if (exact.isNotEmpty) expect(t.v, exact.single);
            }
          }
        }
      }
    });

    test('bench press: a mix that does not exist still works and changes as little as it can', () {
      final g = bench();
      // Barbell with bands has no incline: the chip is there, changes Bands
      // (a thin border), and keeps the grip width.
      final bands = _x('Bench_Press_-_With_Bands');
      final incline = chipTarget(g, bands, 'angle', 'Incline')!;
      expect((incline.v.id, incline.exact), ('Barbell_Incline_Bench_Press_-_Medium_Grip', false));
      // Incline wide grip, then chains: chains exist only flat and medium.
      final wide = _x('Incline_Wide-Grip_Barbell_Bench_Press');
      final chains = chipTarget(g, wide, 'chains', 'Chains')!;
      expect((chains.v.id, chains.exact), ('Bench_Press_with_Chains', false));
      // An existing mix keeps everything else.
      final close = chipTarget(g, wide, 'width', 'Close Grip')!;
      expect((close.v.id, close.exact), ('Incline_Close-Grip_Barbell_Bench_Press', true));
      final decline = chipTarget(g, _x('Close-Grip_Barbell_Bench_Press'), 'angle', 'Decline')!;
      expect((decline.v.id, decline.exact), ('Decline_Close-Grip_Barbell_Bench_Press', true));
      final hammer = chipTarget(g, _x('Incline_Dumbbell_Press'), 'hand', 'Neutral Grip')!;
      expect((hammer.v.id, hammer.exact), ('Hammer_Grip_Incline_DB_Bench_Press', true));
    });

    test('bench press: equipment keeps the angle, and no grip width means Medium Grip', () {
      final g = bench();
      // Was Close-Grip (the shortest name) before.
      expect(chipTarget(g, _x('Dumbbell_Bench_Press'), 'equip', 'Barbell')!.v.id, 'Barbell_Bench_Press_-_Medium_Grip');
      expect(chipTarget(g, _x('Incline_Dumbbell_Press'), 'equip', 'Barbell')!.v.id,
          'Barbell_Incline_Bench_Press_-_Medium_Grip');
      expect(chipTarget(g, _x('Decline_Dumbbell_Bench_Press'), 'equip', 'Smith Machine')!.v.id, 'Smith_Machine_Decline_Press');
      expect(chipTarget(g, _x('Barbell_Incline_Bench_Press_-_Medium_Grip'), 'equip', 'Dumbbell')!.v.id,
          'Incline_Dumbbell_Press');
    });

    test('bench press: barbell, dumbbell, barbell comes back to the same grip', () async {
      final (store, _) = await _store();
      ExerciseGroup card() => store.cards.firstWhere((g) => g.key == 'move:bench press');
      void tap(String axis, String? value) {
        final t = chipTarget(card(), store.variantFor(card()), axis, value)!;
        store.pickVariant(t.v.id);
      }

      store.pickVariant('Wide-Grip_Barbell_Bench_Press');
      tap('angle', 'Decline');
      expect(store.variantFor(card()).id, 'Wide-Grip_Decline_Barbell_Bench_Press');
      tap('equip', 'Dumbbell');
      expect(store.variantFor(card()).id, 'Decline_Dumbbell_Bench_Press');
      tap('equip', 'Barbell');
      expect(store.variantFor(card()).id, 'Wide-Grip_Decline_Barbell_Bench_Press'); // not Medium Grip
      // Dumbbells remember their neutral grip; the shown angle still wins.
      tap('equip', 'Dumbbell');
      tap('angle', 'Incline');
      tap('hand', 'Neutral Grip');
      expect(store.variantFor(card()).id, 'Hammer_Grip_Incline_DB_Bench_Press');
      tap('equip', 'Barbell');
      expect(store.variantFor(card()).id, 'Incline_Wide-Grip_Barbell_Bench_Press');
      tap('equip', 'Dumbbell');
      expect(store.variantFor(card()).id, 'Hammer_Grip_Incline_DB_Bench_Press');
    });
  });

  group('kept on the phone', () {
    test('the picked card and exercise come back after closing the app', () async {
      final (store, prefs) = await _store();
      store.setPickedCard('move:bench press');
      store.pickVariant('Decline_Barbell_Bench_Press');
      final again = LogStore(prefs, clock: () => _now);
      expect(again.pickedCard, 'move:bench press');
      final card = again.cards.firstWhere((g) => g.key == 'move:bench press');
      expect(again.variantFor(card).id, 'Decline_Barbell_Bench_Press');
      // A filter that hides the card keeps the saved pick for later.
      again.setFilter(again.filter.withBody('legs'));
      expect(again.cards.any((g) => g.key == 'move:bench press'), isFalse);
      expect(again.pickedCard, 'move:bench press');
      again.resetFilter();
      expect(again.variantFor(again.cards.firstWhere((g) => g.key == 'move:bench press')).id, 'Decline_Barbell_Bench_Press');
      // A pick the filters hide: the one picked before it.
      again.pickVariant('Bench_Press_with_Chains'); // expert: Sweat does not show it
      expect(again.variantFor(again.cards.firstWhere((g) => g.key == 'move:bench press')).id, 'Decline_Barbell_Bench_Press');
    });

    test('the filters stay after closing the app and the next day; reset clears them', () async {
      final (store, prefs) = await _store();
      final def = store.defaultFilter;
      store.setFilter(store.filter.withBody('legs').withMuscle('quadriceps').copyWith(difficulty: 4));
      final want = ExerciseFilter(classId: def.classId, difficulty: 4, body: 'legs', muscle: 'quadriceps');
      expect(store.filter, want);
      expect(prefs.getString(LogStore.filterKey), isNotNull);
      _now = _now.add(const Duration(days: 1));
      final again = LogStore(prefs, clock: () => _now);
      expect(again.filter, want);
      again.resetFilter();
      expect(again.filter, again.defaultFilter);
      expect(prefs.containsKey(LogStore.filterKey), isFalse);
      expect(LogStore(prefs, clock: () => _now).filter, again.defaultFilter);
      // A new class or mode goes back to the defaults too.
      again.setFilter(again.filter.withBody('arms'));
      again.setProfile(_profile.copyWith(classId: 'cablemancer'));
      expect(again.filter, again.defaultFilter);
      expect(prefs.containsKey(LogStore.filterKey), isFalse);
      // Not in the backup.
      again.setFilter(again.filter.withBody('arms'));
      expect(again.backupJson(), isNot(contains(LogStore.filterKey)));
      expect(again.backupJson(), isNot(contains(LogStore.pickedVariantsKey)));
    });

    test('stale saved filters fall back to the defaults', () async {
      Future<ExerciseFilter> load(Object saved) async {
        final (store, _) = await _store({LogStore.filterKey: saved is String ? saved : jsonEncode(saved)});
        return store.filter;
      }

      final (s, _) = await _store();
      final def = s.defaultFilter;
      expect(await load({'class': 'wizard', 'difficulty': 1, 'body': 'legs'}), def);
      expect(await load({'class': 'paladin', 'difficulty': 9}), def);
      expect(await load('not json'), def);
      expect(await load(const ['x']), def);
      expect(await load({'class': 'paladin', 'difficulty': 2, 'body': 'wings'}), def);
      // A muscle of another body part, or one with nothing left, goes back to all.
      expect(await load({'class': 'paladin', 'difficulty': 2, 'body': 'legs', 'muscle': 'chest'}),
          const ExerciseFilter(classId: 'paladin', difficulty: 2, body: 'legs'));
      expect(await load({'class': 'paladin', 'difficulty': 2, 'body': 'legs', 'muscle': 'adductors'}), // none for a Paladin
          const ExerciseFilter(classId: 'paladin', difficulty: 2, body: 'legs'));
      expect(await load({'class': 'cablemancer', 'difficulty': 5, 'favorites': true}),
          const ExerciseFilter(classId: 'cablemancer', difficulty: 5, favorites: true));
    });
  });
}
