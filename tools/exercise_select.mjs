// Cuts the exercise list down and picks, per class and difficulty mode, the
// cards that make a real workout (D67, D69). Reads the full list
// (tools/exercise_db.json: the 692 database exercises of D56 and the added
// ones of D57 and D69, with `base` and `mods` from exercise_variants.mjs;
// a merged or removed exercise has only `alias`, D90)
// and writes the app list:
//   node tools/exercise_variants.mjs tools/exercise_db.json --write tools/exercise_db.json
//   node tools/exercise_select.mjs tools/exercise_db.json assets/exercises/exercises.json [--report] [--slots] [--cards]
//
// What it writes per exercise, on top of the database fields:
//   rank     commonness of its card (1 = the most common card). All
//            exercises of one move have the rank of the move.
//   pattern  the movement pattern of its card (PATTERNS), for example
//            `hpush` (horizontal push).
//   unlock   class id -> the first difficulty mode (0 Sofa .. 5 Nightmare)
//            that shows the card for that class. Only classes that show
//            the card are listed.
//   level    the database level, or the app's level from LEVEL.
//   aliases  old ids that now mean this exercise (merged or removed, D90).
//            The app reads saved sets, favorites and Today through them.
//            Every id of tools/frozen_ids.txt must be an exercise or an alias.
//
// Rules (D69), per class and mode, in this order:
// 1. Levels: LEVEL changes the level of some exercises (too hard or too
//    easy for their database level). The database file keeps its levels.
//    A mode only takes cards that have an exercise of its level (D51: Sofa
//    and Warm-up beginner; Sweat and Pain also intermediate; Brutal and
//    Nightmare also expert). A card shown in one mode stays in every harder
//    mode.
// 2. PIN: cards the owner placed in a mode for a class come in that mode
//    (not earlier).
// 3. Slots: each movement pattern of SLOTS gets TARGET[mode] cards, the
//    most common first. So every mode has a push, a pull, a squat, a hinge
//    and so on wherever the class has the gear.
// 4. Commonness: each body part (D52) fills up to BUDGET[part][mode]
//    cards. From Sweat on, a body part first takes one card of the mode's
//    new level (harder moves, not only more cards). Then the most common
//    card of a MAIN muscle that has no card yet, else the most common card.
//    COMMON lists the candidate cards in tiers, by judgment of how often
//    the exercise is seen in gyms and training programs (tier 1 = in
//    almost every program). Inside a tier, a move with more variations
//    comes first (one name gives more); then the order of the list.
// 5. Each mode shows more cards than the one before.
// The list keeps every candidate card of COMMON, also one that no class
// shows in a mode (D70 shows all cards of the class, D72 searches all). A
// kept move keeps its variations, but not the ones in OBSCURE and not the
// ones no class can see (equipment `other` or `foam roll`, D50). Exercises with
// `custom: true` (D57, D69) must be kept. Ids do not change (saved sets
// point to them).
import fs from 'node:fs';
import { checkFrozen, composeName, equipShownOf } from './exercise_names.mjs';

