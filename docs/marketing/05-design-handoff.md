# PUMPLEX promo pictures: design handoff

Date: 22 November 2026. Status: v1.1 (name changed back to PUMPLEX, D37). From: marketing. To: the design team.

This is the work order for the promo pictures. It replaces the shot list in
[02-promo-pictures.md](02-promo-pictures.md) where they differ. Keep using 02 for the
platform specs (§1) and the consistency guide (§4).

**Rule order:** [../decisions.md](../decisions.md) wins over this file. This file wins over 02.

## 1. What changed since 02-promo-pictures.md

| Change | Effect on the pictures |
|---|---|
| **The name is PUMPLEX** (D37, owner, 22 Nov 2026). An earlier draft of this file said SWOLEMANCER. That name is dropped. | Use PUMPLEX in the logo, the icon and every headline. Do not use SWOLEMANCER as the app name. |
| No streak (D34) and no achievements or milestones (D35). | Do not show a streak, a week target, embers, medals or milestones. |
| The workout has no tools (D32): no swap, skip, remove or add. | Do not show a swipe, a tool row or an ADD card. |
| No START TRAINING, no I WORKED, no clock, no reward screen (D7). | Do not show these buttons or screens. The reward is the **XP pop**, **CRITICAL SET** and the **level-up freeze-frame card**. |
| No preloader (D29). | Story S2 does not use the preloader. See the new S2 below. |
| 5 starting areas, each with its own set mark (moodboard "Starting areas"). | "Beach or castle" becomes "five worlds". Use the real set marks: chest + shells, chalk scratches, barrel, PUNCH-O-TRON, ice block. |
| Class names: Scrapper, Bargain Bruiser, Plate Paladin, Cablemancer (D9, working names). | Use them. They can still change, so keep them in editable text layers. |
| 6 difficulty names: Sofa, Warm-up, Sweat, Pain, Brutal and **Nightmare Mode** (D28). The demo's Couch Spawn … Ascended Swolemancer names are dropped (owner, 22 Nov 2026). | Use the MODE names. "Become the Swolemancer" can stay as a slogan, but no difficulty has that name. |
| "Swolemancer" as a fantasy word (a tagline, not the app name). | It can stay in a slogan, like the class-step kicker "THE SWOLEMANCER'S PATHS". It is never the app name. |
| A clickable HTML demo of every screen exists (`docs/demo/`). | Instagram and Reddit can show demo screens, marked as "in development". **Google Play cannot** (see §3). |

## 2. Name and brand

- **Name:** PUMPLEX (D37). Write it in capitals in headlines and in the logo.
- **Tagline:** "Train, not track." Other lines you can use: "Summon your gains." and "Count sets. Level up."
- **Legal status:** a trademark search is **not done yet**. Make the logo, but do not print anything (stickers, shirts) until the owner confirms the name is safe.
- **Do not use ™ or ®** after the name until the owner says so.

## 3. Hard rules (read before you start)

1. **Google Play screenshots show the real Android app only.** The HTML demo is not the app. Make P2–P9 after the demo layout is ported into the app (decisions.md §2, the `docs/demo/` screens row). The hub, workout, profile and menu are ported now.
2. **No features that are not built.** On Instagram and Reddit, demo screens get a small "IN DEVELOPMENT" tag (Space Mono, 28 px, MUTED, bottom left).
3. **Sprites scale by whole numbers only** (4×, 5×, 8×, 10×, 12×), nearest-neighbour. Never smooth them.
4. **No pure black or dark grey on the feature graphic.** Use STAGE `#2a1148` with pink dots, not BG `#12061f`.
5. **No body shaming.** Every body is a valid build. Jokes roast the habit, never the body.
6. **Borderlands is tone only.** No Borderlands names, fonts, logos or copied art.
7. **No system emoji in images.** Draw ▶, 💪, check and cross as pixel icons.
8. **Play images:** no "best", "#1", "top", "new", "free", "download now", no rankings or reviews.
9. **AI:** tell the owner if you use AI for any part of a picture. r/indiegaming needs this in the post.

## 4. What to make, in three batches

Colours, sprites and fonts: see 02 §2 (short names BG, SURF, STAGE, INK, TEXT, MUTED, PINK, LIME, ORANGE, VIOLET, SKY; sprites B1–B4, SL-M, SL-F) and `../moodboard/palette.json`.

### Batch 1: brand art (start now, highest priority)

Everything else uses these.

| ID | Item | Size | Notes |
|---|---|---|---|
| A1 | PUMPLEX wordmark | Vector (SVG) + pixel version (2 px stroke) | Anton base. Stacked hard shadow PINK + VIOLET. Must read at 140 px wide. Make a stacked (2-line: PUMP / LEX) and a 1-line version. |
| A2 | App icon art | 64 × 64 sprite, 8× = 512 × 512 PNG | A pixel head with a flexed arm, or a hooded lifter with a glowing dumbbell. Full-square STAGE background. No text, no rounded corners, no shadow (Play adds them). Must read at 48 px. Send 2–3 options. |
| A3 | Pixel icon set | 16 × 16 each | ▶, 💪, check, cross, XP star. The app icon set (`docs/moodboard/icons/`) is done; reuse it at promo size. |

