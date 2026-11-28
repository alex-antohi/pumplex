// FORGE fixes after the phone test (D83): the forged name in the current
// language, the PICK A MOVE hint, the body guess for every chalk word, the
// info on a chip-less Today card, and "+ CHALK" with no count after TO TODAY.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gym_app/i18n.dart';
import 'package:gym_app/game/chalk.dart';
import 'package:gym_app/game/exercises.dart';
import 'package:gym_app/game/forge.dart';
import 'package:gym_app/game/model.dart';
import 'package:gym_app/game/rules.dart';
import 'package:gym_app/main.dart';
import 'package:gym_app/pumplex.dart';
import 'package:gym_app/store.dart';

const _profile = Profile(
  character: Character(sex: 'female', height: 80, muscle: 100, fat: 0),
  classId: 'scrapper',
  difficultyId: 'sweat',
  areaId: 'gainsgard',
);

Future<void> _frames(WidgetTester t, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<LogStore> _store([Map<String, Object> more = const {}]) async {
  SharedPreferences.setMockInitialValues({'profile_v1': jsonEncode(_profile.toJson()), ...more});
  return LogStore(await SharedPreferences.getInstance(), clock: () => DateTime(2026, 11, 21, 10));
}

Future<void> _pumpApp(WidgetTester t, LogStore store) async {
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 2.75;
  t.view.padding = const FakeViewPadding(top: 110, bottom: 146);
  addTearDown(t.view.reset);
  await t.pumpWidget(GymApp(store: store));
  await _frames(t);
}

void main() {
  final langFiles = {for (final l in I18n.languages) l: File(I18n.asset(l)).readAsStringSync()};
  setUp(() => I18n.instance.useJson(langFiles));
  setUpAll(() => exerciseCatalog = ExerciseCatalog.parse(File(ExerciseCatalog.asset).readAsStringSync()));

  String nameIn(String lang, Set<String> line, {String? typed}) {
    I18n.instance.useJson(langFiles, lang: lang);
    return forgeName(line, typed: typed, look: I18n.instance.lookup);
  }

  test('the forged name: move word then tool in Romanian, tool then move in English; typed stays as typed', () {
    expect(nameIn('ro', {'move.curl', 'tool.dumbbell'}), 'Flexii cu gantere');
    expect(nameIn('en', {'move.curl', 'tool.dumbbell'}), 'Dumbbell Curl');
    expect(nameIn('ro', {'pattern.carry'}), 'Cărat');
    expect(nameIn('en', {'pattern.carry'}), 'Carry');
    expect(nameIn('ro', {'move.pulldown', 'tool.kettlebell'}), 'Helcometru cu kettlebell');
    expect(nameIn('ro', {'move.squat', 'tool.bodyweight'}), 'Genuflexiuni'); // bodyweight adds no part
    expect(nameIn('ro', {'move.row', 'tool.towel'}), 'Ramat cu prosop');
    expect(nameIn('ro', {'tool.kettlebell'}, typed: 'snatch'), 'snatch cu kettlebell');
    expect(nameIn('en', {'tool.kettlebell'}, typed: 'SNATCH'), 'Kettlebell SNATCH');
    expect(nameIn('ro', const {}), 'Mișcarea mea');
  });

  test('a forged move shows in the current language and follows the switch; the nickname wins', () async {
    final store = await _store();
    final move = store.forge({'move.curl', 'tool.dumbbell'}, 'biceps', null);
    final e = exerciseCatalog.byId[move.id]!;
    I18n.instance.useJson(langFiles, lang: 'ro');
    expect(displayName(e), 'Flexii cu gantere');
    I18n.instance.useJson(langFiles, lang: 'en');
    expect(displayName(e), 'Dumbbell Curl');
    store.editForged(move.id, move.words, 'biceps', 'Guns');
    I18n.instance.useJson(langFiles, lang: 'ro');
    expect(displayName(exerciseCatalog.byId[move.id]!), 'Guns');
    // Kept as words, never as a name.
    final kept = jsonDecode((await SharedPreferences.getInstance()).getString(LogStore.forgedKey)!) as List;
    expect((kept.single as Map).containsKey('name'), isFalse);
  });

  test('migration: an older forged move with an English name gets its words back and loses the name', () async {
    final old = ForgedMove.fromJson({'id': 'custom_1', 'name': 'Kettlebell Wrist curl', 'muscle': 'forearms'});
    expect(old.words, {'tool.kettlebell', 'move.wristcurl'});
    final store = await _store({
      LogStore.forgedKey: jsonEncode([
        {'id': 'custom_1', 'name': 'Dumbbell Curl', 'muscle': 'biceps'},
      ]),
    });
    expect(store.forged.single.words, {'tool.dumbbell', 'move.curl'});
    I18n.instance.useJson(langFiles, lang: 'ro');
    expect(displayName(exerciseCatalog.byId['custom_1']!), 'Flexii cu gantere');
    final kept = jsonDecode((await SharedPreferences.getInstance()).getString(LogStore.forgedKey)!) as List;
    expect(kept.single, {
      'id': 'custom_1',
      'words': ['tool.dumbbell', 'move.curl'],
      'muscle': 'biceps',
    });
  });

  test('the body guess: every PATTERN and MOVE word gives a sensible part and muscle; every TOOL has gear', () {
    const want = <String, (String, String)>{
      'pattern.push': ('chest', 'chest'),
      'pattern.pull': ('back', 'lats'),
      'pattern.squat': ('legs', 'quadriceps'),
      'pattern.hinge': ('legs', 'hamstrings'),
      'pattern.single': ('legs', 'quadriceps'),
      'pattern.core': ('core', 'abdominals'),
      'pattern.jump': ('legs', 'quadriceps'),
      'pattern.carry': ('arms', 'forearms'),
      'pattern.cardio': ('legs', 'quadriceps'),
      'move.press': ('chest', 'chest'),
      'move.bench': ('chest', 'chest'),
      'move.fly': ('chest', 'chest'),
      'move.pullover': ('back', 'lats'),
      'move.curl': ('arms', 'biceps'),
      'move.wristcurl': ('arms', 'forearms'),
      'move.raise': ('shoulders', 'shoulders'),
      'move.row': ('back', 'middle back'),
      'move.squat': ('legs', 'quadriceps'),
      'move.lunge': ('legs', 'quadriceps'),
      'move.deadlift': ('legs', 'hamstrings'),
      'move.hipthrust': ('legs', 'glutes'),
      'move.bridge': ('legs', 'glutes'),
      'move.pullup': ('back', 'lats'),
      'move.pushup': ('chest', 'chest'),
      'move.dip': ('arms', 'triceps'),
      'move.extension': ('arms', 'triceps'),
      'move.pushdown': ('arms', 'triceps'),
      'move.kickback': ('arms', 'triceps'),
      'move.pulldown': ('back', 'lats'),
      'move.crunch': ('core', 'abdominals'),
      'move.plank': ('core', 'abdominals'),
      'move.shrug': ('back', 'traps'),
    };
    for (final w in chalkWords.where((w) => w.row == 'pattern' || w.row == 'move')) {
      final g = forgeBody({w.key});
      expect(g, want[w.key], reason: w.key);
      expect(bodyPartById(g!.$1)!.muscles, contains(g.$2), reason: w.key);
    }
    // The MOVE word wins over the PATTERN word; the BODY word over both.
    expect(forgeBody({'pattern.carry', 'move.shrug'}), ('back', 'traps'));
    expect(forgeBody({'pattern.carry', 'body.legs'}), ('legs', 'quadriceps'));
    // Every TOOL word has gear, and a towel move is found with its words.
    for (final w in chalkWords.where((w) => w.row == 'tool')) {
      expect(forgeEquipment({w.key}), isNotEmpty, reason: w.key);
    }
    final towel = ForgedMove(id: 'custom_7', words: const {'tool.towel', 'move.row'}, muscle: 'middle back');
    final cat = catalogWithForged(exerciseCatalog, [towel]);
    expect(
      ChalkIndex(cat).words['custom_7'],
      containsAll(['tool.towel', 'tool.bodyweight', 'move.row', 'pattern.pull']),
    );
    final carry = ForgedMove(id: 'custom_8', words: const {'pattern.carry'}, typed: 'yoke', muscle: 'forearms');
    expect(ChalkIndex(catalogWithForged(exerciseCatalog, [carry])).words['custom_8'], contains('pattern.carry'));
    catalogWithForged(exerciseCatalog, const []);
  });

  test('a forged move has the default score 2 (D92)', () {
    final move = ForgedMove(id: 'custom_9', words: const {'move.row'}, muscle: 'middle back').toExercise();
    expect(move.score, 2);
    expect(isHardFor(move, 0), isTrue); // Sofa
    expect(isHardFor(move, 1), isFalse); // Warm-up
    expect(xpRate(difficulty: 5, score: move.score), xpRate(difficulty: 1));
  });

  testWidgets('FORGE from CHALK with only a pattern word: PICK A MOVE, the MOVE slot is pink, FORGE IT is off', (
    t,
  ) async {
    final store = await _store();
    await _pumpApp(t, store);
    I18n.instance.useJson(langFiles, lang: 'ro');
    store.setChalk({'pattern.carry'});
    await t.pump();
    await t.tap(find.byKey(const ValueKey('filter-chalk')));
    await _frames(t, 10);
    final forgeIt = find.byKey(const ValueKey('chalk-forge-it'), skipOffstage: false);
    await t.scrollUntilVisible(
      find.byKey(const ValueKey('chalk-forge-it')),
      120,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('chalk-results-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await t.ensureVisible(forgeIt);
    await _frames(t, 4);
    await t.tap(forgeIt);
    await _frames(t, 20);
    expect(find.byKey(const ValueKey('forge-card')), findsOneWidget);
    // The name is Romanian, and the guess is the grip, not the chest.
    expect(t.widget<Text>(find.byKey(const ValueKey('forge-name'))).data, 'CĂRAT');
    expect(find.byKey(const ValueKey('forge-body-arms')), findsOneWidget);
    expect(find.byKey(const ValueKey('forge-muscle-forearms')), findsOneWidget);
    // The hint shows at once, under the button; the MOVE slot is pink.
    final hint = find.byKey(const ValueKey('forge-need-move'));
    expect(t.widget<Text>(hint).data, 'ALEGE O MIȘCARE');
    expect(t.getRect(hint).top, greaterThanOrEqualTo(t.getRect(find.byKey(const ValueKey('forge-it'))).bottom));
    Color slotBorder(String row) {
      final box = t.widget<Container>(
        find.descendant(of: find.byKey(ValueKey('forge-slot-$row')), matching: find.byType(Container)).first,
      );
      return ((box.decoration! as BoxDecoration).border! as Border).top.color;
    }

    final p = Pal.of(t.element(hint));
    expect(slotBorder('move'), p.pink);
    expect(slotBorder('tool'), isNot(p.pink));
    // FORGE IT is off: a tap forges nothing.
    await t.tap(find.byKey(const ValueKey('forge-it')), warnIfMissed: false);
    await _frames(t, 10);
    expect(store.forged, isEmpty);
    expect(find.byKey(const ValueKey('forge-reveal')), findsNothing);
    // A MOVE word: the hint goes, the slot is no longer pink, FORGE IT works.
    await t.tap(find.byKey(const ValueKey('forge-slot-move')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('forge-move.shrug')));
    await t.tap(find.byKey(const ValueKey('forge-slot-move'))); // close the row
    await t.pump();
    expect(hint, findsNothing);
    expect(slotBorder('move'), isNot(p.pink));
    await t.tap(find.byKey(const ValueKey('forge-it')));
    await _frames(t, 40);
    expect(store.forged, hasLength(1));
    expect(t.takeException(), isNull);
    I18n.instance.useJson(langFiles);
  });

  testWidgets(
    'TO TODAY clears the CHALK words ("+ CHALK", no count); the forged card shows its tool and body · muscle',
    (t) async {
      final store = await _store();
      await _pumpApp(t, store);
      I18n.instance.useJson(langFiles, lang: 'ro');
      store.setChalk({'tool.kettlebell', 'move.pulldown'});
      await t.pump();
      expect(find.text('+ CRETĂ · 2'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('filter-chalk')));
      await _frames(t, 10);
      await t.ensureVisible(find.byKey(const ValueKey('chalk-forge')));
      await t.tap(find.byKey(const ValueKey('chalk-forge')));
      await _frames(t, 20);
      await t.tap(find.byKey(const ValueKey('forge-it')));
      await _frames(t, 40);
      final loot = find.byKey(const ValueKey('forge-loot'));
      expect(find.descendant(of: loot, matching: find.text('HELCOMETRU CU KETTLEBELL')), findsOneWidget);
      expect(store.chalk, isNotEmpty); // kept for FORGE ANOTHER (D83)
      await t.tap(find.byKey(const ValueKey('forge-to-today')));
      await _frames(t, 20);
      expect(store.chalk, isEmpty);
      expect(find.text('+ CRETĂ'), findsOneWidget);
      expect(find.textContaining('+ CRETĂ ·'), findsNothing);
      // The Today card: the Romanian name, and its info under the title.
      expect(t.widget<Text>(find.byKey(const ValueKey('exercise-title'))).data, 'HELCOMETRU CU KETTLEBELL');
      expect(find.byKey(const ValueKey('card-info')), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('card-info-tool')), matching: find.text('KETTLEBELL')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const ValueKey('card-info-body')), matching: find.text('SPATE · DORSALI')),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
      I18n.instance.useJson(langFiles);
    },
  );
}
