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
| `canvas/ClassSelect.dc.html` | Board 6, "Class select": setup step 2, picking a class by equipment. Interactive, runs only inside the canvas. The copy and layout are in "Class select" below. |
| `canvas/StartingAreas.dc.html` | Board 7, "Starting areas": setup step 4, five areas with scene, palette, default path and a working tap-to-mark demo. Interactive, runs only inside the canvas. Spec in "Starting areas" below. |
| `canvas/` | Design-canvas source (`canvas.json`, `*.dc.html`), including the interactive Creator and Class select boards, which only run inside the canvas. Only needed to re-import into the canvas. |
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

## Class select (setup step 2)

Design for screen 3 in `docs/app-flow.md`, following brief 4.1: **class = your equipment**.
The screen calls the classes **paths**, using the marketing draft's working name
(`docs/marketing/01-name.md`: SWOLEMANCER, "Summon your gains"; the classes are
"the Swolemancer's paths"). If the app name changes, change the kicker line.

The layout is a phone version of a classic RPG class picker. There is no stat
table, because brief rule 3 says no tables of numbers. A **loadout** (gear) and
three **training tags** take its place.

Screen, top to bottom (390×844 dp):

1. Kicker `STEP 2 OF 5 · THE SWOLEMANCER'S PATHS`, title **CHOOSE YOUR PATH**, subline **What do you train with?**
2. Preview card: the lifter at 3× from `creator/body_atlas.png` (until there are class outfits, each class
   shows a body that hints at it), the class name in its colour, the loadout line and 3 tags.
   The card's hard shadow takes the class colour.
3. A short description in the voice of an RPG class intro, which also hints at the equipment.
4. Four class buttons (a radio group): class name on the left, equipment on the right. The picked one fills with its colour.
5. **NEXT: DIFFICULTY**.

### Freeze-frame intro card

From `borderlands-reference.md` (character intro card: show it on class pick and on level-up).
Each time a class is picked:

- The preview **freezes**: the sprite goes greyscale with high contrast, and dark diagonal stripes cover the card.
- The class name **slams in** as a stencil tag: an Anton 40 px name on the class colour, with a 4 px ink border,
  a hard ink shadow and a −6° tilt. It scales down from 2.2× in 6 hard steps over 420 ms, with no easing,
  to match the pixel art.
- A **joke subtitle** slides in under it on an ink strip, in the class colour, tilted −3°.
- It closes by itself after **1.8 s**, or when you tap it. Each new pick restarts it.
- With reduced motion turned on, the card appears without the slam and slide.
- Use the same card (with new copy) for level-ups.

### Classes

The tone of each class follows the gun-maker table in `borderlands-reference.md` section 6.

| Equipment (brief 4.1) | Class | Maker tone | Colour | Loadout | Tags | Intro subtitle | Description |
| --- | --- | --- | --- | --- | --- | --- | --- |
| No equipment | **Scrapper** | Bandit / Scav: scrappy, DIY, warm | orange `#ffa033` | Nothin'. Just you, the floor and the stairs. | CARDIO · BODYWEIGHT · SPRINTS | BUILT FROM STAIRS AND SPITE | No gym, no gear, no problem. Builds every workout out of floors, stairs and pure spite. Homemade, held together with tape, and very loud about it. |
| Basic home gym | **Bargain Bruiser** | Tediore: store-brand, cheap and cheerful | sky `#3fd2ff` | Two dumbbells, one mat, a kettlebell of unknown origin. | FLOOR WORK · SOME CARDIO · SOME WEIGHTS | BUY ONE GAIN, GET ONE FREE | Kitted out from the clearance aisle. Every piece of gear is store-brand, slightly wobbly and fully committed. Cheap kit, real gains. |
| Lots of free weights | **Plate Paladin** | Jakobs: old-school, heavy | lime `#c6ff3d` | A barbell, a rack and a wall of plates. | STRONGMAN · BARBELL · HEAVY | OATH-SWORN TO THE BARBELL | Sworn to the barbell. Carries plates like holy relics and drops them like thunder. Big, burly, unbothered. |
| Lots of machines | **Cablemancer** | Maliwan / Hyperion: sleek, high-tech | violet `#a77bff` | Cables, pin-stacks and every machine in the building. | MACHINES · CABLES · LEAN POWER | SPEAKS FLUENT PULLEY | Bends steel cables and pin-stacks to their will. Thin as a wire, strong as the machine. Never waits for the squat rack. |

Preview bodies (atlas cells): Scrapper F fat 0 / muscle 25 · Bargain Bruiser M 25 / 50 ·
Plate Paladin M 75 / 100 · Cablemancer F 0 / 75.

The names are **proposals**. Brief 4.1 says the final names come from the
design phase. They copy the tone of Borderlands' class names (one punchy archetype word,
often a mashup) but are our own. Other options:
- **No equipment:** Burpee Bandit, Dashrat, Floor Phantom
- **Basic home gym:** Value Brawler, Discount Duke, Home Brand Hero
- **Lots of free weights:** Ironclad, Platebreaker, Barbellion
- **Lots of machines:** Pulley Assassin, Leg-Press Lich, Pinstack Witch

Still open: class outfits (the preview uses the starter outfit), and the height
slider from brief 4.2 (the Creator board has only fat and muscle).

## Starting areas (setup step 4)

Brief 4.5–4.6: the area sets **the look, the palette and the set mark**. These five are proposals
built from this moodboard (the violet night base and neons, `borderlands-reference.md` §4 rarity ladder and §9 wasteland tones,
and the phone readability finding).

