# Grid sample for the owner (D90 step 3, part A)

Date: 25 Nov 2026. This is a sample. Read it before the agents write the other cards.

Part A wrote the full grid of 5 cards: Bench Press, Squat, Push-Up, Pull-Up and Bent-Over Row.
The rules are in `CARDS` in `tools/exercise_variants.mjs`. All new names are in `tools/grid_review.md`.
The score curves are in `tools/score_report.md`.

## How a score works (D91)

- Each card has a base score from 1 (Sofa) to 6 (Nightmare).
- Each value can have a level change, for example Knee −1 or One Arm +1.
- The score of a variation is the base score plus the changes of its values.
- The score stays inside 1–6.
- A new variation gets the database level of its score: 1–2 beginner, 3–4 intermediate, 5–6 expert.

## Bench Press

Base score: **3** (the flat barbell bench press).

| Tool | Axes and values | `not` rules |
|---|---|---|
| Barbell | Angle: Flat, Incline, Decline. Width: Close, Medium, Wide. Bands. Chains. | Bands and Chains only flat with a medium grip. Never Bands and Chains together. |
| Smith Machine (−1) | Angle: Flat, Incline, Decline. Width: Close, Medium, Wide. | A decline Smith press is medium grip only. |
| Dumbbell | Angle: Flat, Incline, Decline. Squeeze. Neutral Grip. One Arm. | No Squeeze with Neutral Grip or One Arm. No decline Squeeze, Neutral Grip or One Arm. No Neutral Grip with One Arm. |

Level changes: Squeeze −1, One Arm +1, Bands +1, Chains +1. The other values are 0.

Kept outside the grid (old ids, frozen): `Reverse_Band_Bench_Press` (not in the app list) and `Close-Grip_EZ-Bar_Press` (the one EZ bar row).

Count: 25 → **29** rows in the database, 24 → **28** in the app list. The cap is 30.

## Push-Up

Base score: **2** (the floor push-up).

| Tool | Axes and values | `not` rules |
|---|---|---|
| Bodyweight | Type: Knee, Plyo, Archer, Pseudo Planche. Angle: Flat, Incline, Decline. Width: Close, Medium, Wide. One Arm. | A knee push-up is flat. Plyo, Archer and Pseudo Planche are medium grip. No decline Plyo. Archer and Pseudo Planche are flat. One Arm: no type, medium grip, flat or incline. |
| Rings (+1) | Angle: Flat, Decline (feet up). | Rings have no grip width. |

Level changes: Knee −1, Incline −1, Decline +1, Close Grip +1, Reverse Grip +1, Plyo +2, Archer +2, Pseudo Planche +2, One Arm +4.

Kept outside the grid: `Incline_Push-Up_Reverse_Grip` (an odd old row, not in the app list).

Count: 17 → **21** rows in the database, 16 → **20** in the app list.

## The other 3 cards

- Squat: 17 → 17 (13 in the app). The grid adds nothing new. A narrow bodyweight squat would have the same name as the barbell one, and it is rare.
- Pull-Up: 14 → 19 (19 in the app). New: the machine chin-up and neutral grip, wide band-assisted, wide weighted, the ring pull-up.
- Bent-Over Row: 8 → 12. New: Pendlay row, alternating dumbbell rows, the reverse-grip Smith row.

## 8 example new names

| id | en | ro | score |
|---|---|---|---|
| `bench press\|smith machine\|incline\|close grip` | Incline Close-Grip Smith Machine Bench Press | Împins înclinat la Smith priză îngustă | 2 |
| `bench press\|smith machine\|incline\|wide grip` | Incline Wide-Grip Smith Machine Bench Press | Împins înclinat la Smith priză largă | 2 |
| `bench press\|smith machine\|wide grip` | Wide-Grip Smith Machine Bench Press | Împins la Smith priză largă | 2 |
| `bench press\|dumbbell\|incline\|one arm` | One-Arm Incline Dumbbell Bench Press | Împins înclinat cu gantere 1 braț | 4 |
| `push-up\|bodyweight\|plyo\|incline\|medium grip` | Incline Plyo Push-Up | Flotări pliometrice înclinate | 3 |
| `push-up\|bodyweight\|archer\|medium grip` | Archer Push-Up | Flotări arcaș | 4 |
| `push-up\|rings\|decline` | Decline Ring Push-Up | Flotări declinate la inele | 4 |
| `push-up\|bodyweight\|incline\|medium grip\|one arm` | One-Arm Incline Push-Up | Flotări înclinate 1 braț | 5 |

