# PUMPLEX rules table

Date: 21 November 2026, updated 22 November 2026 (D33–D35). Status: draft v1.1 (numbers for beta testing).
Read with [data-schema.md](data-schema.md) and [decisions.md](decisions.md) (D19 wins over this table; D34 and D35 win over D19).
Every number below is in one constants file, `lib/game/rules.dart`, so it is easy to tune.
The numbers per difficulty mode are in [app-flow.md](app-flow.md) §3.

In the app now: §1 (except bounties), §2 (except loot drops and new game+).
Removed on 22 Nov 2026: the streak and embers of §3 (D34) and achievements (D35).
Removed on 22 Nov 2026: gear and loot, §6 (D38).
Not built yet: §4 and §5.

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
| Critical set | 3% chance, × 2 XP, "CRITICAL SET!" | Habitica crits |
| Bounty done | + 100 to + 300 | Gloomhaven battle goals |
| Old session (beta) | 150 each | Legacy conversion |
| ~~Weekly streak~~ | Removed (D34). The old streak XP stays as saved `streak` XP events. | Habitica streak bonus |
| ~~Achievement~~ | Removed (D35). The old achievement XP stays as saved `achievement` XP events. | Habitica achievements |

**Difficulty multiplier:** 1.0 at the lowest difficulty, rising in even steps to 2.0 at the highest.

**Order of calculation for one set:**

1. Base = 10 × difficulty multiplier.
2. If the set number is above the target and up to 2 × the target: × 1.5. Above 2 × the target: 0.
3. Critical roll (3%): × 2.
4. Round to a whole number.

There is no streak step (D34).

The roll for a critical set must be repeatable (use a seed from the date, the exercise and the set number), so recalculating XP gives the same total.

**Total XP** = the XP of every set + 50 for each training day + the saved XP events (`legacy`, and the old `streak` and `achievement` XP).
The app calculates the set and day XP from the sessions every time. A rule change updates them.

## 2. Level curve

XP to go from level L to L + 1 (Habitica's formula):

| Level | XP to next level |
|---|---|
| 1–4 | 25 × L |
| 5 | 150 |
| 6 and up | round((0.25 × L² + 10 × L + 139.75) / 10) × 10 |

Examples: level 10 → 260, level 20 → 440, level 30 → 660, level 40 → 940, level 50 → 1,260.
(The first draft said 670 for level 30. The formula gives 660, and the formula wins: D19.)

Pace (a typical session is about 15 sets, or about 200 XP):

- Level 5 after the first one or two sessions.
- About 1 level per session around level 10.
- About 1 level per week (3 to 4 sessions) around level 40.

**Level-up:** a big animation (the freeze-frame card with the level title). No loot drop: gear is removed (D38). The body does not change; the sliders stay as the user set them.

**Level 50: new game+** (Habitica rebirth, Gloomhaven retirement). Optional. The level goes back to 1. The character keeps a cosmetic badge and gets + 10% XP for each completed run (max + 30%).

## 3. Streak (removed)

- There is no streak, no week target and no embers (D34, 22 Nov 2026).
- Old rule, kept only for the one-time XP freeze ([data-schema.md](data-schema.md) §5.4): a week with N training days was a streak week (N by difficulty: 2, 2, 2, 3, 3, 4). Each streak week in a row gave + 5% set XP, max + 25%.

## 4. How to measure progress

There are no kilos or reps, so progress comes from set targets and consistency.

### 4.1 Exercise mastery (Gloomhaven checkmarks)

- A session where an exercise reaches its set target gives that exercise 1 checkmark.
- 3 checkmarks = 1 mastery star. Max 5 stars per exercise.
- Stars show on the exercise card.

### 4.2 No progress → swap

- If an exercise gets no new checkmark in 3 weeks (and you did it at least twice in that time), the card suggests a swap from the class pool.
- This is the "change exercises when no progress" arrow in `pumplex.drawio`.
- **On hold:** the workout has no swap (D32). Ask the owner before you build this.

### 4.3 Difficulty climb (D&D milestones)

- If most of the workout's exercises have 3 or more stars, the app suggests the next difficulty level.
  (The first draft also needed the weekly streak target 3 weeks in a row. D34 removes the streak.)
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
- A bounty gives XP (section 1) and 1 checkmark on a "bounty board". 3 checkmarks = a reward, TBD (it was an item drop; gear is removed, D38).
- Unfinished bounties expire. Nothing is lost.

## 6. Gear and loot (removed)

Removed on 22 Nov 2026 (D38): no items, no unlocks, no loot. Kept here as a record.

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
- Bounties this week, bounty board checkmarks.
- Stats (calculated from sessions).
- Rebirth count (new game+).

The schema does not yet store bounties, the bounty board or the rebirth count. Add them in the next schema update.
