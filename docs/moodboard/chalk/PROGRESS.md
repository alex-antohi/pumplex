# CHALK build progress

What is built from `HANDOFF.md` (D70, D72) on branch `design-fixes`, and what is left. Update this file with every increment, so the next agent can pick up from here. The decisions stay the source of truth (`docs/decisions.md`).

## Done

1. **D70: difficulty is not a filter.** (`lib/game/exercises.dart` `ExerciseFilter.apply`, `isHard`; `lib/views/workout.dart`)
   - Every card of the class shows, with all its exercises (no level filter inside a card any more).
   - Suggested order: favorites, then your mode's cards (most common first, D67), then the rest by the mode that brings them in, then commonness. The D69 pattern slots are already in the commonness / unlock data from `tools/exercise_select.mjs`; the app does not re-sort by pattern.
   - HARD badge (`hard-badge`, text key `workout.hard`: HARD / GREU) by the title when the card comes in only at a harder mode or the exercise picked is above the mode's level. Its look is a placeholder (pink tag), design still to decide.
   - The DIFFICULTY tag and its sheet are gone. `filter.difficulty` stays in `ExerciseFilter` (from the profile) for the order and the badge.
2. **D72 tag row, part 1.** CLASS is a label (`class-label`, not tappable). BODY PART opens the body-part sheet (`lib/views/filters.dart`, now body parts and muscles only). The star stays.

3. **CHALK button** on the tag row (`filter-chalk`): `[CLASS label] [BODY PART] [★] [CHALK]`, chalk white on night ink, CHALK · n with n words picked. The row shrinks to fit.
4. **CHALK sheet** (`lib/views/chalk.dart`, words and search in `lib/game/chalk.dart`, mockup `01-chalk-search.html`).
   - Chalk line on a dark floor; tap a word to wipe it. Rows PATTERN, MOVE, TOOL, BODY, ANGLE, GRIP; each tile shows its count (exercises), 0 greyed; one word per row (a tile replaces its row's word, a second tap takes it out). WIPE and SHOW n EXERCISES.
   - Words: PATTERN from the card's `pattern` (push = hpush + vpush, pull, squat, hinge, single leg, core, jump); MOVE from the English name (regex list); TOOL from `mods.equip`, else the database equipment; BODY from the body part of the muscle; ANGLE from `mods.angle` (FLAT = a move with angles, none picked); GRIP from `mods.width` and `mods.hand`.
   - While the line has words, `store.cards` is the search over ALL exercises (no class, no filters; most common first). The line is in memory only; RESET TO MINE also wipes it. A result for other gear has no HARD badge (`store.isHard`).
   - Labels: `chalk.<row>.<id>` in en.json and ro.json (Romanian first draft, to be checked). The Romanian search aliases of D72 are not needed while nobody types; left out.
   - Placeholder look (design still to decide): plain dashed-box chalk words, no chalk texture or icons. The sheet scrolls only if a phone is too short.
5. **0 matches**: the chalk line says NO EXERCISE HAS ALL THESE WORDS and the main button is the pink NO SUCH MOVE. FORGE IT? (`chalk-forge`). For now it only closes the sheet: the FORGE card is the next step.

6. **Star per variant (D72).** `favorites_v1` holds exercise ids; the star saves the exercise shown. A card with a favorite comes first and opens on it (when nothing was picked); favorites only keeps just the starred exercises. Old card favorites (`move:<name>`) become the exercise last picked on the card, else the simplest (`LogStore._favoritesToVariants`).

7. **FORGE card** (`lib/views/forge.dart`, model in `lib/game/forge.dart`, mockup `02-forge.html`). The pink NO SUCH MOVE. FORGE IT? button opens it as a full-screen page.
   - One scrolling card: FORGE A MOVE; the name from the words (angle, grip, tool, move or pattern; Flat and Bodyweight left out, e.g. DECLINE KETTLEBELL CURL), on one line, smaller when long; with a nickname, the nickname is big and the words' name small in orange under it.
   - Word chips per row (TOOL, ANGLE, GRIP, MOVE, PATTERN), tap to change; a SHOWS FOR line (the classes with that gear); BODY PART and MUSCLE chips, first guessed from the BODY word, else the MOVE word (`forgeBody`), then the lifter's pick sticks.
   - BACK and FORGE IT in a bar at the bottom. FORGE IT saves the move, closes the page, and the workout shows it (the chalk line becomes its words, the card is picked).
   - Stored in `custom_exercises_v1` (ids `custom_<n>`, words, muscle, nickname). It joins `exerciseCatalog` at start (`catalogWithForged`) for every class with its gear from Sofa, last in the order; sets and XP work like any exercise (beginner level). The card title shows the nickname (`CatalogExercise.nick`).
8. **Nickname keyboard** (`ArcadeKeyboard` in `lib/views/forge.dart`): QWERTY, Ă Â Î Ș Ț, DEL, SPACE, OK; no digits; docked at the bottom under the BACK / FORGE IT bar; OK closes it; FORGE IT works before OK; no length limit.

## Left to do (in this order)


9. **Open questions (owner):** edit or delete a forged move (there is no menu, D59); forged moves in the backup file (now they are not: `custom_exercises_v1` is not in `backupJson`); should the workout card also show the words' name under a nickname (now only the FORGE card does, D74 has no subtitle).
10. **Design pass** (HANDOFF "Yours to decide"): the HARD badge look, row colours, chalk texture, icons, the tag row on small screens. All current looks are placeholders built from the app's chips, tags and buttons.
11. **Romanian check**: the chalk words and FORGE texts in `assets/i18n/ro.json` are a first draft.
12. **D71 XP tiers**: not in the handoff; tier values are still to be set by the owner.
