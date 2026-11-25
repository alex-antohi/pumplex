# Exercise list plan: bases by hand, variations from rules

Date: 25 Nov 2026. Status: **decided (D90), not built.** This file is the brief for the agents that build it.

## Why

A debate with measurements on the real list (25 Nov 2026) found:

- 527 exercises in 164 cards. 82 cards have 1 variation; Bench Press has 24.
- The variation grids are 64% full (527 of 823 slots, with the tool fixed).
- A blind cross-product is not usable: about 475,000 combinations per lift.
- About 10 lifts are in the list twice under other names (for example Bent-Over Triceps Extension = Kickback, Triceps Press = Skullcrusher, Dip Triceps = Parallel Bar Dip).
- The `type` axis is a junk drawer: 39 values, 26 used once. Wrist Curl grips are reversed. "Two Arms" is on 6 rows only. Deadlift exists on Cable and Machine.
- Tool gaps: trap bar, landmine, rings/TRX and ab wheel have 1 exercise each; plate has 0.
- Too many: 14 one-variation jump cards; 12 powerlifting rows with bands or chains.
- 198 names (38%) are hand-translated; 329 are composed.
- Reality check on 4 real programs (133 lifts, listed from memory): 86% found exactly. The misses are mostly a missing base lift or a missing tool. No generator makes those.

## The model

1. **A person writes each base lift**: pattern, rank, muscles, and its tools. For each tool: the allowed axes and values, the `not` rules, and the level changes. This is today's `GRID` in `tools/exercise_variants.mjs` (D80), extended to every card.
2. **The build makes every combination the rules allow**, and nothing else. A `type` value exists only where a base names it.
3. **Cap: 30 variations per card.**
4. **Ids are frozen.** The 527 current ids never change. New ids are `base|values` (D80). The build fails if an old id is lost. A merged row keeps an alias to its new id.
5. **Names are composed by default** (D80). A hand name stays only where no rule makes it. Gym names (Skullcrusher, Arnold Press) stay as bases, with search words.
6. **Checks in the build:** a review file lists each new name (en and ro); the build fails on a missing Romanian form; a report lists empty card + tool slots.

### Example: Bench Press

- Tools: Barbell, Smith Machine, Dumbbell.
- Angle: Flat, Incline, Decline.
- Barbell and Smith: grip width Close, Medium, Wide.
- Dumbbell: Squeeze, Neutral Grip, One Arm.
- Barbell only: Bands, Chains.
- Rules: no Squeeze + Neutral; no Decline Squeeze; no Decline Neutral; Bands and Chains only Flat with Medium Grip.
- Result: about 30 variations (24 today).
- An old id stays: `Barbell_Incline_Bench_Press_-_Medium_Grip`. A new id: `bench press|smith machine|incline|close grip`.
- Names: en "Incline Close-Grip Smith Machine Bench Press"; ro "Împins înclinat la Smith priză îngustă".

## Owner's choices (25 Nov 2026)

1. Variations come from rules for each card.
2. New tools: first choice was Rings/TRX, Landmine, Trap Bar and Plate. **Changed after the research (the owner left this call to the agent): only Rings/TRX becomes a new tool.** Trap Bar stays a Deadlift chip, Landmine stays its one card, and Plate is not a tool. Merge the two balls into **Ball**. Do not add sled, sandbag or battle rope (D56 stays).
3. Bands and Chains rows stay only on Bench Press, Squat and Deadlift.
4. The 14 one-variation jump cards fold into about 4 cards.
5. Cap per card: 30.
6. Add the calisthenics skills: Front Lever, Support Hold, Shrimp Squat.

## Tools after the change

Bodyweight, Dumbbell, Barbell, EZ Bar, Kettlebell, Cable, Machine, Smith Machine, Bands, Ball, Rings/TRX. The CHALK rack goes from 11 to 11 slots: the two balls merge, the towel stays a word, and Rings/TRX is the one new icon.

Class gear (D50, and the lit rule of D89):

- Scrapper (Haiduc): Bodyweight, Rings/TRX.
- Bargain Bruiser: Dumbbell, Kettlebell, Bands, Ball (+ Bodyweight).
- Plate Paladin: Barbell, EZ Bar, Dumbbell, Kettlebell (+ Bodyweight). Trap Bar and Landmine lifts count as Paladin gear.
- Cablemancer: Machine, Cable, Smith Machine (+ Bodyweight).

## What to add (after the research)

The research read 19 published programs (see "Research results"). It confirmed some holes of the debate and found no support for others. Add these, in this order:

1. **Seated row machine** (Seated Cable Row + tool Machine). Confirmed.
2. **Shrimp Squat** and **Support Hold** (new bases). Confirmed (BWF Recommended Routine).
3. **Assisted pull-up and a pulldown machine** (machine and band). Programs name them as alternatives.
4. **Rings/TRX lifts:** ring dip, ring row, ring push-up, ring ab rollout.
5. **Pseudo Planche Push-Up** (a Push-Up variation) and **bodyweight one-leg Romanian Deadlift**.
6. **Pallof Press with bands.**
7. **Decline Sit-Up** and a machine crunch, if the card lacks them (weighted core).
8. **Bodyweight leg curl** (slider or towel) and **dumbbell Rear Delt Row**.
9. **Jumping Lunge** (inside the folded jump cards) and **Back Bridge** (new base, low rank).
10. **Front Lever** and **Lateral Lunge** (the owner chose the skills; no program in the sample uses them, so give them a low rank).

