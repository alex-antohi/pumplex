// Splits each exercise name into a base move and normalized modifiers (D55)
// and writes them into assets/exercises/exercises.json. Run it again after
// editing the list: node tools/exercise_variants.mjs <in.json> --write <out.json> [--report]
// The full list is tools/exercise_db.json; tools/exercise_select.mjs then cuts
// it down into assets/exercises/exercises.json (D67).
import fs from 'node:fs';
import { AXIS_ORDER, checkFrozen, variationId } from './exercise_names.mjs';

const args = process.argv.slice(2);
// The grid variations (D80, `grid: true`) are made again on every run.
const all = JSON.parse(fs.readFileSync(args[0], 'utf8')).filter((e) => !e.grid);

// Merged and removed exercises (D90 step 1): old id -> the id that replaces
// it. The old row stays in the full list with `alias` (no move, no
// modifiers); tools/exercise_select.mjs leaves it out of the app list and
// writes the old id into the `aliases` of the kept exercise, so saved sets,
// favorites and Today still find it (lib/game/exercises.dart resolveId).
const ALIAS = {
  // The same lift under two names.
  'Standing_Bent-Over_Two-Arm_Dumbbell_Triceps_Extension': 'Tricep_Dumbbell_Kickback', // a kickback
  Lying_Triceps_Press: 'EZ-Bar_Skullcrusher', // a lying EZ bar triceps extension
  Parallel_Bar_Dip: 'Dips_-_Triceps_Version', // the upright dip on parallel bars
  'Floor_Glute-Ham_Raise': 'Natural_Glute_Ham_Raise', // both: kneel, feet held, lower the body
  'Full_Range-Of-Motion_Lat_Pulldown': 'lat pulldown|cable|medium grip', // a lat pulldown
  'Close-Grip_Push-Up_off_of_a_Dumbbell': 'Push-Ups_-_Close_Triceps_Position', // a close-grip push-up
  'Bent-Knee_Hip_Raise': 'Reverse_Crunch', // lying, knees bent, hips curl up
  Scissors_Jump: 'Split_Jump', // a jumping lunge with a leg switch
  Rope_Crunch: 'Cable_Crunch', // the kneeling cable crunch uses the rope too
  // Olympic lifts (D56): only the Power Clean stays (the owner's choice, 23 Nov 2026).
  Dumbbell_Clean: 'Power_Clean',
  'One-Arm_Kettlebell_Clean': 'Power_Clean',
  'Two-Arm_Kettlebell_Clean': 'Power_Clean',
  Clean_and_Press: 'Barbell_Push_Press',
  Kettlebell_Sumo_High_Pull: 'sumo deadlift|kettlebell',
  // D90 step 2: Bands and Chains stay only on Bench Press, Squat and
  // Deadlift. The other powerlifting band and chain rows go to their plain lift.
  Box_Squat_with_Bands: 'Box_Squat',
  Box_Squat_with_Chains: 'Box_Squat',
  Floor_Press_with_Chains: 'Floor_Press',
  Rack_Pull_with_Bands: 'Rack_Pulls',
  Sumo_Deadlift_with_Bands: 'Sumo_Deadlift',
  Sumo_Deadlift_with_Chains: 'Sumo_Deadlift',
  // The owner's delete ticks of 22 Nov 2026 (D90 step 3 part B): rows still
  // in the app list go to the closest kept lift. A card's plain lift and the
  // rows a later decision keeps stay (docs/exercise-list-plan.md).
  'V-Bar_Pullup': 'Pullups', // a pull-up with a V handle over the bar
  Hyperextensions_With_No_Hyperextension_Bench: 'Hyperextensions_Back_Extensions', // a floor back extension
};

// Old ids of grid variations (D80) that a new modifier value renamed (D90
// step 2): old id -> the id that replaces it. The tool writes each as an
// alias row (`grid: true`, so it is made again on every run).
const GRID_ALIAS = {
  // The two balls are one tool, Ball.
  'russian twist|medicine ball': 'russian twist|ball',
};

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
// The axes split out of `type` (D90 step 1): `load` (Weighted, Band
// Assisted) and `setup` (the station or extra gear: a bench, rings, a
// towel, a trap bar, a plate-loaded machine, a cardio machine ...). `type`
// keeps only the ways of doing the move (Knee, Plyo, Walking, Bulgarian ...).
const EXPLICIT = {
  'Dips - Chest Version': ['Dip', { type: 'Chest' }],
  'Dips - Triceps Version': ['Dip', {}], // the standard dip (upright, parallel bars)
  'Bench Dips': ['Dip', { setup: 'Bench' }],
  'Weighted Bench Dip': ['Dip', { setup: 'Bench', load: 'Weighted' }],
  'Ring Dips': ['Dip', {}], // the Rings/TRX tool (D90 step 2), no longer a setup
  'Dip Machine': ['Dip', {}],
  // Dumbbells have no grip width: pressed together, it is a squeeze press.
  'Close-Grip Dumbbell Press': ['Bench Press', { type: 'Squeeze' }],
};

// Database fields that are wrong for the move (D57). The key is a name or an id.
const FIX = {
  'Bench Press - With Bands': { equipment: 'barbell' }, // a barbell bench press with bands
  'Rope Jumping': { equipment: 'body only' }, // a jump rope is cheap home gear (D69 clean-up)
  // Gear `other` that is body only (D50): dip bars, a pull-up bar,
  // an ab wheel, a captain's chair, a box. All other `other` gear stays hidden.
  // Rings are their own tool since D90 step 2 (equipment `rings`).
  'Dips_-_Chest_Version': { equipment: 'body only' }, Parallel_Bar_Dip: { equipment: 'body only' },
  Ring_Dips: { equipment: 'rings' }, Weighted_Bench_Dip: { equipment: 'body only' },
  'Band_Assisted_Pull-Up': { equipment: 'body only' }, Weighted_Pull_Ups: { equipment: 'body only' },
  Ab_Roller: { equipment: 'body only' }, Knee_Hip_Raise_On_Parallel_Bars: { equipment: 'body only' },
  Muscle_Up: { equipment: 'body only' }, Front_Box_Jump: { equipment: 'body only' },
  // A trap bar is a barbell; a back extension bench is gym gear (a machine).
  Trap_Bar_Deadlift: { equipment: 'barbell' }, Hyperextensions_Back_Extensions: { equipment: 'machine' },
  One_Arm_Floor_Press: { equipment: 'dumbbell' }, Cable_Hip_Adduction: { primaryMuscles: ['adductors'] },
  Glute_Ham_Raise: { category: 'strength' }, // a glute-ham bench is gym gear, not only powerlifting
};

