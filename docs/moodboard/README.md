# PUMPLEX game moodboard (v0.2)

Owner decisions win over this document: read [docs/decisions.md](../decisions.md) first.

Visual direction for the PUMPLEX game side: pixel-art characters, cel-shaded,
on the app's dark theme. The classes are decided: one per equipment type (D8, D9).
Only their final names are still open.

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
| `readability.html` | Board 5, "Phone readability": a lifter card on a workout page at 3×/4×/5×, the sprite on every app ground, a 1×–5× size ladder, findings. Opens in a browser. |
| `builds/*.png` | 4 test-build sprites, 40×64 px. |
| `body_sliders/{male,female}/fat{0,50,100}_muscle{0,50,100}.png` | 18 body-slider sprites, 52×64 px. |
| `creator/body_atlas.png` | 50-body atlas used by board 3, "Character creator": 5 fat steps × 5 muscle steps × 2 sexes, 52×64 cells. |
| `animation/animation.json` | Frame order and per-frame milliseconds for every animation. Read this to play them. |
| `animation/<sex>_fat<F>_muscle<M>/` | Per body: `<anim>_<i>_<pose>.png` frames (80×72), `<anim>_sheet.png` strips, `preview_3x.png` contact sheet. |
| `canvas/ClassSelect.dc.html` | Board 6, "Class select": setup step 2, picking a class by equipment. Interactive, runs only inside the canvas. The copy and layout are in "Class select" below. |
| `canvas/StartingAreas.dc.html` | Board 7, "Starting areas": setup step 4, five areas with scene, palette, default path and a working tap-to-mark demo. Interactive, runs only inside the canvas. Spec in "Starting areas" below. |
| `canvas/Workout.dc.html` | Board 8, "Workout": the play screen (app-flow §4.2) in Rustbelt Flats for a Scrapper: exercise strip (swipe to switch, add, remove), barrel = one working set, long-press undo, an XP pop on each set and the level-up card. Interactive, runs only inside the canvas. Spec in "Workout screen" below. |
| `canvas/Difficulty.dc.html` | Board 9, "Difficulty": setup step 3, a six-rung ladder of fantasy-named levels with XP gems and a title card. Interactive, runs only inside the canvas. Spec in "Difficulty" below. |
| `scrapper_rustbelt.html` | Board 10, "Scrapper × Rustbelt Flats": one class in one area, five takes (High Noon, Dusk Drive-In, Dust Devil, Midnight Scrapyard, Toxic Dawn). Hand-painted 172×224 canvas scenes at 2×, 100 ms stepped ambient loops, the lifter's idle and PR-flex frames, the working barrel (tap = set, hold = undo), and 3–4 deliberately useless interactions per take with a global "useless taps" counter. Opens in a browser. |
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
5. The bases are the dark-theme colours from the PUMPLEX app.

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
The canvas's Creator board shows it at 4× with a sex toggle and three 5-step sliders: HEIGHT, FAT and MUSCLE (D10, D11).
Height has no atlas rows: the app draws five height models by removing or repeating pixel rows of the cell
(chest 19, hips 37, shins 48 and 50; −4 to +4 rows, `lib/game/rules.dart`, D64), the same rows in every layer.
The app shows the FAT slider as WEIGHT, 50–200 kg. Skin, hair and facial hair are in [`looks/`](looks/README.md).

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
| `front_squat` | top 500 · d1 140 · d2 140 · d3 160 · bottom 260 · d2 90 · d1 90 | A main barbell lift. Bar racked on the shoulders. Down slow, up fast. |
| `pr_flex` | dip 120 · air2 90 · air4 120 · air2 90 · land 90 · hold 700 · rest 400 | For a level-up or a critical set (there are no PRs, D2). Hop, then a double-biceps hold. |

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
table, because brief rule 3 says no tables of numbers. A **loadout** (the gym
equipment the class trains with) and three **training tags** take its place.

Screen, top to bottom (390×844 dp):

1. No kicker, title or subtitle in the view (D47): the PUMPLEX bar says `CLASS · STEP 2 OF 4`.
2. One big card that fills the space down to the dots (D46): **the user's own body from step 1** on top (D25).
   The class colour and the class outfit show the class, not a different body. Then the class name in its colour,
   the equipment, the loadout line, 3 tags and a short description in the voice of an RPG class intro.
   The card's hard shadow takes the class colour.
3. Swipe the card to change the class: left for the next, right for the one before, round and round.
   The texts slide with the swipe. Four dots under the card show the class; tap one to jump. No class buttons.
