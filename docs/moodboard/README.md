# PUMPLEX game moodboard (v0.2)

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
| `borderlands-reference.md` | Research notes on the Borderlands vibe: style history, rarity and element colours, class ideas, tone. |
| `borderlands_palette.html` | Visual board for those notes: swatches, rarity → PUMPLEX mapping, reward card and title card mocks. |
| `game_look.html` | Board 1, "Game look v0.1": 4 test builds, 3 style rules, palette. Opens in a browser. |
| `body_sliders.html` | Board 2, "Body sliders": a 3×3 fat × muscle grid for male and female. Opens in a browser. |
| `animation.html` | Board 4, "Animation style test": idle, front squat and PR flex loops on 6 bodies, playing. Opens in a browser. |
| `readability.html` | Board 5, "Phone readability": a lifter card on the real Heavy Lower page at 3×/4×/5×, the sprite on every app ground, a 1×–5× size ladder, findings. Opens in a browser. |
| `builds/*.png` | 4 test-build sprites, 40×64 px. |
| `body_sliders/{male,female}/fat{0,50,100}_muscle{0,50,100}.png` | 18 body-slider sprites, 52×64 px. |
| `creator/body_atlas.png` | 50-body atlas used by board 3, "Character creator": 5 fat steps × 5 muscle steps × 2 sexes, 52×64 cells. |
| `animation/animation.json` | Frame order and per-frame milliseconds for every animation. Read this to play them. |
| `animation/<sex>_fat<F>_muscle<M>/` | Per body: `<anim>_<i>_<pose>.png` frames (80×72), `<anim>_sheet.png` strips, `preview_3x.png` contact sheet. |
| `canvas/` | Design-canvas source (`canvas.json`, `*.dc.html`), including the interactive Creator board, which only runs inside the canvas. Only needed to re-import into the canvas. |
| `../../tools/moodboard/animate.mjs` | Regenerates every animation frame from the body sliders. `node tools/moodboard/animate.mjs` |
| `../../tools/moodboard/boards.mjs` | Regenerates `animation.html`, `readability.html` and their canvas copies. Run after `animate.mjs`. |

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

## Character creator atlas (`creator/body_atlas.png`)

260×640 px, 52×64 cells, no gaps. Column = fat (0, 25, 50, 75, 100).
Rows 0–4 = male, muscle 0, 25, 50, 75, 100; rows 5–9 = female, same order.
Cell for (sex, fat, muscle): `x = fat/25 * 52`, `y = ((sex == female ? 5 : 0) + muscle/25) * 64`.
The canvas's Creator board shows it at 4× with two 5-step sliders and a sex toggle.

## Animation style test

Three loops, each generated for 6 bodies (male and female at fat/muscle
0/0, 50/50, 100/100) by `tools/moodboard/animate.mjs`. The script edits the
body-slider pixels: it cuts repeated rows so the body sinks, bows the knees
out, and cuts the arms out and redraws them. Outline, skin tones and outfit
colours stay the same as the source.

- **Frames:** 80×72 px. The 52×64 body sits at (14, 8), leaving room for the bar, the plates and raised arms.
  Every pose for a body lines up on that same origin: just swap frames.
- **Timing:** `animation/animation.json` → `animations.<name>.frames[] = {pose, ms}`.
  `sheetOrder` lists the unique poses in the order they appear in `<name>_sheet.png`.
  The loops repeat poses (e.g. squat `d2`/`d1` on the way up), so play the
  `frames` list, not the sheet left to right.

| Animation | Frames (pose ms) | Notes |
| --- | --- | --- |
| `idle` | rest 420 · out 300 · out 260 · rest 300 | Upper body sinks 1 px on the out-breath. |
| `front_squat` | top 500 · d1 140 · d2 140 · d3 160 · bottom 260 · d2 90 · d1 90 | Heavy Lower main lift. Bar racked on the shoulders. Down slow, up fast. |
| `pr_flex` | dip 120 · air2 90 · air4 120 · air2 90 · land 90 · hold 700 · rest 400 | For a new PR. Hop, then a double-biceps hold. |

Rough spots that still need hand-drawn keyframes: the squat bottom on the skinniest
bodies, the fists on the bar (plain blocks), and the flex forearms on fat-100 bodies (very wide).

## Phone readability findings

Measured on a 390 dp wide phone (`readability.html`). These are observations, not decisions:

- **The ink outline disappears on dark grounds.** `#0b0414` against the dark bg, panels
  and stage is only 1.03–1.22:1, so on dark the silhouette comes from skin and
  clothes alone. On the light theme and on pink or lime buttons it reads strongly.
- **Panel borders don't match the app.** In the app's dark theme, panel borders are
  `#f6eeff` (the theme's `ink`, `lib/pumplex.dart`). Moodboard v0.1 draws panels with
  `#0b0414` borders. Pick one before building game UI.
- **Width budget.** On a 390 dp screen the body takes 40% of the width at 3× (156×192 dp), 53% at 4× (208×256 dp) and 67% at 5× (260×320 dp).
  At 5× nothing fits beside it.
- On a 3× density phone (xxhdpi), one sprite pixel at 3× is 9×9 physical pixels.
