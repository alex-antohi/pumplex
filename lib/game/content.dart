// PUMPLEX fixed game data (docs/data-schema.md §3): every NAME of the game
// lives here (classes, exercise pools, difficulty levels, starting areas,
// gear items, achievements). All are working names and placeholders until
// the design team sends the real ones. The numbers are in rules.dart.
//
// Rule: never reuse or rename an id. Saved data points to it.

enum ExerciseKind { bodyweight, weights, machine, cardio }

class Exercise {
  const Exercise(this.id, this.name, this.kind);

  final String id;
  final String name;
  final ExerciseKind kind;
}

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
    required this.exercises,
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

  /// The class exercise POOL (placeholder, TBD by design). A workout takes
  /// `exercisesPerWorkout` of them (rules.dart); the user can swap, add
  /// and remove exercises from this pool.
  final List<Exercise> exercises;
}

const _b = ExerciseKind.bodyweight, _w = ExerciseKind.weights, _m = ExerciseKind.machine, _c = ExerciseKind.cardio;

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
    exercises: [
      Exercise('scrapper.pushups', 'Push-ups', _b),
      Exercise('scrapper.burpees', 'Burpees', _c),
      Exercise('scrapper.sprints', 'Sprints', _c),
      Exercise('scrapper.jumps', 'Jump squats', _b),
      Exercise('scrapper.lunges', 'Lunges', _b),
      Exercise('scrapper.plank', 'Plank', _b),
      Exercise('scrapper.climbers', 'Mountain climbers', _c),
      Exercise('scrapper.jacks', 'Jumping jacks', _c),
      Exercise('scrapper.squats', 'Air squats', _b),
      Exercise('scrapper.dips', 'Chair dips', _b),
    ],
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
    exercises: [
      Exercise('bruiser.goblet', 'Goblet squats', _w),
      Exercise('bruiser.pushups', 'Push-ups', _b),
      Exercise('bruiser.rows', 'Dumbbell rows', _w),
      Exercise('bruiser.climbers', 'Mountain climbers', _c),
      Exercise('bruiser.kbswing', 'Kettlebell swings', _w),
      Exercise('bruiser.press', 'Dumbbell press', _w),
      Exercise('bruiser.lunges', 'Dumbbell lunges', _w),
      Exercise('bruiser.burpees', 'Burpees', _c),
      Exercise('bruiser.curls', 'Dumbbell curls', _w),
      Exercise('bruiser.plank', 'Plank', _b),
    ],
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
    exercises: [
      Exercise('paladin.squat', 'Back squats', _w),
      Exercise('paladin.deadlift', 'Deadlifts', _w),
      Exercise('paladin.bench', 'Bench press', _w),
      Exercise('paladin.press', 'Overhead press', _w),
      Exercise('paladin.row', 'Barbell rows', _w),
      Exercise('paladin.frontsquat', 'Front squats', _w),
      Exercise('paladin.rdl', 'Romanian deadlifts', _w),
      Exercise('paladin.curls', 'Barbell curls', _w),
      Exercise('paladin.pullups', 'Pull-ups', _b),
      Exercise('paladin.dips', 'Dips', _b),
    ],
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
    exercises: [
      Exercise('cablemancer.legpress', 'Leg press', _m),
      Exercise('cablemancer.pulldown', 'Lat pulldown', _m),
      Exercise('cablemancer.chest', 'Chest press', _m),
      Exercise('cablemancer.cablerow', 'Cable rows', _m),
      Exercise('cablemancer.legcurl', 'Leg curls', _m),
      Exercise('cablemancer.legext', 'Leg extensions', _m),
      Exercise('cablemancer.shoulder', 'Shoulder press machine', _m),
      Exercise('cablemancer.flyes', 'Pec deck', _m),
      Exercise('cablemancer.rower', 'Rowing machine', _c),
      Exercise('cablemancer.abs', 'Ab crunch machine', _m),
    ],
  ),
];

GameClass classById(String? id) =>
    gameClasses.firstWhere((c) => c.id == id, orElse: () => gameClasses.first);

/// Every exercise of every class, by id.
final Map<String, Exercise> exercisesById = {
  for (final c in gameClasses)
    for (final e in c.exercises) e.id: e,
};

