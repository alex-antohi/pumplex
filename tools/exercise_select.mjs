// Cuts the exercise list down and sorts it by how common each exercise is
// (D67). Reads the full list (tools/exercise_db.json: the 692 database
// exercises of D56 and the 3 added ones of D57, with `base` and `mods` from
// exercise_variants.mjs) and writes the app list:
//   node tools/exercise_variants.mjs tools/exercise_db.json --write tools/exercise_db.json
//   node tools/exercise_select.mjs tools/exercise_db.json assets/exercises/exercises.json [--report]
//
// What it writes per exercise, on top of the database fields:
//   rank    commonness of its card (1 = the most common card). All
//           exercises of one move have the rank of the move.
//   unlock  class id -> the first difficulty mode (0 Sofa .. 5 Nightmare)
//           that shows the card for that class. Only classes that show
//           the card are listed.
//
// Rules:
// 1. Commonness: COMMON lists the candidate cards in tiers, by judgment of
//    how often the exercise is seen in gyms and training programs (tier 1 =
//    in almost every program). Inside a tier, a move with more variations
//    comes first (one name gives more); then the order of the list.
// 2. Per class and body part (D52), each mode shows BUDGET[part][mode]
//    cards. The next card is the most common card of a MAIN muscle that has
//    no card yet, else the most common card. So the main muscles of a body
//    part come early.
//    A mode only takes cards that have an exercise of its level (D51: Sofa
//    and Warm-up beginner; Sweat and Pain also intermediate; Brutal and
//    Nightmare also expert). A card shown in one mode stays in every harder
//    mode.
// 3. The list keeps only the cards that some class shows in Nightmare. A
//    kept move keeps its variations, but not the ones in OBSCURE and not the
//    ones no class can see (equipment `other` or `foam roll`, D50).
//    Exercises with `custom: true` (D57) stay with their move. The rest of
//    the database is dropped. Ids do not change (saved sets point to them).
import fs from 'node:fs';

