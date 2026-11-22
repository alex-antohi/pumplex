// PUMPLEX fixed game data (docs/data-schema.md §3): every NAME of the game
// lives here (classes, difficulty levels, starting areas,
// and level titles). All are working names and placeholders until
// the design team sends the real ones. The numbers are in rules.dart.
//
// Rule: never reuse or rename an id. Saved data points to it. (The class
// and area renames, D31 and D36, migrate saved data once: model.dart.)

/// One class per equipment type (docs/app-brief.md §4.1). Names and copy
/// from docs/moodboard/README.md "Class select". The names are
/// PROPOSALS from the design team; the ids never change.
class GameClass {
  const GameClass({
    required this.id,
    required this.name,
    required this.equipment,
    required this.short,
    required this.style,
    required this.loadout,
    required this.tags,
    required this.subtitle,
    required this.icon,
  });

  final String id;

  /// Working class name.
  final String name;

  /// The equipment answer to "What do you train with?".
  final String equipment;

  /// Two-word label under the class icon.
  final String short;

  /// The class intro (RPG voice; hints at the equipment).
  final String style;

  /// The gear the class trains with, in one line.
  final String loadout;

  /// Three training tags (no stat table: brief rule 3).
  final List<String> tags;

  /// Joke line on the freeze-frame intro card.
  final String subtitle;

  /// Icon id in assets/icons (docs/moodboard/icons).
  final String icon;
}

const gameClasses = <GameClass>[
  GameClass(
    id: 'scrapper',
    name: 'Scrapper',
    equipment: 'No equipment',
    short: 'NOTHING',
    style: 'No gym, no gear, no problem. Builds every workout out of floors, stairs and pure spite. '
        'Homemade, held together with tape, and very loud about it.',
    loadout: "Nothin'. Just you, the floor and the stairs.",
    tags: ['CARDIO', 'BODYWEIGHT', 'SPRINTS'],
    subtitle: 'BUILT FROM STAIRS AND SPITE',
    icon: 'class-scrapper',
  ),
  GameClass(
    id: 'bruiser',
    name: 'Bargain Bruiser',
    equipment: 'Basic home gym',
    short: 'HOME GYM',
    style: 'Kitted out from the clearance aisle. Every piece of gear is store-brand, slightly wobbly '
        'and fully committed. Cheap kit, real gains.',
    loadout: 'Two dumbbells, one mat, a kettlebell of unknown origin.',
    tags: ['FLOOR WORK', 'SOME CARDIO', 'SOME WEIGHTS'],
    subtitle: 'BUY ONE GAIN, GET ONE FREE',
    icon: 'class-bruiser',
  ),
  GameClass(
    id: 'paladin',
    name: 'Plate Paladin',
    equipment: 'Lots of free weights',
    short: 'FREE WEIGHTS',
    style: 'Sworn to the barbell. Carries plates like holy relics and drops them like thunder. '
        'Big, burly, unbothered.',
    loadout: 'A barbell, a rack and a wall of plates.',
    tags: ['STRONGMAN', 'BARBELL', 'HEAVY'],
    subtitle: 'OATH-SWORN TO THE BARBELL',
    icon: 'class-paladin',
  ),
  GameClass(
    id: 'cablemancer',
    name: 'Cablemancer',
    equipment: 'Lots of machines',
    short: 'MACHINES',
    style: 'Bends steel cables and pin-stacks to their will. Thin as a wire, strong as the machine. '
        'Never waits for the squat rack.',
    loadout: 'Cables, pin-stacks and every machine in the building.',
    tags: ['MACHINES', 'CABLES', 'LEAN POWER'],
    subtitle: 'SPEAKS FLUENT PULLEY',
    icon: 'class-cablemancer',
  ),
];

GameClass classById(String? id) =>
    gameClasses.firstWhere((c) => c.id == id, orElse: () => gameClasses.first);

/// Difficulty modes, easiest first (docs/moodboard/README.md "Difficulty":
/// 6 levels, every name is `<WORD> MODE`, proposals). The numbers
/// (XP multiplier) are in rules.dart,
/// same order. The gems are a picture of the multiplier, not the number.
class Difficulty {
  const Difficulty(this.id, this.name, this.line, this.joke);

  final String id;
  final String name;

  /// Who it is for.
  final String line;

  /// Subtitle on the freeze-frame title card.
  final String joke;
}

const difficulties = <Difficulty>[
  Difficulty('sofa', 'Sofa Mode', 'Never lifted, or not for years. The gentlest workouts.', 'THE SOFA WILL REMEMBER YOU'),
  Difficulty('warmup', 'Warm-up Mode', 'A few weeks to a few months in. Easy, steady workouts.', 'EVERY LEGEND STARTS HERE'),
  Difficulty('sweat', 'Sweat Mode', 'Training most weeks, for about a year. Proper sweaty workouts.', 'TOWEL STRONGLY RECOMMENDED'),
  Difficulty('pain', 'Pain Mode', 'About two years in. Hard workouts, real effort.', 'OUCH, BUT MAKE IT GAINS'),
  Difficulty('brutal', 'Brutal Mode', 'Years of serious lifting. Very hard workouts.', 'THE RACK FEARS YOU NOW'),
  Difficulty('nightmare', 'Nightmare Mode', 'Many years, competition level. The hardest workouts there are.',
      'GRAVITY FILED A COMPLAINT'),
];

