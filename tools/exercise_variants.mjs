// Splits each exercise name into a base move and normalized modifiers (D55)
// and writes them into assets/exercises/exercises.json. Run it again after
// editing the list: node tools/exercise_variants.mjs <in.json> --write <out.json> [--report]
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
  'Incline Dumbbell Press': 'Bench Press', 'Close-Grip Dumbbell Press': 'Bench Press', 'Smith Machine Decline Press': 'Bench Press',
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
};
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
const rows = all.map(({ base: _oldBase, mods: _oldMods, ...e }) => {
  const p = EXPLICIT[e.name] ? { base: EXPLICIT[e.name][0], mods: EXPLICIT[e.name][1] } : parse(e.name);
  let base = OVERRIDE[e.name] ?? p.base;
  base = MERGE[base.toLowerCase()] ?? base;
  const mods = { equip: equipLabel(e), ...p.mods };
  if (mods.bands === 'Bands' && mods.equip === 'Bands') delete mods.bands;
  return { e, base, mods };
});

const groups = new Map();
for (const r of rows) {
  const k = r.base.toLowerCase();
  if (!groups.has(k)) groups.set(k, []);
  groups.get(k).push(r);
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