// Most common first. A name is a move (`base`) or the id of an exercise with no variations.
const COMMON = [
  // 1: the big lifts, in almost every program.
  ['Bench Press', 'Squat', 'Deadlift', 'Pull-Up', 'Push-Up', 'Shoulder Press', 'Bicep Curl', 'Lat Pulldown', 'Plank',
    'Crunch'],
  // 2: in most gym programs.
  ['Dip', 'Bent over Row', 'Row', 'Lunge', 'Leg Press', 'Triceps Pushdown', 'Lateral Raise', 'Romanian_Deadlift',
    'Seated_Cable_Rows', 'Leg Extension', 'Leg Curl', 'Calf Raise'],
  // 3: very common.
  ['Hammer Curl', 'Chin-Up', 'Barbell_Hip_Thrust', 'Fly', 'Sit-Up', 'Triceps Extension', 'Shrug', 'Hanging_Leg_Raise',
    'Goblet_Squat', 'Face_Pull', 'Skullcrusher', 'Preacher Curl'],
  // 4: common.
  ['Front Raise', 'Reverse Fly', 'Upright Row', 'Crossover', 'Chest Press', 'Butterfly', 'Walking Lunge', 'Step-Up',
    'Glute Bridge', 'Butt_Lift_Bridge', 'Hack Squat', 'Stiff-Legged Deadlift', 'Russian_Twist', 'Air_Bike',
    'Mountain_Climbers', 'Inverted_Row', 'Tricep_Dumbbell_Kickback', 'Hyperextensions_With_No_Hyperextension_Bench'],
  // 5: a regular in many programs.
  ['Good Morning', 'Reverse Crunch', 'Arnold Press', 'Concentration Curl', 'Straight-Arm_Pulldown',
    'Split_Squat_with_Dumbbells', 'Dumbbell_Rear_Lunge', 'Front_Barbell_Squat', 'Machine_Shoulder_Military_Press',
    'T-Bar_Row_with_Handle', 'One-Arm_Kettlebell_Swings', 'Cable_Rope_Overhead_Triceps_Extension', 'Thigh_Abductor',
    'Thigh_Adductor', 'Ab_Crunch_Machine', 'Dead_Bug', 'Side_Bridge', 'Flat_Bench_Lying_Leg_Raise',
    'Standing_Cable_Wood_Chop', 'Wrist Curl', 'Band_Pull_Apart', 'Straight-Arm_Dumbbell_Pullover'],
  // 6: known and used, less often.
  ['Sumo Deadlift', 'Box Squat', 'Floor Press', 'Reverse Curl', 'Overhead Triceps Extension', 'Bent-Arm Pullover',
    'Rack_Pulls', 'Pallof_Press', 'Seated_One-arm_Cable_Pulley_Rows', 'Cable_Rear_Delt_Fly', 'Glute_Kickback',
    'One-Legged_Cable_Kickback', 'Pull_Through', 'Freehand_Jump_Squat', 'Star_Jump', 'Running_Treadmill',
    'Rowing_Stationary', 'Stairmaster', 'Bicycling_Stationary', 'Clean', 'Kettlebell_Thruster', 'Side Bend',
    'Oblique Crunch', 'Cable_Russian_Twists', 'Rope Crunch', 'Leg Pull-In', 'Bent-Knee_Hip_Raise', 'Lying_T-Bar_Row',
    'V-Bar_Pulldown', 'Underhand_Cable_Pulldowns', 'Rope_Straight-Arm_Pulldown', 'Leverage_High_Row',
    'Smith_Machine_Overhead_Shoulder_Press', 'Rear Lateral Raise', 'External Rotation', 'Internal Rotation',
    'Monster_Walk', 'Handstand_Push-Ups', 'Scapular_Pull-Up', 'Natural_Glute_Ham_Raise', 'Reverse_Hyperextension',
    'Jackknife_Sit-Up', 'Exercise_Ball_Crunch', 'Overhead_Slam', 'Alternating_Renegade_Row', 'Bent over Long Bar Row',
    'Calf_Press_On_The_Leg_Press_Machine', 'Plie_Dumbbell_Squat', 'Ball_Leg_Curl', 'Plyo Push-Up',
    'Standing_Towel_Triceps_Extension', 'Body_Tricep_Press', 'Low_Cable_Crossover', 'Tuck_Crunch', 'Cross-Body_Crunch'],
  // 7: seen now and then.
  ['Alternate_Heel_Touchers', 'Exercise_Ball_Pull-In', 'Medicine_Ball_Chest_Pass', 'Kettlebell_Sumo_High_Pull',
    'JM_Press', 'Tate_Press', 'Bent-Over Triceps Extension', 'Triceps Press', 'Close-Grip_Push-Up_off_of_a_Dumbbell',
    'Cross_Body_Hammer_Curl', 'Spider_Curl', 'Drag_Curl', 'Zottman_Curl', 'High_Cable_Curls',
    'Wide-Grip_Rear_Pull-Up', 'V-Bar_Pullup', 'High Pulley Row', 'Deficit_Deadlift', 'Weighted_Ball_Hyperextension',
    'Power_Clean', 'Push Press', 'Kettlebell_Halo', 'Cable_Rope_Rear-Delt_Rows', 'Seated_Bent-Over_Rear_Delt_Raise',
    'Clean_and_Press', 'Kettlebell_Turkish_Get-Up_Squat_style', 'Side_Laterals_to_Front_Raise', 'Push_Up_to_Side_Plank',
    'Front_Squats_With_Two_Kettlebells', 'Elliptical_Trainer', 'Split_Jump', 'Standing_Long_Jump', 'Knee_Tuck_Jump',
    'Lateral_Bound', 'Band_Hip_Adductions', 'Smith_Single-Leg_Split_Squat'],
  // 8: rare; here so that the small classes (Scrapper) have enough cards.
  ['Kneeling_Arm_Drill', 'Body-Up', 'Clock_Push-Up', 'Isometric_Chest_Squeezes', 'Finger_Curls', 'Physioball_Hip_Bridge',
    'Hip_Extension_with_Bands', 'Step-up_with_Knee_Raise', 'Carioca_Quick_Step', 'Fast_Skipping', 'Double_Leg_Butt_Kick',
    'Rocket_Jump', 'Scissors_Jump', 'Zercher_Squats', 'Weighted_Jump_Squat', 'Cuban_Press', 'Dumbbell_Scaption'],
];

