// PUMPLEX fixed game data (docs/data-schema.md §3): every NAME of the game
// (classes, difficulty levels, starting areas, and level titles). The
// texts are in assets/i18n/<language>.json under `class.<id>.*`,
// `difficulty.<id>.*`, `area.<id>.*`, `look.*`, `levelup.*` and `title.*`
// (D68). All are working names and placeholders until the design team
// sends the real ones. The numbers are in rules.dart.
//
// Rule: never reuse or rename an id. Saved data points to it. (The class
// and area renames, D31 and D36, migrate saved data once: model.dart.)

import '../i18n.dart';

/// One class per equipment type (docs/app-brief.md §4.1). Names and copy
/// from docs/moodboard/README.md "Class select". The names are
/// PROPOSALS from the design team; the ids never change.
class GameClass {
  const GameClass({required this.id, required this.icon});

  final String id;

  /// Working class name.
  String get name => t('class.$id.name');

  /// The equipment answer to "What do you train with?".
  String get equipment => t('class.$id.equipment');

  /// Two-word label under the class icon.
  String get short => t('class.$id.short');

  /// The class intro (RPG voice; hints at the equipment).
  String get style => t('class.$id.style');

  /// The gear the class trains with, in one line.
  String get loadout => t('class.$id.loadout');

  /// Three training tags (no stat table: brief rule 3).
  List<String> get tags => [for (var i = 1; i <= 3; i++) t('class.$id.tag$i')];

  /// Joke line on the freeze-frame intro card.
  String get subtitle => t('class.$id.subtitle');

  /// Icon id in assets/icons (docs/moodboard/icons).
  final String icon;
}

const gameClasses = <GameClass>[
  GameClass(id: 'scrapper', icon: 'class-scrapper'),
  GameClass(id: 'bruiser', icon: 'class-bruiser'),
  GameClass(id: 'paladin', icon: 'class-paladin'),
  GameClass(id: 'cablemancer', icon: 'class-cablemancer'),
];

GameClass classById(String? id) =>
    gameClasses.firstWhere((c) => c.id == id, orElse: () => gameClasses.first);

/// Difficulty modes, easiest first (docs/moodboard/README.md "Difficulty":
/// 6 levels, every name is `<WORD> MODE`, proposals). The numbers
/// (XP multiplier) are in rules.dart,
/// same order. The gems are a picture of the multiplier, not the number.
class Difficulty {
  const Difficulty(this.id);

  final String id;
  String get name => t('difficulty.$id.name');

  /// Who it is for.
  String get line => t('difficulty.$id.line');

  /// Subtitle on the freeze-frame title card.
  String get joke => t('difficulty.$id.joke');
}

const difficulties = <Difficulty>[
  Difficulty('sofa'),
  Difficulty('warmup'),
  Difficulty('sweat'),
  Difficulty('pain'),
  Difficulty('brutal'),
  Difficulty('nightmare'),
];

int difficultyIndex(String? id) {
  final i = difficulties.indexWhere((d) => d.id == id);
  return i < 0 ? 0 : i;
}

/// A starting area: the look, the palette and how a set is logged.
/// Proposals from the design team. The scene art is in assets/areas
/// (lib/game/area_art.dart).
class Area {
  const Area({
    required this.id,
    required this.icon,
    required this.object,
    required this.sky,
    required this.floor,
    required this.accent,
    this.defaultFor,
  });

  final String id;
  String get name => t('area.$id.name');
  String get line => t('area.$id.line');

  /// Icon id in assets/icons (for lists).
  final String icon;

  /// Icon id of the object to hit (the scene art is in lib/game/area_art.dart).
  final String object;

  /// The bobbing stencil hint over the object.
  String get hint => t('area.$id.hint');

  /// The stamp on every 5th set.
  String get stamp => t('area.$id.stamp');

  /// Scene colours (ARGB): dark sky above, light floor behind the lifter
  /// (so the ink outline reads), and the neon accent.
  final int sky, floor, accent;

  /// The class whose default area this is (null = neutral).
  final String? defaultFor;
}

const areas = <Area>[
  Area(
    id: 'riptide',
    icon: 'area-riptide',
    object: 'object-chest',
    sky: 0xFF12061F,
    floor: 0xFFAD9293,
    accent: 0xFFFF5FB0,
  ),
  Area(
    id: 'gainsgard',
    icon: 'area-gainsgard',
    object: 'object-wall',
    sky: 0xFF3A2A52,
    floor: 0xFF8672A5,
    accent: 0xFFFFA033,
    defaultFor: 'paladin',
  ),
  Area(
    id: 'rustbelt',
    icon: 'area-rustbelt',
    object: 'object-barrel',
    sky: 0xFF1F0D36,
    floor: 0xFFA6643C,
    accent: 0xFFFFA033,
    defaultFor: 'scrapper',
  ),
  Area(
    id: 'arcade',
    icon: 'area-arcade',
    object: 'object-punch',
    sky: 0xFF12061F,
    floor: 0xFF724EB2,
    accent: 0xFFC6FF3D,
    defaultFor: 'bruiser',
  ),
  Area(
    id: 'frostbite',
    icon: 'area-frostbite',
    object: 'object-ice',
    sky: 0xFF1A0B3B,
    floor: 0xFFC9B8E8,
    accent: 0xFF3FD2FF,
    defaultFor: 'cablemancer',
  ),
];

Area areaById(String? id) => areas.firstWhere((a) => a.id == id, orElse: () => areas.first);

/// The default area of class [classId] (the drawio's "Background changes").
Area defaultAreaFor(String classId) =>
    areas.firstWhere((a) => a.defaultFor == classId, orElse: () => areas.first);

/// A head look in the creator: kind (skin, hair, facial), id (rules.dart),
/// name and swatch colour.
class Look {
  const Look(this.kind, this.id, this.swatch);

  final String kind, id;
  String get name => t('look.$kind.$id');
  final int swatch;
}

const skinLooks = [Look('skin', 'light', 0xFFD39A6A), Look('skin', 'deep', 0xFF8A5534)];
const hairLooks = [Look('hair', 'brown', 0xFF5A3424), Look('hair', 'blonde', 0xFFD9A93E)];
const facialHairLooks = [Look('facial', 'none', 0x00000000), Look('facial', 'beard', 0xFF5A3424)];

/// Kicker line of the class-select step (design: marketing working name).
String get pathsKicker => t('class.kicker');

/// Joke lines for the level-up intro card (one per level, in turn).
List<String> get levelUpLines => [for (var i = 1; i <= 5; i++) t('levelup.$i')];

/// Level titles (from the design demo, since removed).
/// Design proposals; one title per level, the last one stays.
const levelTitleCount = 7;

String levelTitle(int level) => t('title.${level.clamp(1, levelTitleCount)}');