4. **DIFFICULTY** slider under the dots (D47): 6 stops, the mode name above it on the right in its rarity colour.
5. **BACK** and **NEXT: STARTING AREA**.

### Freeze-frame intro card

From `borderlands-reference.md` (character intro card). The app shows it on level-up only,
not on class select (D46) or on a difficulty pick (D47). Each time it shows:

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

Preview body: always the user's own body from step 1 (D25). There is no preview body per class.

The names are **proposals**. Brief 4.1 says the final names come from the
design phase. They copy the tone of Borderlands' class names (one punchy archetype word,
often a mashup) but are our own. Other options:
- **No equipment:** Burpee Bandit, Dashrat, Floor Phantom
- **Basic home gym:** Value Brawler, Discount Duke, Home Brand Hero
- **Lots of free weights:** Ironclad, Platebreaker, Barbellion
- **Lots of machines:** Pulley Assassin, Leg-Press Lich, Pinstack Witch

Still open: class outfits (the preview uses the starter outfit).

## Transitions between views (D23)

The whole app feels like one screen: every change of view is an animated transition, never a jump, a blank or a black flash.
**The lifter stays on screen** between views and moves to its new spot (a shared element). The boards show each step as a separate
phone frame only for layout; this table is the motion between them. All motion is hard-stepped (`steps()`), 240–320 ms.
With reduced motion, the panels cross-fade in 2 steps and the lifter does not move.