// The clean-up of the list (D69): the move (`base`) of an exercise, by id,
// where the name does not give a clean gym name or the right move. A
// string: the move, the modifiers come from the name. An array: the move
// and all its modifiers but the equipment (the name is not used).
const MOVE = {
  // Bench Press is barbell, dumbbell and Smith; a machine is a Chest Press.
  // A "Leverage" machine is plate-loaded; it is its own Type where a plain
  // machine has the same angle (Setup row).
  Machine_Bench_Press: ['Chest Press', {}],
  Leverage_Chest_Press: ['Chest Press', { setup: 'Plate-Loaded' }],
  Leverage_Decline_Chest_Press: ['Chest Press', { angle: 'Decline' }],
  Leverage_Incline_Chest_Press: ['Chest Press', { angle: 'Incline' }],
  Machine_Shoulder_Military_Press: ['Shoulder Press', {}],
  Leverage_Shoulder_Press: ['Shoulder Press', { setup: 'Plate-Loaded' }],
  Smith_Machine_Overhead_Shoulder_Press: ['Shoulder Press', {}],
  // Rows: the ways a lifter names them.
  Bent_Over_Barbell_Row: ['Bent-Over Row', {}],
  'Bent_Over_Two-Dumbbell_Row': ['Bent-Over Row', {}],
  'Bent_Over_Two-Dumbbell_Row_With_Palms_In': ['Bent-Over Row', { hand: 'Neutral Grip' }],
  Smith_Machine_Bent_Over_Row: ['Bent-Over Row', {}],
  'Two-Arm_Kettlebell_Row': ['Bent-Over Row', {}],
  Alternating_Kettlebell_Row: ['Bent-Over Row', { side: 'Alternating' }],
  'One-Arm_Dumbbell_Row': ['One-Arm Row', {}],
  'One-Arm_Kettlebell_Row': ['One-Arm Row', {}],
  Dumbbell_Incline_Row: ['Chest-Supported Row', {}],
  Seated_Cable_Rows: ['Seated Cable Row', {}],
  'Seated_One-arm_Cable_Pulley_Rows': ['Seated Cable Row', { side: 'One Arm' }],
  'T-Bar_Row_with_Handle': ['T-Bar Row', { attach: 'V-Bar' }],
  'Bent_Over_Two-Arm_Long_Bar_Row': ['T-Bar Row', {}],
  'Bent_Over_One-Arm_Long_Bar_Row': ['T-Bar Row', { side: 'One Arm' }],
  'Lying_T-Bar_Row': ['T-Bar Row', { position: 'Lying' }],
  Leverage_High_Row: ['High Row', {}],
  Alternating_Renegade_Row: ['Renegade Row', {}],
  Inverted_Row: ['Inverted Row', {}],
  // The inverted row family is one card (variation audit); the custom
  // rows are in EXTRA.
  Barbell_Rear_Delt_Row: ['Rear Delt Row', {}],
  Bodyweight_Rear_Delt_Row: ['Rear Delt Row', {}],
  'Cable_Rope_Rear-Delt_Rows': ['Rear Delt Row', { attach: 'Rope' }],
  // Vertical pulls: pulldown and pull-up grips are chips.
  'V-Bar_Pulldown': ['Lat Pulldown', { attach: 'V-Bar' }],
  Underhand_Cable_Pulldowns: ['Lat Pulldown', { hand: 'Reverse Grip' }],
  'Wide-Grip_Rear_Pull-Up': ['Pull-Up', { width: 'Wide Grip' }],
  Pullups: ['Pull-Up', {}],
  'Chin-Up': ['Pull-Up', { hand: 'Reverse Grip' }],
  // Band Assisted and Weighted are one Load row (D80: never both).
  'Band_Assisted_Pull-Up': ['Pull-Up', { load: 'Band Assisted' }],
  Weighted_Pull_Ups: ['Pull-Up', { load: 'Weighted' }],
  Muscle_Up: ['Muscle-Up', {}],
  'Straight-Arm_Pulldown': ['Straight-Arm Pulldown', {}],
  'Rope_Straight-Arm_Pulldown': ['Straight-Arm Pulldown', { attach: 'Rope' }],
  'Scapular_Pull-Up': ['Scapular Pull-Up', {}],
  // Triceps: lying extensions are Skullcrushers, overhead ones their own move.
  'EZ-Bar_Skullcrusher': ['Skullcrusher', {}],
  Band_Skull_Crusher: ['Skullcrusher', {}],
  Lying_Dumbbell_Tricep_Extension: ['Skullcrusher', {}],
  Decline_Dumbbell_Triceps_Extension: ['Skullcrusher', { angle: 'Decline' }],
  Decline_EZ_Bar_Triceps_Extension: ['Skullcrusher', { angle: 'Decline' }],
  Incline_Barbell_Triceps_Extension: ['Skullcrusher', { angle: 'Incline' }],
  Cable_Lying_Triceps_Extension: ['Skullcrusher', {}],
  Cable_Incline_Triceps_Extension: ['Skullcrusher', { angle: 'Incline' }],
  One_Arm_Pronated_Dumbbell_Triceps_Extension: ['Skullcrusher', { side: 'One Arm', hand: 'Overhand Grip' }],
  One_Arm_Supinated_Dumbbell_Triceps_Extension: ['Skullcrusher', { side: 'One Arm', hand: 'Reverse Grip' }],
  Kettlebell_Overhead_Triceps_Extension: ['Overhead Triceps Extension', {}],
  Standing_Overhead_Barbell_Triceps_Extension: ['Overhead Triceps Extension', {}],
  Standing_Dumbbell_Triceps_Extension: ['Overhead Triceps Extension', { position: 'Standing' }],
  'Standing_One-Arm_Dumbbell_Triceps_Extension': ['Overhead Triceps Extension', { side: 'One Arm', position: 'Standing' }],
  Seated_Triceps_Press: ['Overhead Triceps Extension', { position: 'Seated' }],
  'Dumbbell_One-Arm_Triceps_Extension': ['Overhead Triceps Extension', { side: 'One Arm', position: 'Seated' }],
  Cable_Rope_Overhead_Triceps_Extension: ['Overhead Triceps Extension', { attach: 'Rope' }],
  Kneeling_Cable_Triceps_Extension: ['Overhead Triceps Extension', { position: 'Kneeling' }],
  Cable_One_Arm_Tricep_Extension: ['Triceps Pushdown', { side: 'One Arm' }],
  Machine_Triceps_Extension: ['Triceps Extension', {}],
  Tricep_Dumbbell_Kickback: ['Triceps Kickback', {}],
  // A bent-over dumbbell triceps extension is a kickback (D90 step 1).
  'Standing_Bent-Over_One-Arm_Dumbbell_Triceps_Extension': ['Triceps Kickback', { side: 'One Arm' }],
  'Seated_Bent-Over_Two-Arm_Dumbbell_Triceps_Extension': ['Triceps Kickback', { position: 'Seated' }],
  'Seated_Bent-Over_One-Arm_Dumbbell_Triceps_Extension': ['Triceps Kickback', { side: 'One Arm', position: 'Seated' }],
  Standing_Towel_Triceps_Extension: ['Towel Triceps Extension', {}],
  Body_Tricep_Press: ['Skullcrusher', {}],
  // Rear delts: a rear delt raise is a reverse fly.
  Cable_Rear_Delt_Fly: ['Reverse Fly', {}],
  Dumbbell_Lying_Rear_Lateral_Raise: ['Reverse Fly', { position: 'Lying' }],
  'Dumbbell_Lying_One-Arm_Rear_Lateral_Raise': ['Reverse Fly', { position: 'Lying', side: 'One Arm' }],
  Bent_Over_Dumbbell_Rear_Delt_Raise_With_Head_On_Bench: ['Reverse Fly', { setup: 'Head Supported' }],
  'Seated_Bent-Over_Rear_Delt_Raise': ['Reverse Fly', { position: 'Seated' }],
  Face_Pull: ['Face Pull', {}],
  Band_Pull_Apart: ['Band Pull-Apart', {}],
  // Legs.
  Butt_Lift_Bridge: ['Glute Bridge', {}],
  Physioball_Hip_Bridge: ['Glute Bridge', {}],
  Barbell_Hip_Thrust: ['Hip Thrust', {}],
  Romanian_Deadlift: ['Romanian Deadlift', {}],
  'Kettlebell_One-Legged_Deadlift': ['Romanian Deadlift', { side: 'One Leg' }],
  // A stiff-legged deadlift is a Romanian Deadlift chip (variation audit).
  'Stiff-Legged_Barbell_Deadlift': ['Romanian Deadlift', { type: 'Stiff-Legged' }],
  'Stiff-Legged_Dumbbell_Deadlift': ['Romanian Deadlift', { type: 'Stiff-Legged' }],
  'Smith_Machine_Stiff-Legged_Deadlift': ['Romanian Deadlift', { type: 'Stiff-Legged' }],
  Trap_Bar_Deadlift: ['Deadlift', { setup: 'Trap Bar' }],
  Goblet_Squat: ['Goblet Squat', {}],
  Front_Squat_Clean_Grip: ['Front Squat', {}],
  Front_Barbell_Squat: ['Front Squat', { hand: 'Cross-Arm' }], // a grip
  Front_Squats_With_Two_Kettlebells: ['Front Squat', {}],
  Plie_Dumbbell_Squat: ['Squat', { stance: 'Wide Stance' }],
  Dumbbell_Rear_Lunge: ['Lunge', { type: 'Reverse' }],
  Barbell_Walking_Lunge: ['Lunge', { type: 'Walking' }],
  Bodyweight_Walking_Lunge: ['Lunge', { type: 'Walking' }],
  'Step-up_with_Knee_Raise': ['Step-Up', { type: 'Knee Raise' }],
  Split_Squat_with_Dumbbells: ['Split Squat', {}],
  'Smith_Single-Leg_Split_Squat': ['Split Squat', { type: 'Bulgarian' }],
  Glute_Kickback: ['Glute Kickback', {}],
  'One-Legged_Cable_Kickback': ['Glute Kickback', {}],
  Pull_Through: ['Pull-Through', {}],
  Rack_Pulls: ['Rack Pull', {}],
  Hyperextensions_Back_Extensions: ['Back Extension', {}],
  Weighted_Ball_Hyperextension: ['Back Extension', {}],
  Kneeling_Arm_Drill: ['Kneeling Arm Drill', {}],
  // The one-variation jump cards fold into 4 cards (D90 step 2): Jump Squat
  // (both feet, up), Jumping Lunge (split stance), Long Jump (forward or
  // sideways) and Running Drill. Burpee and Mountain Climber stay cards.
  Standing_Long_Jump: ['Long Jump', {}],
  Lateral_Bound: ['Long Jump', { type: 'Lateral' }],
  Front_Box_Jump: ['Jump Squat', { setup: 'Box' }],
  Knee_Tuck_Jump: ['Jump Squat', { type: 'Tuck' }],
  Star_Jump: ['Jump Squat', { type: 'Star' }],
  Rocket_Jump: ['Jump Squat', { type: 'Rocket' }],
  Split_Jump: ['Jumping Lunge', {}], // a split jump is the jumping lunge
  Fast_Skipping: ['Running Drill', { type: 'Skipping' }],
  Carioca_Quick_Step: ['Running Drill', { type: 'Carioca' }],
  Double_Leg_Butt_Kick: ['Running Drill', { type: 'Butt Kick' }],
  Single_Leg_Butt_Kick: ['Running Drill', { type: 'Butt Kick', side: 'One Leg' }],
  'One-Arm_Kettlebell_Swings': ['Kettlebell Swing', { side: 'One Arm' }],
  Vertical_Swing: ['Dumbbell Swing', {}],
  // A standing band hip extension is a band glute kickback (D90 step 1).
  Hip_Extension_with_Bands: ['Glute Kickback', {}],
  Ball_Leg_Curl: ['Leg Curl', {}],
  Natural_Glute_Ham_Raise: ['Nordic Curl', {}],
  Glute_Ham_Raise: ['Nordic Curl', {}],
  Thigh_Abductor: ['Hip Abduction', {}],
  Thigh_Adductor: ['Hip Adduction', {}],
  Band_Hip_Adductions: ['Hip Adduction', {}],
  // Calf raises: a position everywhere (variation audit).
  Smith_Machine_Calf_Raise: ['Calf Raise', { position: 'Standing' }],
  'Calf_Raises_-_With_Bands': ['Calf Raise', { position: 'Standing' }],
  Calf_Press_On_The_Leg_Press_Machine: ['Calf Raise', { setup: 'Leg Press' }],
  Rocking_Standing_Calf_Raise: ['Calf Raise', { type: 'Rocking' }],
  Calf_Raise_On_A_Dumbbell: ['Calf Raise on a Dumbbell', {}],
  Freehand_Jump_Squat: ['Jump Squat', {}],
  Weighted_Jump_Squat: ['Jump Squat', {}],
  // Core.
  Ab_Crunch_Machine: ['Crunch', {}],
  // The cable crunch is the rope crunch (D90 step 1): kneeling or standing.
  Cable_Crunch: ['Crunch', { position: 'Kneeling' }],
  Standing_Rope_Crunch: ['Crunch', { position: 'Standing' }],
  Exercise_Ball_Crunch: ['Crunch', {}],
  Standing_Cable_Wood_Chop: ['Wood Chop', {}],
  Cable_Russian_Twists: ['Russian Twist', {}],
  Alternate_Heel_Touchers: ['Heel Touch', {}],
  Air_Bike: ['Bicycle Crunch', {}],
  Flat_Bench_Lying_Leg_Raise: ['Lying Leg Raise', {}],
  Hanging_Pike: ['Hanging Leg Raise', { type: 'Pike' }],
  Knee_Hip_Raise_On_Parallel_Bars: ['Hanging Leg Raise', { type: 'Knee', setup: "Captain's Chair" }],
  Side_Bridge: ['Side Plank', {}],
  Barbell_Ab_Rollout: ['Ab Rollout', {}],
  'Barbell_Ab_Rollout_-_On_Knees': ['Ab Rollout', { position: 'Kneeling' }],
  Ab_Roller: ['Ab Rollout', { setup: 'Ab Wheel' }],
  'Exercise_Ball_Pull-In': ['Ball Pull-In', {}],
  Mountain_Climbers: ['Mountain Climber', {}],
  Overhead_Slam: ['Ball Slam', {}],
  Rope_Jumping: ['Jump Rope', {}],
  Isometric_Chest_Squeezes: ['Isometric Chest Squeeze', {}],
  'Handstand_Push-Ups': ['Handstand Push-Up', {}],
  Push_Up_to_Side_Plank: ['Push-Up to Side Plank', {}],
  'Plyo_Push-up': ['Push-Up', { type: 'Plyo' }],
  // Chest, arms and shoulders (variation audit).
  Butterfly: ['Fly', {}],
  Low_Cable_Crossover: ['Crossover', { type: 'Low' }],
  'Straight-Arm_Dumbbell_Pullover': ['Pullover', { type: 'Straight-Arm' }],
  'Bent-Arm_Barbell_Pullover': ['Pullover', { type: 'Bent-Arm' }],
  'Bent-Arm_Dumbbell_Pullover': ['Pullover', { type: 'Bent-Arm' }],
  // Rare ones stay out of the new moves (not candidates, so not in the list).
  'Wide-Grip_Decline_Barbell_Pullover': ['Decline Pullover', {}],
  Dumbbell_Seated_Box_Jump: ['Seated Box Jump', {}],
  Cable_Chest_Press: ['Chest Press', { position: 'Seated' }],
  'Close-Grip_Standing_Barbell_Curl': ['Bicep Curl', { width: 'Close Grip' }],
  'Wide-Grip_Standing_Barbell_Curl': ['Bicep Curl', { width: 'Wide Grip' }],
  Standing_Biceps_Cable_Curl: ['Bicep Curl', {}],
  'Standing_One-Arm_Cable_Curl': ['Bicep Curl', { side: 'One Arm' }],
  Concentration_Curls: ['Concentration Curl', { position: 'Seated' }],
  Cross_Body_Hammer_Curl: ['Hammer Curl', { type: 'Cross-Body' }],
  High_Cable_Curls: ['High Cable Curl', {}],
  Standing_Dumbbell_Reverse_Curl: ['Reverse Curl', {}],
  Standing_Dumbbell_Upright_Row: ['Upright Row', {}],
  Alternating_Deltoid_Raise: ['Lateral Raise', { side: 'Alternating' }],
  'Standing_Low-Pulley_Deltoid_Raise': ['Lateral Raise', { side: 'One Arm' }],
  Side_Laterals_to_Front_Raise: ['Lateral to Front Raise', {}],
  Power_Clean: ['Power Clean', {}], // the only olympic lift (D56; the owner kept it)
  Landmine_Linear_Jammer: ['Landmine Press', {}],
  JM_Press: ['JM Press', {}],
  'Kettlebell_Turkish_Get-Up_Squat_style': ['Turkish Get-Up', {}],
  // One cardio machine card with a Setup row.
  Running_Treadmill: ['Cardio Machine', { setup: 'Treadmill' }],
  Bicycling_Stationary: ['Cardio Machine', { setup: 'Bike' }],
  Rowing_Stationary: ['Cardio Machine', { setup: 'Rower' }],
  Elliptical_Trainer: ['Cardio Machine', { setup: 'Elliptical' }],
  Stairmaster: ['Cardio Machine', { setup: 'Stairs' }],
};

