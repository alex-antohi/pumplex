# MINIMAL: weight and reps on the exercise card

Date: 24 Nov 2026. Status: **proposal, not built.** It goes against D52 (sets only). Building it needs the owner's go-ahead and a new decision row in `docs/decisions.md`.

Render: `01-sets-reps-weight.png` (mockup A). The debate chose MINIMAL over a game scoreboard (B) and a logger table (C).

## The idea in one line

A tap on the world still adds one set (D48). After the set, a small strip lets the lifter fix the weight and the reps of that set. Doing nothing is fine.

## Owner's rules (fixed)

- **Log only.** Weight and reps never change XP. XP still comes from sets (D19, D52, D77).
- **Only on weighted moves.** The strip shows only for barbell, dumbbell, kettlebell, cable, machine, Smith machine and EZ bar. It does not show for bodyweight, bands or cardio.
- The world tap, the long-press undo (D17), the 10-set XP cap (D52) and the Today list (D79, D82) do not change.

## How it looks

The strip sits on the exercise card, under the chip area and above the Today dots row.

```
SET 3 · OPTIONAL · SAME AS SET 2
[ − ]  24 KG  [ + ]
[ − ]   8 REPS [ + ]
1 · 22×10   2 · 24×8   3 · 24×8      ← the trail of today's sets
```

- The header names the set the strip edits ("SET 3").
- "SAME AS SET 2" shows while the values are carried over and not touched.
- The trail lists today's sets of this exercise as small pips (`weight×reps`).
- Use the app's theme: Pal colours, Anton for the numbers, Space Mono for the labels, and the shared components (`PickChip`, `IconTapButton`).

## How it works

1. **The strip appears after a set.** Before the first set of the day on that exercise, the strip is hidden. The card looks as it does now.
2. **The strip edits the set just done.** It does not edit the next set.
3. **Values carry over.** A new set starts with the values of the previous set of the same exercise today. For the first set of the day, it uses the last set of the last day with that exercise. With no history, it uses empty values ("— KG", "— REPS").
4. **The steppers:**
   - Weight steps by 2.5 kg, and reps by 1.
   - A hold on a stepper repeats it.
   - A tap on the number opens the arcade keypad for a direct value (digits only, the same style as the FORJA keyboard).
5. **The trail fixes older sets.** A tap on a pip makes the strip edit that set. A tap on the last pip goes back to the newest set.
6. **The long-press undo (D17)** removes the last set and its weight and reps.
7. **Zero taps if nothing changed.** The lifter can ignore the strip completely.

## Typed or carried

Carry-over can save wrong numbers without notice. That was the strongest point against MINIMAL in the debate. To keep this visible:

- Each value is saved as **typed** (the lifter touched it) or **carried** (copied from the previous set).
- A carried value shows in a muted colour, and a typed value in full ink.
- Only typed values count for a future "personal best" or history view. Carried values are only a guess.

## Data

Today a set is one record per exercise id (`store.dart`, `addSet`). Add two optional fields to each set:

| Field | Type | Meaning |
|---|---|---|
| `kg` | number or empty | Weight in kg, in steps of 0.5. |
| `reps` | whole number or empty | Reps of that set. |
| `kgTyped`, `repsTyped` | true / false | True when the lifter set the value; false when it was carried over. |

- Old sets have no weight or reps. They stay valid.
- Weight is stored in kg. A later setting can show pounds.
- The fields are not in XP, so the rules in `lib/game/rules.dart` do not change.

## Text (en / ro)

| Key | English | Romanian |
|---|---|---|
| `log.set` | SET {n} | SERIA {n} |
| `log.optional` | OPTIONAL | OPȚIONAL |
| `log.sameAs` | SAME AS SET {n} | LA FEL CA SERIA {n} |
| `log.kg` | KG | KG |
| `log.reps` | REPS | REPETĂRI |

## Tests to write

- The strip is hidden before the first set, and shows after it.
- It shows on a dumbbell move, and not on a bodyweight move.
- A new set carries the previous values, marked as carried.
- A stepper tap changes the value and marks it as typed.
- A tap on a trail pip edits that older set.
- The long-press undo removes the set and its values.
- XP is the same with and without weight and reps.

## Open questions

1. Should the first set of a day carry over the last session's values, or start empty?
2. Should a later history or profile view show the best typed weight per exercise?
3. Do we need pounds?