Dropped as required work (no program supports them; the grid rules may still give some for free): band row/press/curl, Lat Pulldown neutral and rope, Seated Cable Row V-bar, dumbbell and band leg curl, Smith or machine hip thrust. Not added: Plate Pinch, Kettlebell March, one-arm pull-up, donkey machine calf raise, "monkey row", ring Pallof press.

## Rank changes (after the research)

Programs that use the base, out of 19, and our rank today:

| Base | Programs | Rank now | Rank to set |
|---|---|---|---|
| Squat | 16 | 5 | top 2 |
| Bent-Over Row | 9 | 15 | about 6 |
| Romanian Deadlift | 9 | 16 | about 7 |
| One-Arm Row | 7 | 21 | about 12 |
| Fly | 7 | 25 | about 15 |
| Split Squat | 6 | 50 | about 25 |

Keep Push-Up (rank 4) and Hip Thrust (rank 29) where they are: the sample is heavy on barbell programs and bro splits, so it counts home and glute work too low. The 86 bases that no program uses keep their place in the list; they only never move up.

## Expected size (estimates; no generator was run)

- 527 → fewer than the debate's 720, because the research cut the required additions. The build gives the real number.
- 164 → about 160 cards (merge about 10, add about 8).
- Hand-translated names: 198 → about 90.
- Real-program coverage: 86% → about 96%.

## Difficulty score 1–6 (D91)

Measured on 25 Nov 2026: the 3 database levels are lopsided. Of 527 exercises, 69% are beginner, 28% intermediate and 4% expert (20 exercises). Per class (by gear): Haiduc 62 / 30 / 8, Bruiser 65 / 31 / 4, Paladin 59 / 36 / 5, Cablemancer 77 / 19 / 4. Three levels are also too coarse for six modes.

- Each exercise gets a **difficulty score from 1 to 6**, one per mode (1 Sofa … 6 Nightmare). It replaces the 3 levels in the app list. The database file keeps its levels.
- A base lift has a base score. A variation changes it with the level changes of its values (D80), for example Knee −1, Decline +1, One Arm +1. The score stays inside 1–6.
- **HARD badge** (D89): an exercise shows HARD when its score is above the lifter's mode.
- **XP** (D71, D77): the rate of a set is the lower of the mode's rate and the rate of the exercise's score. D77's three tiers become six: score n pays at most mode n's rate.
- **Target shape per class (by gear): a bell curve.** About 7%, 16%, 27%, 27%, 16% and 7% for scores 1 to 6.
- **The curve is a target, not a quota.** Score each lift honestly; never call an easy lift hard to fill a slot. Real gym lifts lean easy, and machines stay easier than free weights, so the hard end may stay thin.
- The build tool prints the curve per class, and per class and body part, and warns when a class is far from the target. Use the warning to choose which lifts to add (the skills in "What to add" fill the hard end).
- Old data: sets and favorites do not store a level, so nothing needs a migration. XP already earned stays.

## Build steps

1. **Clean.** Merge the duplicate lifts (keep aliases). Fix Two Arms and the Wrist Curl grips. Split `type` into real axes. Remove Deadlift on Cable and Machine if it is not a real lift.
2. **Add bases and tools by hand.** Rings/TRX, the items in "What to add", and the rank changes.
3. **Write the grid.** The top 40 cards first, then the rest. Give every base its difficulty score (1–6) and every value its level change. Run the review file and read every new name. Check the curve report per class.
4. **Move names.** Hand names become composed where a rule gives the same name. Keep the keys of old ids for saved sets.

After each step: run the data tools, `flutter analyze`, `flutter test`. Saved sets, favorites, Today and forged moves must keep working.

Also needed in the app: 1 new rack icon for CHALK (Rings/TRX, D87) via `tools/tool_icons.mjs`, the new tool in the CHALK words, and its Romanian name (INELE / TRX).

## Research results (25 Nov 2026)

One agent read 19 published programs (8 barbell, 5 dumbbell or home, 3 bodyweight, 3 machine or general gym) and compared their 164 distinct lifts with our list. It also compared names with open lists (wger, free-exercise-db, wrkout/exercises.json). Nothing was copied.

- **Coverage: 143 of 164 lifts are in our list exactly (87%).** 12 have the card but not that tool or variation. 9 have no card.
- **Every lift that 2 or more programs use is already in the list.** Each of the 21 gaps comes from one program only.
- Per group (exact / card only / missing): barbell 64/2/0, dumbbell 36/3/0, bodyweight 44/7/6, machine 61/0/3. Bodyweight is the weakest group.
- Tools in the programs: Bodyweight 103, Dumbbell 95, Barbell 67, Machine 39, Cable 29, EZ Bar 6, Bands 2, Rings 2, and 1 each for Smith, Plate, the balls and Kettlebell. Landmine and Trap Bar: 0.
- Programs need no new tool besides rings. They use a pull-up bar, dip bars, an ab wheel and cable attachments, which our axes already hold.

Limits: reddit.com was blocked, so the r/bodyweightfitness routine came from two copies, and its Minimalist and Primer routines were not read. nSuns and 5/3/1 BBB were not read. Several sites returned 403. The sample is heavy on barbell programs.

To check: D56 removed olympic lifts, but the list holds Clean, Clean and Press and Kettlebell Sumo High Pull. The owner kept Power Clean on purpose (23 Nov 2026); decide the other three in step 1.

## Risks

- A rule gap makes a bad combination. The review file and the cap limit this.
- Many new Romanian names: the agreement rules (D80) must cover every new part.
- Effort: about 6–8 days of agent work.
