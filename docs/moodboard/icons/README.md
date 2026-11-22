# Pixel icon set (handoff item 3)

60 one-colour pixel icons on a 24×24 grid. They replace the emoji and text glyphs the app shows today
(the design brief says "no emojis").
See them all in `sheet.png`; `icons.json` lists each id, its group, where it is used and the emoji or glyph it replaces.

**Source of truth:** `tools/moodboard/icons.mjs`. Every icon is drawn there in code. Do not edit the files here by hand:
change the drawing and run

```
node tools/moodboard/icons.mjs
```

It rewrites everything in this folder. Ids never change once shipped.

## Files

| Path | What |
| --- | --- |
| `svg/<id>.svg` | `fill="currentColor"`, crisp pixel runs. For the demo and design tools. |
| `png/<id>.png` | 24×24, white on transparent. |
| `png/2.0x/<id>.png`, `png/3.0x/<id>.png` | 48 and 72 px, nearest-neighbour. Flutter picks the right one by screen density. |
| `icons.json` | The index. |
| `sheet.png` | Contact sheet for review, in index order (10 per row). |

## Groups

| Group | Icons |
| --- | --- |
| ui | back, next, menu, close, play, history, user, check, bolt, save, restore, flame, gem, star, ember, swap, plus, skip, trash, undo, edit, gear, arm, dice, male, female |
| profile, menu | body, lock, sound, chaos (chaos mode), cel (cel shader) |
| milestone | drop, fire, bell, crown, skull (plus lock and star for locked and open) |
| class | class-scrapper, class-bruiser, class-paladin, class-cablemancer |
| area | area-riptide, area-gainsgard, area-rustbelt, area-arcade, area-frostbite |
| object | object-chest, object-wall, object-barrel, object-punch, object-ice (the thing to hit in each area) |
| mark | mark-riptide, mark-gainsgard, mark-rustbelt, mark-arcade, mark-frostbite (how each area records a set) |
| slot | slot-head, slot-top, slot-bottom, slot-shoes, slot-weapon (gear slots, D21) |

The class icons use the demo ids. The app's ids map like this: `speedy` → scrapper, `rogue` → bruiser,
`warrior` → paladin, `mage` → cablemancer.

## For the app

Copy `png/` (with its `2.0x` and `3.0x` folders) to `assets/icons/` and register the folder in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/icons/
```

Draw an icon tinted, at a whole multiple of 24 so the pixels stay square:

```dart
Image.asset('assets/icons/flame.png', width: 24, height: 24, color: p.orange, filterQuality: FilterQuality.none)
```

The PNGs are white, so `color:` tints them (the default blend mode is `srcIn`). Icons are one colour on purpose:
the colour comes from the palette at the place the icon is used (moodboard rule 3: neon on art and records, lime for the action).