// Most common first. A name is a move (`base`) or the id of an exercise
// (then it stands for the exercise's move).
const COMMON = [
  // 1: the big lifts, in almost every program.
  ['Bench Press', 'Squat', 'Deadlift', 'Pull-Up', 'Push-Up', 'Shoulder Press', 'Bicep Curl', 'Lat Pulldown', 'Plank',
    'Crunch'],
  // 2: in most gym programs.
  ['Dip', 'Bent-Over Row', 'One-Arm Row', 'Lunge', 'Leg Press', 'Triceps Pushdown', 'Lateral Raise', 'Romanian Deadlift',
    'Seated Cable Row', 'Leg Extension', 'Leg Curl', 'Calf Raise'],
  // 3: very common.
  ['Hammer Curl', 'Hip Thrust', 'Fly', 'Sit-Up', 'Overhead Triceps Extension', 'Shrug', 'Hanging Leg Raise',
    'Goblet Squat', 'Face Pull', 'Skullcrusher', 'Preacher Curl'],
  // 4: common.
  ['Front Raise', 'Reverse Fly', 'Upright Row', 'Crossover', 'Chest Press', 'Step-Up',
    'Glute Bridge', 'Hack Squat', 'Russian_Twist', 'Bicycle Crunch',
    'Mountain Climber', 'Inverted Row', 'Triceps Kickback', 'Back Extension', 'Kettlebell Swing', "Farmer's Walk"],
  // 5: a regular in many programs.
  ['Good Morning', 'Reverse Crunch', 'Arnold Press', 'Concentration Curl', 'Straight-Arm Pulldown',
    'Split Squat', 'Front Squat', 'T-Bar Row', 'Hip Abduction', 'Hip Adduction', 'Dead_Bug', 'Side Plank',
    'Lying Leg Raise', 'Standing_Cable_Wood_Chop', 'Wrist Curl', 'Band Pull-Apart', 'Pullover',
    'Pike Push-Up', 'Burpee', 'Ab Rollout', 'Pistol Squat', 'Chest-Supported Row'],
  // 6: known and used, less often.
  ['Sumo Deadlift', 'Box Squat', 'Floor Press', 'Reverse Curl', 'Triceps Extension',
    'Rack Pull', 'Pallof_Press', 'Glute Kickback', 'Pull-Through', 'Jump Squat', 'Star_Jump', 'Jump Rope',
    'Cardio Machine', 'Power Clean', 'Kettlebell_Thruster', 'Side Bend', 'Landmine_Linear_Jammer', 'Muscle_Up', 'Front_Box_Jump',
    'Oblique Crunch', 'Leg Pull-In',
    'High Row', 'External Rotation', 'Internal Rotation', 'Monster_Walk', 'Handstand Push-Up', 'Scapular Pull-Up',
    'Nordic Curl', 'Reverse_Hyperextension', 'Jackknife_Sit-Up', 'Ball Slam', 'Renegade Row',
    'Towel Triceps Extension', 'Tuck_Crunch', 'Cross-Body_Crunch', 'Dead Hang', 'Superman', 'Wall_Sit', 'Hollow_Body_Hold',
    'Bird_Dog', 'Prone_Y-T-W_Raise', 'Cossack_Squat', 'Rear Delt Row'],
  // 7: seen now and then.
  ['Alternate_Heel_Touchers', 'Ball Pull-In', 'Medicine_Ball_Chest_Pass',
    'JM_Press', 'Tate_Press',
    'Spider_Curl', 'Drag_Curl', 'Zottman_Curl', 'High_Cable_Curls',
    'High Pulley Row', 'Deficit_Deadlift',
    'Push Press', 'Kettlebell_Halo', 'Kettlebell_Turkish_Get-Up_Squat_style',
    'Side_Laterals_to_Front_Raise', 'Push-Up to Side Plank', 'Split_Jump', 'Standing_Long_Jump', 'Knee_Tuck_Jump',
    'Lateral_Bound', 'Wall_Walk', 'Wall_Handstand_Hold',
    'Pogo_Hops', 'L-Sit', 'Dumbbell Swing', 'Flutter_Kicks', 'Reverse_Snow_Angel', 'Chin-Up_Hold'],
  // 8: rare; here so that the small classes (Scrapper) have enough cards.
  ['Kneeling_Arm_Drill', 'Clock_Push-Up', 'Isometric Chest Squeeze', 'Finger_Curls',
    'Carioca_Quick_Step', 'Fast_Skipping', 'Double_Leg_Butt_Kick',
    'Rocket_Jump', 'Zercher_Squats', 'Cuban_Press', 'Dumbbell_Scaption',
    'Doorframe_Curl', 'Calf Raise on a Dumbbell'],
];

