// Splits each exercise name into a base move and normalized modifiers (D55)
// and writes them into assets/exercises/exercises.json. Run it again after
// editing the list: node tools/exercise_variants.mjs <in.json> --write <out.json> [--report]
// The full list is tools/exercise_db.json; tools/exercise_select.mjs then cuts
// it down into assets/exercises/exercises.json (D67).
import fs from 'node:fs';
import { variationId } from './exercise_names.mjs';

const args = process.argv.slice(2);
// The grid variations (D80, `grid: true`) are made again on every run.
const all = JSON.parse(fs.readFileSync(args[0], 'utf8')).filter((e) => !e.grid);

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

// Database fields that are wrong for the move (D57). The key is a name or an id.
const FIX = {
  'Bench Press - With Bands': { equipment: 'barbell' }, // a barbell bench press with bands
  'Rope Jumping': { equipment: 'body only' }, // a jump rope is cheap home gear (D69 clean-up)
  // Gear `other` that is body only (D50): dip bars, rings, a pull-up bar,
  // an ab wheel, a captain's chair, a box. All other `other` gear stays hidden.
  'Dips_-_Chest_Version': { equipment: 'body only' }, Parallel_Bar_Dip: { equipment: 'body only' },
  Ring_Dips: { equipment: 'body only' }, Weighted_Bench_Dip: { equipment: 'body only' },
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
  // machine has the same angle.
  Machine_Bench_Press: ['Chest Press', {}],
  Leverage_Chest_Press: ['Chest Press', { type: 'Plate-Loaded' }],
  Leverage_Decline_Chest_Press: ['Chest Press', { angle: 'Decline' }],
  Leverage_Incline_Chest_Press: ['Chest Press', { angle: 'Incline' }],
  Machine_Shoulder_Military_Press: ['Shoulder Press', {}],
  Leverage_Shoulder_Press: ['Shoulder Press', { type: 'Plate-Loaded' }],
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
  'V-Bar_Pullup': ['Pull-Up', { attach: 'V-Bar' }],
  'Wide-Grip_Rear_Pull-Up': ['Pull-Up', { width: 'Wide Grip' }],
  Pullups: ['Pull-Up', {}],
  'Chin-Up': ['Pull-Up', { hand: 'Reverse Grip' }],
  // Band Assisted and Weighted are one Type row (D80: never both).
  'Band_Assisted_Pull-Up': ['Pull-Up', { type: 'Band Assisted' }],
  Weighted_Pull_Ups: ['Pull-Up', { type: 'Weighted' }],
  Muscle_Up: ['Muscle-Up', {}],
  'Full_Range-Of-Motion_Lat_Pulldown': ['Lat Pulldown', { type: 'Full Range' }],
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
  Standing_Towel_Triceps_Extension: ['Towel Triceps Extension', {}],
  Body_Tricep_Press: ['Skullcrusher', {}],
  'Close-Grip_Push-Up_off_of_a_Dumbbell': ['Close-Grip Dumbbell Push-Up', {}],
  // Rear delts: a rear delt raise is a reverse fly.
  Cable_Rear_Delt_Fly: ['Reverse Fly', {}],
  Dumbbell_Lying_Rear_Lateral_Raise: ['Reverse Fly', { position: 'Lying' }],
  'Dumbbell_Lying_One-Arm_Rear_Lateral_Raise': ['Reverse Fly', { position: 'Lying', side: 'One Arm' }],
  Bent_Over_Dumbbell_Rear_Delt_Raise_With_Head_On_Bench: ['Reverse Fly', { type: 'Head Supported' }],
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
  Trap_Bar_Deadlift: ['Deadlift', { type: 'Trap Bar' }],
  Goblet_Squat: ['Goblet Squat', {}],
  Front_Squat_Clean_Grip: ['Front Squat', {}],
  Front_Barbell_Squat: ['Front Squat', { type: 'Cross-Arm' }],
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
  Hyperextensions_With_No_Hyperextension_Bench: ['Back Extension', { type: 'Floor' }],
  Hyperextensions_Back_Extensions: ['Back Extension', {}],
  Weighted_Ball_Hyperextension: ['Back Extension', {}],
  Kneeling_Arm_Drill: ['Kneeling Arm Drill', {}],
  Standing_Long_Jump: ['Standing Long Jump', {}],
  Front_Box_Jump: ['Box Jump', {}],
  Kettlebell_Sumo_High_Pull: ['Kettlebell Sumo High Pull', {}],
  'One-Arm_Kettlebell_Swings': ['Kettlebell Swing', { side: 'One Arm' }],
  Vertical_Swing: ['Dumbbell Swing', {}],
  Ball_Leg_Curl: ['Leg Curl', {}],
  Natural_Glute_Ham_Raise: ['Nordic Curl', {}],
  'Floor_Glute-Ham_Raise': ['Nordic Curl', { type: 'Floor' }],
  Glute_Ham_Raise: ['Nordic Curl', {}],
  Thigh_Abductor: ['Hip Abduction', {}],
  Thigh_Adductor: ['Hip Adduction', {}],
  Band_Hip_Adductions: ['Hip Adduction', {}],
  // Calf raises: a position everywhere (variation audit).
  Smith_Machine_Calf_Raise: ['Calf Raise', { position: 'Standing' }],
  'Calf_Raises_-_With_Bands': ['Calf Raise', { position: 'Standing' }],
  Calf_Press_On_The_Leg_Press_Machine: ['Calf Raise', { type: 'Leg Press' }],
  Rocking_Standing_Calf_Raise: ['Calf Raise', { type: 'Rocking' }],
  Calf_Raise_On_A_Dumbbell: ['Calf Raise on a Dumbbell', {}],
  Freehand_Jump_Squat: ['Jump Squat', {}],
  Weighted_Jump_Squat: ['Jump Squat', {}],
  // Core.
  Ab_Crunch_Machine: ['Crunch', {}],
  Exercise_Ball_Crunch: ['Crunch', {}],
  Rope_Crunch: ['Rope Crunch', { position: 'Kneeling' }],
  Standing_Cable_Wood_Chop: ['Wood Chop', {}],
  Cable_Russian_Twists: ['Russian Twist', {}],
  Alternate_Heel_Touchers: ['Heel Touch', {}],
  Air_Bike: ['Bicycle Crunch', {}],
  Flat_Bench_Lying_Leg_Raise: ['Lying Leg Raise', {}],
  Hanging_Pike: ['Hanging Leg Raise', { type: 'Pike' }],
  Knee_Hip_Raise_On_Parallel_Bars: ['Hanging Leg Raise', { type: "Captain's Chair" }],
  Side_Bridge: ['Side Plank', {}],
  Barbell_Ab_Rollout: ['Ab Rollout', {}],
  'Barbell_Ab_Rollout_-_On_Knees': ['Ab Rollout', { position: 'Kneeling' }],
  Ab_Roller: ['Ab Rollout', { type: 'Ab Wheel' }],
  'Exercise_Ball_Pull-In': ['Ball Pull-In', {}],
  Mountain_Climbers: ['Mountain Climber', {}],
  Overhead_Slam: ['Ball Slam', {}],
  Rope_Jumping: ['Jump Rope', {}],
  Double_Leg_Butt_Kick: ['Butt Kick', {}],
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
  Power_Clean: ['Clean', {}],
  Landmine_Linear_Jammer: ['Landmine Press', {}],
  JM_Press: ['JM Press', {}],
  'Kettlebell_Turkish_Get-Up_Squat_style': ['Turkish Get-Up', {}],
  // One cardio machine card with a Type row.
  Running_Treadmill: ['Cardio Machine', { type: 'Treadmill' }],
  Bicycling_Stationary: ['Cardio Machine', { type: 'Bike' }],
  Rowing_Stationary: ['Cardio Machine', { type: 'Rower' }],
  Elliptical_Trainer: ['Cardio Machine', { type: 'Elliptical' }],
  Stairmaster: ['Cardio Machine', { type: 'Stairs' }],
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
    'Pike Push-Up', { type: 'Elevated' }],
  ['Wall_Walk', 'Wall Walk', bw('strength', 'intermediate', 'push', 'compound', 'shoulders'), 'Wall Walk', {}],
  ['Wall_Handstand_Hold', 'Wall Handstand Hold', bw('strength', 'intermediate', 'static', 'compound', 'shoulders'),
    'Wall Handstand Hold', {}],
  ['Prone_Y-T-W_Raise', 'Prone Y-T-W Raise', bw('strength', 'beginner', 'pull', 'isolation', 'shoulders'), 'Prone Y-T-W Raise', {}],
  ['Bodyweight_Calf_Raise', 'Bodyweight Calf Raise', bw('strength', 'beginner', 'push', 'isolation', 'calves'), 'Calf Raise',
    { position: 'Standing' }],
  ['Single-Leg_Calf_Raise', 'Single-Leg Calf Raise', bw('strength', 'intermediate', 'push', 'isolation', 'calves'),
    'Calf Raise', { side: 'One Leg', position: 'Standing' }],
  ['Pogo_Hops', 'Pogo Hops', bw('plyometrics', 'beginner', 'push', 'compound', 'calves'), 'Pogo Hops', {}],
  ['Towel_Bicep_Curl', 'Towel Bicep Curl', bw('strength', 'beginner', 'pull', 'isolation', 'biceps'), 'Bicep Curl', { type: 'Towel' }],
  ['Inverted_Bicep_Curl', 'Inverted Bicep Curl', bw('strength', 'intermediate', 'pull', 'isolation', 'biceps'),
    'Bicep Curl', { type: 'Inverted' }],
  ['Dead_Hang', 'Dead Hang', bw('strength', 'beginner', 'static', 'isolation', 'forearms'), 'Dead Hang', {}],
  ['Towel_Hang', 'Towel Hang', bw('strength', 'intermediate', 'static', 'isolation', 'forearms'), 'Dead Hang', { type: 'Towel' }],
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
  ['Towel_Row', 'Towel Row', bw('strength', 'beginner', 'pull', 'compound', 'middle back'), 'Inverted Row', { type: 'Towel' }],
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

