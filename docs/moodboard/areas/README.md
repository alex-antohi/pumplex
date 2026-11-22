# Area scenes (design handoff item 1)

Image layers for the 5 area scenes, drawn from the design demo's area scenes (demo since removed; the coordinates live in `tools/moodboard/areas.mjs`).
Regenerate with `node tools/moodboard/areas.mjs` (Node 22, no packages).

Folders: `riptide`, `gainsgard`, `rustbelt`, `arcade`, `frostbite` (the area ids, D36).
Each has the PNG layers and an `anim.json` with frame order, ms and positions.

## Size and scale

- **Scene: 175 x 150 art pixels.** The demo scene is 350 x 300 CSS px, so 1 art pixel = 2 CSS px.
  Show it at 2x, 3x or 4x with whole-number, nearest-neighbour scaling (`FilterQuality.none`).
- Every position in `anim.json` is in art pixels from the scene's top-left corner, `[x, y]`.
- The demo's 4 px ink frame and the offset colour shadow are not in the art. Add them in the app.
- The lifter is a `body_atlas.png` cell (52 x 64) at 1x, at `[6, 73]`, standing on the shadow.

## Layer order (bottom to top)

| z | Layer | File | Size | Position |
| --- | --- | --- | --- | --- |
| 0 | Sky / wall and far details | `background.png` | 175 x 150 | `[0, 0]` |
| 1 | Floor (and things lying on it) | `floor.png` | 175 x 36 | `[0, 114]` |
| 2 | Ground shadow under the lifter | `shadow.png` | 46 x 5 | `[9, 135]` |
| 3 | Marks (the count) | `mark.png` ... | see `anim.json` | see `marks.layout` |
| 5 | Lifter | `body_atlas.png` cell | 52 x 64 | `[6, 73]` |
| 6 | Action object | `object_idle / tap / hit.png` | see below | `object.frames.*.pos` in `anim.json` |
| 8 | Effect frames | `fx_1..6.png` | 175 x 150 | `[0, 0]` |
| 10 | Burst star | `burst_1..5.png` | 50 x 50 | `burst.pos` |

**Gainsgard Keep exception:** the marks are on the wall, so draw them **above** the object (z 7).
In every other area they go below the lifter. `anim.json` `stack` and `marks.z` say which.

The `+1 SET` / 5th-mark text is not in the burst frames. Write it in Anton on top of the star.

## Object frames

Each area has `object_idle.png`, `object_tap.png` and `object_hit.png`, all the same size, so they swap in place.
`object.frames.<name>.pos` is where to draw the frame. `object.hitBox` is the tap area (art px).
`object.sequence` is the play order on a tap, with ms (0 = hold). Rest on `idle`.

| Area | Object | idle | tap | hit | Extra |
| --- | --- | --- | --- | --- | --- |
| Riptide Shore | Treasure chest | closed | lid nudged up | lid open | |
| Gainsgard Keep | Stone wall | plain | lighter | chalk dust specks | |
| Rustbelt Flats | Hazard barrel | whole | squashed | scorch mark (barrel gone) | `rollIn`: new barrel slides in, 5 steps, 450 ms |
| Arcade Underpass | PUNCH-O-TRON | pad out | pad pushed in a bit | pad pushed in fully | Draw the live LED count at `object.led.rect`; the art only has a dim "88" |
| Frostbite Summit | Ice block | whole | squashed with cracks | two halves apart | `reform`: object_idle scales 0 to 1 in 4 steps, 400 ms |

## Effects

- `effects.fx`: `fx_1..N.png` with `ms` per frame. Play once on a hit, then remove. Full scene size.
  Riptide: a shell flies out in an arc. Rustbelt: smoke puffs, starburst, debris. Frostbite: ice shards.
  Gainsgard and Arcade have none in the demo (the scratch and the punch are the effect).
- `effects.fx5` (Riptide only): the same arc with a pearl, for every 5th mark.
- `burst_1..5.png`: play once, 100 ms each, then hold the last frame about 300 ms.
- Shake the whole stack for 320 ms on every tap (6 steps, no easing).

## Marks (what stays in the world)

`mark.png` is one mark. `anim.json` `marks` gives the layout (positions for the first 12 marks).
A new mark pops in: scale 2.2 to 1 and rotate -14 deg to 0, in 4 steps over 220 ms.

| Area | Mark | Files | Notes |
| --- | --- | --- | --- |
| Riptide Shore | Shell (10 x 8) | `mark.png`, `mark_fifth.png` (pearl 9 x 9) | Pile, 4 per row, filled from the bottom up. Every 5th is a pearl. |
| Gainsgard Keep | Chalk stroke (4 x 22) | `mark.png`, `mark_fifth.png` (slash 30 x 17) | 4 strokes, then the slash across them. Groups wrap. |
| Rustbelt Flats | Spray X (8 x 12) | `mark.png` | White. Tint it with the rarity colour (`marks.tint`). |
| Arcade Underpass | Ticket (6 x 5) | `mark.png` | A row on the floor, from the right edge going left. |
| Frostbite Summit | Flag (10 x 15) | `mark.png`, `mark_tint.png` | Draw `mark_tint.png` over `mark.png`, tinted with the rarity colour. |

Rarity ladder (mark index 0, 1, 2 ...): `#c9b8e8`, `#c6ff3d`, `#3fd2ff`, `#a77bff`, `#ffa033`, `#ff5fb0`. Index 5 and up use the last colour.
The burst star in Rustbelt Flats uses the colour of the newest mark.

## Not exported (approximated or left out)

- The demo's looping ambient motion is not in the files. The backgrounds are one static frame.
  This covers twinkling stars, rolling foam, the swaying palm, torch flicker, neon flicker, the cactus eyes, drifting aurora and falling snow.
- Text in the art (OPEN 24/7, SWOLE, GAINZ, PUNCH-O-TRON) is drawn in a 3 x 5 pixel font. The demo uses Anton, so it is smaller. The tilt of SWOLE is dropped.
- The Gainsgard dumbbell emblems and rack bars are redrawn as simple pixel dumbbells (the demo's box-shadow trick does not map to pixels).
- Fine CSS gradients and dot patterns are sampled to the pixel grid, so patterns are close to, not identical with, the demo.
- Opacity fades in the effects use PNG alpha, so those frames have partly transparent pixels.