// Variations of kept moves that are too rare to keep.
const OBSCURE = new Set([
  'Reverse_Band_Bench_Press', 'Reverse_Band_Power_Squat', 'Reverse_Band_Deadlift', 'Reverse_Band_Box_Squat',
  'Reverse_Band_Sumo_Deadlift', 'Kneeling_Squat', 'Lying_Machine_Squat', 'One_Leg_Barbell_Squat',
  'Close-Grip_EZ-Bar_Curl_with_Band', 'Plyo_Kettlebell_Pushups',
]);

const MODES = ['sofa', 'warmup', 'sweat', 'pain', 'brutal', 'nightmare'];
// Cards per class and body part, one number per mode (MODES). Each mode has more than the one before.
const BUDGET = {
  chest: [2, 3, 4, 5, 6, 8],
  back: [3, 4, 5, 6, 8, 10],
  shoulders: [2, 3, 4, 5, 6, 8],
  arms: [3, 4, 5, 6, 8, 10],
  legs: [4, 5, 6, 8, 10, 14],
  core: [2, 3, 4, 5, 7, 9],
};
const topLevel = (mode) => Math.floor(mode / 2); // D51
const LEVELS = ['beginner', 'intermediate', 'expert'];

// The class filter (D50); the same as classEquipment and classCategories in lib/game/exercises.dart.
const CLASSES = {
  scrapper: [['body only'], ['strength', 'plyometrics', 'cardio']],
  bruiser: [['body only', 'dumbbell', 'kettlebells', 'bands', 'medicine ball', 'exercise ball'], ['strength', 'plyometrics', 'cardio']],
  paladin: [['body only', 'barbell', 'e-z curl bar', 'dumbbell', 'kettlebells'], ['strength', 'powerlifting']],
  cablemancer: [['body only', 'machine', 'cable'], ['strength', 'cardio']],
};
const inClass = (c, e) => CLASSES[c][0].includes(e.equipment ?? 'body only') && CLASSES[c][1].includes(e.category);

// The body parts (D52); the same as bodyParts in lib/game/exercises.dart.
const PARTS = {
  chest: ['chest'], back: ['lats', 'middle back', 'lower back', 'traps'], shoulders: ['shoulders'],
  arms: ['biceps', 'triceps', 'forearms'], legs: ['quadriceps', 'hamstrings', 'glutes', 'calves', 'abductors', 'adductors'],
  core: ['abdominals'],
};
const partOf = (m) => Object.keys(PARTS).find((p) => PARTS[p].includes(m));
// The main muscles: each gets a card before a second card of another muscle.
const MAIN = new Set(['chest', 'lats', 'middle back', 'lower back', 'shoulders', 'biceps', 'triceps', 'quadriceps',
  'hamstrings', 'glutes', 'calves', 'abdominals']);

const args = process.argv.slice(2);
const all = JSON.parse(fs.readFileSync(args[0], 'utf8'));
const cardOf = (e) => e.base ?? e.id;
const visible = all.filter((e) => !OBSCURE.has(e.id) && Object.keys(CLASSES).some((c) => inClass(c, e)));

const byCard = new Map();
for (const e of visible) {
  if (!byCard.has(cardOf(e))) byCard.set(cardOf(e), []);
  byCard.get(cardOf(e)).push(e);
}

// Candidate cards in rank order.
const order = [];
COMMON.forEach((tier, t) => tier.forEach((name, i) => {
  if (!byCard.has(name)) throw new Error(`COMMON: no card ${name}`);
  if (order.some((o) => o.name === name)) throw new Error(`COMMON: ${name} twice`);
  order.push({ name, t, i, n: byCard.get(name).length });
}));
order.sort((a, b) => a.t - b.t || b.n - a.n || a.i - b.i);
const rankOf = new Map(order.map((o, i) => [o.name, i + 1]));

// The simplest exercise first (as in the app): fewest modifiers, then the shortest name.
const simplest = (a, b) => Object.keys(a.mods ?? {}).length - Object.keys(b.mods ?? {}).length || a.name.length - b.name.length;