// The movement pattern of each candidate card. The slot patterns are in
// SLOTS; the others (raise, fly, ...) only fill the budget.
const PATTERNS = {
  hpush: ['Bench Press', 'Push-Up', 'Chest Press', 'Floor Press', 'Push-Up to Side Plank', 'Clock_Push-Up',
    'Medicine_Ball_Chest_Pass'],
  vpush: ['Shoulder Press', 'Arnold Press', 'Handstand Push-Up', 'Push Press', 'Pike Push-Up', 'Wall_Walk', 'Wall_Handstand_Hold',
    'Kettlebell_Thruster', 'Landmine_Linear_Jammer'],
  hpull: ['Bent-Over Row', 'One-Arm Row', 'Seated Cable Row', 'Inverted Row', 'T-Bar Row', 'Chest-Supported Row', 'High Row',
    'Renegade Row'],
  vpull: ['Pull-Up', 'Lat Pulldown', 'Straight-Arm Pulldown', 'Scapular Pull-Up', 'High Pulley Row', 'Muscle_Up'],
  squat: ['Squat', 'Leg Press', 'Leg Extension', 'Goblet Squat', 'Hack Squat', 'Front Squat', 'Box Squat',
    'Zercher_Squats', 'Wall_Sit'],
  hinge: ['Deadlift', 'Romanian Deadlift', 'Hip Thrust', 'Glute Bridge', 'Back Extension',
    'Good Morning', 'Kettlebell Swing', 'Sumo Deadlift', 'Rack Pull', 'Glute Kickback', 'Pull-Through', 'Reverse_Hyperextension',
    'Deficit_Deadlift', 'Superman', 'Dumbbell Swing'],
  single: ['Lunge', 'Step-Up', 'Split Squat', 'Pistol Squat'],
  calves: ['Calf Raise', 'Pogo_Hops', 'Calf Raise on a Dumbbell'],
  biceps: ['Bicep Curl', 'Hammer Curl', 'Preacher Curl', 'Concentration Curl', 'Spider_Curl', 'Drag_Curl',
    'Zottman_Curl', 'High_Cable_Curls', 'Chin-Up_Hold', 'Doorframe_Curl'],
  triceps: ['Dip', 'Triceps Pushdown', 'Overhead Triceps Extension', 'Skullcrusher', 'Triceps Kickback', 'Triceps Extension',
    'Towel Triceps Extension', 'JM_Press', 'Tate_Press'],
  rear: ['Face Pull', 'Reverse Fly', 'Band Pull-Apart', 'Prone_Y-T-W_Raise', 'Rear Delt Row', 'Cuban_Press', 'Reverse_Snow_Angel'],
  flex: ['Crunch', 'Sit-Up', 'Hanging Leg Raise', 'Bicycle Crunch', 'Reverse Crunch', 'Lying Leg Raise', 'Oblique Crunch',
    'Leg Pull-In', 'Jackknife_Sit-Up', 'Tuck_Crunch',
    'Cross-Body_Crunch', 'Alternate_Heel_Touchers', 'Flutter_Kicks', 'L-Sit'],
  antiext: ['Plank', 'Dead_Bug', 'Side Plank', 'Ball Pull-In', 'Ab Rollout', 'Hollow_Body_Hold', 'Bird_Dog', 'Pallof_Press'],
  forearms: ['Wrist Curl', 'Reverse Curl', 'Dead Hang', 'Finger_Curls'],
  abductor: ['Hip Abduction', 'Monster_Walk'],
  adductor: ['Hip Adduction', 'Cossack_Squat'],
  // Not slots.
  raise: ['Lateral Raise', 'Front Raise', 'Upright Row', 'Kettlebell_Halo', 'Side_Laterals_to_Front_Raise', 'Dumbbell_Scaption',
    'External Rotation', 'Internal Rotation', 'Kneeling_Arm_Drill'],
  fly: ['Fly', 'Crossover', 'Pullover', 'Isometric Chest Squeeze'],
  shrug: ['Shrug'],
  carry: ["Farmer's Walk"],
  hamcurl: ['Leg Curl', 'Nordic Curl'],
  rotation: ['Russian_Twist', 'Standing_Cable_Wood_Chop', 'Side Bend'],
  power: ['Power Clean', 'Ball Slam', 'Kettlebell_Turkish_Get-Up_Squat_style'],
  plyo: ['Mountain Climber', 'Burpee', 'Jump Squat', 'Star_Jump', 'Split_Jump', 'Standing_Long_Jump', 'Knee_Tuck_Jump',
    'Lateral_Bound', 'Carioca_Quick_Step', 'Fast_Skipping', 'Double_Leg_Butt_Kick', 'Rocket_Jump',
    'Front_Box_Jump'],
  cardio: ['Cardio Machine', 'Jump Rope'],
};

// The pattern slots: id, name, core (every mode) or extra (from Sweat).
const SLOTS = [
  ['hpush', 'horizontal push', true], ['vpush', 'vertical push', true], ['hpull', 'horizontal pull', true],
  ['vpull', 'vertical pull', true], ['squat', 'squat / knee', true], ['hinge', 'hinge / hip', true],
  ['single', 'single leg', true], ['calves', 'calves', true], ['biceps', 'biceps', true], ['triceps', 'triceps', true],
  ['rear', 'rear delt / upper back', true], ['flex', 'core flexion', true], ['antiext', 'core anti-extension', true],
  ['forearms', 'forearms', false], ['abductor', 'abductors', false], ['adductor', 'adductors', false],
];
// Cards per slot, one number per mode.
const TARGET = { core: [1, 1, 2, 2, 3, 3], extra: [0, 0, 1, 1, 1, 2] };

