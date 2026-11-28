// Cuts the exercise list down to the common cards and ranks them (D67,
// D69, D90). Reads the full list
// (tools/exercise_db.json: the 692 database exercises of D56 and the added
// ones of D57 and D69, with `base`, `mods` and `score` from exercise_variants.mjs;
// a merged or removed exercise has only `alias`, D90)
// and writes the app list:
//   node tools/exercise_variants.mjs tools/exercise_db.json --write tools/exercise_db.json
//   node tools/exercise_select.mjs tools/exercise_db.json assets/exercises/exercises.json [--report] [--slots]
//
// What it writes per exercise, on top of the database fields:
//   rank     commonness of its card (1 = the most common card). All
//            exercises of one move have the rank of the move.
//   pattern  the movement pattern of its card (PATTERNS), for example
//            `hpush` (horizontal push).
//   level    the database level, or the app's level from LEVEL.
//   aliases  old ids that now mean this exercise (merged or removed, D90).
//            The app reads saved sets, favorites and Today through them.
//            Every id of tools/frozen_ids.txt must be an exercise or an alias.
// There is no `unlock` (D89): no lift is hidden by class or mode. The app
// puts the lifter's gear first (lib/game/chalk.dart), then the rank; HARD
// and the XP tier come from the score (D91).
//
// COMMON lists the candidate cards in tiers, by judgment of how often the
// exercise is seen in gyms and training programs (tier 1 = in almost every
// program); the order in COMMON (and RANK) is the rank. `--slots` shows the
// pattern slots (D69) per class and mode from the score: the cards a class
// has with a score up to the mode.
// The list keeps every candidate card of COMMON. A
// kept move keeps its variations, but not the ones in OBSCURE and not the
// ones no class can see (equipment `other` or `foam roll`, D50). Exercises with
// `custom: true` (D57, D69) must be kept. Ids do not change (saved sets
// point to them).
import fs from 'node:fs';
import { checkFrozen, composeName, equipShownOf } from './exercise_names.mjs';

