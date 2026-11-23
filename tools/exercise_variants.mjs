// Splits each exercise name into a base move and normalized modifiers (D55)
// and writes them into assets/exercises/exercises.json. Run it again after
// editing the list: node tools/exercise_variants.mjs <in.json> --write <out.json> [--report]
// The full list is tools/exercise_db.json; tools/exercise_select.mjs then cuts
// it down into assets/exercises/exercises.json (D67).
import fs from 'node:fs';

const args = process.argv.slice(2);
const all = JSON.parse(fs.readFileSync(args[0], 'utf8'));

// Each axis: [label, regex]. Axis order matters (stance before width).
const AXES = {
  stance: [
    ['Narrow Stance', /\bnarrow[- ]stance\b/i],
    ['Wide Stance', /\bwide[- ]stance\b/i],
  ],
  angle: [
    ['Incline', /\bincline\b/i],
    ['Decline', /\bdecline\b/i],
  ],
  width: [
    ['Close Grip', /\b(close|narrow)[- ]grip\b|\bclose triceps position\b/i],
    ['Medium Grip', /\bmedium[- ]grip\b|\bmedium\b/i],
    ['Wide Grip', /\bwide[- ]grip\b|\bwide\b/i],
  ],
  hand: [
    ['Reverse Grip', /\breverse[- ]grip\b|\bunderhand\b|\bpalms?[- ]up\b|\bsupinated\b/i],
    ['Neutral Grip', /\bneutral[- ]grip\b|\bwith palms[- ]in\b|\bpalms?[- ]in\b|\bhammer[- ]grip\b/i],
    ['Overhand Grip', /\boverhand\b|\bpalms?[- ]down\b|\bpronated\b/i],
    ['Mixed Grip', /\bmixed[- ]grip\b/i],
  ],
  side: [
    ['One Arm', /\b(one|single)[- ]arm(ed)?\b/i],
    ['One Leg', /\b(one|single)[- ]leg(ged)?\b/i],
    ['Alternating', /\balternat(e|ing)\b/i],
    ['Two Arms', /\bdouble\b|\btwo[- ]arms?\b/i],
  ],
  position: [
    ['Standing', /\bstanding\b/i],
    ['Seated', /\bseated\b/i],
    ['Lying', /\blying\b/i],
    ['Kneeling', /\bkneeling\b/i],
  ],
  attach: [
    ['Rope', /\brope attachment\b/i],
    ['V-Bar', /\bv-bar attachment\b/i],
  ],
  bands: [
    ['Band Assisted', /\bband assisted\b/i],
    ['Reverse Bands', /\breverse bands?\b/i],
    ['Bands', /\bwith bands?\b|\bbands?\b/i],
  ],
  chains: [
    ['Chains', /\bwith chains\b|\bchains?\b/i],
  ],
};

// Equipment words in names (the equipment row comes from the data).
const EQUIP_WORDS = /\b(two[- ]dumbbells?|flat bench|flat|barbell|dumbbells?|kettlebells?|cable|smith machine|machine|ez[- ]bar|e-z bar|leverage|bodyweight|db)\b/gi;

