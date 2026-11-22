# PUMPLEX promo pictures plan

Date: 21 November 2026. Status: draft v1. Owner: art director.
Read with [../app-brief.md](../app-brief.md), [../app-flow.md](../app-flow.md) and [../moodboard/README.md](../moodboard/README.md).

> **Out of date (22 Nov 2026):** D38–D41 removed gear items, chaos mode, the CEL SHADER mode and sound.
> Do not use copy or pictures here that show them. [05-design-handoff.md](05-design-handoff.md) and
> [../decisions.md](../decisions.md) win.

Working name: **PUMPLEX™** (placeholder). Tagline: **"Train, not track."**
Nothing in this plan is posted. No accounts were made.

## 0. Key points

1. Most Play Store screenshots need app screens that are **not built yet** (hub, workout, reward, setup). Play wants the real app in screenshots, so we cannot fake them.
2. Things we can make **now**: the moodboard sprites, the palette, the CEL SHADER mode, and the existing screens (preloader, START TRAINING clock, I WORKED, DAY DONE burst, past sessions, menu).
3. Our background `#12061f` is almost black. Play says the feature graphic must not use pure black or dark grey. Use `#2a1148` with the pink polka dots for the feature graphic.
4. r/androidapps does not take app launches now. Use r/droidappshowcase instead. r/Fitness allows promo only in the weekly Self-Promotion Saturday thread.
5. Pixel sprites scale only by whole numbers (2×, 4×, 5×, 10×, 12×), nearest-neighbour. Never smooth them.

---

## 1. Platform specs (checked 21 Nov 2026)

### 1.1 Google Play

| Asset | Spec |
|---|---|
| App icon | 512 × 512 px, 32-bit PNG (alpha OK), sRGB, max 1024 KB. Full square. Play adds the rounded mask (radius = 30 % of the size) and the shadow. Do not round corners or add a drop shadow. |
| Icon content | No text or badges for rank, price, deals, or Play programs. Nothing that misleads. Transparent parts show the Play UI colour, so use a solid background. |
| Feature graphic | 1024 × 500 px, JPEG or 24-bit PNG, **no alpha**. Keep key items away from the edges. Avoid pure white, black or dark grey. No device frames, no Play badges, no third-party trademarks. Alt text: 140 characters max. |
| Phone screenshots | 2 to 8. PNG or JPEG, max 8 MB each. Each side 320 to 3840 px. Long side max 2.3 × the short side. 9:16 or 16:9. |
| For promotion (recommended) | Apps: at least 4 screenshots, min 1080 px. Portrait 9:16, min 1080 × 1920. **We use 1080 × 1920 for all 8.** |
| Text on screenshots | Tagline max **20 % of the image area**. No small text. No busy background behind text. |
| Banned words on images | Rankings, awards, testimonials. "Best", "#1", "Top", "New", "Discount", "Sale", "Million downloads". |
| Banned calls to action | "Download now", "Play now" (and similar). |
| Status bar | Full battery, full Wi-Fi and signal, no notifications. |
| Short description | 80 characters. No emoji, no symbols, no repeated punctuation, no all-caps for emphasis. |
| Promo video | One YouTube URL (not a playlist or channel, no timecode). Public or unlisted. Ads off. Not age-restricted. Embeddable. Real app in the first 10 s. At least 80 % real app footage. Only the first 30 s autoplays (muted). Portrait or landscape, no black bars. Captions recommended. No promo or ranking words in overlays. |

### 1.2 Instagram

| Format | Size | Safe zone / notes |
|---|---|---|
| Feed post | **1080 × 1350 (4:5)**. Also OK: 1080 × 1440 (3:4), 1080 × 1080 (1:1). | The profile grid shows a **3:4** crop. On a 4:5 post, the grid cuts the sides: keep key items in the centre **1012 × 1350**. |
| Carousel | Same size on every slide. Up to 20 slides. | Instagram sizes all slides from slide 1. Make all slides 1080 × 1350. Keep the same safe zone on each slide. |
| Reels cover | 1080 × 1920 (9:16). | The grid shows a 3:4 crop (centre **1080 × 1440**; it cuts 240 px top and bottom). Keep the title in the middle. Nothing important near the bottom edge. |
| Story | 1080 × 1920 (9:16). | Keep about **250 px top and bottom** free of text and logos (profile bar, reply bar). Keep about 120 px clear on the right for Reels buttons. |
| Profile picture | Shows as a circle (320 × 320). | Use the icon art, centred. |