// Most common first, by hand (D90 step 3 part B): the order in a tier is
// the rank, not the number of variations, so a new variation never moves a
// card. A name is a move (`base`) or the id of an exercise (then it stands
// for the exercise's move).
const COMMON = [
  // 1: the big lifts, in almost every program.
  [
    'Bench Press', 'Squat', 'Shoulder Press', 'Push-Up', 'Bicep Curl', 'Pull-Up', 'Deadlift', 'Lat Pulldown', 'Crunch',
    'Plank'],
  // 2: in most gym programs.
  [
    'Bent-Over Row', 'Romanian Deadlift', 'One-Arm Row', 'Calf Raise', 'Lunge', 'Lateral Raise', 'Dip',
    'Triceps Pushdown', 'Leg Press', 'Seated Cable Row', 'Leg Curl', 'Leg Extension'],
  // 3: very common.
  [
    'Fly', 'Skullcrusher', 'Overhead Triceps Extension', 'Hammer Curl', 'Preacher Curl', 'Hip Thrust', 'Shrug',
    'Hanging Leg Raise', 'Sit-Up', 'Goblet Squat', 'Face Pull'],
  // 4: common.
  [
    'Reverse Fly', 'Upright Row', 'Chest Press', 'Inverted Row', 'Front Raise', 'Glute Bridge', 'Triceps Kickback',
    'Crossover', 'Step-Up', 'Russian_Twist', 'Hack Squat', 'Back Extension', 'Kettlebell Swing', "Farmer's Walk",
    'Bicycle Crunch', 'Mountain Climber'],
  // 5: a regular in many programs.
  [
    'Split Squat', 'Wrist Curl', 'T-Bar Row', 'Ab Rollout', 'Reverse Crunch', 'Concentration Curl', 'Front Squat',
    'Hip Abduction', 'Hip Adduction', 'Pullover', 'Good Morning', 'Arnold Press', 'Straight-Arm Pulldown',
    'Pike Push-Up', 'Pistol Squat', 'Dead_Bug', 'Side Plank', 'Lying Leg Raise', 'Standing_Cable_Wood_Chop',
    'Band Pull-Apart', 'Burpee', 'Chest-Supported Row'],
  // 6: known and used, less often. (D90 step 2 added the BWF skills Shrimp Squat and Support Hold.)
  [
    'Jump Squat', 'Floor Press', 'Cardio Machine', 'Reverse Curl', 'Rear Delt Row', 'Glute Kickback', 'Side Bend',
    'External Rotation', 'Sumo Deadlift', 'Pallof_Press', 'Oblique Crunch', 'Leg Pull-In', 'Internal Rotation',
    'Nordic Curl', 'Dead Hang', 'Support Hold', 'Box Squat', 'Triceps Extension', 'Rack Pull', 'Pull-Through',
    'Jump Rope', 'Power Clean', 'Kettlebell_Thruster', 'Landmine_Linear_Jammer', 'Muscle_Up', 'High Row',
    'Monster_Walk', 'Handstand Push-Up', 'Scapular Pull-Up', 'Reverse_Hyperextension', 'Jackknife_Sit-Up', 'Ball Slam',
    'Renegade Row', 'Towel Triceps Extension', 'Tuck_Crunch', 'Cross-Body_Crunch', 'Superman', 'Wall_Sit',
    'Hollow_Body_Hold', 'Bird_Dog', 'Prone_Y-T-W_Raise', 'Cossack_Squat', 'Shrimp Squat'],
  // 7: seen now and then.
  [
    'Push Press', 'High Pulley Row', 'Jumping Lunge', 'Long Jump', 'Alternate_Heel_Touchers', 'Ball Pull-In',
    'Medicine_Ball_Chest_Pass', 'JM_Press', 'Tate_Press', 'Spider_Curl', 'Drag_Curl', 'Zottman_Curl',
    'High_Cable_Curls', 'Deficit_Deadlift', 'Kettlebell_Halo', 'Kettlebell_Turkish_Get-Up_Squat_style',
    'Side_Laterals_to_Front_Raise', 'Push-Up to Side Plank', 'Wall_Walk', 'Wall_Handstand_Hold', 'Pogo_Hops', 'L-Sit',
    'Dumbbell Swing', 'Flutter_Kicks', 'Reverse_Snow_Angel', 'Chin-Up_Hold'],
  // 8: rare; here so that the small classes (Scrapper) have enough cards.
  // (D90 step 2 added the owner's skills Back Bridge and Front Lever; no
  // program in the sample uses them.)
  [
    'Running Drill', 'Front Lever', 'Kneeling_Arm_Drill', 'Clock_Push-Up', 'Isometric Chest Squeeze', 'Finger_Curls',
    'Zercher_Squats', 'Cuban_Press', 'Dumbbell_Scaption', 'Doorframe_Curl', 'Calf Raise on a Dumbbell', 'Back Bridge'],
];

