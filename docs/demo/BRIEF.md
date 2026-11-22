# PUMPLEX demo: design brief for every screen

A clickable HTML demo of the whole app flow (`docs/app-flow.md` §2). Screens 01 (preloader) and 09 (reward)
are gone (D29, D7, D19); the other files keep their numbers.
Open `docs/demo/index.html` in a browser. Each screen is one HTML file; they link to each other
and share state through `localStorage`, so the demo plays like the real app.

**Source of truth:** when a canvas board (`docs/moodboard/canvas/*.dc.html`) and the demo differ, the demo wins (`docs/decisions.md` still wins over both).

Read before you design a screen:

1. `docs/decisions.md` (the owner's decisions D1–D30; they win over everything below), then
   `docs/app-brief.md` (product rules) and `docs/app-flow.md` (the flow and each screen).
2. `docs/moodboard/README.md` (the look, palette, type, panels, class and area specs).
3. The board for your screen in `docs/moodboard/canvas/*.dc.html`, if there is one. Port its look; don't reinvent it.
4. `shared/pumplex.css` (tokens and components) and `shared/demo.js` (`window.PX`: data, state, navigation, helpers).

## Files

| File | Screen |
|---|---|
| `02-character.html` | Character creation: sex, height, fat, muscle (setup 1 of 5) |
| `03-class.html` | Class / path (setup 2 of 5) |
| `04-difficulty.html` | Difficulty (setup 3 of 5) |
| `05-area.html` | Starting area (setup 4 of 5) |
| `06-summary.html` | Setup summary (setup 5 of 5) |
| `07-hub.html` | Hub |
| `08-workout.html` | Workout |
| `10-history.html` | Past sessions |
| `11-profile.html` | Profile |
| `12-menu.html` | Menu |

## The flow (links)

```
app opens -> PX.homeId(): 07 hub, or 02 character at the first launch (no preloader, D29)
02 character -> 03 class -> 04 difficulty -> 05 area -> 06 summary --LET'S GO--> 07 hub
   (each setup step has BACK to the step before; 02's back goes nowhere)
07 hub --workout card, TRAIN ▶--> 08 workout --◀ HUB--> 07 hub
   (each set is saved into today's session at once, with an XP pop, CRITICAL SET on a crit and the
    freeze-frame card on a level-up; no I WORKED, no clock, no SESSION n, no reward screen: D6, D7, D19)
07 hub -> 10 history, 11 profile, 12 menu (each has a back/close to 07)
11 profile -> may link to 10 history
12 menu: backup / restore (fake, toast), chaos mode, cel shader (no wipe or RESTART SETUP, D30)
11 profile: change path / difficulty / world / body opens that one setup screen with ?edit=1 and returns to 11
```

Use `PX.go("<id>")` for every jump. Never hard-code a file name.

## Rules (from the owner's refs: UI polish checklist + "AI-built sites" fixes)

- **One main action per screen**, as `.btn.cta` (lime) in `.foot`. It's the biggest thing after the art.
- **One accent colour for the action** (lime). Neons on art, clothes, the class colour and records only (moodboard rule 3).
- **No emojis.** Use `PX.icon(name)` SVGs (one pixel style) or add a new one in the same style in your screen.
- **No tables of numbers** (brief rule 3). Show progress as the character, the level and short messages.
- **No rounded corners, no blur, no gradients on UI**, hard offset shadows, hard-stepped motion (`steps()`), never easing.
- Fixed spacing scale `--s1…--s7`. Tabular numbers for figures (already on `body`).
- Copy: short, loud, funny, specific. Uppercase display (Anton) for titles and buttons, Space Mono for body.
- **Design the empty, loading and error states** that apply to your screen.
- Animations must mean something (feedback for a tap, a reward). Respect `prefers-reduced-motion` (handled globally).
- Touch targets at least 44 px. `:focus-visible` outlines. Buttons are `<button>`, with labels.
- Fits a 390×844 phone with no horizontal scroll; the `.screen` area scrolls if it must, `.foot` stays put.

## Page skeleton

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>PUMPLEX · Hub</title>
<link rel="stylesheet" href="shared/pumplex.css">
<script src="shared/demo.js"></script>
<style>/* screen-only styles, prefixed with the screen id, e.g. .hub-… */</style>
</head>
<body class="px">
<main class="phone" data-screen="hub">
  <header class="topbar">…</header>
  <section class="screen">…</section>
  <footer class="foot"><button class="btn cta" type="button">LET'S GO</button></footer>
</main>
<script>/* screen logic, uses window.PX */</script>
</body>
</html>
```

Don't edit `shared/*` from a screen agent. If you need something shared, put it in your screen and say so in your report.