// Plural and spelling forms -> one form.
const NORMAL = [
  [/\bpush[- ]?ups?\b/gi, 'Push-Up'], [/\bpull[- ]?ups?\b/gi, 'Pull-Up'], [/\bchin[- ]?ups?\b/gi, 'Chin-Up'],
  [/\bsit[- ]?ups?\b/gi, 'Sit-Up'], [/\bstep[- ]?ups?\b/gi, 'Step-Up'],
  [/\bcurls\b/gi, 'Curl'], [/\brows\b/gi, 'Row'], [/\bsquats\b/gi, 'Squat'], [/\bfly(e|es)?\b|\bflies\b/gi, 'Fly'],
  [/\braises\b/gi, 'Raise'], [/\blunges\b/gi, 'Lunge'], [/\bdips\b/gi, 'Dip'], [/\bcrunches\b/gi, 'Crunch'],
  [/\bextensions\b/gi, 'Extension'], [/\bpresses\b/gi, 'Press'], [/\bdeadlifts\b/gi, 'Deadlift'], [/\bshrugs\b/gi, 'Shrug'],
  [/\bkickbacks\b/gi, 'Kickback'], [/\bswings\b/gi, 'Swing'], [/\bthrusters\b/gi, 'Thruster'], [/\bpulldowns\b/gi, 'Pulldown'],
  [/\bskull ?crushers?\b/gi, 'Skullcrusher'], [/\bgood mornings\b/gi, 'Good Morning'], [/\bhyperextensions\b/gi, 'Hyperextension'],
  [/\btriceps?\b/gi, 'Triceps'], [/\bbiceps?\b/gi, 'Bicep'], [/\bcross over\b/gi, 'Crossover'],
];

// Exercises that belong to another move than their name says.
const OVERRIDE = {
  'Incline Dumbbell Press': 'Bench Press', 'Smith Machine Decline Press': 'Bench Press',
  'Close-Grip EZ-Bar Press': 'Bench Press', 'Seated Cable Rows': 'Seated Cable Row',
};
// Exercises whose names the parser cannot split: move name and modifiers by hand.
const EXPLICIT = {
  'Dips - Chest Version': ['Dip', { type: 'Chest' }],
  'Dips - Triceps Version': ['Dip', { type: 'Triceps' }],
  'Bench Dips': ['Dip', { type: 'Bench' }],
  'Weighted Bench Dip': ['Dip', { type: 'Weighted Bench' }],
  'Parallel Bar Dip': ['Dip', { type: 'Parallel Bar' }],
  'Ring Dips': ['Dip', { type: 'Rings' }],
  'Dip Machine': ['Dip', {}],
  // Dumbbells have no grip width: pressed together, it is a squeeze press.
  'Close-Grip Dumbbell Press': ['Bench Press', { type: 'Squeeze' }],
};

// Database fields that are wrong for the move (D57).
const FIX = {
  'Bench Press - With Bands': { equipment: 'barbell' }, // a barbell bench press with bands
};