int difficultyIndex(String? id) {
  final i = difficulties.indexWhere((d) => d.id == id);
  return i < 0 ? 0 : i;
}

/// How an area shows the working sets (docs/moodboard/README.md "Starting
/// areas": the action is the set, and the result stays in the world).
enum MarkStyle {
  shells, // a loot pile of shells on the sand
  tally, // chalk tally marks on a wall
  crosses, // spray-painted Xs on a scrap sign
  tickets, // arcade tickets on the floor
  flags, // flags up the slope to the summit
}

/// A starting area: the look, the palette and how a set is logged.
/// Proposals from the design team. The scene art is in assets/areas
/// (lib/game/area_art.dart).
class Area {
  const Area({
    required this.id,
    required this.name,
    required this.line,
    required this.icon,
    required this.marks,
    required this.object,
    required this.hint,
    required this.stamp,
    required this.sky,
    required this.floor,
    required this.accent,
    this.defaultFor,
  });

  final String id;
  final String name;
  final String line;

  /// Icon id in assets/icons (for lists).
  final String icon;
  final MarkStyle marks;

  /// Icon id of the object to hit (the scene art is in lib/game/area_art.dart).
  final String object;

  /// The bobbing stencil hint over the object.
  final String hint;

  /// The stamp on every 5th set.
  final String stamp;

  /// Scene colours (ARGB): dark sky above, light floor behind the lifter
  /// (so the ink outline reads), and the neon accent.
  final int sky, floor, accent;

  /// The class whose default area this is (null = neutral).
  final String? defaultFor;
}

const areas = <Area>[
  Area(
    id: 'riptide',
    name: 'Riptide Shore',
    line: 'Moonlit sand, a palm island and a treasure chest full of shells.',
    icon: 'area-riptide',
    marks: MarkStyle.shells,
    object: 'object-chest',
    hint: 'TAP THE CHEST',
    stamp: 'PEARL!',
    sky: 0xFF12061F,
    floor: 0xFFAD9293,
    accent: 0xFFFF5FB0,
  ),
  Area(
    id: 'gainsgard',
    name: 'Gainsgard Keep',
    line: 'Cold stone, a flickering torch and a wall that wants scratches.',
    icon: 'area-gainsgard',
    marks: MarkStyle.tally,
    object: 'object-wall',
    hint: 'SCRATCH THE WALL',
    stamp: 'SLASHED!',
    sky: 0xFF3A2A52,
    floor: 0xFF8672A5,
    accent: 0xFFFFA033,
    defaultFor: 'paladin',
  ),
  Area(
    id: 'rustbelt',
    name: 'Rustbelt Flats',
    line: 'A striped sunset, a car wreck and barrels that go boom.',
    icon: 'area-rustbelt',
    marks: MarkStyle.crosses,
    object: 'object-barrel',
    hint: 'BLOW UP THE BARREL',
    stamp: 'TAGGED!',
    sky: 0xFF1F0D36,
    floor: 0xFFA6643C,
    accent: 0xFFFFA033,
    defaultFor: 'scrapper',
  ),
  Area(
    id: 'arcade',
    name: 'Arcade Underpass',
    line: 'Graffiti, a flickering OPEN 24/7 sign and the PUNCH-O-TRON.',
    icon: 'area-arcade',
    marks: MarkStyle.tickets,
    object: 'object-punch',
    hint: 'PUNCH THE MACHINE',
    stamp: 'COMBO!',
    sky: 0xFF12061F,
    floor: 0xFF724EB2,
    accent: 0xFFC6FF3D,
    defaultFor: 'bruiser',
  ),
  Area(
    id: 'frostbite',
    name: 'Frostbite Summit',
    line: 'Aurora, falling snow and a slope up to the summit flag.',
    icon: 'area-frostbite',
    marks: MarkStyle.flags,
    object: 'object-ice',
    hint: 'SMASH THE ICE',
    stamp: 'SUMMIT!',
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

/// A head look in the creator: id (rules.dart), name and swatch colour.
class Look {
  const Look(this.id, this.name, this.swatch);

  final String id, name;
  final int swatch;
}

const skinLooks = [Look('light', 'LIGHT', 0xFFD39A6A), Look('deep', 'DEEP', 0xFF8A5534)];
const hairLooks = [Look('brown', 'BROWN', 0xFF5A3424), Look('blonde', 'BLONDE', 0xFFD9A93E)];
const facialHairLooks = [Look('none', 'NONE', 0x00000000), Look('beard', 'BEARD', 0xFF5A3424)];

/// Kicker line of the class-select step (design: marketing working name).
const pathsKicker = "THE SWOLEMANCER'S PATHS";

/// Joke lines for the level-up intro card (one per level, in turn).
const levelUpLines = [
  'MORE XP. SAME BAR.',
  'THE MIRROR NOTICED.',
  'GAINS ACQUIRED. RECEIPT LOST.',
  'YOUR SHOES ARE IMPRESSED.',
  'THE BAR FEARS YOU SLIGHTLY MORE.',
];

/// Level titles (from the design demo, since removed).
/// Design proposals; one title per level, the last one stays.
const levelTitles = [
  'Fresh Spawn',
  'Sweat Rookie',
  'Rep Goblin',
  'Pump Raider',
  'Iron Ronin',
  'Gain Lord',
  'Mythic Meathead',
];

String levelTitle(int level) => levelTitles[(level - 1).clamp(0, levelTitles.length - 1)];
