// PUMPLEX game content: every NAME of the game lives here (classes,
// exercises, difficulty levels, starting areas). All are working names and
// placeholders until the design team sends the real ones.
//
// Ids are stored on the phone. Rename the names freely, but keep the ids.

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

  /// Placeholder list. It will be replaced by the real workouts.
  final List<Exercise> exercises;
}

class Exercise {
  const Exercise(this.id, this.name);

  final String id;
  final String name;
}

const gameClasses = <GameClass>[
  GameClass(
    id: 'speedy',
    name: 'Speedster',
    equipment: 'Nothing. Just me.',
    short: 'NOTHING',
    style: 'Cardio and bodyweight. Fast and light.',
    icon: '👟',
    exercises: [
      Exercise('speedy.pushups', 'Push-ups'),
      Exercise('speedy.burpees', 'Burpees'),
      Exercise('speedy.sprints', 'Sprints'),
      Exercise('speedy.jumps', 'Jump squats'),
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
      Exercise('rogue.goblet', 'Goblet squats'),
      Exercise('rogue.pushups', 'Push-ups'),
      Exercise('rogue.rows', 'Dumbbell rows'),
      Exercise('rogue.climbers', 'Mountain climbers'),
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
      Exercise('warrior.squat', 'Back squats'),
      Exercise('warrior.deadlift', 'Deadlifts'),
      Exercise('warrior.bench', 'Bench press'),
      Exercise('warrior.press', 'Overhead press'),
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
      Exercise('mage.legpress', 'Leg press'),
      Exercise('mage.pulldown', 'Lat pulldown'),
      Exercise('mage.chest', 'Chest press'),
      Exercise('mage.cablerow', 'Cable rows'),
    ],
  ),
];

GameClass classById(String? id) =>
    gameClasses.firstWhere((c) => c.id == id, orElse: () => gameClasses.first);

/// Difficulty levels, easiest first. The XP multipliers are in
/// lib/game/rules.dart (same order). Our own names, Borderlands-like tone.
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