// Exercises the database lacks but a gym has (D57, D69): [id, name, fields,
// move, modifiers]. Fields: the id of an exercise to copy them from, or a
// bodyweight exercise as [category, level, force, mechanic, muscle].
const bw = (category, level, force, mechanic, muscle) => ({
  category, equipment: 'body only', level, force, mechanic, primaryMuscles: [muscle],
});
const EXTRA = [
  ['Incline_Close-Grip_Barbell_Bench_Press', 'Incline Close-Grip Barbell Bench Press', 'Barbell_Incline_Bench_Press_-_Medium_Grip',
    'Bench Press', { angle: 'Incline', width: 'Close Grip' }],
  ['Incline_Wide-Grip_Barbell_Bench_Press', 'Incline Wide-Grip Barbell Bench Press', 'Barbell_Incline_Bench_Press_-_Medium_Grip',
    'Bench Press', { angle: 'Incline', width: 'Wide Grip' }],
  ['Decline_Close-Grip_Barbell_Bench_Press', 'Decline Close-Grip Barbell Bench Press', 'Decline_Barbell_Bench_Press',
    'Bench Press', { angle: 'Decline', width: 'Close Grip' }],
  // Bodyweight exercises for the Scrapper (D69). The database has no
  // copies of them (side plank = Side_Bridge, nordic curl =
  // Natural_Glute_Ham_Raise, australian pull-up = Inverted_Row).
  ['Pike_Push-Up', 'Pike Push-Up', bw('strength', 'beginner', 'push', 'compound', 'shoulders'), 'Pike Push-Up', {}],
  ['Elevated_Pike_Push-Up', 'Elevated Pike Push-Up', bw('strength', 'intermediate', 'push', 'compound', 'shoulders'),
    'Pike Push-Up', { type: 'Elevated' }],
  ['Wall_Walk', 'Wall Walk', bw('strength', 'intermediate', 'push', 'compound', 'shoulders'), 'Wall Walk', {}],
  ['Wall_Handstand_Hold', 'Wall Handstand Hold', bw('strength', 'intermediate', 'static', 'compound', 'shoulders'),
    'Wall Handstand Hold', {}],
  ['Prone_Y-T-W_Raise', 'Prone Y-T-W Raise', bw('strength', 'beginner', 'pull', 'isolation', 'shoulders'), 'Prone Y-T-W Raise', {}],
  ['Bodyweight_Calf_Raise', 'Bodyweight Calf Raise', bw('strength', 'beginner', 'push', 'isolation', 'calves'), 'Calf Raise', {}],
  ['Single-Leg_Calf_Raise', 'Single-Leg Calf Raise', bw('strength', 'intermediate', 'push', 'isolation', 'calves'),
    'Calf Raise', { side: 'One Leg' }],
  ['Pogo_Hops', 'Pogo Hops', bw('plyometrics', 'beginner', 'push', 'compound', 'calves'), 'Pogo Hops', {}],
  ['Towel_Bicep_Curl', 'Towel Bicep Curl', bw('strength', 'beginner', 'pull', 'isolation', 'biceps'), 'Bicep Curl', { type: 'Towel' }],
  ['Inverted_Bicep_Curl', 'Inverted Bicep Curl', bw('strength', 'intermediate', 'pull', 'isolation', 'biceps'),
    'Bicep Curl', { type: 'Inverted' }],
  ['Dead_Hang', 'Dead Hang', bw('strength', 'beginner', 'static', 'isolation', 'forearms'), 'Dead Hang', {}],
  ['Towel_Hang', 'Towel Hang', bw('strength', 'intermediate', 'static', 'isolation', 'forearms'), 'Dead Hang', { type: 'Towel' }],
  ['Superman', 'Superman', bw('strength', 'beginner', 'static', 'isolation', 'lower back'), 'Superman', {}],
  ['Bodyweight_Bulgarian_Split_Squat', 'Bodyweight Bulgarian Split Squat', bw('strength', 'intermediate', 'push', 'compound', 'quadriceps'),
    'Bodyweight Bulgarian Split Squat', {}],
  ['Pistol_Squat', 'Pistol Squat', bw('strength', 'expert', 'push', 'compound', 'quadriceps'), 'Pistol Squat', {}],
  ['Wall_Sit', 'Wall Sit', bw('strength', 'beginner', 'static', 'compound', 'quadriceps'), 'Wall Sit', {}],
  ['Cossack_Squat', 'Cossack Squat', bw('strength', 'intermediate', 'push', 'compound', 'adductors'), 'Cossack Squat', {}],
  ['Reverse_Lunge', 'Reverse Lunge', bw('strength', 'beginner', 'push', 'compound', 'quadriceps'), 'Lunge', { type: 'Reverse' }],
  ['Hollow_Body_Hold', 'Hollow Body Hold', bw('strength', 'beginner', 'static', 'compound', 'abdominals'), 'Hollow Body Hold', {}],
  ['Bird_Dog', 'Bird Dog', bw('strength', 'beginner', 'static', 'compound', 'abdominals'), 'Bird Dog', {}],
  ['L-Sit', 'L-Sit', bw('strength', 'expert', 'static', 'compound', 'abdominals'), 'L-Sit', {}],
  ['Hanging_Knee_Raise', 'Hanging Knee Raise', bw('strength', 'beginner', 'pull', 'isolation', 'abdominals'),
    'Hanging Leg Raise', { type: 'Knee' }],
  ['Burpee', 'Burpee', bw('plyometrics', 'intermediate', 'push', 'compound', 'quadriceps'), 'Burpee', {}],
  // More bodyweight cards for the thin Scrapper slots (D69): horizontal
  // pull, biceps and rear delt. Each one is its own card, so the slot has
  // two cards or more from Sweat on.
  ['Towel_Row', 'Towel Row', bw('strength', 'beginner', 'pull', 'compound', 'middle back'), 'Towel Row', {}],
  ['Feet-Elevated_Inverted_Row', 'Feet-Elevated Inverted Row', bw('strength', 'intermediate', 'pull', 'compound', 'middle back'),
    'Feet-Elevated Inverted Row', {}],
  ['One-Arm_Inverted_Row', 'One-Arm Inverted Row', bw('strength', 'expert', 'pull', 'compound', 'middle back'),
    'One-Arm Inverted Row', {}],
  ['Chin-Up_Hold', 'Chin-Up Hold', bw('strength', 'beginner', 'static', 'isolation', 'biceps'), 'Chin-Up Hold', {}],
  ['Doorframe_Curl', 'Doorframe Curl', bw('strength', 'beginner', 'pull', 'isolation', 'biceps'), 'Doorframe Curl', {}],
  ['Reverse_Snow_Angel', 'Reverse Snow Angel', bw('strength', 'beginner', 'pull', 'isolation', 'shoulders'), 'Reverse Snow Angel', {}],
  ['Bodyweight_Rear_Delt_Row', 'Bodyweight Rear Delt Row', bw('strength', 'intermediate', 'pull', 'compound', 'shoulders'),
    'Bodyweight Rear Delt Row', {}],
];
for (const [id, name, from, base, mods] of EXTRA) {
  EXPLICIT[name] = [base, mods];
  if (all.some((e) => e.id === id)) continue;
  let fields = from;
  if (typeof from === 'string') {
    const src = all.find((e) => e.id === from);
    if (!src) throw new Error(`EXTRA ${id}: no source ${from}`);
    const { id: _i, name: _n, base: _b, mods: _m, ...f } = src;
    fields = f;
  }
  all.push({ id, name, ...fields, custom: true });
}

