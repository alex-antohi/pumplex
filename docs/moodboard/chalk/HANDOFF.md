# CHALK handoff for the design team

Date: 23 Nov 2026. Source of truth: `docs/decisions.md` (D70, D71, D72). Nothing here is built yet. Design first, then code.

Mockups in this folder:

- `01-chalk-search.html` / `.png`: the CHALK search sheet and the 0-match state.
- `02-forge.html` / `.png`: the FORGE card and the nickname keyboard.

The mockups use the app's current colours, chips and buttons. They show the flow, not the final look.

## What CHALK is

CHALK is the exercise search. The lifter never types: they tap word tiles, like the soapstone messages in Dark Souls, with gym chalk in place of the soapstone. Each tap narrows the list at once. When nothing matches, the lifter can FORGE their own exercise from the same words.

## What to design

1. **The workout card row (D72).** Under the world: `[BODY PART ▾] [★] [CHALK]`.
   - CLASS is a label now, not a filter tag. DIFFICULTY is gone from the card (D70).
   - The counter (`3 / 28`) stays under the exercise carousel.
2. **The HARD badge (D70).** All cards of the class show. A card above the lifter's mode gets a HARD badge. Nothing is locked or hidden.
3. **The CHALK sheet.**
   - At the top, a chalk line shows the picked words. Tap a word to wipe it.
   - Rows: PATTERN (new: squat, hinge, push, pull, carry …), MOVE, TOOL, BODY, ANGLE, GRIP. ANGLE and GRIP are two rows.
   - Each tile shows a count. A tile with 0 is greyed.
   - Buttons: WIPE and SHOW n EXERCISES.
   - With 0 matches, the main button becomes NO SUCH MOVE. FORGE IT?
4. **The FORGE card.**
   - One card that scrolls.
   - The name comes from the chalk words, for example DECLINE KETTLEBELL CURL.
   - The word chips can be edited on the card.
   - BODY PART and MUSCLE are picked already from the MOVE word. The lifter can change them.
   - NICKNAME (optional).
   - BACK and FORGE IT.
5. **The nickname keyboard.**
   - An arcade-style keyboard, not the phone keyboard.
   - QWERTY layout, plus a Romanian row: Ă Â Î Ș Ț.
   - SPACE, DEL and OK. No digits.
   - The keyboard sits under NICKNAME, at the bottom of the screen.

## Fixed by the owner (do not change)

- CHALK searches ALL exercises. It ignores the class.
- An exercise for another class's gear opens like any other, with no badge.
- The sheet is tall enough that nothing scrolls. Tiles wrap.
- The reset button is called WIPE.
- There is no HOME word.
- The nickname:
  - It has no length limit. About 10 letters fit at full size. After that, the font gets smaller so the whole name fits on one line.
  - When it is set, the nickname is the big name. The chalk name is small under it.
- BACK and FORGE IT sit above the keyboard. FORGE IT works before OK.
- The star saves the exact variant, not the whole card.
- All text works in English and Romanian. Each word tile is a translation key, so leave room for longer Romanian words.

## Yours to decide

- How to fit the tag row on small screens (the owner said: cram it in, design decides).
- The colours of the rows, the chalk texture, icons and art.
- What the HARD badge looks like.

## Still open (not for design yet)

- Can a lifter edit or delete a forged move later? There is no menu now (D59).
- Do custom moves go into a backup file?