### Batch 2: pictures we can make now

Use the moodboard sprites, the demo screens and the boards.

| ID | Platform | Size | Headline | Content | Source |
|---|---|---|---|---|---|
| P1 | Play feature graphic | 1024 × 500, no alpha | PUMPLEX / TRAIN, NOT TRACK. | Left 45 %: A1 + tagline. Right 55 %: B1–B4 at 4× on one floor line. 60 px clear on every edge. Keep the centre calm (a video play button can sit there). | A1, `moodboard/builds/` |
| C1 | IG carousel | 1080 × 1350 | YOUR GYM APP IS A SPREADSHEET. OURS IS A GAME. | Left: a grey table of reps and kilos (MUTED). Right: B1 at 10×. Diagonal INK split. | B1 (later: `pr_flex` frame) |
| C2 | IG carousel | 1080 × 1350 | NO REPS. NO KILOS. JUST SETS. | REPS and KG crossed out, SETS with a lime check. | A3 |
| C3 | IG carousel | 1080 × 1350 | SLIDE YOUR BODY. NEVER TYPE YOUR WEIGHT. | SL-M 3 × 3 at 4×. Axes FAT → and MUSCLE ↑. Add the height slider from `02-character.html`. | `body_sliders/male/` |
| C4 | IG carousel | 1080 × 1350 | YOUR GEAR = YOUR CLASS. | 4 panels: SCRAPPER (no gear), BARGAIN BRUISER (home gym), PLATE PALADIN (free weights), CABLEMANCER (machines). Class colours from `demo.js`. | `03-class.html` |
| C5 | IG carousel | 1080 × 1350 | FROM SOFA MODE TO NIGHTMARE MODE. | The 6 difficulty names as a ladder, gems 1–6, top rung in PINK. | `04-difficulty.html` |
| C6 | IG carousel | 1080 × 1350 | FIVE WORLDS. FIVE WAYS TO COUNT A SET. | 5 strips: chest + shells, chalk scratches, barrel, PUNCH-O-TRON, ice block. Each with its call (PEARL!, SLASHED!, TAGGED!, COMBO!, SUMMIT!). | `05-area.html`, `scrapper_rustbelt.html`, moodboard "Starting areas" |
| C7 | IG carousel | 1080 × 1350 | ONE SET. ONE BOOM. LEVEL UP. | Barrel blast → XP pop → level-up freeze-frame card. | `08-workout.html`, `canvas/Workout.dc.html` |
| C8 | IG carousel | 1080 × 1350 | TRAIN, NOT TRACK. ANDROID. OFFLINE. | A1 centred, B1–B4 in a row, "link in bio" in Space Mono. | A1 |
| IG1 | IG post | 1080 × 1350 | WHICH ONE ARE YOU? | SL-F 3 × 3 at 4×, tiles numbered 1–9. | `body_sliders/female/` |
| IG2 | IG post | 1080 × 1350 | OTHER GYM APPS / PUMPLEX | 2-panel meme. Top: B4 under a wall of numbers. Bottom: B1 blowing up a barrel, smug. | B4, B1, barrel |
| IG3 | IG post | 1080 × 1350 | THE STARTING FOUR. | B1–B4 at 8× with name tags and a silly one-line bio. Bios: marketing writes them, see 03-promo-text.md. | `moodboard/builds/` |
| S1 | IG Story | 1080 × 1920 | DO YOU COUNT REPS? | B4 confused at 10×. Leave y 1150–1500 empty for the poll sticker. | B4 |
| S2 | IG Story | 1080 × 1920 | THE SWOLEMANCER AWAITS. | The freeze-frame title card (greyscale sprite, diagonal stripes, stencil name). Leave y 1200–1500 empty for a countdown or link sticker. **Not the preloader** (D29). | moodboard "Freeze-frame intro card" |
| RC1 | IG Reels cover | 1080 × 1920 | I BLEW UP BARRELS, NOT COUNTED REPS. | Still from the Rustbelt workout: the barrel blast. Title in the centre 1080 × 1440. | `scrapper_rustbelt.html` |
| RC2 | IG Reels cover | 1080 × 1920 | MAX FAT. MAX MUSCLE. GO. | `male/fat100_muscle100` vs `male/fat0_muscle0` at 12×, PINK "VS". | `body_sliders/male/` |
| R1 | r/IndieDev | 1200 × 1200 | (labels only) `fat →` `muscle ↑` | SL-M and SL-F side by side at 4×, like a sprite sheet. No logo. | `body_sliders/` |
| R2 | r/indiegaming | 1080 × 1350 | (labels only) OFF / ON | The app with CEL SHADER off (top) and on (bottom). | Screenshots of the real app, menu → cel shader |
| R3 | r/gamification | 1200 × 1200 | (step labels only) | Loop diagram: OPEN APP → TAP THE MARK = 1 SET → XP POP → LEVEL-UP CARD → NEW GEAR. No streak (D34). Flat SURF boxes, INK borders, one neon per step. **No START TRAINING, no I WORKED.** | `../rules.md` |