// Exercises the database lacks but a gym has (D57, D69): [id, name, fields,
// move, modifiers]. Fields: the id of an exercise to copy them from, or a
// bodyweight exercise as [category, level, force, mechanic, muscle].
const gear = (equipment, category, level, force, mechanic, muscle) => ({
  category, equipment, level, force, mechanic, primaryMuscles: [muscle],
});
const bw = (...a) => gear('body only', ...a);
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
    'Pike Push-Up', { angle: 'Decline' }], // feet up, like the feet-elevated row
  ['Wall_Walk', 'Wall Walk', bw('strength', 'intermediate', 'push', 'compound', 'shoulders'), 'Wall Walk', {}],
  ['Wall_Handstand_Hold', 'Wall Handstand Hold', bw('strength', 'intermediate', 'static', 'compound', 'shoulders'),
    'Wall Handstand Hold', {}],
  ['Prone_Y-T-W_Raise', 'Prone Y-T-W Raise', bw('strength', 'beginner', 'pull', 'isolation', 'shoulders'), 'Prone Y-T-W Raise', {}],
  ['Bodyweight_Calf_Raise', 'Bodyweight Calf Raise', bw('strength', 'beginner', 'push', 'isolation', 'calves'), 'Calf Raise',
    { position: 'Standing' }],
  ['Single-Leg_Calf_Raise', 'Single-Leg Calf Raise', bw('strength', 'intermediate', 'push', 'isolation', 'calves'),
    'Calf Raise', { side: 'One Leg', position: 'Standing' }],
  ['Pogo_Hops', 'Pogo Hops', bw('plyometrics', 'beginner', 'push', 'compound', 'calves'), 'Pogo Hops', {}],
  ['Towel_Bicep_Curl', 'Towel Bicep Curl', bw('strength', 'beginner', 'pull', 'isolation', 'biceps'), 'Bicep Curl', { setup: 'Towel' }],
  ['Inverted_Bicep_Curl', 'Inverted Bicep Curl', bw('strength', 'intermediate', 'pull', 'isolation', 'biceps'),
    'Bicep Curl', { type: 'Inverted' }],
  ['Dead_Hang', 'Dead Hang', bw('strength', 'beginner', 'static', 'isolation', 'forearms'), 'Dead Hang', {}],
  ['Towel_Hang', 'Towel Hang', bw('strength', 'intermediate', 'static', 'isolation', 'forearms'), 'Dead Hang', { setup: 'Towel' }],
  ['Superman', 'Superman', bw('strength', 'beginner', 'static', 'isolation', 'lower back'), 'Superman', {}],
  ['Bodyweight_Bulgarian_Split_Squat', 'Bodyweight Bulgarian Split Squat', bw('strength', 'intermediate', 'push', 'compound', 'quadriceps'),
    'Split Squat', { type: 'Bulgarian' }],
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
  // More bodyweight exercises for the thin Scrapper slots (D69): horizontal
  // pull, biceps and rear delt. The rows are chips of Inverted Row
  // (variation audit); the curl and the hold stay their own cards.
  ['Towel_Row', 'Towel Row', bw('strength', 'beginner', 'pull', 'compound', 'middle back'), 'Inverted Row', { setup: 'Towel' }],
  ['Feet-Elevated_Inverted_Row', 'Feet-Elevated Inverted Row', bw('strength', 'intermediate', 'pull', 'compound', 'middle back'),
    'Inverted Row', { angle: 'Decline' }],
  ['One-Arm_Inverted_Row', 'One-Arm Inverted Row', bw('strength', 'expert', 'pull', 'compound', 'middle back'),
    'Inverted Row', { side: 'One Arm' }],
  ['Chin-Up_Hold', 'Chin-Up Hold', bw('strength', 'beginner', 'static', 'isolation', 'biceps'), 'Chin-Up Hold', {}],
  ['Doorframe_Curl', 'Doorframe Curl', bw('strength', 'beginner', 'pull', 'isolation', 'biceps'), 'Doorframe Curl', {}],
  ['Reverse_Snow_Angel', 'Reverse Snow Angel', bw('strength', 'beginner', 'pull', 'isolation', 'shoulders'), 'Reverse Snow Angel', {}],
  ['Bodyweight_Rear_Delt_Row', 'Bodyweight Rear Delt Row', bw('strength', 'intermediate', 'pull', 'compound', 'shoulders'),
    'Bodyweight Rear Delt Row', {}],
  // Common moves the database lacks (the list clean-up, D69). A loaded
  // carry is its own pattern (`carry`).
  ['Dumbbell_Farmers_Walk', "Dumbbell Farmer's Walk", gear('dumbbell', 'strength', 'beginner', 'static', 'compound', 'forearms'),
    "Farmer's Walk", {}],
  ['Kettlebell_Farmers_Walk', "Kettlebell Farmer's Walk", gear('kettlebells', 'strength', 'beginner', 'static', 'compound', 'forearms'),
    "Farmer's Walk", {}],
  ['Dumbbell_Romanian_Deadlift', 'Dumbbell Romanian Deadlift', gear('dumbbell', 'strength', 'beginner', 'pull', 'compound', 'hamstrings'),
    'Romanian Deadlift', {}],
  ['Dumbbell_Goblet_Squat', 'Dumbbell Goblet Squat', gear('dumbbell', 'strength', 'beginner', 'push', 'compound', 'quadriceps'),
    'Goblet Squat', {}],
  ['Dumbbell_Hip_Thrust', 'Dumbbell Hip Thrust', gear('dumbbell', 'strength', 'beginner', 'push', 'compound', 'glutes'),
    'Hip Thrust', {}],
  ['Bodyweight_Hip_Thrust', 'Bodyweight Hip Thrust', bw('strength', 'beginner', 'push', 'compound', 'glutes'), 'Hip Thrust', {}],
  ['Kettlebell_Swing', 'Kettlebell Swing', gear('kettlebells', 'strength', 'beginner', 'push', 'compound', 'hamstrings'),
    'Kettlebell Swing', {}],
  // Common variations the database lacks (variation audit).
  ['Bodyweight_Lunge', 'Bodyweight Lunge', bw('strength', 'beginner', 'push', 'compound', 'quadriceps'), 'Lunge', {}],
  ['Barbell_Reverse_Lunge', 'Barbell Reverse Lunge', gear('barbell', 'strength', 'intermediate', 'push', 'compound', 'quadriceps'),
    'Lunge', { type: 'Reverse' }],
  ['Dumbbell_Walking_Lunge', 'Dumbbell Walking Lunge', gear('dumbbell', 'strength', 'beginner', 'push', 'compound', 'quadriceps'),
    'Lunge', { type: 'Walking' }],
  ['Bodyweight_Step-Up', 'Bodyweight Step-Up', bw('strength', 'beginner', 'push', 'compound', 'quadriceps'), 'Step-Up', {}],
  ['Single-Leg_Hip_Thrust', 'Single-Leg Hip Thrust', bw('strength', 'intermediate', 'push', 'compound', 'glutes'),
    'Hip Thrust', { side: 'One Leg' }],
  ['Bodyweight_Split_Squat', 'Bodyweight Split Squat', bw('strength', 'beginner', 'push', 'compound', 'quadriceps'), 'Split Squat', {}],
  ['Dumbbell_Bulgarian_Split_Squat', 'Dumbbell Bulgarian Split Squat',
    gear('dumbbell', 'strength', 'intermediate', 'push', 'compound', 'quadriceps'), 'Split Squat', { type: 'Bulgarian' }],
  ['Single-Leg_Leg_Press', 'Single-Leg Leg Press', gear('machine', 'strength', 'beginner', 'push', 'compound', 'quadriceps'),
    'Leg Press', { side: 'One Leg' }],
  ['Wide_Stance_Leg_Press', 'Wide Stance Leg Press', gear('machine', 'strength', 'beginner', 'push', 'compound', 'quadriceps'),
    'Leg Press', { stance: 'Wide Stance' }],
  ['Bodyweight_Wide_Stance_Squat', 'Bodyweight Wide Stance Squat', bw('strength', 'beginner', 'push', 'compound', 'quadriceps'),
    'Squat', { stance: 'Wide Stance' }],
  ['Dumbbell_Deadlift', 'Dumbbell Deadlift', gear('dumbbell', 'strength', 'beginner', 'pull', 'compound', 'lower back'), 'Deadlift', {}],
  ['Dumbbell_Single-Leg_Romanian_Deadlift', 'Dumbbell Single-Leg Romanian Deadlift',
    gear('dumbbell', 'strength', 'intermediate', 'pull', 'compound', 'hamstrings'), 'Romanian Deadlift', { side: 'One Leg' }],
  ['Knee_Push-Up', 'Knee Push-Up', bw('strength', 'beginner', 'push', 'compound', 'chest'), 'Push-Up', { type: 'Knee' }],
  ['Barbell_Push_Press', 'Barbell Push Press', gear('barbell', 'strength', 'intermediate', 'push', 'compound', 'shoulders'),
    'Push Press', {}],
  ['Dumbbell_Push_Press', 'Dumbbell Push Press', gear('dumbbell', 'strength', 'intermediate', 'push', 'compound', 'shoulders'),
    'Push Press', {}],
  ['EZ_Bar_Preacher_Curl', 'EZ Bar Preacher Curl', gear('e-z curl bar', 'strength', 'beginner', 'pull', 'isolation', 'biceps'),
    'Preacher Curl', {}],
  ['EZ_Bar_Overhead_Triceps_Extension', 'EZ Bar Overhead Triceps Extension',
    gear('e-z curl bar', 'strength', 'beginner', 'push', 'isolation', 'triceps'), 'Overhead Triceps Extension', {}],
  ['EZ_Bar_Upright_Row', 'EZ Bar Upright Row', gear('e-z curl bar', 'strength', 'beginner', 'pull', 'compound', 'shoulders'),
    'Upright Row', {}],
  ['Barbell_Skullcrusher', 'Barbell Skullcrusher', gear('barbell', 'strength', 'beginner', 'push', 'isolation', 'triceps'),
    'Skullcrusher', {}],
  ['Cable_Side_Bend', 'Cable Side Bend', gear('cable', 'strength', 'beginner', 'pull', 'isolation', 'abdominals'), 'Side Bend', {}],
  ['Machine_Lateral_Raise', 'Machine Lateral Raise', gear('machine', 'strength', 'beginner', 'push', 'isolation', 'shoulders'),
    'Lateral Raise', {}],
  ['Cable_Triceps_Kickback', 'Cable Triceps Kickback', gear('cable', 'strength', 'beginner', 'push', 'isolation', 'triceps'),
    'Triceps Kickback', {}],
  ['Decline_Cable_Fly', 'Decline Cable Fly', gear('cable', 'strength', 'beginner', 'push', 'isolation', 'chest'),
    'Fly', { angle: 'Decline' }],
  ['Barbell_Front_Raise', 'Barbell Front Raise', gear('barbell', 'strength', 'beginner', 'push', 'isolation', 'shoulders'),
    'Front Raise', {}],
  ['One-Arm_Dumbbell_Curl', 'One-Arm Dumbbell Curl', gear('dumbbell', 'strength', 'beginner', 'pull', 'isolation', 'biceps'),
    'Bicep Curl', { side: 'One Arm' }],
  ['Cable_Hip_Abduction', 'Cable Hip Abduction', gear('cable', 'strength', 'beginner', 'push', 'isolation', 'abductors'),
    'Hip Abduction', {}],
  // New bases (D90 step 2, docs/exercise-list-plan.md "What to add"). New
  // ids are `base|values` (D80). The calisthenics skills: Shrimp Squat and
  // Support Hold (the BWF Recommended Routine), Back Bridge and Front Lever
  // (the owner's choice; no program in the sample uses them: a low rank).
  // Their Rings/TRX variations are in GRID.
  ['shrimp squat|bodyweight', 'Shrimp Squat', bw('strength', 'intermediate', 'push', 'compound', 'quadriceps'), 'Shrimp Squat', {}],
  ['support hold|bodyweight', 'Support Hold', bw('strength', 'beginner', 'static', 'compound', 'triceps'), 'Support Hold', {}],
  ['back bridge|bodyweight', 'Back Bridge', bw('strength', 'intermediate', 'static', 'compound', 'lower back'), 'Back Bridge', {}],
  ['front lever|bodyweight', 'Front Lever', bw('strength', 'expert', 'static', 'compound', 'lats'), 'Front Lever', {}],
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
// The tools (D90 step 2): Bodyweight, Dumbbell, Barbell, EZ Bar, Kettlebell,
// Cable, Machine, Smith Machine, Bands, Ball, Rings/TRX. The two database
// balls (exercise ball, medicine ball) are one tool, Ball (equipment `ball`).
const BALLS = new Set(['exercise ball', 'medicine ball']);
const EQUIP_LABEL = {
  'body only': 'Bodyweight', barbell: 'Barbell', dumbbell: 'Dumbbell', kettlebells: 'Kettlebell', cable: 'Cable', machine: 'Machine',
  bands: 'Bands', 'e-z curl bar': 'EZ Bar', ball: 'Ball', rings: 'Rings', 'foam roll': 'Foam Roll',
  other: 'Other',
};
function equipLabel(e) {
  if (/\bsmith\b/i.test(e.name)) return 'Smith Machine';
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

// Grips the name parser reads the wrong way round on one move (D90 step 1).
// A wrist curl is palms up (no grip value); palms down is the reverse wrist curl.
const FLIP_HAND = { 'Wrist Curl': { 'Reverse Grip': null, 'Overhand Grip': 'Reverse Grip' } };

// Old base, mods and alias fields are dropped first, so the tool can run on its own output.
const rows = all.map(({ base: _oldBase, mods: _oldMods, alias: _oldAlias, ...raw }) => {
  const e = { ...raw, ...FIX[raw.name], ...FIX[raw.id] };
  if (BALLS.has(e.equipment)) e.equipment = 'ball';
  // No equipment in the database is Bodyweight (D90 step 3 part B: Decline
  // Push-Up, Inverted Row and a few more had null).
  if (e.equipment == null) e.equipment = 'body only';
  const p = EXPLICIT[e.name] ? { base: EXPLICIT[e.name][0], mods: { ...EXPLICIT[e.name][1] } } : parse(e.name);
  let base = OVERRIDE[e.name] ?? p.base;
  base = MERGE[base.toLowerCase()] ?? base;
  const move = MOVE[e.id];
  if (typeof move === 'string') base = move;
  else if (move) [base, p.mods] = [move[0], { ...move[1] }];
  const mods = { equip: equipLabel(e), ...p.mods };
  if (mods.bands === 'Bands' && mods.equip === 'Bands') delete mods.bands;
  // Two arms is the default, not a value (D90 step 1): "Double" and
  // "Two-Arm" only leave the name.
  if (mods.side === 'Two Arms') delete mods.side;
  const flip = FLIP_HAND[base]?.[mods.hand];
  if (flip !== undefined) {
    if (flip) mods.hand = flip;
    else delete mods.hand;
  }
  if (!WIDTH_EQUIP.has(mods.equip)) delete mods.width;
  return { e, base, mods };
});

for (const id of Object.keys(ALIAS)) if (!rows.some((r) => r.e.id === id)) throw new Error(`ALIAS: no exercise ${id}`);
const groups = new Map();
// An aliased exercise is in no move (its id points to another exercise).
for (const r of rows.filter((x) => !ALIAS[x.e.id])) {
  const k = r.base.toLowerCase();
  if (!groups.has(k)) groups.set(k, []);
  groups.get(k).push(r);
}

// The variation grids (D80): a move's axes and their values, per
// equipment. Every combination a gym or home lifter does is a variation;
// `not` lists the combinations that make no sense (a partial set of
// modifiers; a list = any of these values). `add` lists single extra
// variations. A new variation copies its fields from the closest one of the
// move with the same equipment; its level is `level` (else the closest
// one's) plus the largest raise and the largest cut of `adj`; `set` replaces
// copied fields (for example the category). Its id is
// variationId (tools/exercise_names.mjs): stable, never renamed.
const GRID = [
  // Every card of the app list has a full grid in CARDS (D90 step 3). The
  // build pushes its tools here.
];

// Full grids (D90 step 3, docs/exercise-list-plan.md "The model"): a card
// lists its tools; each tool lists its axes and values and the `not` rules
// (and `add` for single extra combinations, `from` for a tool with no row
// yet). The build makes every combination the rules allow. Every other row
// of the card must be in `keep` with a reason (an old id that no rule makes
// stays: ids are frozen). A row that matches a combination keeps its old id.
// `score` is the base score (D91) of the card's plain lift; `change` is the
// level change of a value (an axis-qualified key like `bands.Bands` first,
// then the value; a tool's own `change` first). A new row's database
// level comes from its score (1-2 beginner, 3-4 intermediate, 5-6 expert).
const CARDS = {
  'Bench Press': {
    score: 3, // the barbell bench press: a staple, but a loaded bar over the chest
    change: { 'Smith Machine': -1, Squeeze: -1, 'One Arm': 1, 'bands.Bands': 1, Chains: 1 },
    tools: {
      Barbell: {
        axes: { angle: [null, 'Incline', 'Decline'], width: ['Close Grip', 'Medium Grip', 'Wide Grip'], bands: [null, 'Bands'],
          chains: [null, 'Chains'] },
        // Bands and Chains only flat with a medium grip, never both.
        not: [{ bands: 'Bands', chains: 'Chains' }, { bands: 'Bands', angle: ['Incline', 'Decline'] },
          { bands: 'Bands', width: ['Close Grip', 'Wide Grip'] }, { chains: 'Chains', angle: ['Incline', 'Decline'] },
          { chains: 'Chains', width: ['Close Grip', 'Wide Grip'] }],
      },
      // A decline Smith press stays medium grip.
      'Smith Machine': {
        axes: { angle: [null, 'Incline', 'Decline'], width: ['Close Grip', 'Medium Grip', 'Wide Grip'] },
        not: [{ angle: 'Decline', width: ['Close Grip', 'Wide Grip'] }],
      },
      // Dumbbells: squeeze, neutral grip, one arm. No squeeze with a neutral
      // grip or one arm; no decline squeeze, decline neutral or decline one arm.
      Dumbbell: {
        axes: { type: [null, 'Squeeze'], angle: [null, 'Incline', 'Decline'], hand: [null, 'Neutral Grip'], side: [null, 'One Arm'] },
        not: [{ type: 'Squeeze', hand: 'Neutral Grip' }, { type: 'Squeeze', side: 'One Arm' }, { angle: 'Decline', type: 'Squeeze' },
          { angle: 'Decline', hand: 'Neutral Grip' }, { angle: 'Decline', side: 'One Arm' }, { hand: 'Neutral Grip', side: 'One Arm' }],
      },
    },
    keep: {
      Reverse_Band_Bench_Press: 'reverse bands: a rare powerlifting row (OBSCURE, not in the app list)',
      'Close-Grip_EZ-Bar_Press': 'the one EZ bar row; EZ Bar is not a bench press tool',
    },
  },
  'Push-Up': {
    score: 2, // the floor push-up: most beginners do a few
    change: { Knee: -1, Incline: -1, Decline: 1, 'Close Grip': 1, 'Reverse Grip': 1, Plyo: 2, Archer: 2, 'Pseudo Planche': 2,
      'One Arm': 4, Rings: 1 },
    tools: {
      Bodyweight: {
        axes: { type: [null, 'Knee', 'Plyo', 'Archer', 'Pseudo Planche'], angle: [null, 'Incline', 'Decline'],
          width: ['Close Grip', 'Medium Grip', 'Wide Grip'], side: [null, 'One Arm'] },
        // A knee push-up is flat. Plyo, archer and pseudo planche have their
        // own hand place (medium); plyo is not done on a decline, archer and
        // pseudo planche only flat. One arm: medium, flat or incline, no type.
        not: [{ type: 'Knee', angle: ['Incline', 'Decline'] }, { type: ['Plyo', 'Archer', 'Pseudo Planche'], width: ['Close Grip', 'Wide Grip'] },
          { type: 'Plyo', angle: 'Decline' }, { type: ['Archer', 'Pseudo Planche'], angle: ['Incline', 'Decline'] },
          { side: 'One Arm', type: ['Knee', 'Plyo', 'Archer', 'Pseudo Planche'] }, { side: 'One Arm', width: ['Close Grip', 'Wide Grip'] },
          { side: 'One Arm', angle: 'Decline' }],
      },
      // Rings: flat, or feet up (decline). Rings have no grip width.
      Rings: { from: 'Bodyweight', axes: { angle: [null, 'Decline'] } },
    },
    keep: { 'Incline_Push-Up_Reverse_Grip': 'an odd old row (OBSCURE, not in the app list)' },
  },
  'Pull-Up': {
    score: 4, // a strict pull-up: many lifters cannot do one
    change: { 'Band Assisted': -2, Negative: -1, Weighted: 1, Machine: -3, Rings: 0 },
    tools: {
      // Grips: overhand, chin-up (reverse) and neutral. No wide chin-up or
      // wide neutral grip, no close neutral grip. Band-assisted and weighted
      // with a medium grip, or wide overhand. No archer pull-up: a Type row
      // would be a 6th chip row (the chip area has 5, D79).
      Bodyweight: {
        axes: { load: [null, 'Band Assisted', 'Weighted'], width: ['Close Grip', 'Medium Grip', 'Wide Grip'],
          hand: [null, 'Reverse Grip', 'Neutral Grip'] },
        not: [{ width: 'Wide Grip', hand: ['Reverse Grip', 'Neutral Grip'] }, { width: 'Close Grip', hand: 'Neutral Grip' },
          { load: ['Band Assisted', 'Weighted'], width: 'Close Grip' }],
        // The negative (jump up, lower slowly): a step before the first
        // pull-up. It is a Load value, as the chip area has 5 rows (D79).
        add: [{ load: 'Negative', width: 'Medium Grip' }],
      },
      // The assisted pull-up machine: its three handles.
      Machine: { from: 'Bodyweight', axes: { width: ['Medium Grip'], hand: [null, 'Reverse Grip', 'Neutral Grip'] } },
      Rings: { from: 'Bodyweight', axes: {} },
    },
  },
  Squat: {
    score: 3, // the barbell back squat
    change: { Bodyweight: -2, Dumbbell: -1, 'Smith Machine': -1, 'equip.Bands': -2, Machine: -1, 'bands.Bands': 1, Chains: 1,
      'One Leg': 2 },
    tools: {
      // Bands and Chains only with the normal stance, never both.
      Barbell: {
        axes: { stance: [null, 'Narrow Stance', 'Wide Stance'], bands: [null, 'Bands'], chains: [null, 'Chains'] },
        not: [{ bands: 'Bands', chains: 'Chains' }, { bands: 'Bands', stance: ['Narrow Stance', 'Wide Stance'] },
          { chains: 'Chains', stance: ['Narrow Stance', 'Wide Stance'] }],
      },
      'Smith Machine': { axes: { stance: [null, 'Narrow Stance', 'Wide Stance'] } },
      Dumbbell: { axes: { stance: [null, 'Wide Stance'] } }, // a narrow dumbbell squat is not a gym lift
      Bodyweight: { axes: { stance: [null, 'Wide Stance'] } }, // a narrow one is named like the barbell one, and rare
      Bands: { axes: {} },
    },
    keep: {
      Kneeling_Squat: 'a partial old row (OBSCURE)', Lying_Machine_Squat: 'the one machine row (OBSCURE)',
      One_Leg_Barbell_Squat: 'an old row (OBSCURE); one-leg squats are Pistol Squat and Split Squat',
      Reverse_Band_Power_Squat: 'reverse bands: a rare powerlifting row (OBSCURE)',
    },
  },
  'Bent-Over Row': {
    score: 3, // the barbell row: a held hinge and a heavy pull
    change: { Dumbbell: -1, Kettlebell: -1, 'Smith Machine': -1, Pendlay: 1 },
    tools: {
      // The Pendlay row is overhand (from the floor, each rep).
      Barbell: { axes: { type: [null, 'Pendlay'], hand: [null, 'Reverse Grip'] }, not: [{ type: 'Pendlay', hand: 'Reverse Grip' }] },
      Dumbbell: {
        axes: { hand: [null, 'Neutral Grip', 'Reverse Grip'], side: [null, 'Alternating'] },
        not: [{ side: 'Alternating', hand: 'Reverse Grip' }],
      },
      Kettlebell: { axes: { side: [null, 'Alternating'] } },
      'Smith Machine': { axes: { hand: [null, 'Reverse Grip'] } },
    },
  },
  // Part B (D90 step 3): every other card of the app list, in rank order.
  // The scoring rule (the owner, 27 Nov 2026): 1 only for the easiest lifts
  // (assisted, knee, incline push-up, bodyweight squat and lifts of that
  // kind); isolation and machine lifts start at 2; the main free-weight
  // lifts are 3 or 4; hard skills 5-6. One arm on an isolation lift is not
  // harder (0). A tool with no row of its own copies one (`from`).
  'Shoulder Press': {
    score: 3, // the standing barbell press
    change: { Machine: -1, 'Smith Machine': -1, Cable: -1, 'equip.Bands': -1, 'One Arm': 1 },
    tools: {
      Barbell: { axes: { position: ['Seated', 'Standing'] } },
      // Seated or standing; alternating, one arm (standing, palms in) or a
      // neutral grip. No alternating neutral press; no seated one-arm press.
      Dumbbell: {
        axes: { position: ['Seated', 'Standing'], side: [null, 'Alternating', 'One Arm'], hand: [null, 'Neutral Grip'] },
        not: [{ side: 'Alternating', hand: 'Neutral Grip' }, { side: 'One Arm', position: 'Seated' },
          { side: 'One Arm', position: 'Standing', hand: null }],
        add: [{ side: 'One Arm' }],
      },
      Kettlebell: {
        axes: { side: [null, 'Alternating', 'One Arm'], position: [null, 'Seated'] },
        not: [{ position: 'Seated', side: ['Alternating', 'One Arm'] }],
      },
      Cable: { axes: { position: [null, 'Seated'], side: [null, 'Alternating'] }, not: [{ position: 'Seated', side: 'Alternating' }] },
      Machine: { axes: { setup: [null, 'Plate-Loaded'] } },
      'Smith Machine': {},
      Bands: {},
    },
    keep: {
      Barbell_Shoulder_Press: 'the same lift as Standing_Military_Press (OBSCURE)',
      Dumbbell_Shoulder_Press: 'the same lift as the seated and standing dumbbell press (OBSCURE)',
      Chain_Press: 'chains stay only on Bench Press, Squat and Deadlift (D90); gear other, not in the app list',
    },
  },
  'Romanian Deadlift': {
    score: 3, // the barbell Romanian deadlift
    change: { Dumbbell: -1, Kettlebell: -1, 'Smith Machine': -1, Bodyweight: -2, 'One Leg': 1 },
    tools: {
      Barbell: { axes: { type: [null, 'Stiff-Legged'] } },
      'Smith Machine': { axes: { type: [null, 'Stiff-Legged'] } },
      Dumbbell: { axes: { type: [null, 'Stiff-Legged'], side: [null, 'One Leg'] }, not: [{ type: 'Stiff-Legged', side: 'One Leg' }] },
      Kettlebell: { from: 'Dumbbell', axes: { side: [null, 'One Leg'] } },
      Bodyweight: { from: 'Dumbbell', add: [{ side: 'One Leg' }] }, // a two-leg one is only a warm-up
    },
  },
  'Bicep Curl': {
    score: 2, // an isolation lift
    change: { 'One Arm': 0, Inverted: 1 },
    tools: {
      // No incline curl seated or one arm (the incline bench is the seat).
      Dumbbell: {
        axes: { angle: [null, 'Incline'], position: [null, 'Seated'], side: [null, 'Alternating', 'One Arm'] },
        not: [{ angle: 'Incline', position: 'Seated' }, { angle: 'Incline', side: 'One Arm' }, { position: 'Seated', side: 'One Arm' }],
      },
      Barbell: { axes: { width: ['Close Grip', 'Medium Grip', 'Wide Grip'] } },
      'EZ Bar': { axes: { width: ['Close Grip', 'Medium Grip', 'Wide Grip'] } },
      Cable: { axes: { position: [null, 'Lying'], side: [null, 'One Arm'] }, not: [{ position: 'Lying', side: 'One Arm' }] },
      Machine: {},
      Bodyweight: { add: [{ setup: 'Towel' }, { type: 'Inverted' }] },
    },
    keep: { 'Close-Grip_EZ-Bar_Curl_with_Band': 'a band on an EZ bar: rare (OBSCURE)' },
  },
  Deadlift: {
    score: 4, // the barbell deadlift: the heaviest pull from the floor
    change: { Dumbbell: -2, Kettlebell: -2, Cable: -2, Machine: -2, 'Trap Bar': -1, 'bands.Bands': 1, Chains: 1 },
    tools: {
      Barbell: {
        axes: { setup: [null, 'Trap Bar'], bands: [null, 'Bands'], chains: [null, 'Chains'] },
        not: [{ bands: 'Bands', chains: 'Chains' }, { setup: 'Trap Bar', bands: 'Bands' }, { setup: 'Trap Bar', chains: 'Chains' }],
      },
      Dumbbell: {},
      Kettlebell: { from: 'Dumbbell' },
      Cable: {},
      Machine: {},
    },
    keep: { Reverse_Band_Deadlift: 'reverse bands: a rare powerlifting row (OBSCURE)' },
  },
  'Lat Pulldown': {
    score: 2, // a machine lift
    tools: {
      Cable: {
        axes: { width: ['Close Grip', 'Medium Grip', 'Wide Grip'], hand: [null, 'Reverse Grip'] },
        not: [{ width: 'Wide Grip', hand: 'Reverse Grip' }],
        add: [{ side: 'One Arm', width: 'Medium Grip' }, { attach: 'V-Bar', width: 'Medium Grip' }],
      },
      Machine: { from: 'Cable', axes: { width: ['Medium Grip'] } },
    },
  },
  Crunch: {
    score: 2, // the floor crunch
    change: { Decline: 1 },
    tools: {
      Bodyweight: { axes: { angle: [null, 'Decline'] } },
      Cable: { axes: { position: ['Kneeling', 'Seated', 'Standing'] } },
      Machine: {},
      Ball: {},
    },
  },
  'One-Arm Row': { score: 2, tools: { Dumbbell: {}, Kettlebell: {} } }, // a supported row
  Plank: {
    score: 2,
    change: { Weighted: 1, Rings: 1 },
    tools: { Bodyweight: { axes: { load: [null, 'Weighted'] } }, Rings: { from: 'Bodyweight' } },
  },
  'Calf Raise': {
    score: 2,
    change: { 'One Leg': 1 },
    tools: {
      Barbell: { axes: { position: ['Standing', 'Seated'] }, add: [{ type: 'Rocking' }] },
      Machine: { axes: { position: ['Standing', 'Seated'] }, add: [{ setup: 'Leg Press' }] },
      Dumbbell: { axes: { position: ['Standing', 'Seated'], side: [null, 'One Leg'] } },
      'Smith Machine': { axes: { position: ['Standing'] } },
      Bands: { axes: { position: ['Standing'] } },
      Bodyweight: { axes: { position: ['Standing'], side: [null, 'One Leg'] } },
    },
  },
  Fly: {
    score: 2,
    tools: {
      Dumbbell: { axes: { angle: [null, 'Incline', 'Decline'], side: [null, 'One Arm'] }, not: [{ side: 'One Arm', angle: ['Incline', 'Decline'] }] },
      Cable: { axes: { angle: [null, 'Incline', 'Decline'] } },
      Machine: {},
    },
    keep: { Bodyweight_Flyes: 'an odd old row on an EZ bar (OBSCURE)' },
  },
  Lunge: {
    score: 2, // the dumbbell lunge
    change: { Barbell: 1 },
    tools: {
      Barbell: { axes: { type: [null, 'Walking', 'Reverse'] } },
      Dumbbell: { axes: { type: [null, 'Walking', 'Reverse', 'Lateral'] } },
      Bodyweight: { axes: { type: [null, 'Walking', 'Reverse', 'Lateral'] } },
    },
  },
  'Lateral Raise': {
    score: 2,
    tools: {
      Dumbbell: {
        axes: { position: [null, 'Seated'], side: [null, 'Alternating', 'One Arm'] },
        not: [{ position: 'Seated', side: 'One Arm' }],
        add: [{ side: 'One Arm', position: 'Lying' }, { angle: 'Incline', side: 'One Arm' }],
      },
      Cable: { axes: { position: [null, 'Seated'], side: [null, 'One Arm'] }, not: [{ position: 'Seated', side: 'One Arm' }] },
      Bands: {},
      Machine: {},
    },
  },
  Dip: {
    score: 4, // the parallel bar dip
    change: { Machine: -3, Bench: -2, 'Band Assisted': -1, Weighted: 1, Rings: 1 },
    tools: {
      Bodyweight: {
        axes: { type: [null, 'Chest'], load: [null, 'Band Assisted', 'Weighted'] },
        not: [{ type: 'Chest', load: 'Band Assisted' }],
        add: [{ setup: 'Bench' }, { setup: 'Bench', load: 'Weighted' }],
      },
      Machine: {}, // the assisted dip machine
      Rings: {},
    },
  },
  'Triceps Pushdown': {
    score: 2,
    tools: {
      Cable: { axes: { hand: [null, 'Reverse Grip'], side: [null, 'One Arm'] }, add: [{ attach: 'Rope' }, { attach: 'V-Bar' }] },
      Bands: { from: 'Cable' }, // a band over a door or a bar
    },
  },
  'Leg Press': {
    score: 2,
    tools: {
      Machine: { axes: { stance: [null, 'Narrow Stance', 'Wide Stance'] }, add: [{ side: 'One Leg' }] },
      'Smith Machine': {},
    },
  },
  'Seated Cable Row': {
    score: 2,
    tools: {
      Cable: {
        axes: { width: ['Medium Grip', 'Wide Grip'], hand: [null, 'Reverse Grip'] },
        not: [{ width: 'Wide Grip', hand: 'Reverse Grip' }],
        add: [{ side: 'One Arm', width: 'Medium Grip' }],
      },
      Machine: { from: 'Cable', axes: { width: ['Medium Grip'] } },
    },
  },
  'Leg Curl': {
    score: 2,
    change: { Bodyweight: 1 }, // feet on a towel or a slider: hard
    tools: {
      Machine: { axes: { position: ['Lying', 'Seated', 'Standing'] } },
      Ball: {},
      Bodyweight: { from: 'Ball', add: [{ setup: 'Towel' }] },
    },
    keep: { Seated_Band_Hamstring_Curl: 'gear other in the database (not in the app list)' },
  },
  'Leg Extension': { score: 2, tools: { Machine: { axes: { side: [null, 'One Leg'] } } } },
  Skullcrusher: {
    score: 2,
    change: { Bodyweight: 1 }, // the body as the weight, on a bar
    tools: {
      'EZ Bar': { axes: { angle: [null, 'Incline', 'Decline'] } },
      Barbell: { axes: { angle: [null, 'Incline', 'Decline'] } },
      Dumbbell: {
        axes: { angle: [null, 'Incline', 'Decline'] },
        add: [{ side: 'One Arm', hand: 'Overhand Grip' }, { side: 'One Arm', hand: 'Reverse Grip' }],
      },
      Cable: { axes: { angle: [null, 'Incline'] } },
      Bands: {},
      Bodyweight: {},
    },
  },
  'Split Squat': {
    score: 2, // the dumbbell split squat
    change: { Barbell: 1, Bulgarian: 1 },
    tools: {
      Dumbbell: { axes: { type: [null, 'Bulgarian'] } },
      Barbell: { from: 'Dumbbell', axes: { type: [null, 'Bulgarian'] } },
      'Smith Machine': { axes: { type: [null, 'Bulgarian'] } },
      Bodyweight: { axes: { type: [null, 'Bulgarian'] } },
    },
  },
  'Overhead Triceps Extension': {
    score: 2,
    tools: {
      Dumbbell: { axes: { position: ['Seated', 'Standing'], side: [null, 'One Arm'] } },
      Cable: { add: [{ attach: 'Rope' }, { position: 'Kneeling' }] },
      Kettlebell: {},
      Barbell: {},
      'EZ Bar': {},
    },
  },
  'Hammer Curl': {
    score: 2,
    tools: {
      Dumbbell: {
        axes: { position: [null, 'Seated'], side: [null, 'Alternating'] },
        add: [{ type: 'Cross-Body' }, { angle: 'Incline' }],
      },
      Cable: { add: [{ attach: 'Rope' }] },
    },
  },
  'Preacher Curl': {
    score: 2,
    tools: { Barbell: {}, 'EZ Bar': {}, Dumbbell: { axes: { side: [null, 'One Arm'] } }, Cable: {}, Machine: {} },
  },
  'Hip Thrust': {
    score: 3, // the barbell hip thrust: a main free-weight lift
    change: { Dumbbell: -1, Bodyweight: -1, 'One Leg': 1 },
    tools: { Barbell: {}, Dumbbell: {}, Bodyweight: { axes: { side: [null, 'One Leg'] } } },
  },
  Shrug: {
    score: 2,
    tools: { Barbell: {}, Dumbbell: {}, Cable: {}, Machine: {}, 'Smith Machine': { from: 'Barbell' } },
  },
  'Hanging Leg Raise': {
    score: 4, // straight legs from a bar
    change: { Knee: -1, Pike: 1, "Captain's Chair": -1 },
    tools: {
      // The captain's chair (back on a pad, forearms on the arms) is a knee raise here.
      Bodyweight: { axes: { type: [null, 'Knee', 'Pike'], setup: [null, "Captain's Chair"] }, not: [{ type: [null, 'Pike'], setup: "Captain's Chair" }] },
    },
  },
  'Sit-Up': {
    score: 2,
    change: { Decline: 1, Weighted: 1 },
    tools: { Bodyweight: { axes: { angle: [null, 'Decline'], load: [null, 'Weighted'] } } },
    keep: { 'Weighted_Sit-Ups_-_With_Bands': 'gear other in the database (not in the app list)' },
  },
  'Goblet Squat': { score: 2, tools: { Kettlebell: {}, Dumbbell: {} } },
  'Face Pull': { score: 2, tools: { Cable: {}, Bands: { from: 'Cable' } } },
  'Reverse Fly': {
    score: 2,
    tools: {
      Dumbbell: {
        axes: { position: [null, 'Seated', 'Lying'] },
        add: [{ position: 'Lying', side: 'One Arm' }, { setup: 'Head Supported' }, { angle: 'Incline' }],
      },
      Cable: {},
      Machine: {},
      Bands: {},
    },
  },
  'Upright Row': {
    score: 2,
    tools: {
      Barbell: {}, 'EZ Bar': {}, Dumbbell: { axes: { side: [null, 'One Arm'] } }, 'Smith Machine': { axes: { side: [null, 'One Arm'] } },
      Cable: {}, Bands: {},
    },
  },
  'Chest Press': {
    score: 2,
    tools: {
      Machine: { axes: { angle: [null, 'Incline', 'Decline'] }, add: [{ setup: 'Plate-Loaded' }] },
      Cable: { axes: { position: ['Seated', 'Standing'] }, add: [{ angle: 'Incline' }] },
    },
  },
  'Inverted Row': {
    score: 2, // a bar at waist height, heels on the floor
    change: { Towel: -1, Decline: 1, 'One Arm': 3, Rings: 1 },
    tools: {
      Bodyweight: {
        axes: { hand: [null, 'Reverse Grip'], angle: [null, 'Decline'] },
        not: [{ hand: 'Reverse Grip', angle: 'Decline' }],
        add: [{ setup: 'Towel' }, { side: 'One Arm' }],
      },
      Rings: { from: 'Bodyweight', axes: { angle: [null, 'Decline'] } }, // feet up on a box
    },
  },
  'Front Raise': {
    score: 2,
    tools: {
      Dumbbell: { axes: { side: [null, 'Alternating'] }, add: [{ angle: 'Incline' }] },
      Barbell: {},
      Cable: {},
      Bands: { from: 'Cable' },
    },
  },
  'Glute Bridge': {
    score: 2, // the loaded bridge
    change: { Bodyweight: -1, 'One Leg': 1 }, // the floor bridge is one of the easiest lifts
    tools: {
      Barbell: {}, Dumbbell: { from: 'Barbell' }, Ball: {}, Bodyweight: { axes: { side: [null, 'One Leg'] } },
    },
  },
  'Triceps Kickback': {
    score: 2,
    tools: { Dumbbell: { axes: { position: [null, 'Seated'], side: [null, 'One Arm'] } }, Cable: { axes: { side: [null, 'One Arm'] } } },
  },
  Crossover: {
    score: 2,
    tools: { Cable: { axes: { type: [null, 'Low'], side: [null, 'One Arm'] }, not: [{ type: 'Low', side: 'One Arm' }] }, Bands: {} },
  },
  'Step-Up': {
    score: 2,
    change: { Barbell: 1 },
    tools: { Barbell: {}, Dumbbell: {}, Bodyweight: { axes: { type: [null, 'Knee Raise'] } } },
  },
  'Russian Twist': {
    score: 2,
    tools: { Bodyweight: {}, Cable: {}, Ball: { from: 'Bodyweight' }, Dumbbell: { from: 'Bodyweight' } },
  },
  'Hack Squat': {
    score: 2, // the machine
    change: { Barbell: 1 }, // the bar behind the legs: awkward
    tools: { Machine: { axes: { stance: [null, 'Narrow Stance'] } }, Barbell: {} },
  },
  'Back Extension': { score: 2, tools: { Machine: {}, Ball: {} } },
  'Kettlebell Swing': { score: 3, change: { 'One Arm': 1 }, tools: { Kettlebell: { axes: { side: [null, 'One Arm'] } } } },
  "Farmer's Walk": { score: 2, tools: { Dumbbell: {}, Kettlebell: {} } },
  'Bicycle Crunch': { score: 2, tools: { Bodyweight: {} } },
  'Mountain Climber': { score: 2, tools: { Bodyweight: {} } },
  'Wrist Curl': {
    score: 2,
    tools: {
      Dumbbell: { axes: { hand: [null, 'Reverse Grip'], side: [null, 'One Arm'], position: ['Seated'] } },
      Barbell: { axes: { hand: [null, 'Reverse Grip'], position: ['Seated'] } },
      Cable: {},
    },
    keep: {
      'Palms-Down_Dumbbell_Wrist_Curl_Over_A_Bench': 'the same as the seated palms-down curl (OBSCURE)',
      'Palms-Down_Wrist_Curl_Over_A_Bench': 'the same as the seated palms-down curl (OBSCURE)',
      'Palms-Up_Barbell_Wrist_Curl_Over_A_Bench': 'the same as the seated palms-up curl (OBSCURE)',
      'Palms-Up_Dumbbell_Wrist_Curl_Over_A_Bench': 'the same as the seated palms-up curl (OBSCURE)',
    },
  },
  'T-Bar Row': {
    score: 3,
    change: { Machine: -1 }, // the chest pad holds the body
    tools: { Barbell: { add: [{}, { side: 'One Arm' }, { attach: 'V-Bar' }] }, Machine: { axes: { position: ['Lying'] } } },
  },
  'Ab Rollout': {
    score: 3,
    change: { Rings: 1 },
    tools: {
      Bodyweight: { add: [{ setup: 'Ab Wheel' }] },
      Barbell: { axes: { position: [null, 'Kneeling'] } },
      Rings: { from: 'Bodyweight' },
    },
  },
  'Reverse Crunch': { score: 2, change: { Decline: 1 }, tools: { Bodyweight: { axes: { angle: [null, 'Decline'] } }, Cable: {} } },
  'Concentration Curl': {
    score: 2,
    tools: { Dumbbell: { axes: { position: ['Seated', 'Standing'] } }, Barbell: { add: [{ width: 'Close Grip', position: 'Seated' }] } },
  },
  'Front Squat': {
    score: 4, // the bar on the front of the shoulders
    change: { Kettlebell: -1 },
    tools: { Barbell: { axes: { hand: [null, 'Cross-Arm'] } }, Kettlebell: {} },
  },
  'Hip Abduction': { score: 2, tools: { Machine: {}, Cable: {}, Bands: { from: 'Cable' } } },
  'Hip Adduction': { score: 2, tools: { Machine: {}, Cable: {}, Bands: {} } },
  Pullover: {
    score: 2,
    tools: { Dumbbell: { axes: { type: ['Bent-Arm', 'Straight-Arm'] } }, Barbell: { axes: { type: ['Bent-Arm'] } } },
  },
  'Good Morning': {
    score: 3,
    change: { 'equip.Bands': -1 },
    tools: { Barbell: { axes: { position: [null, 'Seated'] } }, Bands: {} },
  },
  'Arnold Press': { score: 3, tools: { Dumbbell: {}, Kettlebell: {} } }, // a dumbbell shoulder press with a turn
  'Straight-Arm Pulldown': { score: 2, tools: { Cable: { add: [{}, { attach: 'Rope' }] } } },
  'Pike Push-Up': { score: 3, change: { Decline: 1 }, tools: { Bodyweight: { axes: { angle: [null, 'Decline'] } } } },
  'Pistol Squat': {
    score: 5, // a full one-leg squat: a skill
    tools: { Bodyweight: {}, Kettlebell: {} },
    keep: { Smith_Machine_Pistol_Squat: 'a pistol squat on a Smith machine: odd (OBSCURE)' },
  },
  'Dead Bug': { score: 1, tools: { Bodyweight: {} } }, // lying on the back: one of the easiest core lifts
  'Side Plank': { score: 2, tools: { Bodyweight: {} } },
  'Lying Leg Raise': { score: 2, tools: { Bodyweight: {} } },
  'Wood Chop': { score: 2, tools: { Cable: {} } },
  'Band Pull-Apart': { score: 2, tools: { Bands: {} } },
  Burpee: { score: 3, tools: { Bodyweight: {} } },
  'Chest-Supported Row': { score: 2, tools: { Dumbbell: {} } },
  'Jump Squat': {
    score: 3,
    change: { Barbell: 1, Tuck: 1, Star: -1 },
    tools: {
      Bodyweight: { add: [{}, { setup: 'Box' }, { type: 'Tuck' }, { type: 'Rocket' }, { type: 'Star' }] },
      Barbell: {},
    },
  },
  'Floor Press': {
    score: 3, // the barbell floor press
    change: { Dumbbell: -1, Kettlebell: -1, 'One Arm': 1 },
    tools: {
      Barbell: {},
      Dumbbell: { axes: { side: [null, 'One Arm'] } },
      Kettlebell: { axes: { side: [null, 'Alternating', 'One Arm'] } },
    },
  },
  'Cardio Machine': { score: 2, tools: { Machine: { axes: { setup: ['Treadmill', 'Bike', 'Rower', 'Elliptical', 'Stairs'] } } } },
  'Reverse Curl': { score: 2, tools: { Barbell: {}, 'EZ Bar': { from: 'Barbell' }, Dumbbell: {}, Cable: {} } },
  'Rear Delt Row': {
    score: 2,
    tools: { Barbell: {}, Dumbbell: { from: 'Barbell' }, Cable: { add: [{ attach: 'Rope' }] }, Bodyweight: {} },
  },
  'Glute Kickback': { score: 2, tools: { Bodyweight: {}, Cable: {}, Bands: {} } },
  'Side Bend': { score: 2, tools: { Dumbbell: {}, Barbell: {}, Cable: {} } },
  'External Rotation': { score: 2, tools: { Dumbbell: {}, Cable: {}, Bands: {} } },
  'Sumo Deadlift': {
    score: 4,
    change: { Kettlebell: -2 },
    tools: { Barbell: {}, Kettlebell: { from: 'Barbell', set: { category: 'strength' } } },
    keep: { Reverse_Band_Sumo_Deadlift: 'reverse bands: a rare powerlifting row (OBSCURE)' },
  },
  'Pallof Press': { score: 2, tools: { Cable: {}, Bands: { from: 'Cable' } } },
  'Oblique Crunch': { score: 2, change: { Decline: 1 }, tools: { Bodyweight: { axes: { angle: [null, 'Decline'] } } } },
  'Leg Pull-In': { score: 2, tools: { Bodyweight: { axes: { position: [null, 'Seated'] } } } },
  'Internal Rotation': { score: 2, tools: { Cable: {}, Bands: {} } },
  'Nordic Curl': {
    score: 5, // lower the body from the knees: few lifters can
    change: { Machine: -1, 'Band Assisted': -1 },
    tools: { Bodyweight: { axes: { load: [null, 'Band Assisted'] } }, Machine: {} },
  },
  'Dead Hang': {
    score: 2,
    change: { Towel: 1, 'One Arm': 2 },
    tools: { Bodyweight: { axes: { setup: [null, 'Towel'], side: [null, 'One Arm'] }, not: [{ setup: 'Towel', side: 'One Arm' }] } },
  },
  'Support Hold': { score: 2, change: { Rings: 2 }, tools: { Bodyweight: {}, Rings: { from: 'Bodyweight' } } },
  'Box Squat': {
    score: 3,
    tools: { Barbell: {} },
    keep: { Reverse_Band_Box_Squat: 'reverse bands: a rare powerlifting row (OBSCURE)' },
  },
  'Triceps Extension': { score: 2, tools: { Machine: {} } },
  'Rack Pull': { score: 3, tools: { Barbell: {} } },
  'Pull-Through': { score: 2, tools: { Cable: {} } },
  'Jump Rope': { score: 2, tools: { Bodyweight: {} } },
  'Power Clean': { score: 5, tools: { Barbell: {} } }, // a fast, technical lift
  Thruster: { score: 4, tools: { Kettlebell: {}, Barbell: { from: 'Kettlebell' }, Dumbbell: { from: 'Kettlebell' } } },
  'Landmine Press': { score: 2, tools: { Barbell: {} } }, // an easy angle for the shoulder
  'Muscle-Up': { score: 6, tools: { Bodyweight: {}, Rings: { from: 'Bodyweight' } } },
  'High Row': { score: 2, tools: { Machine: {} } },
  'Monster Walk': { score: 2, tools: { Bands: {} } },
  'Handstand Push-Up': { score: 5, tools: { Bodyweight: {} } }, // against a wall; a free one would be 6
  'Scapular Pull-Up': { score: 2, tools: { Bodyweight: {} } },
  'Reverse Hyperextension': { score: 2, tools: { Machine: {} } },
  'Jackknife Sit-Up': { score: 3, tools: { Bodyweight: {} } },
  'Ball Slam': { score: 2, tools: { Ball: {} } },
  'Renegade Row': { score: 4, tools: { Kettlebell: {}, Dumbbell: { from: 'Kettlebell' } } }, // a row from a plank
  'Towel Triceps Extension': { score: 2, tools: { Bodyweight: {} } },
  'Tuck Crunch': { score: 2, tools: { Bodyweight: {} } },
  'Cross-Body Crunch': { score: 2, tools: { Bodyweight: {} } },
  Superman: { score: 1, tools: { Bodyweight: {} } }, // lying face down: one of the easiest lifts
  'Wall Sit': { score: 2, tools: { Bodyweight: {} } },
  'Hollow Body Hold': { score: 3, tools: { Bodyweight: {} } },
  'Bird Dog': { score: 1, tools: { Bodyweight: {} } }, // on hands and knees: one of the easiest lifts
  'Prone Y-T-W Raise': { score: 2, tools: { Bodyweight: {} } },
  'Cossack Squat': { score: 3, tools: { Bodyweight: {} } },
  'Shrimp Squat': { score: 4, tools: { Bodyweight: {} } },
  'Push Press': { score: 4, tools: { Barbell: {}, Dumbbell: {}, Kettlebell: { add: [{}, { side: 'One Arm' }] } } },
  'High Pulley Row': { score: 2, tools: { Cable: { axes: { position: ['Kneeling'], side: [null, 'One Arm'] } } } },
  'Jumping Lunge': { score: 3, change: { Dumbbell: 1 }, tools: { Bodyweight: {}, Dumbbell: { from: 'Bodyweight' } } },
  'Long Jump': { score: 3, tools: { Bodyweight: { axes: { type: [null, 'Lateral'] } } } },
  'Heel Touch': { score: 2, tools: { Bodyweight: {} } },
  'Ball Pull-In': { score: 3, tools: { Ball: {} } },
  'Medicine Ball Chest Pass': { score: 2, tools: { Ball: {} } },
  'JM Press': { score: 4, tools: { Barbell: {} } },
  'Tate Press': { score: 3, tools: { Dumbbell: {} } },
  'Spider Curl': { score: 2, tools: { 'EZ Bar': {} } },
  'Drag Curl': { score: 2, tools: { Barbell: {} } },
  'Zottman Curl': { score: 2, tools: { Dumbbell: {} } },
  'High Cable Curl': { score: 2, tools: { Cable: {} } },
  'Deficit Deadlift': { score: 5, tools: { Barbell: {} } },
  Halo: { score: 2, tools: { Kettlebell: {} } },
  'Turkish Get-Up': { score: 5, tools: { Kettlebell: {} } },
  'Lateral to Front Raise': { score: 2, tools: { Dumbbell: {} } },
  'Push-Up to Side Plank': { score: 3, tools: { Bodyweight: {} } },
  'Wall Walk': { score: 4, tools: { Bodyweight: {} } },
  'Wall Handstand Hold': { score: 4, tools: { Bodyweight: {} } },
  'Pogo Hops': { score: 2, tools: { Bodyweight: {} } },
  'L-Sit': { score: 5, tools: { Bodyweight: {}, Rings: { from: 'Bodyweight' } } },
  'Dumbbell Swing': { score: 2, tools: { Dumbbell: {} } },
  'Flutter Kicks': { score: 2, tools: { Bodyweight: {} } },
  'Reverse Snow Angel': { score: 2, tools: { Bodyweight: {} } },
  'Chin-Up Hold': { score: 3, tools: { Bodyweight: {} } },
  'Running Drill': {
    score: 2,
    change: { 'One Leg': 1 },
    tools: { Bodyweight: { axes: { type: ['Skipping', 'Carioca', 'Butt Kick'] }, add: [{ type: 'Butt Kick', side: 'One Leg' }] } },
  },
  'Front Lever': {
    score: 6, // the full lever: an elite skill
    change: { Tuck: -2, Rings: 0 }, // knees to the chest: the first step
    tools: { Bodyweight: { axes: { type: [null, 'Tuck'] } }, Rings: { from: 'Bodyweight', axes: { type: [null, 'Tuck'] } } },
  },
  'Kneeling Arm Drill': { score: 1, tools: { Bodyweight: {} } }, // arm swings on the knees
  'Clock Push-Up': { score: 4, tools: { Bodyweight: {} } },
  'Isometric Chest Squeeze': { score: 1, tools: { Bodyweight: {} } }, // press the palms together
  'Finger Curl': { score: 2, tools: { Barbell: {} } },
  'Zercher Squat': { score: 4, tools: { Barbell: {} } },
  'Cuban Press': { score: 2, tools: { Dumbbell: {} } },
  Scaption: { score: 2, tools: { Dumbbell: {} } },
  'Doorframe Curl': { score: 2, tools: { Bodyweight: {} } },
  'Calf Raise on a Dumbbell': { score: 2, tools: { Dumbbell: {} } },
  'Back Bridge': { score: 4, tools: { Bodyweight: {} } },
};

const CARD_OF = new Map(Object.entries(CARDS).map(([k, c]) => [k.toLowerCase(), c]));
/** The difficulty score 1-6 (D91) of variation [mods] of [base]; undefined for a card with no score. */
function scoreOf(base, mods) {
  const b = base.toLowerCase(), card = CARD_OF.get(b);
  const [score, change] = card ? [card.score, card.change ?? {}] : [];
  if (score === undefined) return undefined;
  const own = card?.tools[mods.equip]?.change ?? {};
  let s = score;
  for (const a of AXIS_ORDER) {
    const v = mods[a];
    if (v == null) continue;
    const q = `${a}.${v}`;
    s += own[q] ?? own[v] ?? change[q] ?? change[v] ?? 0;
  }
  return Math.max(1, Math.min(6, s));
}
const levelOfScore = (s) => (s <= 2 ? 'beginner' : s <= 4 ? 'intermediate' : 'expert');
// The cap (D90): at most this many variations per card.
const CAP = 30;
for (const [move, card] of Object.entries(CARDS)) {
  if (!Number.isInteger(card.score) || card.score < 1 || card.score > 6) throw new Error(`CARDS ${move}: score 1-6`);
  for (const [equip, t] of Object.entries(card.tools)) {
    // A tool with no axes and no `add` is its plain lift.
    GRID.push({ move, equip, axes: t.axes ?? (t.add ? undefined : {}), not: t.not, add: t.add, from: t.from, set: t.set, card: move });
  }
}
// The database equipment of an equipment modifier (for a new equipment on a move).
const EQUIP_DB = {
  Bodyweight: 'body only', Barbell: 'barbell', Dumbbell: 'dumbbell', Kettlebell: 'kettlebells', Cable: 'cable', Machine: 'machine',
  'Smith Machine': 'machine', Bands: 'bands', 'EZ Bar': 'e-z curl bar', Ball: 'ball', Rings: 'rings',
};
const matches = (mods, rule) => Object.entries(rule).every(([a, v]) => (Array.isArray(v) ? v : [v]).includes(mods[a] ?? null));
// Two modifier sets are the same variation (no width = Medium Grip, D57).
const sameMods = (a, b) => {
  const norm = (m) => ({ ...m, width: m.width ?? (WIDTH_EQUIP.has(m.equip) ? 'Medium Grip' : undefined) });
  const x = norm(a), y = norm(b);
  return AX_ALL.every((k) => (x[k] ?? null) === (y[k] ?? null));
};
const AX_ALL = AXIS_ORDER;
const combos = (axes) => Object.entries(axes).reduce((acc, [a, vs]) =>
  acc.flatMap((m) => vs.map((v) => (v == null ? { ...m } : { ...m, [a]: v }))), [{}]);
const wantedOf = (spec) =>
  [...(spec.axes ? combos(spec.axes).filter((m) => !(spec.not ?? []).some((r) => matches(m, r))) : []), ...(spec.add ?? [])]
    .map((m) => ({ equip: spec.equip, ...m }));
const modsText = (m) => AXIS_ORDER.map((a) => m[a]).filter(Boolean).join(', ');
// A full grid makes the card (CARDS): every row the rules do not make must
// be in `keep` with a reason, and a kept row must be one the rules do not make.
for (const [move, card] of Object.entries(CARDS)) {
  const g = groups.get(move.toLowerCase());
  if (!g) throw new Error(`CARDS: no move ${move}`);
  const wanted = GRID.filter((s) => s.card === move).flatMap(wantedOf);
  for (const r of g) {
    const made = wanted.some((m) => sameMods(r.mods, m));
    if (!made && !card.keep?.[r.e.id]) throw new Error(`CARDS ${move}: ${r.e.id} [${modsText(r.mods)}] is outside the grid (add a rule or keep it)`);
    if (made && card.keep?.[r.e.id]) throw new Error(`CARDS ${move}: keep ${r.e.id}: the grid makes it`);
  }
  for (const id of Object.keys(card.keep ?? {})) if (!g.some((r) => r.e.id === id)) throw new Error(`CARDS ${move}: keep ${id}: no such row`);
}
const generated = [];
for (const spec of GRID) {
  const g = groups.get(spec.move.toLowerCase());
  if (!g) throw new Error(`GRID: no move ${spec.move}`);
  const wanted = wantedOf(spec);
  for (const mods of wanted) {
    if (g.some((r) => sameMods(r.mods, mods))) continue;
    const from = g.filter((r) => r.mods.equip === (spec.from ?? spec.equip));
    if (!from.length) throw new Error(`GRID ${spec.move}: no ${spec.from ?? spec.equip} variation to copy`);
    const shared = (r) => AX_ALL.filter((a) => a !== 'equip' && r.mods[a] && r.mods[a] === mods[a]).length
      + (r.mods.width && r.mods.width === mods.width ? 0.5 : 0) + (r.mods.hand && r.mods.hand === mods.hand ? 0.5 : 0);
    const src = [...from].sort((a, b) => shared(b) - shared(a) || Object.keys(a.mods).length - Object.keys(b.mods).length)[0];
    const adj = Object.values(mods).map((v) => spec.adj?.[v] ?? 0);
    const L = ['beginner', 'intermediate', 'expert'];
    const lv = L.indexOf(spec.level ?? src.e.level) + Math.max(0, ...adj) + Math.min(0, ...adj);
    const id = variationId(spec.move, mods);
    if (all.some((e) => e.id === id) || generated.some((r) => r.e.id === id)) throw new Error(`GRID: id ${id} twice`);
    const { id: _i, name: _n, custom: _c, score: _s, ...fields } = src.e;
    // A full grid's new row: the database level of its score (D91).
    const level = spec.card ? levelOfScore(scoreOf(spec.move, mods)) : L[Math.max(0, Math.min(2, lv))];
    const e = { id, name: id, ...fields, ...spec.set, equipment: spec.from ? EQUIP_DB[spec.equip] : src.e.equipment,
      level, custom: true, grid: true };
    const r = { e, base: spec.move, mods: { ...mods } };
    if (!WIDTH_EQUIP.has(r.mods.equip)) delete r.mods.width;
    g.push(r);
    rows.push(r);
    generated.push(r);
  }
}
// A nonsense combination never comes back (D80).
for (const r of rows) {
  for (const spec of GRID) {
    if (spec.move.toLowerCase() === r.base.toLowerCase() && r.mods.equip === spec.equip && (spec.not ?? []).some((n) => matches(r.mods, n))) {
      throw new Error(`GRID ${spec.move}: ${r.e.id} is a combination the rules exclude`);
    }
  }
}

for (const g of groups.values()) {
  const withWidth = new Set(g.filter((r) => r.mods.width).map((r) => r.mods.equip));
  for (const r of g) if (!r.mods.width && withWidth.has(r.mods.equip)) r.mods.width = 'Medium Grip';
}
const AX = AXIS_ORDER;
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
for (const g of groups.values()) if (g.length > CAP) throw new Error(`${g[0].base}: ${g.length} variations, more than the cap of ${CAP} (D90)`);
// The difficulty score (D91) of every exercise of a card with a score.
for (const r of rows) {
  delete r.e.score;
  const s = ALIAS[r.e.id] ? undefined : scoreOf(r.base, r.mods);
  if (s !== undefined) r.e.score = s;
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
for (const id of Object.keys(MOVE)) if (!all.some((e) => e.id === id)) throw new Error(`MOVE: no exercise ${id}`);
for (const id of Object.keys(MOVE)) if (ALIAS[id]) throw new Error(`MOVE: ${id} is an alias`);
// A Smith machine row is database equipment `machine` (the Cablemancer's
// gear, D50) with the tool Smith Machine: the app and CHALK read the tool
// from `mods.equip` (lib/game/chalk.dart chalkToolOfMod).
// Checked on the cards of CARDS (the app list); the other database rows are not shown.
for (const r of rows) {
  if (ALIAS[r.e.id] || !CARD_OF.has(r.base.toLowerCase())) continue;
  if (r.e.equipment == null) throw new Error(`${r.e.id}: no equipment (Bodyweight is "body only")`);
  if ((r.mods.equip === 'Smith Machine') !== /smith/i.test(r.e.id) || (r.mods.equip === 'Smith Machine' && r.e.equipment !== 'machine')) {
    throw new Error(`${r.e.id}: a Smith machine row needs the tool Smith Machine and equipment machine`);
  }
}
// No id of the app list is lost (D90): each one is a row here or an alias.
for (const id of Object.keys(GRID_ALIAS)) if (rows.some((r) => r.e.id === id)) throw new Error(`GRID_ALIAS: ${id} is still made`);
checkFrozen(rows.filter((r) => !ALIAS[r.e.id]).map((r) => r.e.id), { ...ALIAS, ...GRID_ALIAS }, 'exercise_variants');
const wi = args.indexOf('--write');
if (wi >= 0) {
  // Every exercise gets its move (D69 clean-up): a card with one exercise
  // is a move too, so search finds a clean move name for every card. An
  // aliased one gets only its alias.
  const out = rows.map((r) => (ALIAS[r.e.id] ? { ...r.e, alias: ALIAS[r.e.id] } : { ...r.e, base: r.base, mods: r.mods }));
  for (const [id, alias] of Object.entries(GRID_ALIAS)) out.push({ id, alias, grid: true });
  fs.writeFileSync(args[wi + 1], '[\n' + out.map((r) => JSON.stringify(r)).join(',\n') + '\n]\n');
  console.log('written', out.length, 'in groups:', inGroup.size);
}