// The app's level for exercises whose database level is wrong for the app
// (D69). The database file keeps its own levels.
const LEVEL = {
  // Too hard for beginners. Chin-ups and pull-ups are the same level.
  Pullups: 'intermediate', 'Chin-Up': 'intermediate', 'Dips_-_Triceps_Version': 'intermediate',
  'Plyo_Push-up': 'intermediate', Knee_Tuck_Jump: 'intermediate', 'Decline_Push-Up': 'intermediate',
  'V-Bar_Pullup': 'intermediate', Muscle_Up: 'expert',
  // A barbell lunge is a barbell lunge, walking or not.
  Barbell_Walking_Lunge: 'intermediate',
  // Machines and cables that beginners use.
  Face_Pull: 'beginner', Flat_Bench_Cable_Flyes: 'beginner', Incline_Cable_Flye: 'beginner',
  Hyperextensions_With_No_Hyperextension_Bench: 'beginner', Ab_Crunch_Machine: 'beginner', Lying_Cable_Curl: 'beginner',
  'Standing_One-Arm_Cable_Curl': 'beginner', 'Seated_One-arm_Cable_Pulley_Rows': 'beginner', 'V-Bar_Pulldown': 'beginner',
  Smith_Machine_Leg_Press: 'beginner', Narrow_Stance_Leg_Press: 'beginner', Kneeling_Cable_Triceps_Extension: 'beginner',
  // Basics that beginners learn: the barbell deadlift (light), the jump rope.
  Barbell_Deadlift: 'beginner', Rope_Jumping: 'beginner',
  // Cardio machines that beginners use.
  Elliptical_Trainer: 'beginner', Rowing_Stationary: 'beginner',
};

const MODES = ['sofa', 'warmup', 'sweat', 'pain', 'brutal', 'nightmare'];
const M = Object.fromEntries(MODES.map((m, i) => [m, i]));

// Cards the owner placed (D69): class -> exercise id or card name -> mode.
// The card comes in that mode, not earlier.
const PIN = {
  scrapper: {
    'Scapular_Pull-Up': M.sofa, Butt_Lift_Bridge: M.sofa, 'Sit-Up': M.sofa,
    Dead_Bug: M.warmup, Side_Bridge: M.warmup, 'Step-up_with_Knee_Raise': M.warmup, Bird_Dog: M.warmup,
    Glute_Kickback: M.sweat, Mountain_Climbers: M.sweat, 'Cross-Body_Crunch': M.sweat, Rope_Jumping: M.sweat,
    // The variation audit merged 6 Scrapper cards into chips (rows, chin-up,
    // plyo push-up, glute-ham raise): these keep the steps even.
    Tuck_Crunch: M.sweat, Lateral_Bound: M.sweat, Alternate_Heel_Touchers: M.sweat,
    // D90 step 1: Bent-Knee Hip Raise is now Reverse Crunch, Floor Glute-Ham
    // Raise the Nordic Curl, Scissors Jump the Split Jump.
    Flutter_Kicks: M.pain, Hollow_Body_Hold: M.pain, Reverse_Crunch: M.pain,
    Natural_Glute_Ham_Raise: M.pain, 'Jackknife_Sit-Up': M.pain,
    'L-Sit': M.brutal, Rocket_Jump: M.brutal,
    Double_Leg_Butt_Kick: M.nightmare, Carioca_Quick_Step: M.nightmare, Fast_Skipping: M.nightmare,
  },
  bruiser: {
    Inverted_Row: M.sofa, Butt_Lift_Bridge: M.sofa, Dead_Bug: M.sofa,
    Reverse_Flyes: M.warmup, Goblet_Squat: M.warmup, Split_Squat_with_Dumbbells: M.warmup,
    Side_Bridge: M.warmup, Hammer_Curls: M.warmup, Dumbbell_Shrug: M.warmup, 'Sit-Up': M.warmup, Bird_Dog: M.warmup,
    'Exercise_Ball_Pull-In': M.sweat, Band_Pull_Apart: M.sweat, Kettlebell_Swing: M.sweat,
    Dumbbell_Farmers_Walk: M.sweat,
    Rope_Jumping: M.pain,
    Tricep_Dumbbell_Kickback: M.pain, Vertical_Swing: M.pain, Ball_Leg_Curl: M.pain, Dumbbell_Step_Ups: M.pain,
    Mountain_Climbers: M.pain, Kettlebell_Thruster: M.pain,
    Kettlebell_Pistol_Squat: M.brutal, Alternating_Renegade_Row: M.brutal,
    // Band and kettlebell variations (D80) that give the class a new card:
    // the band ones with Band Pull-Apart and the abductor slot, the
    // kettlebell sumo deadlift with the Paladin's sumo deadlift.
    'face pull|bands': M.sweat, 'hip abduction|bands': M.sweat, 'sumo deadlift|kettlebell': M.pain,
    // The rare moves the keep rule brought back, placed by gear (D50) in late modes.
    // The band hip extension is now a Glute Kickback chip (D90 step 1).
    Hip_Extension_with_Bands: M.sweat, Halo: M.pain,
    Scaption: M.brutal, 'Lateral to Front Raise': M.brutal,
    'Zottman Curl': M.nightmare, 'Cuban Press': M.nightmare,
  },
  paladin: {
    Reverse_Flyes: M.sofa,
    Split_Squat_with_Dumbbells: M.warmup, Inverted_Row: M.warmup, Barbell_Rear_Delt_Row: M.warmup, Dead_Bug: M.warmup,
    Hammer_Curls: M.warmup, Barbell_Shrug: M.warmup, 'Sit-Up': M.warmup,
    Side_Bridge: M.sweat, Kettlebell_Swing: M.sweat, Barbell_Hack_Squat: M.sweat, Bird_Dog: M.sweat,
    Dumbbell_Farmers_Walk: M.sweat,
    Sumo_Deadlift: M.pain, Rack_Pulls: M.pain, Front_Squat_Clean_Grip: M.pain, 'Push Press': M.pain,
    Barbell_Ab_Rollout: M.pain, Barbell_Step_Ups: M.pain, Kettlebell_Thruster: M.pain,
    Power_Clean: M.brutal, Box_Squat: M.brutal, Landmine_Linear_Jammer: M.brutal,
    Kettlebell_Pistol_Squat: M.nightmare, 'Kettlebell_Turkish_Get-Up_Squat_style': M.nightmare,
    // The rare moves the keep rule brought back, placed by gear (D50) in late modes.
    'Spider Curl': M.sweat, 'JM Press': M.pain,
    'Drag Curl': M.brutal, 'Deficit Deadlift': M.brutal, 'Tate Press': M.brutal,
    'Finger Curl': M.nightmare,
  },
  cablemancer: {
    Leg_Press: M.sofa, Leg_Extensions: M.sofa, Butterfly: M.sofa, Face_Pull: M.sofa, Reverse_Machine_Flyes: M.sofa,
    Seated_Cable_Rows: M.sofa, Cable_Deadlifts: M.sofa,
    Cable_Crossover: M.warmup, Leverage_High_Row: M.warmup, 'Sit-Up': M.warmup,
    Bird_Dog: M.warmup,
    Thigh_Abductor: M.sweat, Thigh_Adductor: M.sweat, 'Cable_Hammer_Curls_-_Rope_Attachment': M.sweat,
    Pull_Through: M.pain, Pallof_Press: M.pain,
    Standing_Cable_Wood_Chop: M.brutal,
    // The rare moves the keep rule brought back, placed by gear (D50) in late modes.
    'Triceps Extension': M.pain, 'High Pulley Row': M.brutal, 'High Cable Curl': M.brutal,
    'Reverse Hyperextension': M.nightmare,
  },
};