### 1.3 Reddit

| Item | Spec |
|---|---|
| Image post | No fixed ratio. Max 20 MB per image. **Use 1080 × 1350 (4:5) or 1200 × 1200 (1:1).** The feed can crop tall images, so keep key items in the centre. |
| Gallery | Up to 20 images. Caption up to 180 characters per image. |
| General rule | Many subs follow the 90 / 10 guide: about 90 % real participation, max 10 % own content. Sub rules always win. |

Subreddit rules (from rule mirrors and guides; reddit.com blocked our reader). **Read each sidebar again before you post.**

| Subreddit | What we found | What works |
|---|---|---|
| r/IndieDev | Few strict rules. Images and GIFs do better than store links. Capsule-art comparisons only on Wednesdays. | Dev-log images: "I made X, what do you think?" Raw art, process, before/after. |
| r/indiegaming | One post per 2 weeks. No repeats. Store pages alone are "bad content". **Say how generative AI was used, if it was used anywhere in the game or promo.** | One strong visual, a game-like look, a human story. |
| r/gamification | Small, design-minded sub. No rule text found. | A discussion post about the mechanic (sets, not reps), with one clear diagram. |
| r/androidapps | **No launch, self-promo or tester posts.** It sends them to r/droidappshowcase. | Do not post the launch here. Use r/droidappshowcase. Join normal threads only as a user. |
| r/droidappshowcase | The place r/androidapps names for "check out my app" posts. | Plain screenshot gallery + honest text. |
| r/Fitness | Promo only in the weekly **Self-Promotion Saturday** thread. Own content elsewhere needs mod approval first. Older rule: no self-promo or surveys. | One comment in the Saturday thread with one image link. |
| r/bodyweightfitness | "Limited self-promotion". Older rule: apps allowed only if **totally free** (no paid tier, no in-app purchases). | Only if PUMPLEX is fully free. Ask the mods first. Focus on the no-equipment (Speedy) class. |

---

## 2. Shot lists

Colour short names: **BG** `#12061f`, **SURF** `#1f0d36`, **STAGE** `#2a1148` (+ pink dots), **INK** `#0b0414`, **TEXT** `#f6eeff`, **MUTED** `#c9b8e8`, **PINK** `#ff5fb0`, **LIME** `#c6ff3d`, **ORANGE** `#ffa033`, **VIOLET** `#a77bff`, **SKY** `#3fd2ff`.

Sprite short names: **B1** `builds/build01_male_fat55_muscle100.png` (big lime tank), **B2** `build02_female_fat0_muscle35` (lean, pink ponytail, sky), **B3** `build03_female_fat100_muscle50` (heavy, orange), **B4** `build04_male_fat0_muscle15` (skinny, blue mohawk). **SL-M / SL-F** = the 3 × 3 body-slider grids in `body_sliders/male|female/`.

Status key: **NOW** = can make from existing assets. **SCREEN** = needs a new app screen built first. **ART** = needs new art.

### 2.1 Google Play Store

#### P0 – App icon (512 × 512)

| Field | Plan |
|---|---|
| Purpose | Be readable at 48 px in search results. |
| Layout | Full-bleed STAGE background with pink dots. A pixel-art head + flexed arm (from B1), big, centred inside the keyline circle (about 384 px). INK 1 px outline at the source scale. One neon (LIME tank) as the accent. |
| Text | None. |
| Source | New 64 × 64 icon art, scaled 8× to 512. |
| Status | **ART** |

#### P1 – Feature graphic (1024 × 500)

