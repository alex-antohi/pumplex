# PUMPLEX game moodboard (v0.1)

Visual direction for the PUMPLEX game side: pixel-art characters, cel-shaded,
on the app's dark theme. These are **style tests**. Character classes are not
decided yet.

Source: the "PUMPLEX Game Moodboard" design canvas on claude.ai
(https://claude.ai/artifact/UhACEHxxvFme5njX4ZjuV5), exported 2026-11-21.
This folder is the copy in the repo. Use it as the reference when building game art or UI.

## Files

| Path | What it is |
| --- | --- |
| `README.md` | This spec. Start here. |
| `palette.json` | Every colour and font, as machine-readable JSON. |
| `game_look.html` | Board 1, "Game look v0.1": 4 test builds, 3 style rules, palette. Opens in a browser. |
| `body_sliders.html` | Board 2, "Body sliders": a 3×3 fat × muscle grid for male and female. Opens in a browser. |
| `builds/*.png` | 4 test-build sprites, 40×64 px. |
| `body_sliders/{male,female}/fat{0,50,100}_muscle{0,50,100}.png` | 18 body-slider sprites, 52×64 px. |
| `canvas/` | Original design-canvas source (`canvas.json`, `*.dc.html`). Only needed to re-import into the canvas. |

All sprites are transparent RGBA PNGs at native size. Scale them by whole
numbers with nearest-neighbour sampling: the boards show builds at 5× and
sliders at 4×. In Flutter, use `Image.asset(..., filterQuality: FilterQuality.none, scale: 1/N)`
or a `Transform.scale`. Never use bilinear filtering on them.

File names hold the slider values: `fat<0-100>_muscle<0-100>`. Builds also
include the sex (`build01_male_fat55_muscle100`).

## Character sprites

**Test builds** (`builds/`):

| File | Body | Outfit |
| --- | --- | --- |
| `build01_male_fat55_muscle100.png` | heavy-set, very muscular male | lime tank top, violet pants |
| `build02_female_fat0_muscle35.png` | lean female, pink ponytail | sky-blue top and shorts |
| `build03_female_fat100_muscle50.png` | heavy female | orange tank top, dark violet pants, pink boots |
| `build04_male_fat0_muscle15.png` | skinny male, blue mohawk | violet long sleeves, orange shorts |

**Body sliders** (`body_sliders/`): the same character in a starter outfit
at every slider stop, with cartoon extremes. Fat runs 0 / 50 / 100 (columns),
muscle runs 0 / 50 / 100 (rows). There are 9 per sex. Values in between will
need interpolation or more frames. None are drawn yet.

## Style rules

1. **Ink outline.** A 1 px near-black (`#0b0414`) line around every character,
   and between the arms and the body.
2. **Three flat tones.** Each colour has a highlight, a base and a shadow. Light comes from the top-left.
   No gradients, no dithering.
3. **Neon only on clothes.** Neon colours go on outfits only. Everything around them stays dark.
4. Shadows lean violet, not grey.
5. The bases are the dark-theme colours from the PUMPLEX app. The in-app cel
   shader (`shaders/cel.frag`) has the same look: flat toon bands and ink
   outlines.

## Palette

Grounds and ink:

| Role | Hex |
| --- | --- |
| background | `#12061f` |
| surface | `#1f0d36` |
| surface raised (sprite stage) | `#2a1148` |
| ink / outline | `#0b0414` |
| text | `#f6eeff` |
| muted text | `#c9b8e8` |

Neons (highlight / base / shadow):

| Name | Highlight | Base | Shadow |
| --- | --- | --- | --- |
| Pink | `#ff98c2` | `#ff5fb0` | `#a63e84` |
| Lime | `#dcfb7b` | `#c6ff3d` | `#849b42` |
| Orange | `#ffc075` | `#ffa033` | `#a6643c` |
| Violet | `#c8a9f3` | `#a77bff` | `#724eb2` |
| Sky | `#88dff3` | `#3fd2ff` | `#3681b2` |

## UI treatment on the boards

- Display type: **Anton**, uppercase, 1 px letter spacing. Titles get a
  stacked hard drop shadow, `3px 3px 0 <neon>, 6px 6px 0 <neon2>`.
- Body type: **Space Mono**.
- Panels: flat `#1f0d36` with a 3–4 px `#0b0414` border and a hard offset
  shadow in a neon (`5px 5px 0` or `8px 8px 0`). No blur, no rounded corners.
- Sprite stage: `#2a1148` with a pink polka-dot grid
  (`radial-gradient(rgba(255,95,176,.22) 2px, transparent 2.5px)`, 20 px tiles).
- Name tags: `#0b0414` box with a 2 px border in the outfit's neon.