### Batch 3: after the app has the new screens

Wait until the demo layout is in the Android app. Then take real screenshots from a phone (full battery, full signal, no notifications).

| ID | Purpose | Headline | App screen | Accent |
|---|---|---|---|---|
| P2 | Hook | TRAIN, NOT TRACK. | Hub: character, level, XP bar, workout card with TRAIN ▶ | PINK |
| P3 | The rule | COUNT SETS. NOTHING ELSE. | Workout: one mark tapped, `SET n OF t` | LIME |
| P4 | Character | BUILD YOUR BODY. NO SCALE. | Character creation: sex, height, fat, muscle | ORANGE |
| P5 | Class | YOUR GEAR IS YOUR CLASS. | Class select with the user's body (D25) | SKY |
| P6 | Difficulty | BECOME THE SWOLEMANCER. | Difficulty ladder, Nightmare Mode on top | VIOLET |
| P7 | Worlds | FIVE WORLDS TO TRAIN IN. | Area select, or a split of 2 area workouts | ORANGE + SKY |
| P8 | Reward | EVERY SET IS XP. | Level-up freeze-frame card, or CRITICAL SET | LIME |
| P9 | Trust | OFFLINE. YOUR DATA STAYS ON YOUR PHONE. | Past sessions (rows by date) + menu backup | PINK |
| R4 | r/droidappshowcase | (none) | P2, P3, P4, P8, P9 without the headline bands | – |
| R5 | r/Fitness Saturday thread | NO GEAR CLASS | Scrapper workout: push-ups, burpees, sprints | ORANGE |

Screenshot layout (P2–P9): 1080 × 1920. Top band 0–340 px on SURF with a 4 px INK bottom line.
Headline in Anton 104 px, TEXT, max 2 lines, with a hard shadow in the accent colour. The real screen goes below, full width, with no device frame.

**Later (optional):** a 20–30 s portrait promo video. Show the hub in the first 3 s. Then show 3 set marks, an XP pop and the level-up card. At least 80 % must be real app footage.

## 5. New art still needed

| ID | Item | For | Priority |
|---|---|---|---|
| A1–A3 | Wordmark, icon, pixel icons | Everything | **High (batch 1)** |
| A4 | `pr_flex` frames for B1–B4 | C1, C7, IG2, P8 | High |
| A5 | Class outfits (4) | C4, P5, R5 | Medium. C4 can use B1–B4 until then. |
| A6 | Set-mark art for all 5 areas at promo size | C6, P3, P7 | Medium. Rustbelt exists. |
| A7 | Level-up card at promo size, with PUMPLEX copy | C7, S2, P8 | Medium |

## 6. Delivery

- **Folder:** `docs/marketing/assets/<platform>/`. Use `play`, `instagram` and `reddit`, and put A1–A3 in `brand`.
- **File name:** `<ID>_<short-name>_<W>x<H>.png`, for example `C3_body-sliders_1080x1350.png`.
- **Format:** PNG, sRGB. The feature graphic has no alpha. The icon is 512 × 512, 32-bit, max 1 MB.
- **Sources:** put the editable source file next to each PNG (`.svg`, `.fig` export, `.aseprite` or `.html`). Keep all text as live text, because class and difficulty names can still change.
- **Order:** Batch 1 first, then batch 2. Commit each finished batch on its own branch and ask the owner to review.

## 7. Check each picture before delivery

- [ ] The right size, and the text is inside the safe zone (02 §1.2).
- [ ] Sprites use whole-number scale and are not blurred.
- [ ] Only colours from `palette.json`. No gradients, glow or blur.
- [ ] No START TRAINING, I WORKED, clock, reward screen or preloader.
- [ ] No streak, week target, embers, milestones, medals, workout tool row or ADD card (D32, D34, D35).
- [ ] Demo screens have the "IN DEVELOPMENT" tag (Instagram and Reddit only).
- [ ] Headline text is readable at phone size (min 32 px on a 1080 px canvas).
- [ ] No banned Play words. No system emoji.
- [ ] "PUMPLEX" is spelled right, with no ™ (until the owner says so, §2).

## 8. Open questions for the owner

1. Is the trademark check for PUMPLEX done? Batch 1 can start before it, but printing cannot.
2. ~~Should the top difficulty keep the name "Ascended Swolemancer"?~~ Answered: no. The owner dropped those names; the top difficulty is Nightmare Mode (D28).
3. Is the app free, paid or freemium? This decides R5 (r/bodyweightfitness allows only fully free apps).
4. Was AI used for any sprites? If yes, the r/indiegaming post must say so.