| Field | Plan |
|---|---|
| Purpose | The top banner of the store page. Sets the "video game" tone. |
| Layout | Background STAGE with pink dots (not BG: too close to black). Left 45 %: PUMPLEX™ wordmark (Anton, TEXT, stacked shadow PINK + VIOLET), tagline below in Space Mono. Right 55 %: B1, B2, B3, B4 at 4× (160 × 256 each) on one floor line, with neon name tags. Keep 60 px clear on every edge. Keep the centre light, in case a video play button sits on top. |
| Text | **PUMPLEX™** / "TRAIN, NOT TRACK." |
| Colours | STAGE, TEXT, PINK, VIOLET, + outfit neons. |
| Status | **NOW** with a temporary Anton wordmark. Final needs the **logo (ART)**. |

#### P2–P9 – Phone screenshots (1080 × 1920, 9:16), in story order

Shared layout for all 8: top band 0–340 px (17.7 % of the area, under the 20 % limit) on SURF with an INK 4 px bottom border. Headline in Anton 104 px, TEXT, max 2 lines, stacked hard shadow in the slide's neon. Below the band: the real app screen, full width, scaled to fit. No device frame. Clean status bar.

| # | Purpose | Headline | App screen / sprites | Accent | Status |
|---|---|---|---|---|---|
| P2 | Hook: the whole idea | TRAIN, NOT TRACK. | Hub: character, level, XP bar, START TRAINING ▶ | PINK | SCREEN (hub) |
| P3 | The main rule | COUNT SETS. NOTHING ELSE. | Workout: SQUATS and PUSH-UPS cards, shells in a pouch | LIME | SCREEN + ART (shells, pouch) |
| P4 | Character | BUILD YOUR BODY. NO SCALE. | Character creation with 3 sliders and SL sprites | ORANGE | SCREEN (sprites exist) |
| P5 | Class | YOUR GEAR IS YOUR CLASS. | Class pick: 4 equipment cards with class sprites | SKY | SCREEN + ART (class outfits) |
| P6 | Difficulty | FROM COUCH TO LEGEND. (placeholder; final names from design) | Difficulty list with fantasy names | VIOLET | SCREEN + names |
| P7 | Worlds | TRAIN ON A BEACH. OR IN A CASTLE. | Split: beach area with shells / castle wall with scratches | ORANGE + SKY | SCREEN + ART (areas) |
| P8 | Reward | I WORKED 💪 = XP. | Reward: XP burst, LEVEL UP, character pose | LIME | SCREEN + ART (burst, pose) |
| P9 | Trust | OFFLINE. YOUR DATA STAYS ON YOUR PHONE. | Past sessions list (exists) + menu backup | PINK | **NOW** (change after the history redesign) |

Rules for P2–P9:
- Use only screens that exist in the build we upload.
- No "new", "best", "#1", "download now".
- Draw 💪 and ▶ as pixel icons, not system emoji. System emoji look different on each phone.

Promo video (optional, later): 20–30 s portrait screen recording. The first 3 s show the hub and START TRAINING. Then 3 shell taps, I WORKED, LEVEL UP. Captions in Anton. No promo words.

### 2.2 Instagram

All feed pictures: 1080 × 1350. Key items in the centre 1012 × 1350. Logo small, bottom right, inside the safe zone.

#### Launch carousel (8 slides, 1080 × 1350)