## Base score of the top 40 cards

The score is for the card's plain lift. Some cards have a tool change (in brackets).

| Rank | Card | Base score |
|---|---|---|
| 1 | Bench Press | 3 (Smith −1) |
| 2 | Squat | 3 (Bodyweight −2, Bands −2, Dumbbell −1, Smith −1) |
| 3 | Shoulder Press | 3 (Machine, Smith, Cable, Bands −1) |
| 4 | Push-Up | 2 (Rings +1) |
| 5 | Pull-Up | 4 (Machine −3) |
| 6 | Bent-Over Row | 3 (Dumbbell, Kettlebell, Smith −1) |
| 7 | Romanian Deadlift | 3 (Dumbbell, Kettlebell −1; Bodyweight −2) |
| 8 | Bicep Curl | 1 (Bodyweight +1) |
| 9 | Deadlift | 4 (Dumbbell, Kettlebell, Cable, Machine −2) |
| 10 | Lat Pulldown | 1 |
| 11 | Crunch | 1 |
| 12 | One-Arm Row | 2 |
| 13 | Plank | 1 |
| 14 | Calf Raise | 1 |
| 15 | Fly | 2 (Machine −1) |
| 16 | Lunge | 2 (Barbell +1) |
| 17 | Lateral Raise | 1 |
| 18 | Dip | 4 (Machine −3, Bench −2) |
| 19 | Triceps Pushdown | 1 |
| 20 | Leg Press | 1 |
| 21 | Seated Cable Row | 1 |
| 22 | Leg Curl | 1 (Bodyweight +2, Ball +1) |
| 23 | Leg Extension | 1 |
| 24 | Skullcrusher | 2 |
| 25 | Split Squat | 2 |
| 26 | Overhead Triceps Extension | 2 (Cable −1) |
| 27 | Hammer Curl | 1 |
| 28 | Preacher Curl | 1 |
| 29 | Hip Thrust | 2 (Bodyweight −1) |
| 30 | Shrug | 1 |
| 31 | Hanging Leg Raise | 4 |
| 32 | Sit-Up | 1 (Decline +1) |
| 33 | Goblet Squat | 2 |
| 34 | Face Pull | 1 |
| 35 | Reverse Fly | 1 |
| 36 | Upright Row | 2 |
| 37 | Chest Press | 1 |
| 38 | Inverted Row | 2 (One Arm +3, Towel −1) |
| 39 | Front Raise | 1 |
| 40 | Glute Bridge | 1 |

The other cards use the default changes: Rings +1, One Arm +1, One Leg +1, Knee −1, Band Assisted −1, Weighted +1, Plyo +1, Bands +1, Chains +1 (and a few more in `DEFAULT_CHANGE`).

## Class curves (all 545 exercises of the app list)

Share per score 1–6, in %. Target: 7 / 16 / 27 / 27 / 16 / 7.

| Class | n | 1 | 2 | 3 | 4 | 5 | 6 | Off by |
|---|---|---|---|---|---|---|---|---|
| Scrapper | 148 | 20 | 32 | 20 | 16 | 8 | 3 | 30 |
| Bargain Bruiser | 309 | 27 | 39 | 18 | 10 | 5 | 1 | 43 |
| Plate Paladin | 356 | 24 | 36 | 23 | 12 | 5 | 1 | 37 |
| Cablemancer | 259 | 42 | 36 | 9 | 7 | 4 | 2 | 55 |

All 4 classes are far from the target (more than 20 points). The scores are honest: gym lifts lean easy, and machines are easier. The hard end is thin. The Scrapper is closest, because of the skills. To move the curve, add hard lifts (part B), not higher scores.

## Questions for the owner

1. Are the base scores right? Most isolation lifts are 1 (Sofa).
2. Is a score of 1 for the assisted pull-up machine right (Pull-Up 4, Machine −3)?
3. Pull-Up now has more variations than Bicep Curl. So its rank goes from 8 to 5 (the same tier, more variations first). Unlock did not change.