// Display names (D80): a special name from assets/i18n/en.json (`exercise.<id>`,
// the clean names of the D69 clean-up that no rule makes), else the name
// composed from the move and its modifiers (tools/exercise_names.mjs). The
// database file keeps its names, and ids never change.
const EN = JSON.parse(fs.readFileSync(new URL('../assets/i18n/en.json', import.meta.url), 'utf8'));

// Variations of kept moves that are too rare to keep.
const OBSCURE = new Set([
  'Reverse_Band_Bench_Press', 'Reverse_Band_Power_Squat', 'Reverse_Band_Deadlift', 'Reverse_Band_Box_Squat',
  'Reverse_Band_Sumo_Deadlift', 'Kneeling_Squat', 'Lying_Machine_Squat', 'One_Leg_Barbell_Squat',
  'Close-Grip_EZ-Bar_Curl_with_Band', 'Plyo_Kettlebell_Pushups',
  // The variation audit: odd or duplicate variations. Saved sets keep
  // their names (`exercise.<id>` stays in en.json and ro.json).
  'Incline_Push-Up_Reverse_Grip', 'Bodyweight_Flyes', 'Smith_Machine_Pistol_Squat',
  'Palms-Down_Dumbbell_Wrist_Curl_Over_A_Bench', 'Palms-Down_Wrist_Curl_Over_A_Bench',
  'Palms-Up_Barbell_Wrist_Curl_Over_A_Bench', 'Palms-Up_Dumbbell_Wrist_Curl_Over_A_Bench',
  'Barbell_Shoulder_Press', // the same as Standing_Military_Press
  'Dumbbell_Shoulder_Press', // the same as the seated and standing dumbbell press
]);

