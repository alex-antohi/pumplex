# CHALK design debate 01

Date: 24 Nov 2026. Topic: how the CHALK screen can be improved, design / UI wise. Three agents argued three stances. Each one rendered the current sheet at phone size in its states (empty, words picked, 0 matches). Nothing here is built or decided yet. The owner decides.

## Where all three agree (the real problems)

1. **The tiles are cut off.** The results box has a fixed height of 270 dp. Above it you see PATTERN and MOVE. TOOL is a sliver and BODY is off-screen. This breaks the HANDOFF rule "nothing scrolls".
2. **The empty state wastes space.** With no words, the 270 dp box holds one hint line, about 40% of the sheet, while the tiles above stay clipped.
3. **At 0 matches, the word that caused it is hidden.** For example, KETTLEBELL is scrolled away, so the lifter cannot see what to un-pick.
4. **Few results fit.** About 3.5 rows show (64 dp per row). A 23-result list is about 6 scrolls, with no grouping.

## The three stances

| | REFINE | BOLD GAME | USABILITY FIRST |
|---|---|---|---|
| Core idea | Keep the layout, fix the sizes and states | Make CHALK feel like writing on a dark floor | Fewest taps, one sweaty thumb |
| Top fix | Results box flexible: tiles take the sheet when empty, results capped at ~45% once words are picked | Dark floor sheet (kNight, chalk-dust), chalk-white tiles | Pinned picked-words strip above results (tap to drop) |
| Then | Tighter tiles (all 4 rows fit); show the picked words at 0; compact result rows (~52 dp); fixed-width TODAY badge; bigger CHALK title, quieter BACK TO TODAY; dashed hint slot | Written phrase of picked words; scribble stroke + haptic on tap; results stagger in; 0 matches "cracks", then FORGE slams in; dusty "TAP A WORD" in the empty space | Dynamic results box; 40 dp tiles; TOOL / BODY before the long MOVE row; sort results by tool, then name; close (keeps words) vs WIPE split; 50% greyed tiles + `enabled:false` semantics; "+" with UNDO |
| Measured | — | — | Incline DB press to Today: 7 actions; barbell squat: 5; cable curl: 5. Tiles 29 dp tall (FLY 41×29). BACK TO TODAY top-right (hard reach). Greyed tiles ~2.3:1 contrast. |
| Risk they admit | Structure stays crowded with long RO labels | Theatre mid-set; dark sheet contrast | Looks more like a filter form |

## Owner calls needed

- **A picked-words line** (BOLD and USABILITY both want it; REFINE wants it at 0 matches only). It partly reverses D81 ("no chalk line").
- **Close vs WIPE**: BACK TO TODAY now also wipes the words (USABILITY wants them split; D81 removed WIPE).
- **Dark floor sheet** (BOLD): an identity change from the light sheet.

## Suggested order (synthesis)

1. A flexible results box, with tiles tight enough that all 4 rows fit when empty. All three agree, it is low cost, and it needs no owner call. **Built (D86):** before the first word the results area is only the hint, so all 4 rows fit on a common phone in EN and RO; small phones in RO still scroll.
2. Make the picked words visible: a pinned line, or at least at 0 matches (owner call on how far).
3. Bigger tap targets (tiles ≥ 36–40 dp) and a quieter, reachable BACK; greyed-tile semantics and contrast.
4. Game feel that never blocks input: a haptic on a tile tap, results staggering in, the 0-match moment handing off to the ANVIL reveal.
5. The dark floor sheet as a separate design pass, with a contrast check.