| # | Purpose | Headline on image | Layout and sprites | Colours | Status |
|---|---|---|---|---|---|
| C1 | Stop the scroll | YOUR GYM APP IS A SPREADSHEET. OURS IS A GAME. | Left: a grey, boring table of reps and kilos (drawn flat, MUTED). Right: B1 at 10× flexing on STAGE. Hard diagonal split in INK. | MUTED vs PINK, LIME | NOW (B1 static); better with flex pose (ART) |
| C2 | The rule | NO REPS. NO KILOS. JUST SETS. | 3 big tally icons crossed out (REPS, KG), one lime check (SETS). | LIME, INK | NOW (simple shapes) |
| C3 | Body sliders | SLIDE YOUR BODY. NEVER TYPE YOUR WEIGHT. | SL-M grid, 3 × 3 at 4× (208 × 256 each), axes labelled FAT → and MUSCLE ↑. | ORANGE, STAGE | **NOW** |
| C4 | Classes | YOUR GEAR = YOUR CLASS. | 4 panels: NO GEAR / HOME GYM / FREE WEIGHTS / MACHINES with B2, B4, B1, B3 (temporary). | SKY, VIOLET | NOW (temp); final needs class outfits (ART) |
| C5 | Difficulty | DIFFICULTY NAMES THAT ROAST YOU. | A loud vertical list of fantasy level names, one highlighted. | VIOLET, PINK | Needs names (copy) |
| C6 | Worlds | COUNT SETS WITH SHELLS. OR SCRATCHES. | Top half beach + pouch, bottom half castle wall + tally marks. | ORANGE, SKY | ART |
| C7 | Reward | I WORKED 💪 → LEVEL UP. | Big XP bar, LEVEL UP burst, B1 in a pose. | LIME, PINK | ART (burst); DAY DONE burst exists as a base |
| C8 | Close | TRAIN, NOT TRACK. ANDROID. OFFLINE. | Wordmark centred, all 4 builds in a row, "link in bio" in Space Mono. | PINK, VIOLET | NOW (temp wordmark) |

#### Single posts (1080 × 1350)

| # | Purpose | Headline | Layout and sprites | Status |
|---|---|---|---|---|
| IG1 | Comments: "which one are you?" | WHICH ONE ARE YOU? | SL-F grid 3 × 3 at 4×, each tile numbered 1–9. Caption asks for a number. | **NOW** |
| IG2 | Meme, share bait | OTHER GYM APPS / PUMPLEX | Two-panel meme. Top: a stressed sprite (B4) under a wall of numbers. Bottom: B1 dropping a shell in a pouch, smug. | NOW (B4, B1); shell is ART, can be a simple placeholder |
| IG3 | Meet the cast | THE STARTING FOUR. | B1–B4 at 8× on STAGE with name tags (INK box, 2 px neon border) and a silly one-line bio each. | **NOW** |

#### Story frames (1080 × 1920)

| # | Purpose | Headline | Layout | Status |
|---|---|---|---|---|
| S1 | Poll | DO YOU COUNT REPS? | Headline at y 300–600. B4 confused at 10× in the middle. Leave y 1150–1500 empty for the poll sticker ("YES" / "WHAT ARE REPS"). | **NOW** |
| S2 | Launch countdown / link | PUMPLEX LOADS IN… | The preloader look (exists) with a fake progress bar. Leave space for a countdown or link sticker at y 1200–1500. | **NOW** (preloader screen capture) |

#### Reels covers (1080 × 1920; title inside the centre 1080 × 1440)

| # | Reel | Cover headline | Layout | Status |
|---|---|---|---|---|
| RC1 | Screen recording: tap shells, I WORKED, LEVEL UP | I COUNTED SHELLS, NOT REPS. | Phone screen still in the middle (no frame). Headline in the middle third, Anton 120 px. | SCREEN + ART |
| RC2 | Slider challenge: fat 100 / muscle 100 vs fat 0 / muscle 0 | MAX FAT. MAX MUSCLE. GO. | Two sprites side by side at 12×: `male/fat100_muscle100` and `male/fat0_muscle0`. "VS" in PINK between them. | **NOW** |

### 2.3 Reddit (native look, not an ad)

Rules for all Reddit images: no big logo, no tagline banner, no "download". Show real work. Max 1 line of label text. Small PUMPLEX™ only in a corner, or not at all. The post text tells the story, in first person.

