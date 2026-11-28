// The workout state kept on the phone (the picked card, the picked
// exercise), and an old saved filter.

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
      final card = exerciseCatalog.byKey['move:bench press']!;
      expect(again.variantFor(card).id, 'Decline_Barbell_Bench_Press');
      // A CHALK search does not change the saved pick.
      again.setChalk({'tool.barbell', 'move.press'});
      expect(again.variantFor(card).id, 'Decline_Barbell_Bench_Press');
      // Not in the backup.
      expect(again.backupJson(), isNot(contains(LogStore.pickedVariantsKey)));
    });

    test('an old saved filter (before D82) is ignored', () async {
      for (final saved in [
        jsonEncode({'class': 'paladin', 'difficulty': 2, 'body': 'legs', 'muscle': 'quadriceps', 'favorites': true}),
        'not json',
      ]) {
        final (store, _) = await _store({'workout_filter_v1': saved});
        expect((store.gameClass.id, store.difficulty), ('paladin', 2));
        store.addToToday('Decline_Barbell_Bench_Press');
        expect(store.carousel.map((e) => e.id), ['Decline_Barbell_Bench_Press']);
      }
    });
  });
}