// Per class: the first mode of each card. A card's muscle is the most
// frequent first muscle of its exercises in the class (a tie: the simplest
// exercise's); its level is the easiest level there.
const unlock = new Map(order.map((o) => [o.name, {}]));
const table = {};
for (const c of Object.keys(CLASSES)) {
  const cards = [];
  for (const o of order) {
    const vs = byCard.get(o.name).filter((e) => inClass(c, e)).sort(simplest);
    if (!vs.length) continue;
    const count = new Map();
    for (const e of vs) count.set(e.primaryMuscles[0], (count.get(e.primaryMuscles[0]) ?? 0) + 1);
    const muscle = [...count].reduce((a, b) => (b[1] > a[1] ? b : a))[0];
    cards.push({ name: o.name, muscle, part: partOf(muscle), level: Math.min(...vs.map((e) => LEVELS.indexOf(e.level))) });
  }
  table[c] = [];
  for (let mode = 0; mode < MODES.length; mode++) {
    for (const part of Object.keys(PARTS)) {
      const shown = cards.filter((k) => k.part === part && k.mode !== undefined);
      const pool = cards.filter((k) => k.part === part && k.mode === undefined && k.level <= topLevel(mode));
      while (shown.length < BUDGET[part][mode] && pool.length) {
        const first = (k) => (MAIN.has(k.muscle) && !shown.some((s) => s.muscle === k.muscle) ? 0 : 1);
        pool.sort((a, b) => first(a) - first(b) || rankOf.get(a.name) - rankOf.get(b.name));
        const k = pool.shift();
        k.mode = mode;
        shown.push(k);
      }
    }
    table[c].push(Object.fromEntries(Object.keys(PARTS).map((p) => [p, cards.filter((k) => k.part === p && k.mode !== undefined).length])));
  }
  for (const k of cards) if (k.mode !== undefined) unlock.get(k.name)[c] = k.mode;
  if (args.includes('--cards')) {
    for (const p of Object.keys(PARTS)) {
      const shown = cards.filter((k) => k.part === p && k.mode !== undefined).sort((a, b) => a.mode - b.mode);
      console.log(`${c} ${p}: ${shown.map((k) => `${k.mode} ${k.name}`).join(', ')}`);
    }
  }
}

// Kept cards get ranks 1..n again, with no gaps.
const kept = order.filter((o) => Object.keys(unlock.get(o.name)).length);
const unused = order.filter((o) => !kept.includes(o)).map((o) => o.name);
const out = [];
kept.forEach((o, i) => { for (const e of byCard.get(o.name)) out.push({ ...e, rank: i + 1, unlock: unlock.get(o.name) }); });
out.sort((a, b) => a.id.localeCompare(b.id));
if (all.some((e) => e.custom && !out.some((o) => o.id === e.id))) throw new Error('a custom exercise is dropped');

const total = (row) => Object.values(row).reduce((a, b) => a + b, 0);
const problems = [];
for (const c of Object.keys(CLASSES)) {
  table[c].forEach((row, mode) => {
    for (const p of Object.keys(PARTS)) if (!row[p]) problems.push(`${c} ${MODES[mode]}: no ${p}`);
    if (mode && total(row) <= total(table[c][mode - 1])) problems.push(`${c} ${MODES[mode]}: not more cards than ${MODES[mode - 1]}`);
  });
}

if (args.includes('--report')) {
  console.log(`kept ${out.length} of ${all.length} exercises in ${kept.length} cards (${kept.filter((o) => o.n > 1).length} moves)`);
  console.log('top 15:', kept.slice(0, 15).map((o, i) => `${i + 1}. ${o.name} (${byCard.get(o.name).length})`).join(', '));
  console.log('candidates no class shows (dropped):', unused.join(', ') || 'none');
  for (const c of Object.keys(CLASSES)) {
    console.log(`\n${c.padEnd(12)}${Object.keys(PARTS).map((p) => p.padStart(10)).join('')}     total`);
    table[c].forEach((row, mode) => console.log(`${MODES[mode].padEnd(12)}${Object.keys(PARTS).map((p) => String(row[p]).padStart(10)).join('')}${String(total(row)).padStart(10)}`));
  }
  console.log('\nproblems:', problems.join('; ') || 'none');
} else if (problems.length) throw new Error(problems.join('\n'));
const outPath = args.slice(1).find((a) => !a.startsWith('--'));
if (outPath) {
  fs.writeFileSync(outPath, '[\n' + out.map((r) => JSON.stringify(r)).join(',\n') + '\n]\n');
  console.log('written', out.length);
}