/// Display name of an exercise id (the id itself if it is unknown).
String exerciseName(String id) => exercisesById[id]?.name ?? id;

/// Difficulty modes, easiest first (docs/moodboard/README.md "Difficulty":
/// 6 levels, every name is `<WORD> MODE`, proposals). The numbers
/// (exercises, target sets, XP multiplier, streak N) are in rules.dart,
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
    id: 'beach',
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
    id: 'castle',
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
    id: 'summit',
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

// ------------------------------------------------------------------- gear

enum GearSlot { head, top, bottom, shoes, weapon }

/// A gear item. The level unlocks it; the user equips one per slot.
/// The sprites are in assets/gear. The body never changes with gear.
class Item {
  const Item(this.id, this.name, this.slot, this.unlockLevel, this.icon);

  final String id;
  final String name;
  final GearSlot slot;
  final int unlockLevel;

  /// Menu icon (assets/gear/icons, white: tint it).
  final String icon;
}

const items = <Item>[
  Item('head.sweatband', 'Sweatband of Mild Effort', GearSlot.head, 2, 'assets/gear/icons/head.sweatband.png'),
  Item('top.tank', 'Tank Top of Vanity', GearSlot.top, 3, 'assets/gear/icons/top.tank.png'),
  Item('shoes.sneakers', 'Squeaky Sneakers', GearSlot.shoes, 4, 'assets/gear/icons/shoes.sneakers.png'),
  Item('bottom.shorts', 'Shorts, Too Short', GearSlot.bottom, 5, 'assets/gear/icons/bottom.shorts.png'),
  Item('weapon.shaker', 'Protein Shaker +1', GearSlot.weapon, 6, 'assets/gear/icons/weapon.shaker.png'),
  Item('head.crown', 'Crown of Leg Day', GearSlot.head, 8, 'assets/gear/icons/head.crown.png'),
  Item('weapon.kettlebell', 'Kettlebell of Doom', GearSlot.weapon, 10, 'assets/gear/icons/weapon.kettlebell.png'),
  Item('top.cape', 'Cape of Unearned Confidence', GearSlot.top, 12, 'assets/gear/icons/top.cape.png'),
  Item('shoes.boots', 'Boots of Heavy Stomping', GearSlot.shoes, 15, 'assets/gear/icons/shoes.boots.png'),
  Item('bottom.belt', 'Belt of Brace Yourself', GearSlot.bottom, 18, 'assets/gear/icons/bottom.belt.png'),
];

Item? itemById(String? id) => items.where((i) => i.id == id).firstOrNull;

// ----------------------------------------------------------- achievements

/// What an achievement condition can look at (computed by the store).
typedef AchievementStats = ({int totalSets, int trainingDays, int bestStreakWeeks, int level});

class Achievement {
  const Achievement(this.id, this.name, this.line, this.xp, this.met);

  final String id;
  final String name;
  final String line;

  /// XP when it unlocks (a number, so it belongs to the rules table later).
  final int xp;
  final bool Function(AchievementStats s) met;
}

final achievements = <Achievement>[
  Achievement('first_set', 'First Blood', 'Mark your first working set.', 25, (s) => s.totalSets >= 1),
  Achievement('sets_100', 'Century of Suffering', 'Do 100 working sets.', 150, (s) => s.totalSets >= 100),
  Achievement('days_10', 'Regular', 'Train on 10 days.', 100, (s) => s.trainingDays >= 10),
  Achievement('streak_4', 'Month of Iron', 'Hit your week target 4 weeks in a row.', 200, (s) => s.bestStreakWeeks >= 4),
  Achievement('level_5', 'Getting Somewhere', 'Reach level 5.', 0, (s) => s.level >= 5),
];

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

/// Level titles (design demo `docs/demo/shared/demo.js` LEVEL_TITLES).
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

/// Design file names for the areas (docs/moodboard/areas, sounds, icons).
/// The app keeps its own area ids (saved data uses them); only three differ.
const _areaArtIds = {'beach': 'riptide', 'castle': 'gainsgard', 'summit': 'frostbite'};

extension AreaArtId on Area {
  /// The design id of this area: `beach` -> `riptide`, and so on.
  String get artId => _areaArtIds[id] ?? id;
}
