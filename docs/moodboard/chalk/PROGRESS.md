# CHALK build progress

What is built from `HANDOFF.md` (D70, D72) on branch `design-fixes`, and what is left. Update this file with every increment, so the next agent can pick up from here. The decisions stay the source of truth (`docs/decisions.md`).

## Done

1. **D70: difficulty is not a filter.** (`lib/game/exercises.dart` `ExerciseFilter.apply`, `isHard`; `lib/views/workout.dart`)
   - Every card of the class shows, with all its exercises (no level filter inside a card any more).
   - Suggested order: favorites, then your mode's cards (most common first, D67), then the rest by the mode that brings them in, then commonness. The D69 pattern slots are already in the commonness / unlock data from `tools/exercise_select.mjs`; the app does not re-sort by pattern.
   - HARD badge (`hard-badge`, text key `workout.hard`: HARD / GREU) by the title when the card comes in only at a harder mode or the exercise picked is above the mode's level. Its look is a placeholder (pink tag), design still to decide.
   - The DIFFICULTY tag and its sheet are gone. `filter.difficulty` stays in `ExerciseFilter` (from the profile) for the order and the badge.
2. **D72 tag row, part 1.** CLASS is a label (`class-label`, not tappable). BODY PART opens the body-part sheet (`lib/views/filters.dart`, now body parts and muscles only). The star stays.

## Left to do (in this order)

3. **CHALK button** on the tag row: `[CLASS label] [BODY PART ▾] [★] [CHALK]`. Fit on small screens (the row already shrinks to fit).
4. **CHALK sheet** (mockup `01-chalk-search.html`): chalk line of picked words (tap a word to wipe it); rows PATTERN, MOVE, TOOL, BODY, ANGLE, GRIP, tiles with counts, 0 greyed; WIPE and SHOW n EXERCISES; searches ALL exercises, ignores the class; no HOME word; nothing scrolls, tiles wrap. Each tile is a translation key (EN + RO; Romanian aliases per D72).
   - Needs: a word index over the catalog (pattern from `pattern`, MOVE from `base`, TOOL from equipment / `mods.equip`, BODY from body parts, ANGLE / GRIP from `mods`), a chalk query in the store, and the workout carousel showing the chalk results while a query is set.
5. **0 matches**: the main button becomes NO SUCH MOVE. FORGE IT?
6. **FORGE card** (mockup `02-forge.html`): one scrolling card; the name from the chalk words; editable word chips; BODY PART and MUSCLE preset from the MOVE word; NICKNAME (optional); BACK and FORGE IT. Needs a stored custom exercise (new prefs key; open: backup or not, edit / delete later, see HANDOFF "Still open").
7. **Nickname keyboard**: arcade QWERTY + Ă Â Î Ș Ț row, SPACE, DEL, OK, no digits; under NICKNAME at the bottom; BACK / FORGE IT above it; FORGE IT works before OK. The nickname shrinks to fit one line after about 10 letters; when set it is the big name, the chalk name small under it.
8. **Star per variant (D72)**: favorites save the exact exercise id, not the card key. Needs a migration of `favorites_v1` (card keys -> the variant picked / the simplest).
9. **D71 XP tiers**: not in the handoff; tier values are still to be set by the owner.