// The movement pattern of each candidate card. The slot patterns are in
// SLOTS; the others (raise, fly, ...) only fill the budget.
const PATTERNS = {
  hpush: ['Bench Press', 'Push-Up', 'Chest Press', 'Floor Press', 'Push-Up to Side Plank', 'Clock_Push-Up',
    'Medicine_Ball_Chest_Pass'],
  vpush: ['Shoulder Press', 'Arnold Press', 'Handstand Push-Up', 'Push Press', 'Pike Push-Up', 'Wall_Walk', 'Wall_Handstand_Hold',
    'Kettlebell_Thruster', 'Landmine_Linear_Jammer'],
  hpull: ['Bent-Over Row', 'One-Arm Row', 'Seated Cable Row', 'Inverted Row', 'T-Bar Row', 'Chest-Supported Row', 'High Row',
    'Renegade Row', 'Front Lever'],
  vpull: ['Pull-Up', 'Lat Pulldown', 'Straight-Arm Pulldown', 'Scapular Pull-Up', 'High Pulley Row', 'Muscle_Up'],
  squat: ['Squat', 'Leg Press', 'Leg Extension', 'Goblet Squat', 'Hack Squat', 'Front Squat', 'Box Squat',
    'Zercher_Squats', 'Wall_Sit'],
  hinge: ['Deadlift', 'Romanian Deadlift', 'Hip Thrust', 'Glute Bridge', 'Back Extension',
    'Good Morning', 'Kettlebell Swing', 'Sumo Deadlift', 'Rack Pull', 'Glute Kickback', 'Pull-Through', 'Reverse_Hyperextension',
    'Deficit_Deadlift', 'Superman', 'Dumbbell Swing', 'Back Bridge'],
  single: ['Lunge', 'Step-Up', 'Split Squat', 'Pistol Squat', 'Shrimp Squat'],
  calves: ['Calf Raise', 'Pogo_Hops', 'Calf Raise on a Dumbbell'],
  biceps: ['Bicep Curl', 'Hammer Curl', 'Preacher Curl', 'Concentration Curl', 'Spider_Curl', 'Drag_Curl',
    'Zottman_Curl', 'High_Cable_Curls', 'Chin-Up_Hold', 'Doorframe_Curl'],
  triceps: ['Dip', 'Triceps Pushdown', 'Overhead Triceps Extension', 'Skullcrusher', 'Triceps Kickback', 'Triceps Extension',
    'Towel Triceps Extension', 'JM_Press', 'Tate_Press', 'Support Hold'],
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
  // The jumps are 4 cards (D90 step 2): Jump Squat, Jumping Lunge, Long Jump, Running Drill.
  plyo: ['Mountain Climber', 'Burpee', 'Jump Squat', 'Jumping Lunge', 'Long Jump', 'Running Drill'],
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
  Muscle_Up: 'expert',
  // A barbell lunge is a barbell lunge, walking or not.
  Barbell_Walking_Lunge: 'intermediate',
  // Machines and cables that beginners use.
  Face_Pull: 'beginner', Flat_Bench_Cable_Flyes: 'beginner', Incline_Cable_Flye: 'beginner',
  Ab_Crunch_Machine: 'beginner', Lying_Cable_Curl: 'beginner',
  'Standing_One-Arm_Cable_Curl': 'beginner', 'Seated_One-arm_Cable_Pulley_Rows': 'beginner', 'V-Bar_Pulldown': 'beginner',
  Smith_Machine_Leg_Press: 'beginner', Narrow_Stance_Leg_Press: 'beginner', Kneeling_Cable_Triceps_Extension: 'beginner',
  // Basics that beginners learn: the barbell deadlift (light), the jump rope.
  Barbell_Deadlift: 'beginner', Rope_Jumping: 'beginner',
  // Cardio machines that beginners use.
  Elliptical_Trainer: 'beginner', Rowing_Stationary: 'beginner',
};

const MODES = ['sofa', 'warmup', 'sweat', 'pain', 'brutal', 'nightmare'];
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

const LEVELS = ['beginner', 'intermediate', 'expert'];

// The class gear (D50), for the reports: the same equipment as classEquipment in lib/game/exercises.dart.
const CLASSES = {
  scrapper: [['body only', 'rings'], ['strength', 'plyometrics', 'cardio']],
  bruiser: [['body only', 'dumbbell', 'kettlebells', 'bands', 'ball'], ['strength', 'plyometrics', 'cardio']],
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
  order.push({ name, t, i });
}));
order.sort((a, b) => a.t - b.t || a.i - b.i);
// Ranks set by hand (D90 step 2, after the research on 19 programs): the card
// goes to that place, the others keep their order around it. Push-Up and
// Hip Thrust stay where they were. Pull-Up stays 8 (part B: part A's grid
// had moved it by its number of variations).
const RANK = {
  Squat: 2, 'Push-Up': 4, 'Bent-Over Row': 6, 'Romanian Deadlift': 7, 'Pull-Up': 8, 'One-Arm Row': 12, Fly: 15,
  'Split Squat': 25, 'Hip Thrust': 29,
};
{
  const fixed = Object.entries(RANK).map(([n, r]) => {
    const i = order.findIndex((o) => o.name === n);
    if (i < 0) throw new Error(`RANK: no card ${n}`);
    return [order.splice(i, 1)[0], r];
  });
  for (const [o, r] of fixed.sort((a, b) => a[1] - b[1])) order.splice(r - 1, 0, o);
}
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
// Rings/TRX counts as one modifier more (D90 step 2): a ring lift is the
// bodyweight lift made harder, never the card's first.
const plainness = (e) => Object.keys(e.mods ?? {}).length + (e.mods?.equip === 'Rings' ? 1 : 0);
const simplest = (a, b) => plainness(a) - plainness(b) || a.name.length - b.name.length;