| # | Subreddit | Purpose | Size | Image | Text on image | Status |
|---|---|---|---|---|---|---|
| R1 | r/IndieDev | Dev log: body sliders | 1200 × 1200 | SL-M and SL-F grids side by side at 4×, on STAGE, with tiny Space Mono labels `fat0 … fat100`. Looks like a sprite sheet. Title idea: "I drew fat × muscle sliders for my gym game. 18 sprites so far. What's missing?" | `fat →` `muscle ↑` | **NOW** |
| R2 | r/indiegaming | Look reveal | 1080 × 1350 | Top: the app with CEL SHADER off. Bottom: CEL SHADER on, with B1–B4. "Before / after" feel. Disclose any AI help in the post. | OFF / ON | **NOW** (shader exists) |
| R3 | r/gamification | Discussion: does a simpler log help the game layer? | 1200 × 1200 | A clean loop diagram: START TRAINING → tap = 1 shell → I WORKED → XP → level. Flat SURF boxes, INK borders, one neon per step. | Step labels only | **NOW** |
| R4 | r/droidappshowcase (not r/androidapps) | Launch gallery | 1080 × 1920, 4–5 images | Plain real screenshots (P2, P3, P4, P8, P9) **without** the headline bands. Honest post text: offline, no account, what is not done yet. | None | SCREEN |
| R5 | r/bodyweightfitness (only if fully free) or the r/Fitness Self-Promotion Saturday thread | "No equipment" angle | 1080 × 1350 | The Speedy class (no equipment) workout screen: PUSH-UPS, BURPEES, SPRINTS cards with set marks. B2 at 8× beside it. | None, or "NO GEAR CLASS" | SCREEN + ART (class) |

Timing: one sub per day at most. Do not post the same image to many subs in one hour. Reply to every comment.

---

## 3. What we can make now, and the new art we need

### 3.1 Summary

| Can make now (existing assets) | Needs new screens or art |
|---|---|
| P1 feature graphic (temp wordmark) | P0 icon |
| P9 screenshot | P2–P8 screenshots |
| C2, C3, C8 (C1, C4 with temporary art) | C5, C6, C7 |
| IG1, IG3 (IG2 with a placeholder shell) | RC1 |
| S1, S2 | R4, R5 |
| RC2 | Promo video |
| R1, R2, R3 | |

About 15 of 31 pictures can be made now.

### 3.2 New art list

| # | Item | Size / form | Used by | Priority |
|---|---|---|---|---|
| A1 | PUMPLEX™ logo: Anton-based wordmark + pixel version | Vector + 2 px pixel version | P1, C8, all corners | High |
| A2 | Icon art: head + flexed arm | 64 × 64 sprite, 8× = 512 | P0, IG profile | High |
| A3 | Flex / victory pose frames for B1 (and later all builds) | 40 × 64, 2–4 frames | C1, C7, P8, RC1 | High |
| A4 | Shell + pouch set marks (beach) | 16 × 16 shell, 32 × 32 pouch, 3 fill states | P3, C6, IG2, RC1 | High |
| A5 | Wall + scratch tally marks (castle) | 64 × 64 wall tile, 1–5 tally states | P7, C6 | Medium |
| A6 | Beach and castle backgrounds | 270 × 480 (4× = 1080 × 1920) | P7, C6, hub | Medium |
| A7 | Class outfits for the 4 classes | 40 × 64 each | P5, C4, R5 | Medium |
| A8 | LEVEL UP burst + XP bar | burst 64 × 64, 4 frames | P8, C7 | Medium |
| A9 | Pixel icons: ▶, 💪, check, cross | 16 × 16 | All buttons and headlines | Medium |
| A10 | Fantasy difficulty names (copy, not art) | 8–12 names + one-liners | P6, C5 | Medium |
| A11 | Built app screens: character creation, class, difficulty, area, hub, workout, reward | Real app | P2–P8, R4, R5, RC1 | Blocker for Play |

---

## 4. Consistency guide

### 4.1 Fonts

| Use | Font | Rules |
|---|---|---|
| Headlines | **Anton** (Google Fonts, OFL) | Uppercase. Letter spacing 1 px. Stacked hard shadow `3px 3px 0 <neon>, 6px 6px 0 <neon2>` (scale with size: about 3 % of the font size per step). |
| Body, labels, captions | **Space Mono** 400 / 700 | Sentence case. Never below the minimum size. |