// Cards per class and body part, one number per mode (MODES): what the
// commonness step fills up to. Pins and slots may give a body part more.
const BUDGET = {
  chest: [2, 3, 4, 5, 6, 8],
  back: [3, 4, 6, 7, 9, 11],
  shoulders: [2, 3, 4, 5, 6, 8],
  arms: [3, 4, 5, 6, 8, 10],
  legs: [4, 6, 8, 10, 12, 16],
  core: [3, 3, 4, 5, 7, 9],
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
// Merged and removed exercises (D90): only their alias goes into the list.
const aliasOf = {};
const all = JSON.parse(fs.readFileSync(args[0], 'utf8')).filter((e) => !(e.alias && (aliasOf[e.id] = e.alias)));
for (const [id, level] of Object.entries(LEVEL)) {
  const e = all.find((x) => x.id === id);
  if (!e) throw new Error(`LEVEL: no exercise ${id}`);
  if (e.level === level) throw new Error(`LEVEL: ${id} is already ${level}`);
  e.level = level;
}
const cardOf = (e) => e.base ?? e.id;
const visible = all.filter((e) => !OBSCURE.has(e.id) && Object.keys(CLASSES).some((c) => inClass(c, e)));
const byId = new Map(all.map((e) => [e.id, e]));

const byCard = new Map();
for (const e of visible) {
  if (!byCard.has(cardOf(e))) byCard.set(cardOf(e), []);
  byCard.get(cardOf(e)).push(e);
}
for (const vs of byCard.values()) {
  const shown = equipShownOf(vs);
  for (const e of vs) e.name = EN[`exercise.${e.id}`] ?? composeName(e.base, e.mods, shown, (k) => EN[k]);
}
// A name in COMMON and PATTERNS: a move, or an exercise id for its move.
const cardName = (n) => (byCard.has(n) ? n : byId.has(n) ? cardOf(byId.get(n)) : n);

// Candidate cards in rank order.
const order = [];
COMMON.forEach((tier, t) => tier.forEach((id, i) => {
  const name = cardName(id);
  if (!byCard.has(name)) throw new Error(`COMMON: no card ${id}`);
  if (order.some((o) => o.name === name)) throw new Error(`COMMON: ${name} twice`);
  order.push({ name, t, i, n: byCard.get(name).length });
}));
order.sort((a, b) => a.t - b.t || b.n - a.n || a.i - b.i);
const rankOf = new Map(order.map((o, i) => [o.name, i + 1]));

const patternOf = new Map();
for (const [p, names] of Object.entries(PATTERNS)) {
  for (const id of names) {
    const n = cardName(id);
    if (!rankOf.has(n)) throw new Error(`PATTERNS ${p}: ${id} is not in COMMON`);
    if (patternOf.has(n)) throw new Error(`PATTERNS: ${n} twice`);
    patternOf.set(n, p);
  }
}
for (const o of order) if (!patternOf.has(o.name)) throw new Error(`PATTERNS: no pattern for ${o.name}`);

// The simplest exercise first (as in the app): fewest modifiers, then the shortest name.
const simplest = (a, b) => Object.keys(a.mods ?? {}).length - Object.keys(b.mods ?? {}).length || a.name.length - b.name.length;

// Per class: the first mode of each card. A card's muscle is the most
// frequent first muscle of its exercises in the class (a tie: the simplest
// exercise's); its level is the easiest level there.
const unlock = new Map(order.map((o) => [o.name, {}]));
const table = {};
const slotTable = {};
const candidates = {};
for (const c of Object.keys(CLASSES)) {
  const cards = [];
  for (const o of order) {
    const vs = byCard.get(o.name).filter((e) => inClass(c, e)).sort(simplest);
    if (!vs.length) continue;
    const count = new Map();
    for (const e of vs) count.set(e.primaryMuscles[0], (count.get(e.primaryMuscles[0]) ?? 0) + 1);
    const muscle = [...count].reduce((a, b) => (b[1] > a[1] ? b : a))[0];
    cards.push({
      name: o.name, muscle, part: partOf(muscle), pattern: patternOf.get(o.name), rank: rankOf.get(o.name), tier: o.t,
      level: Math.min(...vs.map((e) => LEVELS.indexOf(e.level))),
    });
  }
  candidates[c] = cards;
  const card = (name) => cards.find((k) => k.name === name);
  for (const [key, mode] of Object.entries(PIN[c])) {
    const e = byId.get(key);
    const k = card(e ? cardOf(e) : key);
    if (!k) throw new Error(`PIN ${c} ${key}: not a candidate card of the class`);
    if (e && (!inClass(c, e) || OBSCURE.has(e.id))) throw new Error(`PIN ${c} ${key}: the class cannot see it`);
    const level = e ? LEVELS.indexOf(e.level) : k.level;
    if (level > topLevel(mode)) throw new Error(`PIN ${c} ${key}: too hard for ${MODES[mode]}`);
    if (k.pin !== undefined && k.pin !== mode) throw new Error(`PIN ${c} ${key}: card ${k.name} pinned twice`);
    k.pin = mode;
  }
  const byRank = (a, b) => a.rank - b.rank;
  table[c] = [];
  slotTable[c] = [];
  for (let mode = 0; mode < MODES.length; mode++) {
    const free = (k) => k.mode === undefined && k.level <= topLevel(mode) && (k.pin === undefined || k.pin <= mode);
    const take = (k) => { k.mode = mode; };
    // 2. Pins.
    for (const k of cards) if (k.pin === mode) take(k);
    // 3. Slots.
    for (const [s, , core] of SLOTS) {
      const want = TARGET[core ? 'core' : 'extra'][mode];
      const have = () => cards.filter((k) => k.pattern === s && k.mode !== undefined).length;
      const pool = cards.filter((k) => k.pattern === s && free(k)).sort(byRank);
      while (have() < want && pool.length) take(pool.shift());
    }
    // 4. Commonness, per body part. Pinned cards do not use the budget.
    for (const part of Object.keys(PARTS)) {
      const shown = () => cards.filter((k) => k.part === part && k.mode !== undefined);
      const pool = cards.filter((k) => k.part === part && free(k));
      const hard = () => mode >= 2 && !shown().some((k) => k.mode === mode && k.level === topLevel(mode));
      const used = () => shown().filter((k) => k.pin === undefined).length;
      while (used() < BUDGET[part][mode] && pool.length) {
        const s = shown();
        // A harder card only when it is fairly common (tiers 1-5).
        const first = (k) => (hard() && k.level === topLevel(mode) && k.tier < 5 ? 0 : 1)
          + (MAIN.has(k.muscle) && k.tier < 5 && !s.some((x) => x.muscle === k.muscle) ? 0 : 2);
        pool.sort((a, b) => first(a) - first(b) || byRank(a, b));
        take(pool.shift());
      }
    }
    // 5. More cards than the mode before.
    const prev = mode ? cards.filter((k) => k.mode !== undefined && k.mode < mode).length : 0;
    if (mode && cards.filter((k) => k.mode !== undefined).length <= prev) {
      const k = cards.filter(free).sort(byRank)[0];
      if (k) take(k);
    }
    table[c].push(Object.fromEntries(Object.keys(PARTS).map((p) => [p, cards.filter((k) => k.part === p && k.mode !== undefined).length])));
    slotTable[c].push(Object.fromEntries(SLOTS.map(([s]) => [s, cards.filter((k) => k.pattern === s && k.mode !== undefined).length])));
  }
  for (const k of cards) if (k.mode !== undefined) unlock.get(k.name)[c] = k.mode;
  if (args.includes('--free')) {
    console.log(`${c} not shown: ${cards.filter((k) => k.mode === undefined).map((k) => `${k.name} (${k.part} ${k.pattern} L${k.level})`).join(', ')}`);
  }
  if (args.includes('--cards')) {
    for (const p of Object.keys(PARTS)) {
      const shown = cards.filter((k) => k.part === p && k.mode !== undefined).sort((a, b) => a.mode - b.mode);
      console.log(`${c} ${p}: ${shown.map((k) => `${k.mode} ${k.name}`).join(', ')}`);
    }
  }
}

// Every candidate card stays, also one that no class shows in a mode:
// D70 shows all cards of the class and D72 searches all exercises. Kept
// cards get ranks 1..n again, with no gaps.
const kept = order;
const unused = order.filter((o) => !Object.keys(unlock.get(o.name)).length).map((o) => o.name);
const out = [];
kept.forEach((o, i) => {
  for (const e of byCard.get(o.name)) out.push({ ...e, rank: i + 1, pattern: patternOf.get(o.name), unlock: unlock.get(o.name) });
});
out.sort((a, b) => a.id.localeCompare(b.id));
// The app makes one card per base (case ignored) and CHALK reads the
// pattern of every exercise: all exercises of one move must have the same
// pattern and rank, or a search finds only some of them.
const moveOf = new Map();
for (const e of out) {
  const k = e.base.toLowerCase(), m = moveOf.get(k);
  if (!m) moveOf.set(k, e);
  else if (m.pattern !== e.pattern || m.rank !== e.rank) {
    throw new Error(`move ${e.base}: ${m.id} is ${m.pattern} #${m.rank}, ${e.id} is ${e.pattern} #${e.rank}`);
  }
}
const lost = all.filter((e) => e.custom && !out.some((o) => o.id === e.id));
if (lost.length) throw new Error(`custom exercises dropped: ${lost.map((e) => e.id).join(', ')}`);
// Old ids keep working (D90): each alias goes on the exercise it points to,
// and no id of tools/frozen_ids.txt is lost.
checkFrozen(out.map((e) => e.id), aliasOf, 'exercise_select');
const outById = new Map(out.map((e) => [e.id, e]));
for (const [from, to] of Object.entries(aliasOf).sort()) (outById.get(to).aliases ??= []).push(from);

// A slot's state in one class and mode: OK (the target or more), THIN
// (fewer; THIN*: and no other card exists), MISSING (none), n/a (the class has no card of the pattern in
// the mode's levels).
const slotState = (c, mode, s, core) => {
  const n = slotTable[c][mode][s];
  const want = TARGET[core ? 'core' : 'extra'][mode];
  const exists = candidates[c].filter((k) => k.pattern === s && k.level <= topLevel(mode)).length;
  if (!want) return n ? 'OK' : '-';
  if (n >= want) return 'OK';
  if (!exists) return 'n/a';
  return n ? (n >= exists ? 'THIN*' : 'THIN') : 'MISSING';
};

const total = (row) => Object.values(row).reduce((a, b) => a + b, 0);
const problems = [];
for (const c of Object.keys(CLASSES)) {
  table[c].forEach((row, mode) => {
    for (const p of Object.keys(PARTS)) if (!row[p]) problems.push(`${c} ${MODES[mode]}: no ${p}`);
    if (mode && total(row) <= total(table[c][mode - 1])) problems.push(`${c} ${MODES[mode]}: not more cards than ${MODES[mode - 1]}`);
    for (const [s, , core] of SLOTS) {
      if (core && slotState(c, mode, s, core) === 'MISSING') problems.push(`${c} ${MODES[mode]}: no ${s}`);
    }
  });
}

if (args.includes('--report')) {
  console.log(`kept ${out.length} of ${all.length} exercises in ${kept.length} cards (${kept.filter((o) => o.n > 1).length} moves)`);
  console.log('top 15:', kept.slice(0, 15).map((o, i) => `${i + 1}. ${o.name} (${byCard.get(o.name).length})`).join(', '));
  console.log('cards no class shows in a mode (kept, D70):', unused.join(', ') || 'none');
  for (const c of Object.keys(CLASSES)) {
    console.log(`\n${c.padEnd(12)}${Object.keys(PARTS).map((p) => p.padStart(10)).join('')}     total`);
    table[c].forEach((row, mode) => console.log(`${MODES[mode].padEnd(12)}${Object.keys(PARTS).map((p) => String(row[p]).padStart(10)).join('')}${String(total(row)).padStart(10)}`));
  }
}
if (args.includes('--slots')) {
  const weak = [];
  for (const c of Object.keys(CLASSES)) {
    console.log(`\n${c.padEnd(12)}${MODES.map((m) => m.padStart(12)).join('')}`);
    for (const [s, name, core] of SLOTS) {
      const cells = MODES.map((_, mode) => {
        const st = slotState(c, mode, s, core);
        if (!['OK', '-'].includes(st)) weak.push(`${c} ${MODES[mode]} ${s}: ${st} (${slotTable[c][mode][s]})`);
        return `${slotTable[c][mode][s]} ${st}`.padStart(12);
      });
      console.log(`${name.padEnd(22).slice(0, 22)}${cells.join('')}`.replace(/^(.{12})/, (x) => x));
    }
  }
  console.log('\nnot OK:', weak.join('; ') || 'none');
  console.log('(target per mode: core', TARGET.core.join(' '), '; extra', TARGET.extra.join(' '),
    '; THIN* = thin, but the class has no other card there; n/a = the class has no such card in the levels)');
}
if (args.includes('--report') || args.includes('--slots')) console.log('\nproblems:', problems.join('; ') || 'none');
else if (problems.length) throw new Error(problems.join('\n'));
const outPath = args.slice(1).find((a) => !a.startsWith('--'));
if (outPath) {
  fs.writeFileSync(outPath, '[\n' + out.map((r) => JSON.stringify(r)).join(',\n') + '\n]\n');
  // The move names, one per card, for the translator (D68: `move.<base>`).
  const moves = [...new Set(out.map((r) => r.base))].sort((a, b) => a.localeCompare(b));
  fs.writeFileSync(new URL('move_names.txt', import.meta.url), moves.join('\n') + '\n');
  console.log('written', out.length, 'and', moves.length, 'move names');
}