// Old base and mods fields are dropped first, so the tool can run on its own output.
const rows = all.map(({ base: _oldBase, mods: _oldMods, ...raw }) => {
  const e = { ...raw, ...FIX[raw.name], ...FIX[raw.id] };
  const p = EXPLICIT[e.name] ? { base: EXPLICIT[e.name][0], mods: { ...EXPLICIT[e.name][1] } } : parse(e.name);
  let base = OVERRIDE[e.name] ?? p.base;
  base = MERGE[base.toLowerCase()] ?? base;
  const move = MOVE[e.id];
  if (typeof move === 'string') base = move;
  else if (move) [base, p.mods] = [move[0], { ...move[1] }];
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

// The variation grids (D80): a move's axes and their values, per
// equipment. Every combination a gym or home lifter does is a variation;
// `not` lists the combinations that make no sense (a partial set of
// modifiers; a list = any of these values). `add` lists single extra
// variations. A new variation copies its fields from the closest one of the
// move with the same equipment; its level is `level` (else the closest
// one's) plus the largest raise and the largest cut of `adj`. Its id is
// variationId (tools/exercise_names.mjs): stable, never renamed.
const GRID = [
  // Knee push-ups with every grip width; decline push-ups too. A knee
  // push-up is not done on an incline or a decline.
  { move: 'Push-Up', equip: 'Bodyweight', level: 'beginner',
    axes: { type: [null, 'Knee'], angle: [null, 'Incline', 'Decline'], width: ['Close Grip', 'Medium Grip', 'Wide Grip'] },
    not: [{ type: 'Knee', angle: ['Incline', 'Decline'] }], adj: { Knee: -1, Decline: 1, 'Close Grip': 1 } },
  // The incline squeeze press. No decline squeeze or neutral-grip squeeze.
  { move: 'Bench Press', equip: 'Dumbbell',
    axes: { angle: [null, 'Incline', 'Decline'], type: [null, 'Squeeze'], hand: [null, 'Neutral Grip'] },
    not: [{ type: 'Squeeze', hand: 'Neutral Grip' }, { angle: 'Decline', type: 'Squeeze' }, { angle: 'Decline', hand: 'Neutral Grip' }] },
  // Pull-up grips: overhand, chin-up (reverse) and neutral; band-assisted
  // and weighted with each. No wide chin-up or wide neutral grip.
  { move: 'Pull-Up', equip: 'Bodyweight', level: 'intermediate',
    axes: { hand: [null, 'Reverse Grip', 'Neutral Grip'], width: ['Close Grip', 'Medium Grip', 'Wide Grip'], type: [null, 'Band Assisted', 'Weighted'] },
    not: [{ width: 'Wide Grip', hand: ['Reverse Grip', 'Neutral Grip'] }, { width: 'Close Grip', hand: 'Neutral Grip' },
      { type: ['Band Assisted', 'Weighted'], width: ['Close Grip', 'Wide Grip'] }],
    adj: { 'Band Assisted': -1, Weighted: 1 } },
  // Every stance on the Smith machine.
  { move: 'Squat', equip: 'Smith Machine', axes: { stance: [null, 'Narrow Stance', 'Wide Stance'] } },
  // Dumbbell curls: seated and alternating together; EZ bar grip widths.
  { move: 'Bicep Curl', equip: 'Dumbbell', axes: { position: [null, 'Seated'], side: [null, 'Alternating', 'One Arm'] },
    not: [{ position: 'Seated', side: 'One Arm' }] },
  { move: 'Bicep Curl', equip: 'EZ Bar', axes: { width: ['Close Grip', 'Medium Grip', 'Wide Grip'] } },
  { move: 'Bent-Over Row', equip: 'Dumbbell', axes: { hand: [null, 'Neutral Grip', 'Reverse Grip'] } },
  // Seated cable row with a wide bar or an underhand bar.
  { move: 'Seated Cable Row', equip: 'Cable', axes: { width: ['Medium Grip', 'Wide Grip'], hand: [null, 'Reverse Grip'] },
    not: [{ width: 'Wide Grip', hand: 'Reverse Grip' }] },
  // Dumbbell shoulder press: seated or standing, alternating or neutral grip.
  { move: 'Shoulder Press', equip: 'Dumbbell',
    axes: { position: ['Seated', 'Standing'], side: [null, 'Alternating'], hand: [null, 'Neutral Grip'] },
    not: [{ side: 'Alternating', hand: 'Neutral Grip' }] },
  { move: 'Shoulder Press', equip: 'Kettlebell', add: [{ side: 'One Arm' }] },
  { move: 'Calf Raise', equip: 'Dumbbell', axes: { position: ['Standing', 'Seated'], side: [null, 'One Leg'] } },
  { move: 'Lat Pulldown', equip: 'Cable', axes: { width: ['Close Grip', 'Medium Grip', 'Wide Grip'], hand: [null, 'Reverse Grip'] },
    not: [{ width: 'Wide Grip', hand: 'Reverse Grip' }] },
  { move: 'Triceps Pushdown', equip: 'Cable', add: [{ side: 'One Arm', hand: 'Reverse Grip' }] },
  { move: 'Hammer Curl', equip: 'Dumbbell', add: [{ position: 'Seated' }] },
  { move: 'Lateral Raise', equip: 'Dumbbell', add: [{ side: 'One Arm' }] },
  { move: 'Front Raise', equip: 'Dumbbell', add: [{ side: 'Alternating' }] },
  { move: 'Skullcrusher', equip: 'EZ Bar', add: [{ angle: 'Incline' }] },
  { move: 'Skullcrusher', equip: 'Dumbbell', add: [{ angle: 'Incline' }] },
  { move: 'Reverse Fly', equip: 'Dumbbell', add: [{ angle: 'Incline' }] },
  { move: 'Split Squat', equip: 'Barbell', from: 'Dumbbell', level: 'intermediate', add: [{}, { type: 'Bulgarian' }] },
  { move: 'Glute Bridge', equip: 'Dumbbell', from: 'Barbell', level: 'beginner', add: [{}] },
  { move: 'Romanian Deadlift', equip: 'Kettlebell', from: 'Dumbbell', add: [{}] },
  { move: 'Deadlift', equip: 'Kettlebell', from: 'Dumbbell', add: [{}] },
  { move: 'Shrug', equip: 'Smith Machine', from: 'Barbell', add: [{}] },
  { move: 'Reverse Curl', equip: 'EZ Bar', from: 'Barbell', add: [{}] },
  { move: 'Dip', equip: 'Bodyweight', add: [{ type: 'Weighted' }, { type: 'Band Assisted' }],
    adj: { 'Band Assisted': -1, Weighted: 1 }, level: 'intermediate' },
  { move: 'Inverted Row', equip: 'Bodyweight', add: [{ hand: 'Reverse Grip' }] },
  { move: 'Russian Twist', equip: 'Medicine Ball', from: 'Bodyweight', add: [{}] },
  { move: 'Russian Twist', equip: 'Dumbbell', from: 'Bodyweight', add: [{}] },
];
// The database equipment of an equipment modifier (for a new equipment on a move).
const EQUIP_DB = {
  Bodyweight: 'body only', Barbell: 'barbell', Dumbbell: 'dumbbell', Kettlebell: 'kettlebells', Cable: 'cable', Machine: 'machine',
  'Smith Machine': 'machine', Bands: 'bands', 'EZ Bar': 'e-z curl bar', 'Medicine Ball': 'medicine ball', 'Exercise Ball': 'exercise ball',
};
const matches = (mods, rule) => Object.entries(rule).every(([a, v]) => (Array.isArray(v) ? v : [v]).includes(mods[a] ?? null));
// Two modifier sets are the same variation (no width = Medium Grip, D57).
const sameMods = (a, b) => {
  const norm = (m) => ({ ...m, width: m.width ?? (WIDTH_EQUIP.has(m.equip) ? 'Medium Grip' : undefined) });
  const x = norm(a), y = norm(b);
  return AX_ALL.every((k) => (x[k] ?? null) === (y[k] ?? null));
};
const AX_ALL = ['equip', 'type', ...Object.keys(AXES)];
const combos = (axes) => Object.entries(axes).reduce((acc, [a, vs]) =>
  acc.flatMap((m) => vs.map((v) => (v == null ? { ...m } : { ...m, [a]: v }))), [{}]);
const generated = [];
for (const spec of GRID) {
  const g = groups.get(spec.move.toLowerCase());
  if (!g) throw new Error(`GRID: no move ${spec.move}`);
  const wanted = [...(spec.axes ? combos(spec.axes).filter((m) => !(spec.not ?? []).some((r) => matches(m, r))) : []), ...(spec.add ?? [])]
    .map((m) => ({ equip: spec.equip, ...m }));
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
    const { id: _i, name: _n, custom: _c, ...fields } = src.e;
    const e = { id, name: id, ...fields, equipment: spec.from ? EQUIP_DB[spec.equip] : src.e.equipment,
      level: L[Math.max(0, Math.min(2, lv))], custom: true, grid: true };
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
for (const id of Object.keys(MOVE)) if (!all.some((e) => e.id === id)) throw new Error(`MOVE: no exercise ${id}`);
const wi = args.indexOf('--write');
if (wi >= 0) {
  // Every exercise gets its move (D69 clean-up): a card with one exercise
  // is a move too, so search finds a clean move name for every card.
  const out = rows.map((r) => ({ ...r.e, base: r.base, mods: r.mods }));
  fs.writeFileSync(args[wi + 1], '[\n' + out.map((r) => JSON.stringify(r)).join(',\n') + '\n]\n');
  console.log('written', out.length, 'in groups:', inGroup.size);
}
