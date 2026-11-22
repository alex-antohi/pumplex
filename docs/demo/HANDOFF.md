# Demo to app: design handoff

Date: 22 November 2026. Status: v1. From: the app build. To: the design team.

The app team will port the demo layout (`docs/demo/`) into the Flutter app.
This file lists what the app team needs from design to do it well.

**Rule order:** [../decisions.md](../decisions.md) wins over this file. This file wins over `BRIEF.md`.

## 1. Why we need files, not more HTML

The demo draws almost all art with CSS boxes. For example, `05-area.html` and `08-workout.html`
each have about 90 hand-placed boxes for the area scenes. The app can copy these boxes into Flutter,
but that is slow work, and the real pixel art will replace it later.
Give us the art as image files. Then the app shows the real art, and we copy it only once.

## 2. Needed to port the layout (please send first)

| # | What | Format | Notes |
|---|---|---|---|
| 1 | **Area scenes**, all 5 areas (Riptide Shore, Gainsgard Keep, Rustbelt Flats, Arcade Underpass, Frostbite Summit) | PNG, 1× pixel scale, transparent where layers overlap | One file per layer: background (sky / wall), floor, the action object, the effect frames (burst, smoke, debris), and one sprite for each set mark (shell, scratch, X, ticket, flag). Give the object its idle, tap and hit frames. Give the frame order and milliseconds in a JSON file, like `docs/moodboard/animation/animation.json`. |
| 2 | **Fonts**: Anton and Space Mono | TTF, with the licence file (OFL) | The demo loads them from Google Fonts. The app is fully offline (D3), so the fonts must be files in the repo. Now the app uses the phone's own fonts and does not look like the demo. |
| 3 | **Icon set** | One SVG or PNG file per icon, 24×24 grid | All icons in `shared/demo.js` `ICONS` (back, menu, close, play, history, user, check, bolt, save, restore, flame and the rest), the area icons in `11-profile.html`, and the icons the app still shows as emoji: areas, gear slots, milestones (unlocked and locked), body, chaos mode, cel shader. The brief says "no emojis", and these files let us remove them. |
| 4 | **Screen-size rules** | A short note or a board | The demo fits only 390×844. Tell us what shrinks, scrolls or hides on a small phone (360×640) and on a tall phone (412×915). Tell us how `.foot` (the main button) sits above the Android navigation bar. |
| 5 | **One source of truth** | One line in `BRIEF.md` | When a canvas board (`docs/moodboard/canvas/*.dc.html`) and the demo differ, which one wins? We suggest the demo. |

## 3. Needed later (does not stop the port)

| # | What | Format | Notes |
|---|---|---|---|
| 6 | **Animations for all bodies** | PNG frames or sheets, like `docs/moodboard/animation/` | Now only 6 of the 50 bodies (2 sexes × 5 fat × 5 muscle) have idle, squat and flex. Send the rest, or a rule for which body to use when a body has no frames. Note: there are no PRs (D2), so the flex is for a level-up or a critical set. |
| 7 | **Class outfits and gear sprites** | PNG, same cell size as `body_atlas.png` (52×64) | One item per slot: head, top, bottom, shoes, weapon (D21). Gear never changes the body. |
| 8 | **Sound pack** | OGG or WAV, short | For the SOUND toggle in the menu: a set, the 5th-mark stamp, a critical set, a level-up. Now the app shows the toggle off, with a SOON tag. |

## 4. Not for design

These are owner decisions (D27). Do not wait for them, and do not design them:

- The exercise lists per class.
- The set targets and the number of exercises per difficulty level. The demo has 3, 4, 5, 6, 7, 8 exercises. The app has 3, 3, 4, 5, 6, 8. Both are placeholders.

## 5. Where to put the files

- Put the art in `docs/moodboard/` (for example `docs/moodboard/areas/<area-id>/` and `docs/moodboard/icons/`).
  The app copies it into `assets/`.
- Use the area and class ids from `shared/demo.js` in the file names (`rustbelt`, `scrapper` and so on). The ids never change.
- Push to `design/demo-flow` and say in the commit message which items of this list are done.