| From → to | Lifter | Panels | Ms |
| --- | --- | --- | --- |
| First launch → 1 Creator | Drops onto the stage floor from the top, one squash on landing | The sliders panel slides up from the bottom | 320 |
| 1 Creator → 2 Class select | Shrinks from 4× to 3× and steps onto the preview card | The sliders slide out left, the class card slides in from the right | 280 |
| 2 Class select → 3 Difficulty | Stays at 3×, moves to the left of the ladder | The class card slides out left, the ladder rises from the bottom rung up | 280 |
| 3 Difficulty → 4 Starting area | Stays on the floor line | The ladder slides out left; the area scene wipes in behind the lifter from the right, floor first, then the sky | 320 |
| 4 Starting area → 5 Summary | Stays in the area scene | The camera pulls back 1 step; the four choice chips stamp in around the lifter, one by one | 320 |
| 5 Summary → Hub (LET'S GO) | Stays in the same scene, now the hub's | The chips fly to their hub spots (class tag, level, workout card); the HUD and nav slide in | 320 |
| Any BACK in the setup | The same move, reversed | Reversed | same |
| Profile → one setup step (`?edit=1`) and back | Stays | The profile slides down, the step's panel slides up; SAVE reverses it | 280 |
| Hub → Workout (TRAIN ▶) and back (HUB in the bottom bar) | Stays in the scene | The camera zooms 1 step into the scene; the exercise strip drops in from the top; HUB reverses it | 240 |

## Starting areas (setup step 3)

**In the app** (D47) the area is picked on a swipe card like the class card: the scene with the lifter in it, then the name, line, hint and default tag.

**Reference board, not an app screen.** Like every board here, it shows the look and the behaviour for the Flutter build.
Shapes are placeholders for pixel-art scenes.

Brief 4.5–4.6: the area sets **the look, the palette and how a set is logged**. These five are proposals
built from this moodboard (the violet night base and neons, `borderlands-reference.md` §4 rarity ladder and §9 wasteland tones,
and the phone readability finding).

### The action is the set

There is **no + SET button**. Each area has one object to hit. Doing the action in the world logs one working set,
and the result **stays in the world** as the count:

| Area | Tap this | What happens | What stays (the count) | Every 5th | Default path |
| --- | --- | --- | --- | --- | --- |
| **Riptide Shore** (brief's beach) | Treasure chest on the sand | The lid flips open, a shell flies out in an arc | A loot pile of shells grows on the sand | a pearl flies out, **PEARL!** | any (neutral) |
| **Gainsgard Keep** (brief's castle) | The stone wall | A chalk scratch is drawn top-down, chalk dust | Tally marks on the wall: 4 strokes, then a slash | **SLASHED!** | Plate Paladin |
| **Rustbelt Flats** | Hazard-striped barrel | It explodes: starburst, smoke puffs, flying debris. A new barrel rolls in | A spray-painted X on the scrap sign, colour on the rarity ladder | **TAGGED!** | Scrapper |
| **Arcade Underpass** | PUNCH-O-TRON boxing machine | The pad snaps back, the counter ticks | Tickets on the floor, plus the machine's LED counter | **COMBO!** | Bargain Bruiser |
| **Frostbite Summit** | Ice block | It shatters into shards and reforms | A flag one step higher up the slope to the summit, rarity colours | **SUMMIT!** | Cablemancer |

Every action:
- The **whole scene shakes** (320 ms) and a starburst in the area colour says **+1 SET**, or the 5th-mark stamp.
- The object shows it can be tapped: a dashed ring and a bobbing stencil hint (TAP THE CHEST, SCRATCH THE WALL, BLOW UP THE BARREL, PUNCH THE MACHINE, SMASH THE ICE).
- All motion is hard-stepped (CSS `steps()`), with no easing, to match the pixel art. The action takes 0.4–0.7 s.
- **Long-press the object** takes the last set back (app-flow §4.2). On the board an UNDO button stands in for it. Undo has no effect animation.
- Records group in fives so you can count them without numbers (rule 3). The demo caps at 12.
- With reduced motion turned on, nothing shakes, flies, explodes or loops. Records just appear.

### Scenes

**Rule for every area: a light floor behind the lifter, a dark sky above,** plus a ground shadow under the lifter.
The `#0b0414` ink outline then has something light to stand against, which fixes the 1.03–1.22:1 contrast problem from the readability board.
Neon only on the action object, the records, props that react (torches, neon signs) and clothes (rule 3).

| Area | Sky / wall | Floor | Accent | Details |
| --- | --- | --- | --- | --- |
| Riptide Shore | `#12061f`, sea `#2a1148` | sand `#ad9293` | pink `#ff5fb0` | Twinkling stars, a cratered moon and its reflection, a palm island, rolling foam, a swaying palm, a starfish. |
| Gainsgard Keep | `#3a2a52` bricks | flagstone `#8672a5` | orange `#ffa033` | An arched moonlit window with a light beam, a chain, banners with dumbbell emblems, a flickering torch, a dumbbell rack, a pink runner rug. |
| Rustbelt Flats | `#1f0d36`, mesas `#3b2230`, dust `#ecd7d0` | rust `#a6643c` | orange | A striped setting sun, a mesa, a telephone pole with a sagging wire, a cactus with blinking orange eyes, a car wreck, tyres, cracks. |
| Arcade Underpass | `#12061f` + pink dots | concrete `#724eb2` | lime `#c6ff3d` | A riveted bridge deck, graffiti (SWOLE, GAINZ), a torn poster, a flickering OPEN 24/7 sign, a neon puddle, road markings. |
| Frostbite Summit | `#1a0b3b` | snow `#c9b8e8` | sky `#3fd2ff` | Stars, three drifting aurora bands, a snowy peak, a pine, a slope up to a pink summit flag, falling snow, footprints. |

The class link is the drawio's "Background changes" edge (Character Creation → Starting Area). The class picks the
default area, and the player can still choose any area. Lifters use `creator/body_atlas.png` at 2×.

## Workout screen (play, app-flow §4.2)

**Reference board, not an app screen.** Shown in Rustbelt Flats for a Scrapper (no equipment: push-ups, burpees, sprints).
Owner choices (21 Nov 2026): an active-exercise strip, a set target per exercise, this area and class. Owner decisions D6, D7, D15, D16 and D19 apply:
one session per calendar day that closes by itself, no I WORKED, no clock, no session counter, and XP per set with no reward screen.

**In the app** (D48) the workout is one card: the world on top, and under it an exercise carousel (one exercise at a time,
swiped both ways, round and round) in place of the strip and the header. Tapping the world adds to the exercise shown.
**Since D50–D53** the carousel runs over every exercise the filter tags (class, difficulty, body part, star) show, with a
counter (`12 / 437`) in place of the dots and a star button on the card. There are **no targets** (D52): no target slots,
no "SET n OF t", no CRUSHED, no moving on. The board below still shows the old strip and targets; follow `docs/decisions.md`.

Screen, top to bottom (390×844 dp):

1. **Top bar:** the class name (`SCRAPPER`) and the area name. HUB in the bottom bar goes back (every set is already saved, D44). No session counter, no clock.
2. **Exercise strip:** one card per exercise, 3 to 8 from the difficulty (D15). Each card shows the name, **target slots** (outlined Xs, filled in rarity-ladder colours as sets land), `+n` for extra sets, and a status: NOW / NEXT UP / CRUSHED.
   The active card is orange with a pink hard shadow. Tap a card to make it active. **Swipe a card** to switch the exercise for another
   from the class pool, **↺** returns a switched card to the first exercise, **✕** removes a card, and **+ ADD EXERCISE** adds one from the pool (D16).
3. **The world:** the Rustbelt Flats scene with the lifter at 3×. A bobbing hint says **BLOW UP THE BARREL** with `<EXERCISE> · SET n OF t` under it.
   The scrap sign shows the **active exercise's** Xs: filled ones in rarity colours, outlined ones still to do.
4. No finish button. The day's session closes by itself at midnight; a second visit on the same day adds to it (D6, D7).

Rules:
- **Tap the barrel = one working set of the active exercise.** It explodes, the scene shakes, a new barrel rolls in, and an X lands on the sign. The burst says **+1 SET**, or **CRUSHED!** when the target is reached.
- **Hold the barrel (550 ms) = take the last set back** (long-press, app-flow §4.2). On the board this works for real.
- When an exercise reaches its target, the strip **moves to the next unfinished exercise** after 0.8 s. Extra sets are allowed (up to 9).
- The **targets come from the app** (brief rule 4). 3 × 3 here is a placeholder until the workout lists per class exist (brief §8).
- **First-workout tip** (app-flow §4.2), at the top of the scene: "ONLY WORKING SETS COUNT. WARM-UPS DON'T. HOLD THE BARREL TO TAKE ONE BACK." with an OK button.
- **XP on each set** (D19, `docs/rules.md`): every set pops `+n XP` over the scene. A critical set (3%, ×2) pops **CRITICAL SET!!!** in pink.
- **Level-up:** the freeze-frame title card (same as Class select) slams **LEVEL n** with the level title.
  There is no reward overlay and no end-of-workout screen.

For other areas, swap the scene and the action object. Everything else stays the same (see "Starting areas").

## Difficulty (reference board)

**In the app** (D47) difficulty is a slider on the class step, not a ladder screen. The names, colours and jokes below still apply.

**Reference board, not an app screen.** Brief 4.3: many levels from total beginner to years of lifting, fantasy names, Borderlands tone.
Owner choices (21 Nov 2026): **6 levels**, a **vertical ladder** picker, XP shown as **gems with no numbers**, and names written here (proposals).

**Naming rule (owner, 21 Nov 2026):** difficulty names must read as difficulty levels. They must not sound like classes or hint at
classes (no Squire, Ranger, Warlock and so on). So every name is **`<WORD> MODE`**, the way games name difficulty.

Screen, top to bottom (390×844 dp):

1. `STEP 3 OF 5 · DIFFICULTY`, title **HOW HARD DO YOU GO?**, subline "Pick a difficulty mode. Harder modes earn more XP."
2. **The ladder:** two wooden rails with 6 rung buttons between them (a radio group), the hardest at the top and the easiest at the bottom.
   Each rung has a diamond in its rarity colour, the name, and 1–6 XP gems. The picked rung fills with its colour and gets a pink hard shadow.
3. **Detail card:** the name in its colour, `DIFFICULTY n OF 6`, who it is for, and the XP gems. The card's shadow takes the level colour.
4. **NEXT: STARTING AREA**.

Picking a rung plays the **freeze-frame title card** (same as Class select): a stencil slam of the name and a joke subtitle.
It closes after 1.8 s or on tap.

| # | Rarity colour | Name | Who it's for | Title-card joke | XP gems |
| --- | --- | --- | --- | --- | --- |
| 1 | muted `#c9b8e8` | **SOFA MODE** | Never lifted, or not for years. The gentlest workouts. | THE SOFA WILL REMEMBER YOU | 1 |
| 2 | lime `#c6ff3d` | **WARM-UP MODE** | A few weeks to a few months in. Easy, steady workouts. | EVERY LEGEND STARTS HERE | 2 |
| 3 | sky `#3fd2ff` | **SWEAT MODE** | Training most weeks, for about a year. Proper sweaty workouts. | TOWEL STRONGLY RECOMMENDED | 3 |
| 4 | violet `#a77bff` | **PAIN MODE** | About two years in. Hard workouts, real effort. | OUCH, BUT MAKE IT GAINS | 4 |
| 5 | orange `#ffa033` | **BRUTAL MODE** | Years of serious lifting. Very hard workouts. | THE RACK FEARS YOU NOW | 5 |
| 6 | pink `#ff5fb0` | **NIGHTMARE MODE** | Many years, competition level. The hardest workouts there are. | GRAVITY FILED A COMPLAINT | 6 |

- The gem count is a **picture of the XP multiplier**, not the number. The multipliers are in `docs/rules.md` (D19): 1.0 at the easiest level to 2.0 at the hardest, in even steps.
- The colours follow the rarity ladder from `borderlands-reference.md` §4, so harder reads as rarer.
- Don't use Borderlands' own difficulty names.
- The tone is loud and silly, never mean about bodies, as the reference asks.