**Rule for every area: a light floor behind the lifter, a dark sky above.** The lifter stands on
a pale floor (sand, flagstone, rust, concrete, snow), so the `#0b0414` ink outline has something light to stand against.
That fixes the 1.03–1.22:1 contrast problem from the readability board. Skies and walls stay dark. Neon only on the marks,
on props that react (torches, neon signs) and on clothes (rule 3).

| Area | Scene | Sky / wall | Floor | Accent | Set mark | Default path |
| --- | --- | --- | --- | --- | --- | --- |
| **Riptide Shore** (brief's beach) | Night beach, moon, violet sea with sky-blue foam | `#12061f`, sea `#2a1148` | sand `#ad9293` | pink `#ff5fb0` | A **shell** drops into a rope pouch. Every 5th is a **pearl** (`#88dff3`, the "pearlescent" tier). | any (neutral pick) |
| **Gainsgard Keep** (brief's castle) | Stone brick hall, banners, two torches | `#3a2a52`, bricks `#2a1148` | flagstone `#8672a5` | orange `#ffa033` | **Chalk scratches** on the wall: 4 strokes, then a slash for 5. | Plate Paladin |
| **Rustbelt Flats** | Junkyard wasteland: dust horizon, violet mesas, scrap fence | `#1f0d36`, mesas `#3b2230`, dust `#ecd7d0` | rust `#a6643c` | orange | A **spray-painted X** on a scrap sign. The colour climbs the rarity ladder: `#c9b8e8` → lime → sky → violet → orange, then pink. | Scrapper |
| **Arcade Underpass** | The app's own look: pink polka dots, a lime "OPEN 24/7" sign, bridge pillar | `#12061f` + dots | concrete `#724eb2` | lime `#c6ff3d` | A **token** drops into a glass tube, and an LED counter ticks up (`07`). | Bargain Bruiser |
| **Frostbite Summit** (optional) | Snowy peaks, aurora bands in violet and sky blue | `#1a0b3b`, peaks `#2a1148` | snow `#c9b8e8` | sky `#3fd2ff` | A **flag** planted one step higher up the slope per set, so you can see the climb. | Cablemancer |

Mark behaviour (all areas):
- One tap = one working set (brief 4.5). The mark lands in about 200–300 ms with **weight**: shells and tokens drop in, chalk scratches top-down,
  spray and flags pop in. All motion is hard-stepped (CSS `steps()`), with no easing.
- **Every tap is an event:** the set box shakes (320 ms) and a starburst in the area colour says **+1 SET**.
- **Every 5th mark gets its own stamp:** PEARL! (beach), SLASHED! (keep), TAGGED! (rustbelt), COMBO! (arcade), SUMMIT! (summit).
- A long-press takes the last mark back (app-flow §4.2). On the board an UNDO button stands in for it. Undo has no burst.
- Marks group in fives so you can count them without numbers (rule 3). The board caps the demo at 12.
- With reduced motion turned on, nothing shakes, drops or loops, and marks just appear.

Set boxes (180 px tall, themed, each with a stencilled name plate):

| Area | Box | Details |
| --- | --- | --- |
| Riptide Shore | **Pouch of shells** on speckled sand | A drawstring rope pouch that grows as it fills. Ridged pink shells, and a shiny sky-blue pearl every 5th. |
| Gainsgard Keep | **Tally wall** | Stone bricks, a torch with a pool of warm light. Big chalk strokes with chalk dust; the 5th is a diagonal slash. |
| Rustbelt Flats | **Scrap sign** | A rusty riveted plate under a hazard-stripe band. Each X has paint drips in its rarity colour. A spray can at the side shows the *next* colour. |
| Arcade Underpass | **Token machine** | An "INSERT SET" marquee, a 7-segment counter with ghost `88` digits, and a glass coin tube that fills from the bottom. |
| Frostbite Summit | **The climb** | A snowy slope up to a pink summit flag. Each set plants a flag one step higher; flag colours climb the rarity ladder. |

Scene details (all flat CSS shapes as placeholders for pixel art; the lifter has a ground shadow):
- **Riptide Shore:** twinkling stars, a cratered moon and its reflection on the sea, a palm island on the horizon, rolling foam (stepped), speckled sand with a crab and a starfish, a swaying palm tree.
- **Gainsgard Keep:** an arched moonlit window with a light beam, hanging chains, banners with dumbbell emblems, flickering torches with light pools, a dumbbell rack, a pink runner rug on flagstones.
- **Rustbelt Flats:** banded dusk sky, a striped setting sun, mesas, a leaning telephone pole with a sagging wire, a cactus with blinking orange eyes (from the reference), a car wreck, a hazard barrel, tyres, cracked ground.
- **Arcade Underpass:** a riveted bridge deck, graffiti (SWOLE, GAINZ), torn posters, a flickering OPEN 24/7 sign and a pink arrow, an arcade cabinet with a flickering screen, a puddle reflecting neon, a cone, road markings.
- **Frostbite Summit:** stars, three drifting aurora bands, layered snowy peaks, snowy pines, a cabin with a lit window, falling snow (stepped), drifts and footprints.

The class link is the drawio's "Background changes" edge (Character Creation → Starting Area). The class picks the
default area, and the player can still choose any area.

Scenes on the board are flat CSS shapes as placeholders for pixel-art backgrounds. Lifters use `creator/body_atlas.png` at 2×.