// Every candidate card stays (D70 shows all cards, D72 searches all). There
// is no `unlock` any more (D89): no lift is hidden by class or mode. The app
// orders by the lifter's gear and the rank, and the HARD badge and the XP
// tier come from the score (D91).
const kept = order;
const out = [];
kept.forEach((o, i) => {
  for (const e of byCard.get(o.name)) out.push({ ...e, rank: i + 1, pattern: patternOf.get(o.name) });
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

// The pattern slots (D69) per class (by gear, D50) and mode, from the score
// (D91, replaces `unlock`): a card is in reach of a mode when the class has
// an exercise of it with a score up to the mode (1 Sofa .. 6 Nightmare).
// A report only: nothing is hidden. OK (the target or more), THIN (fewer),
// MISSING (none), - (no target).
const reach = (c, mode) => {
  const keys = new Set(out.filter((e) => e.score <= mode + 1 && inClass(c, e)).map((e) => e.base));
  return kept.filter((o) => keys.has(o.name));
};
const slotCount = (c, mode, s) => reach(c, mode).filter((o) => patternOf.get(o.name) === s).length;
const slotState = (c, mode, s, core) => {
  const n = slotCount(c, mode, s), want = TARGET[core ? 'core' : 'extra'][mode];
  if (!want) return n ? 'OK' : '-';
  return n >= want ? 'OK' : n ? 'THIN' : 'MISSING';
};

if (args.includes('--report')) {
  console.log(`kept ${out.length} of ${all.length} exercises in ${kept.length} cards (${kept.filter((o) => o.n > 1).length} moves)`);
  console.log('top 15:', kept.slice(0, 15).map((o, i) => `${i + 1}. ${o.name} (${byCard.get(o.name).length})`).join(', '));
  console.log('\ncards in reach per class and mode (an exercise of the class gear with score <= mode):');
  for (const c of Object.keys(CLASSES)) {
    console.log(`${c.padEnd(12)}${MODES.map((_, m) => String(reach(c, m).length).padStart(10)).join('')}`);
  }
}
if (args.includes('--slots')) {
  const weak = [];
  for (const c of Object.keys(CLASSES)) {
    console.log(`\n${c.padEnd(12)}${MODES.map((m) => m.padStart(12)).join('')}`);
    for (const [s, name, core] of SLOTS) {
      const cells = MODES.map((_, mode) => {
        const st = slotState(c, mode, s, core);
        if (!['OK', '-'].includes(st)) weak.push(`${c} ${MODES[mode]} ${s}: ${st} (${slotCount(c, mode, s)})`);
        return `${slotCount(c, mode, s)} ${st}`.padStart(12);
      });
      console.log(`${name.padEnd(22).slice(0, 22)}${cells.join('')}`);
    }
  }
  console.log('\nnot OK:', weak.join('; ') || 'none');
  console.log('(target per mode: core', TARGET.core.join(' '), '; extra', TARGET.extra.join(' '), ')');
}
// The difficulty score (D91): every exercise of the app list has one
// (tools/exercise_variants.mjs CARDS and SCORE).
const noScore = [...new Set(out.filter((e) => !Number.isInteger(e.score) || e.score < 1 || e.score > 6).map((e) => e.base))];
if (noScore.length) throw new Error(`no difficulty score (D91; SCORE in exercise_variants.mjs): ${noScore.join(', ')}`);

// Every composed name has all its parts in English and Romanian (D80): the
// move, a part for each value, and the move's form where a part agrees.
const RO = JSON.parse(fs.readFileSync(new URL('../assets/i18n/ro.json', import.meta.url), 'utf8'));
function missingParts(base, mods, equipShown, look) {
  const b = base.toLowerCase(), miss = [];
  if (look(`move.${b}`) == null) miss.push(`move.${b}`);
  const slots = (look('name.order') ?? '').split(' ').filter(Boolean);
  const moveSlot = slots.find((s) => mods[s] != null && look(`name.move.${b}.${mods[s]}`) != null);
  for (const [a, v] of Object.entries(mods)) {
    if (!slots.includes(a)) miss.push(`name.order: ${a}`);
    if (a === moveSlot || (a === 'equip' && !equipShown)) continue;
    const p = look(`name.${b}.${v}`) ?? look(`name.${a}.${v}`) ?? look(`name.${v}`);
    if (p == null) miss.push(`name.${v}`);
    else if (p.includes('|') && look(`name.form.${b}`) == null) miss.push(`name.form.${b}`);
  }
  return miss;
}
const roName = new Map();
{
  const missing = [];
  for (const vs of byCard.values()) {
    const shown = equipShownOf(vs);
    for (const e of vs) {
      if (!outById.has(e.id)) continue;
      for (const [lang, L] of [['en', EN], ['ro', RO]]) {
        if (L[`exercise.${e.id}`] != null) continue;
        for (const k of missingParts(e.base, e.mods, shown, (key) => L[key])) missing.push(`${lang} ${e.id}: ${k}`);
      }
      roName.set(e.id, RO[`exercise.${e.id}`] ?? composeName(e.base, e.mods, shown, (k) => RO[k]));
    }
  }
  if (missing.length) throw new Error(`names without a translated part (D80):\n${missing.join('\n')}`);
  // Names are unique on each card, in each language.
  for (const vs of byCard.values()) {
    for (const [lang, nameOf] of [['en', (e) => e.name], ['ro', (e) => roName.get(e.id)]]) {
      const seen = new Map();
      for (const e of vs.filter((x) => outById.has(x.id))) {
        const n = nameOf(e).toLowerCase();
        if (seen.has(n)) throw new Error(`${lang} name "${n}" twice on ${e.base}: ${seen.get(n)}, ${e.id}`);
        seen.set(n, e.id);
      }
    }
  }
}

// The review file (D90 step 3): every variation that is not a frozen id
// (tools/frozen_ids.txt), per card, with its English and Romanian name and
// its score. Read every new name.
const frozen = new Set(fs.readFileSync(new URL('frozen_ids.txt', import.meta.url), 'utf8').split('\n').map((l) => l.trim()).filter(Boolean));
const fresh = out.filter((e) => !frozen.has(e.id));
const review = ['# New variations (review)', '',
  'Every exercise of the app list that is not a frozen id (tools/frozen_ids.txt). Made by',
  '`node tools/exercise_select.mjs`. Read every name in both languages.', '',
  `${fresh.length} new variations in ${new Set(fresh.map((e) => e.base)).size} cards.`, ''];
for (const o of kept) {
  const vs = fresh.filter((e) => e.base === o.name);
  if (!vs.length) continue;
  review.push(`## ${o.name} (${vs.length} new, ${byCard.get(o.name).filter((e) => outById.has(e.id)).length} in the card)`, '',
    '| id | en | ro | score |', '|---|---|---|---|');
  for (const e of vs.sort((a, b) => a.score - b.score || a.name.localeCompare(b.name))) {
    review.push(`| \`${e.id}\` | ${e.name} | ${roName.get(e.id)} | ${e.score} |`);
  }
  review.push('');
}

// The score curve (D91) per class (by gear) and per class and body part,
// against the bell-curve target. A class is far off when the shares differ
// from the target by more than FAR points in all (half the sum of the
// differences). The curve is a target, not a quota.
const CURVE = [7, 16, 27, 27, 16, 7];
const FAR = 20;
const shares = (es) => {
  const n = [0, 0, 0, 0, 0, 0];
  for (const e of es) n[e.score - 1]++;
  return n.map((x) => (es.length ? Math.round((100 * x) / es.length) : 0));
};
const offBy = (s) => Math.round(s.reduce((a, x, i) => a + Math.abs(x - CURVE[i]), 0) / 2);
const curve = ['# Difficulty score curve (D91)', '',
  `Share of exercises per score 1-6, in %. Target: ${CURVE.join(' / ')}. A class is far off when it differs by more than ${FAR} points.`,
  'The curve is a target, not a quota: score each lift honestly.', '',
  '| class | n | 1 | 2 | 3 | 4 | 5 | 6 | off by |', '|---|---|---|---|---|---|---|---|---|',
  `| target | | ${CURVE.join(' | ')} | |`];
// Hard lifts (score 5-6) the list does not have, per class gear: the warning
// names them, to choose what to add later (D91: add hard lifts, never score
// easy lifts higher). Not added in D90 step 3 (only the Negative Pull-Up).
const HARD_MISSING = {
  scrapper: ['archer pull-up', 'one-arm pull-up', 'tuck planche', 'dragon flag', 'freestanding handstand push-up',
    'skin the cat', 'archer squat'],
  // No olympic lifts but the Power Clean (D56).
  bruiser: ['kettlebell windmill', 'dumbbell Turkish get-up', 'weighted Cossack squat', 'dumbbell overhead squat'],
  paladin: ['overhead squat', 'Jefferson curl', 'standing barbell rollout', 'barbell Cossack squat'],
  cablemancer: ['none honest: machine and cable lifts stay easy (D91); the hard end is the bodyweight skills'],
};
const warnings = [];
for (const c of Object.keys(CLASSES)) {
  const es = out.filter((e) => inClass(c, e));
  const s = shares(es), off = offBy(s);
  curve.push(`| ${c} | ${es.length} | ${s.join(' | ')} | ${off}${off > FAR ? ' FAR' : ''} |`);
  if (off > FAR) {
    const noHard = Object.keys(PARTS).filter((p) => !es.some((e) => e.score >= 5 && partOf(e.primaryMuscles[0]) === p));
    warnings.push(`${c} is far from the target (off by ${off} points): ${s.join(' / ')}. `
      + (noHard.length ? `No hard lift (score 5-6) for: ${noHard.join(', ')}. ` : '')
      + `Hard lifts to add later: ${HARD_MISSING[c].join('; ')}`);
  }
}
curve.push('', '## Per class and body part', '', '| class | part | n | 1 | 2 | 3 | 4 | 5 | 6 | off by |', '|---|---|---|---|---|---|---|---|---|---|');
for (const c of Object.keys(CLASSES)) {
  for (const p of Object.keys(PARTS)) {
    const es = out.filter((e) => inClass(c, e) && partOf(e.primaryMuscles[0]) === p);
    const s = shares(es), off = offBy(s);
    curve.push(`| ${c} | ${p} | ${es.length} | ${s.join(' | ')} | ${off}${off > FAR ? ' FAR' : ''} |`);
  }
}
curve.push('', '## Warnings', '', ...(warnings.length ? warnings.map((w) => `- ${w}`) : ['none']), '');
if (args.includes('--report')) {
  console.log('\nscore curve (D91), % per score 1-6; target', CURVE.join(' / '));
  for (const c of Object.keys(CLASSES)) {
    const es = out.filter((e) => inClass(c, e));
    console.log(`${c.padEnd(12)}${shares(es).map((x) => String(x).padStart(4)).join('')}   off by ${offBy(shares(es))}`);
    for (const p of Object.keys(PARTS)) {
      const ps = es.filter((e) => partOf(e.primaryMuscles[0]) === p);
      console.log(`  ${p.padEnd(10)}${shares(ps).map((x) => String(x).padStart(4)).join('')}   off by ${offBy(shares(ps))} (n ${ps.length})`);
    }
  }
  console.log(`new variations (not frozen): ${fresh.length}`);
}
for (const w of warnings) console.warn(`WARNING score curve: ${w}`);

const outPath = args.slice(1).find((a) => !a.startsWith('--'));
if (outPath) {
  fs.writeFileSync(new URL('grid_review.md', import.meta.url), review.join('\n'));
  fs.writeFileSync(new URL('score_report.md', import.meta.url), curve.join('\n'));
  fs.writeFileSync(outPath, '[\n' + out.map((r) => JSON.stringify(r)).join(',\n') + '\n]\n');
  // The move names, one per card, for the translator (D68: `move.<base>`).
  const moves = [...new Set(out.map((r) => r.base))].sort((a, b) => a.localeCompare(b));
  fs.writeFileSync(new URL('move_names.txt', import.meta.url), moves.join('\n') + '\n');
  console.log('written', out.length, 'and', moves.length, 'move names');
}
