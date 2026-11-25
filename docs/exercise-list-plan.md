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
2. New tools: **Rings/TRX, Landmine, Trap Bar, Plate.** Merge the two balls into **Ball**. Do not add sled, sandbag or battle rope (D56 stays).
3. Bands and Chains rows stay only on Bench Press, Squat and Deadlift.
4. The 14 one-variation jump cards fold into about 4 cards.
5. Cap per card: 30.
6. Add the calisthenics skills: Front Lever, Support Hold, Shrimp Squat.

## Tools after the change

Bodyweight, Dumbbell, Barbell, EZ Bar, Kettlebell, Cable, Machine, Smith Machine, Bands, Ball, Rings/TRX, Landmine, Trap Bar, Plate.

Class gear (D50, and the lit rule of D89) — proposal, check when building:

- Scrapper (Haiduc): Bodyweight, Rings/TRX.
- Bargain Bruiser: Dumbbell, Kettlebell, Bands, Ball, Plate (+ Bodyweight).
- Plate Paladin: Barbell, EZ Bar, Dumbbell, Kettlebell, Trap Bar, Landmine, Plate (+ Bodyweight).
- Cablemancer: Machine, Cable, Smith Machine (+ Bodyweight).

## The 10 holes to fill

1. Machine and band vertical pull (machine pulldown, assisted pull-up, band pulldown).
2. A seated row machine.
3. Band row, band press, band curl.
4. Ring row and ring push-up.
5. Lat Pulldown: neutral grip and rope.
6. Seated Cable Row: V-bar.
7. Weighted core (sit-up, crunch, plank variations).
8. Dumbbell and band leg curl.
9. Smith or machine hip thrust.
10. Missing bases: Lateral Lunge, Shrimp Squat, Support Hold, Front Lever.

## Expected size (estimates; no generator was run)

- 527 → about 720 exercises.
- 164 → about 160 cards (merge about 10, add about 8).
- Hand-translated names: 198 → about 90.
- Real-program coverage: 86% → about 96%.

## Build steps

1. **Clean.** Merge the duplicate lifts (keep aliases). Fix Two Arms and the Wrist Curl grips. Split `type` into real axes. Remove Deadlift on Cable and Machine if it is not a real lift.
2. **Add bases and tools by hand.** The new tools, the holes above, the calisthenics skills. Check real programs first (see "Research" below).
3. **Write the grid.** The top 40 cards first, then the rest. Run the review file and read every new name.
4. **Move names.** Hand names become composed where a rule gives the same name. Keep the keys of old ids for saved sets.

After each step: run the data tools, `flutter analyze`, `flutter test`. Saved sets, favorites, Today and forged moves must keep working.

Also needed in the app: 4 new rack icons for CHALK (D87) via `tools/tool_icons.mjs`, the new tools in the CHALK words, and Romanian names for the new tools.

## Research before step 2

Check published programs and open exercise lists (sites and GitHub repos) for the lifts they use, so the base list comes from real programs and not from memory.

## Risks

- A rule gap makes a bad combination. The review file and the cap limit this.
- Many new Romanian names: the agreement rules (D80) must cover every new part.
- Effort: about 6–8 days of agent work.
