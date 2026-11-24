# CHALK layout debate 02

Date: 24 Nov 2026. Exploratory only: nothing here is built or decided. Four agents each argued for a completely different layout for the CHALK screen and made an HTML mockup of it, in three states (just opened, words picked, 0 matches). The baseline is today's screen on the phone after D86 (`debate-02/00-today-on-phone.png`, dark theme): all four word rows fit before the first word.

Each mockup has its flow on the screens: numbered pink badges on what you tap, a FLOW panel under each phone, arrows between the phones, and a TWO TASKS box at the top with the exact taps (the counts below come from those boxes). Open the files from disk; the fonts load from `assets/fonts`:

- `debate-02/sentence-builder.html`
- `debate-02/results-first.html`
- `debate-02/steps-tabs.html`
- `debate-02/visual-map.html`

The agents checked their layouts in a preview that could not load Anton or Space Mono, so the final look with the real fonts is still unchecked.

## The four layouts

| | SENTENCE BUILDER | RESULTS FIRST | STEPS / TABS | VISUAL MAP |
|---|---|---|---|---|
| Idea | A chalk message "[TOOL] [MOVE] for [BODY]"; a tap on a slot opens only its words | The list fills the sheet; the words live in a dock at the bottom | One tab per row; each tab holds its picked word, like a loadout | Your lifter sprite with body tags, a gear rack of tool icons, results as loot cards |
| Words shown | The open slot's words only (MOVE first, grouped behind PUSH ▸ / PULL ▸) | One row's words in a sideways strip, about 8 of the 22 MOVE words | The open tab's words as 54 dp tiles; dead words folded behind "+13" | 6 body tags and 11 tool slots, plus a "say the move" strip |
| Results | About 8 rows under the sentence once the panel closes | 9–10 rows always; with no words, a ranked list of cards | A drawer that peeks (3.5 rows) and rises at ≤ 8 matches | One loot card per move, with variation pips ("+" and DO IT ▸) |
| Picked words | The sentence slots | Lime in the tabs | In the tab slots, with ✕ | A LOADOUT bar, with ✕ |
| At 0 matches | The slots that cause it turn pink; repair rows ("✕ KETTLEBELL → … · 4"), then FORGE | NO SUCH MOVE; "drop X → n" per word; FORGE IT | The drawer becomes FORGE, with "✕ KETTLEBELL → 6 moves" | An empty loot slot, FORGE IT, and OR DROP ONE |
| BACK TO TODAY | Bottom (with WIPE) | Bottom left, in the dock | Bottom bar | Bottom |
| Incline DB press → Today (today: 7) | 5 | 4 | 5 (4 if the row already peeks) | 5 |
| Barbell squat, do it now (today: 5) | 4 (2 if it already shows) | 2 | 4 | 4 |
| Targets | Slots 48 dp, tiles 40 dp | Tiles 44 dp, rows 52 dp | Tiles 54 dp | 36–48 dp |
| Decisions changed | D81 (chalk line and WIPE back), D72 (PATTERN folds into MOVE), D86 | D81, D86, HANDOFF "nothing scrolls, tiles wrap" | D81, D86; TOOL first, PATTERN last | D81, D72/D86 (no PATTERN row), D82 (cards with pips) |
| Biggest weakness | A tap per slot to open it; sentence word order differs per language (RO), and long words wrap | Can't see all words at once; looks like a shop filter | Words split across tabs; the jump to the next tab can cause a wrong tap | Body regions are ambiguous (BACK, glutes); art cost |
| Cost | M | M | M | M code + M art (L with a back view of every body) |

## What all four agree on

Each agent reached these on its own:

1. **The picked words are always on screen** (slots, tabs, a sentence or a loadout bar), with ✕ to drop one. This brings back a picked-words line, which reverses D81's "no chalk line".
2. **BACK TO TODAY goes to the bottom**, in thumb reach.
3. **0 matches offers repairs:** "drop X → n moves" for each picked word, then FORGE IT.
4. **Bigger targets:** 40 dp or more, instead of today's 29 dp tiles.
5. **More results on screen:** 8 rows or more, instead of today's 3.5.

## How they differ

- **Fastest:** RESULTS FIRST (4 actions and 2). It also changes the most: the list leads and the words become a secondary dock.
- **Most "chalk":** SENTENCE BUILDER, the closest to the HANDOFF's soapstone idea. The cost is a tap per slot and a word order per language.
- **Calmest for a sweaty thumb:** STEPS / TABS, with the biggest tiles and one row at a time.
- **Most game-like and most expensive:** VISUAL MAP, which needs art and has ambiguous body regions.

## Suggested next steps (owner calls)

1. Decide on the shared core above (points 1 to 5). It works in any of the four layouts, including today's screen. For example, today's screen plus a pinned picked-words line, BACK at the bottom and the 0-match repairs.
2. Then pick a direction: RESULTS FIRST for speed, SENTENCE BUILDER for identity, or STEPS / TABS for calm. A hybrid also came up twice: tabs or slots for the words, with the results under them.
3. Keep VISUAL MAP as a later "flavour" pass. Its gear-rack tool icons could be reused in any layout.

## Outcome

- 24 Nov 2026: **VISUAL MAP built (D87)**, with the gear-rack icons as app assets. Left out for now: tap zones on the sprite and the back view for BACK.

## Feedback

- 24 Nov 2026, Anca: likes the **tool icons** from the first screen of VISUAL MAP (the gear rack: 12×12 pixel icons, drawn inline in `debate-02/visual-map.html`). Use them for the TOOL words, whichever layout is chosen.