// Grip width exists for bars, cables, machines and the body; not for
// dumbbells or kettlebells. Where a move has a width row, no width means
// Medium Grip (D57).
const WIDTH_EQUIP = new Set(['Barbell', 'EZ Bar', 'Smith Machine', 'Machine', 'Cable', 'Bodyweight']);
// Whole groups that are the same move.
const MERGE = {
  'press': 'Shoulder Press', 'military press': 'Shoulder Press', 'curl': 'Bicep Curl', 'wrist curl over a bench': 'Wrist Curl',
  'side lateral raise': 'Lateral Raise', 'front lat pulldown': 'Lat Pulldown', 'glute': 'Glute Stretch', 'hamstring': 'Hamstring Stretch',
  'power squat': 'Squat', 'back fly': 'Reverse Fly', 'hamstring curl': 'Leg Curl', 'weighted sit-up': 'Sit-Up',
};
const EQUIP_LABEL = {
  'body only': 'Bodyweight', barbell: 'Barbell', dumbbell: 'Dumbbell', kettlebells: 'Kettlebell', cable: 'Cable', machine: 'Machine',
  bands: 'Bands', 'e-z curl bar': 'EZ Bar', 'medicine ball': 'Medicine Ball', 'exercise ball': 'Exercise Ball', 'foam roll': 'Foam Roll',
  other: 'Other',
};
function equipLabel(e) {
  if (/smith machine/i.test(e.name)) return 'Smith Machine';
  if (/\bez[- ]bar\b|e-z bar/i.test(e.name)) return 'EZ Bar';
  return EQUIP_LABEL[e.equipment ?? 'body only'] ?? 'Other';
}

const cap = (w) => (w ? w[0].toUpperCase() + w.slice(1).toLowerCase() : w);
const SMALL = new Set(['a', 'an', 'and', 'of', 'on', 'the', 'to', 'with', 'in', 'off', 'from', 'over']);
const title = (s) => s.replace(/\s+/g, ' ').trim().split(' ')
  .map((w, i) => (i > 0 && SMALL.has(w.toLowerCase()) ? w.toLowerCase()
    : w.includes('-') ? w.split('-').map(cap).join('-') : cap(w)))
  .join(' ');