### 4.2 Text size (on a 1080 px wide canvas)

| Format | Headline (Anton) | Body (Space Mono) | Max headline words |
|---|---|---|---|
| Play screenshot | 96–110 px | 40 px | 6 |
| Play feature graphic (1024 wide) | wordmark 110 px, tagline 36 px | – | 4 |
| Instagram feed | 90–130 px | 36–44 px | 8 |
| Story / Reels cover | 110–140 px | 44 px | 6 |
| Reddit | labels only, 32–48 px Space Mono | – | 3 |

Minimum text: 32 px on a 1080 px canvas. Test every image at phone size.

### 4.3 Logo placement

- Play: the logo is only in the feature graphic (left side) and the app itself. Not on screenshots.
- Instagram: small wordmark, bottom right, 140 px wide, 60 px inside the safe zone. On covers and Stories, keep it above the bottom 250 px.
- Reddit: no logo, or a tiny one in a corner (max 100 px wide).
- Clear space around the logo: the height of the letter "P" on all sides.

### 4.4 Sprites

- Scale only by whole numbers: 4×, 5×, 8×, 10×, 12×. Nearest-neighbour only.
- Keep the 1 px INK outline (it scales with the sprite).
- Put characters on STAGE (`#2a1148` + pink dots) or SURF. Neon goes on clothes and accents only.
- Light comes from the top left. Shadows lean violet.

### 4.5 Do / Don't

| Do | Don't |
|---|---|
| Use the palette in `palette.json` only. | Use gradients, glows, blur or soft shadows. |
| Use flat panels with 3–4 px INK borders and hard offset neon shadows. | Use rounded corners on panels or the icon. |
| Use one main neon per picture, one or two more as accents. | Use all 5 neons at the same size and weight. |
| Make the joke loud and short. Roast the user lightly. | Body-shame. Mock the body, never the person. Every body type is a valid build. |
| Show the real app on Play and r/droidappshowcase. | Show features that are not built. |
| Keep text inside the safe zones listed in section 1. | Put text at the edges of a Reels cover or Story. |
| Use our own names and art. Borderlands is for tone only. | Use any Borderlands names, fonts, logos or art style copies. |
| Say "offline" and "no account" only while they are true. | Use "best", "#1", "new", "download now" on Play images. |
| Draw emoji as pixel icons. | Use system emoji inside images. |
| Disclose AI help where a sub asks (r/indiegaming). | Post the same image to many subs in one hour. |

---

## 5. Open questions

1. Is PUMPLEX free, paid or freemium? This decides r/bodyweightfitness.
2. Final name and logo: the plan uses PUMPLEX™ as a placeholder.
3. Difficulty names and class names: needed for P5, P6, C4, C5.
4. Was any AI used to make the sprites? If yes, say so on r/indiegaming.

## 6. Sources

- Google Play preview assets: https://support.google.com/googleplay/android-developer/answer/9866151
- Google Play icon design specs: https://developer.android.com/distribute/google-play/resources/icon-design-specifications
- Instagram sizes: https://buffer.com/resources/instagram-image-size/ , https://stan.store/blog/instagram-post-size-guide-2026/ , https://influencermarketinghub.com/instagram-image
- Reddit image sizes: https://picturesizes-com.pages.dev/specs/social-media/reddit , https://thenextweb.com/news/reddit-now-supports-up-to-20-gifs-or-images-in-a-single-post
- Subreddit rules: https://okara.ai/blog/subreddits-that-allow-self-promotion , https://github.com/DevelopersCoffee/airo/issues/1756 , https://axebps-redlib.hf.space/r/Fitness/wiki/rules , https://lr.vern.cc/r/bodyweightfitness/wiki/rules , https://redship.io/blog/reddit-self-promotion-rules

Note: reddit.com could not be read directly. The subreddit rules come from mirrors and guides. Check each live sidebar before posting.
