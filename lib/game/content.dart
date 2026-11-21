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

/// One class per equipment type (docs/app-brief.md §4.1).
class GameClass {
  const GameClass({
    required this.id,
    required this.name,
    required this.equipment,
    required this.short,
    required this.style,
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

  /// One line about the training style.
  final String style;

  /// Placeholder icon (emoji) until the design has class art.
  final String icon;

  /// The class exercise POOL (placeholder, TBD by design). A workout takes
  /// `exercisesPerWorkout` of them (rules.dart); the user can swap, add
  /// and remove exercises from this pool.
  final List<Exercise> exercises;
}

const _b = ExerciseKind.bodyweight, _w = ExerciseKind.weights, _m = ExerciseKind.machine, _c = ExerciseKind.cardio;

const gameClasses = <GameClass>[
  GameClass(
    id: 'speedy',
    name: 'Speedster',
    equipment: 'Nothing. Just me.',
    short: 'NOTHING',
    style: 'Cardio and bodyweight. Fast and light.',
    icon: '👟',
    exercises: [
      Exercise('speedy.pushups', 'Push-ups', _b),
      Exercise('speedy.burpees', 'Burpees', _c),
      Exercise('speedy.sprints', 'Sprints', _c),
      Exercise('speedy.jumps', 'Jump squats', _b),
      Exercise('speedy.lunges', 'Lunges', _b),
      Exercise('speedy.plank', 'Plank', _b),
      Exercise('speedy.climbers', 'Mountain climbers', _c),
      Exercise('speedy.jacks', 'Jumping jacks', _c),
      Exercise('speedy.squats', 'Air squats', _b),
      Exercise('speedy.dips', 'Chair dips', _b),
    ],
  ),
  GameClass(
    id: 'rogue',
    name: 'Rogue',
    equipment: 'A basic home gym.',
    short: 'HOME GYM',
    style: 'Floor work, some cardio, some weights.',
    icon: '🗡️',
    exercises: [
      Exercise('rogue.goblet', 'Goblet squats', _w),
      Exercise('rogue.pushups', 'Push-ups', _b),
      Exercise('rogue.rows', 'Dumbbell rows', _w),
      Exercise('rogue.climbers', 'Mountain climbers', _c),
      Exercise('rogue.kbswing', 'Kettlebell swings', _w),
      Exercise('rogue.press', 'Dumbbell press', _w),
      Exercise('rogue.lunges', 'Dumbbell lunges', _w),
      Exercise('rogue.burpees', 'Burpees', _c),
      Exercise('rogue.curls', 'Dumbbell curls', _w),
      Exercise('rogue.plank', 'Plank', _b),
    ],
  ),
  GameClass(
    id: 'warrior',
    name: 'Warrior',
    equipment: 'A lot of free weights.',
    short: 'FREE WEIGHTS',
    style: 'Burly, bulky, strongman.',
    icon: '🛡️',
    exercises: [
      Exercise('warrior.squat', 'Back squats', _w),
      Exercise('warrior.deadlift', 'Deadlifts', _w),
      Exercise('warrior.bench', 'Bench press', _w),
      Exercise('warrior.press', 'Overhead press', _w),
      Exercise('warrior.row', 'Barbell rows', _w),
      Exercise('warrior.frontsquat', 'Front squats', _w),
      Exercise('warrior.rdl', 'Romanian deadlifts', _w),
      Exercise('warrior.curls', 'Barbell curls', _w),
      Exercise('warrior.pullups', 'Pull-ups', _b),
      Exercise('warrior.dips', 'Dips', _b),
    ],
  ),
  GameClass(
    id: 'mage',
    name: 'Mage',
    equipment: 'A lot of machines.',
    short: 'MACHINES',
    style: 'Stringy and strong.',
    icon: '🔮',
    exercises: [
      Exercise('mage.legpress', 'Leg press', _m),
      Exercise('mage.pulldown', 'Lat pulldown', _m),
      Exercise('mage.chest', 'Chest press', _m),
      Exercise('mage.cablerow', 'Cable rows', _m),
      Exercise('mage.legcurl', 'Leg curls', _m),
      Exercise('mage.legext', 'Leg extensions', _m),
      Exercise('mage.shoulder', 'Shoulder press machine', _m),
      Exercise('mage.flyes', 'Pec deck', _m),
      Exercise('mage.rower', 'Rowing machine', _c),
      Exercise('mage.abs', 'Ab crunch machine', _m),
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

/// Difficulty levels, easiest first. The numbers (exercises, target sets,
/// XP multiplier, streak N) are in rules.dart, same order. Our own names,
/// Borderlands-like tone.
class Difficulty {
  const Difficulty(this.id, this.name, this.line);

  final String id;
  final String name;
  final String line;
}

const difficulties = <Difficulty>[
  Difficulty('d01', 'Fresh Meat', 'Never lifted. The remote counts as cardio.'),
  Difficulty('d02', 'Couch Escapee', 'You own sneakers. They are scared.'),
  Difficulty('d03', 'Snack Paladin', 'Some sport at school. Mostly snacks.'),
  Difficulty('d04', 'Weekend Brawler', 'You train sometimes. Mostly Saturdays.'),
  Difficulty('d05', 'Gym Rat Larva', 'A few months in. The mirror knows you.'),
  Difficulty('d06', 'Plate Botherer', 'About a year. You have opinions on chalk.'),
  Difficulty('d07', 'Rack Goblin', 'You live in the squat rack. Rent is due.'),
  Difficulty('d08', 'Bar Bender', 'Two years plus. Barbells fear you a bit.'),
  Difficulty('d09', 'Chalk Wizard', 'Years in. You speak fluent protein.'),
  Difficulty('d10', 'Iron Lich', 'Many years. Your gym bag has a gym bag.'),
  Difficulty('d11', 'Mythic Meathead', 'You were the warm-up for other people.'),
  Difficulty('d12', 'Ascended Swole', 'Beyond help. Beyond reason. Beyond legs.'),
];

int difficultyIndex(String? id) {
  final i = difficulties.indexWhere((d) => d.id == id);
  return i < 0 ? 0 : i;
}

/// How a working set shows on an exercise card. Only [tally] is drawn now;
/// themed marks per area come from the design team.
enum MarkStyle { tally }

/// Starting areas (placeholders until the mood board has them).
class Area {
  const Area(this.id, this.name, this.line, this.icon, this.marks);

  final String id;
  final String name;
  final String line;
  final String icon;
  final MarkStyle marks;
}

const areas = <Area>[
  Area('beach', 'Swole Beach', 'Sand, sun, and suspicious seagulls.', '🏖️', MarkStyle.tally),
  Area('castle', 'Castle Gainsworth', 'Cold stone. Loud echoes. A moat of sweat.', '🏰', MarkStyle.tally),
];

Area areaById(String? id) => areas.firstWhere((a) => a.id == id, orElse: () => areas.first);

// ------------------------------------------------------------------- gear

enum GearSlot { head, top, bottom, shoes, weapon }

/// A gear item. The level unlocks it; the user equips one per slot.
/// Placeholder icons until the design has gear sprites. The body never
/// changes with gear.
class Item {
  const Item(this.id, this.name, this.slot, this.unlockLevel, this.icon);

  final String id;
  final String name;
  final GearSlot slot;
  final int unlockLevel;
  final String icon;
}

const items = <Item>[
  Item('head.sweatband', 'Sweatband of Mild Effort', GearSlot.head, 2, '🎽'),
  Item('top.tank', 'Tank Top of Vanity', GearSlot.top, 3, '👕'),
  Item('shoes.sneakers', 'Squeaky Sneakers', GearSlot.shoes, 4, '👟'),
  Item('bottom.shorts', 'Shorts, Too Short', GearSlot.bottom, 5, '🩳'),
  Item('weapon.shaker', 'Protein Shaker +1', GearSlot.weapon, 6, '🥤'),
  Item('head.crown', 'Crown of Leg Day', GearSlot.head, 8, '👑'),
  Item('weapon.kettlebell', 'Kettlebell of Doom', GearSlot.weapon, 10, '🔔'),
  Item('top.cape', 'Cape of Unearned Confidence', GearSlot.top, 12, '🦸'),
  Item('shoes.boots', 'Boots of Heavy Stomping', GearSlot.shoes, 15, '🥾'),
  Item('bottom.belt', 'Belt of Brace Yourself', GearSlot.bottom, 18, '🎗️'),
];

Item? itemById(String? id) {
  for (final i in items) {
    if (i.id == id) return i;
  }
  return null;
}

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
