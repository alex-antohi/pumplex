# PUMPLEX rules table

Date: 21 November 2026. Status: draft v1 (numbers for beta testing).
Read with [data-schema.md](data-schema.md). Put every number below in one
constants file in the code, so it is easy to tune.

Sources of the ideas: Habitica (source code), D&D 5e, the Dark Souls and
Bloodborne board games, Gloomhaven. Rule from the brief: **rest never punishes
the user.** So there is no HP loss, no lost XP and no dropped currency.

## 1. XP

| Source | XP | Idea from |
|---|---|---|
| Working set | 10 × difficulty multiplier | Habitica XP per task |
| Set above the target | × 1.5, up to 2 × the target | Bonus without farming |
| Set beyond 2 × the target | 0 | Habitica diminishing returns |
| First set of the day | + 50 | Daily bonus |
| Weekly streak (N training days met) | + 5% XP per week in a row, max + 25% | Habitica streak bonus |
| Critical set | 3% chance, × 2 XP, "CRITICAL SET!" | Habitica crits |
| Bounty done | + 100 to + 300 | Gloomhaven battle goals |
| Achievement | per achievement (list TBD) | Habitica achievements |
| Old session (beta) | 150 each | Legacy conversion |

**Difficulty multiplier:** 1.0 at the lowest difficulty, rising in even steps to 2.0 at the highest.

**Order of calculation for one set:**

1. Base = 10 × difficulty multiplier.
2. If the set number is above the target and up to 2 × the target: × 1.5. Above 2 × the target: 0.
3. Critical roll (3%): × 2.
4. Streak bonus: × (1 + 0.05 × weeks in a row, max 0.25).
5. Round to a whole number.

The roll for a critical set must be repeatable (use a seed from the date, the exercise and the set number), so recalculating XP gives the same total.

## 2. Level curve

XP to go from level L to L + 1 (Habitica's formula):

| Level | XP to next level |
|---|---|
| 1–4 | 25 × L |
| 5 | 150 |
| 6 and up | round((0.25 × L² + 10 × L + 139.75) / 10) × 10 |

Examples: level 10 → 260, level 20 → 440, level 30 → 670, level 40 → 940, level 50 → 1,260.

Pace (a typical session is about 15 sets, or about 200 XP):

- Level 5 after the first one or two sessions.
- About 1 level per session around level 10.
- About 1 level per week (3 to 4 sessions) around level 40.

**Level-up:** a big animation, and a loot drop (gear with a rarity colour). The body does not change; the sliders stay as the user set them.

**Level 50: new game+** (Habitica rebirth, Gloomhaven retirement). Optional. The level goes back to 1. The character keeps a cosmetic badge and its gear, and gets + 10% XP for each completed run (max + 30%).

## 3. Streak

- The streak counts **training days per calendar week**. N comes from the difficulty.
- A week with N or more training days continues the streak. Missing days inside the week never break it.
- **Embers** (the Dark Souls spark, as a reward): a perfect week (N met) earns 1 ember, max 3. When a week misses N, 1 ember is used and the streak continues.
- With no ember, the streak goes to 0. Nothing else is lost.

## 4. How to measure progress

There are no kilos or reps, so progress comes from set targets and consistency.

### 4.1 Exercise mastery (Gloomhaven checkmarks)

- A session where an exercise reaches its set target gives that exercise 1 checkmark.
- 3 checkmarks = 1 mastery star. Max 5 stars per exercise.
- Stars show on the exercise card.

### 4.2 No progress → swap

- If an exercise gets no new checkmark in 3 weeks (and you did it at least twice in that time), the card suggests a swap from the class pool.
- This is the "change exercises when no progress" arrow in `pumplex.drawio`.

### 4.3 Difficulty climb (D&D milestones)

- If the weekly streak target is met 3 weeks in a row, and most of the workout's exercises have 3 or more stars, the app suggests the next difficulty level.
- The user decides. It is never automatic. The user can also go down at any time.

### 4.4 Character stats (Dark Souls stats)

Working sets feed one stat, by the exercise type:

| Exercise type | Stat |
|---|---|
| Weights, machines | STRENGTH |
| Cardio | ENDURANCE |
| Bodyweight | AGILITY |

- Each working set adds 1 point to its stat.
- The stats show the training balance without numbers about weight.
- They do not change XP (balance can come later).

## 5. Bounties (Gloomhaven battle goals)

- 1 to 3 small missions each week, picked from a list. Examples:
  - "12 sets of push-ups this week."
  - "Train on 3 days."
  - "Try an exercise you have not done yet."
- A bounty gives XP (section 1) and 1 checkmark on a "bounty board". 3 checkmarks = 1 item drop.
- Unfinished bounties expire. Nothing is lost.

## 6. Gear and loot

- Slots: top, bottom, shoes, head, weapon (from the data schema).
- Rarity colours: common, uncommon, rare, epic, legendary.
- Drop chances on level-up (draft): common 50%, uncommon 30%, rare 14%, epic 5%, legendary 1%.
- Gear is cosmetic in v1.

## 7. Not used (and why)

| Mechanic | Game | Why not |
|---|---|---|
| HP loss for missed tasks | Habitica | Rest must never punish. |
| Dropped souls when you die | Dark Souls | Same. |
| Lost echoes before banking | Bloodborne | Same. |
| Fixed XP per encounter | D&D | Replaced by XP per working set. |

## 8. Data needed (check against data-schema.md)

- Per exercise: checkmarks and stars (calculated from sessions).
- Embers count, bounties this week, bounty board checkmarks.
- Stats (calculated from sessions).
- Rebirth count (new game+).

The schema does not yet store embers, bounties, the bounty board or the rebirth count. Add them in the next schema update.
