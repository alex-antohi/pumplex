# Original-app names → exercise ids

Used by `tools/import_original.mjs` (the `NAME_MAP` there; keep both the same).
Names match case-insensitive, trimmed. Ids are from `assets/exercises/exercises.json`; never change an id.
A name not in this table is skipped, and the script lists it.

Run (one time, for the owner):

```
node tools/import_original.mjs <original-backup.json> <out.json> [--into <main-backup.json>]
node tools/import_original.mjs --self-test
```

Then LOAD BACKUP on the phone with `<out.json>`. A file with no profile (no `--into`) keeps the lifter,
favorites and gear, and replaces only sessions and XP.

| Original name | Exercise id | App name (en) | Why, when unsure |
|---|---|---|---|
| Bench | `Barbell_Bench_Press_-_Medium_Grip` | Barbell Bench Press | |
| Close Bench | `Close-Grip_Barbell_Bench_Press` | Close-Grip Barbell Bench Press | |
| BB Row | `Bent_Over_Barbell_Row` | Barbell Bent-Over Row | |
| Pull up | `Pullups` | Pull-Up | The 85 kg is the lifter's body weight; it is saved as typed. |
| Side Raise | `Side_Lateral_Raise` | Dumbbell Lateral Raise | |
| Bicep Curl | `Dumbbell_Bicep_Curl` | Dumbbell Bicep Curl | 10 kg suggests dumbbells; the EZ bar curl is a separate name. |
| Rear Delt Fly | `Reverse_Flyes` | Dumbbell Reverse Fly | 5 kg suggests dumbbells, not a cable or machine. |
| LB Squat | `Barbell_Squat` | Barbell Squat | The list has no low-bar squat; this is the closest. |
| Good Morning | `Good_Morning` | Good Morning | |
| Lunges | `Barbell_Lunge` | Barbell Lunge | 42-52 kg on a barbell. |
| Leg curl | `Lying_Leg_Curls` | Lying Machine Leg Curl | Lying or seated is not known; lying is the common one. |
| Cable Ab Curls | `Cable_Crunch` | Kneeling Cable Crunch | "Ab curl" on a cable is the kneeling cable crunch. |
| Rolling DB Ext. | `Lying_Dumbbell_Tricep_Extension` | Dumbbell Skullcrusher | A rolling extension is a lying dumbbell triceps extension; no rolling variant. |
| DB Row | `One-Arm_Dumbbell_Row` | Dumbbell One-Arm Row | 25 kg; one-arm is the usual "DB row". |
| lat pulldown | `lat pulldown\|cable\|medium grip` | Lat Pulldown | |
| Front Raise | `Front_Dumbbell_Raise` | Dumbbell Front Raise | 7.5-10 kg suggests dumbbells. |
| ez bar curl | `EZ-Bar_Curl` | EZ Bar Bicep Curl | |
| face pulls | `Face_Pull` | Cable Face Pull | |
| Box Squat | `Box_Squat` | Box Squat | |
| Stiff Leg DL | `Stiff-Legged_Barbell_Deadlift` | Barbell Stiff-Legged Deadlift | |
| Bulgarian Split Squats | `Dumbbell_Bulgarian_Split_Squat` | Dumbbell Bulgarian Split Squat | 10 kg suggests dumbbells. |
| Leg Raise | `Flat_Bench_Lying_Leg_Raise` | Lying Leg Raise | 15 kg in a "Moderate Posterior Chain" slot: maybe a reverse hyperextension (`Reverse_Hyperextension`); the name says leg raise. |
| over head press | `Standing_Military_Press` | Standing Military Press | A standing barbell press (32 kg, 5×5 in the bench slot). |