function parse(name) {
  let rest = ` ${name} `;
  const mods = {};
  for (const [axis, list] of Object.entries(AXES)) {
    for (const [label, re] of list) {
      if (re.test(rest)) {
        mods[axis] = label;
        rest = rest.replace(new RegExp(re.source, 'gi'), ' ');
        break;
      }
    }
  }
  rest = rest.replace(EQUIP_WORDS, ' ');
  for (const [re, to] of NORMAL) rest = rest.replace(re, to);
  rest = rest.replace(/\(\s*\)/g, ' ').replace(/\s-\s/g, ' ').replace(/^\s*-|-\s*$/g, ' ')
    .replace(/\b(on|with|from)\s*$/i, ' ').replace(/\s+/g, ' ').trim();
  return { base: title(rest || name), mods };
}

// Old base and mods fields are dropped first, so the tool can run on its own output.
const rows = all.map(({ base: _oldBase, mods: _oldMods, ...raw }) => {
  const e = { ...raw, ...FIX[raw.name] };
  const p = EXPLICIT[e.name] ? { base: EXPLICIT[e.name][0], mods: { ...EXPLICIT[e.name][1] } } : parse(e.name);
  let base = OVERRIDE[e.name] ?? p.base;
  base = MERGE[base.toLowerCase()] ?? base;
  const mods = { equip: equipLabel(e), ...p.mods };
  if (mods.bands === 'Bands' && mods.equip === 'Bands') delete mods.bands;
  if (!WIDTH_EQUIP.has(mods.equip)) delete mods.width;
  return { e, base, mods };
});

const groups = new Map();
for (const r of rows) {
  const k = r.base.toLowerCase();
  if (!groups.has(k)) groups.set(k, []);
  groups.get(k).push(r);
}
for (const g of groups.values()) {
  const withWidth = new Set(g.filter((r) => r.mods.width).map((r) => r.mods.equip));
  for (const r of g) if (!r.mods.width && withWidth.has(r.mods.equip)) r.mods.width = 'Medium Grip';
}
const AX = ['equip', 'type', ...Object.keys(AXES)];
const keyOf = (r) => AX.map((a) => r.mods[a] ?? '').join('|');
// Two exercises with the same modifiers in one group: the shorter name
// stays, the other becomes its own move.
const clashes = [];
for (const g of [...groups.values()]) {
  const seen = new Map();
  for (const r of [...g].sort((a, b) => a.e.name.length - b.e.name.length)) {
    if (seen.has(keyOf(r))) {
      clashes.push(`${r.e.name} (same as ${seen.get(keyOf(r)).e.name})`);
      g.splice(g.indexOf(r), 1);
      r.base = r.e.name;
      groups.set(r.e.name.toLowerCase(), [r]);
    } else seen.set(keyOf(r), r);
  }
}
const multi = [...groups.values()].filter((g) => g.length > 1);
const inGroup = new Set(multi.flat());

if (args.includes('--report')) {
  console.log('groups with variations:', multi.length, 'exercises in them:', inGroup.size, 'split off:', clashes.length);
  console.log('split off:', clashes.join(' ; '));
  for (const g of multi.sort((a, b) => b.length - a.length)) {
    console.log(`${g[0].base} (${g.length}): ` + g.map((r) => `${r.e.name} [${AX.map((a) => r.mods[a]).filter(Boolean).join(', ')}]`).join(' ; '));
  }
}
const wi = args.indexOf('--write');
if (wi >= 0) {
  const out = rows.map((r) => (inGroup.has(r) ? { ...r.e, base: r.base, mods: r.mods } : r.e));
  fs.writeFileSync(args[wi + 1], '[\n' + out.map((r) => JSON.stringify(r)).join(',\n') + '\n]\n');
  console.log('written', out.length, 'in groups:', inGroup.size);
}
