// The workout state kept on the phone (the picked card, the picked exercise, the
// filters).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gym_app/i18n.dart';
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

void main() {
  final langFiles = {for (final l in I18n.languages) l: File(I18n.asset(l)).readAsStringSync()};
  setUp(() => I18n.instance.useJson(langFiles));
  setUpAll(() => exerciseCatalog = ExerciseCatalog.parse(File(ExerciseCatalog.asset).readAsStringSync()));

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
      // A muscle of another body part goes back to all.
      expect(await load({'class': 'paladin', 'difficulty': 2, 'body': 'legs', 'muscle': 'chest'}),
          const ExerciseFilter(classId: 'paladin', difficulty: 2, body: 'legs'));
      expect(await load({'class': 'cablemancer', 'difficulty': 5, 'favorites': true}),
          const ExerciseFilter(classId: 'cablemancer', difficulty: 5, favorites: true));
    });
  });
}
