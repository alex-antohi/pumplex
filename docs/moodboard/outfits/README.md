# Class outfits

One transparent overlay atlas per class: `scrapper.png`, `bruiser.png`, `paladin.png`, `cablemancer.png`.
Each is **260x640**, with the same layout as `../creator/body_atlas.png`: 52x64 cells,
column = fat/25, row = (female ? 5 : 0) + muscle/25.

An outfit replaces the starter clothes: top, bottoms and shoes. Every starter top, bottom and shoe pixel of every
one of the 50 bodies is covered, and nothing else is drawn. The body is never changed (D21).

## Layer order (bottom to top)

1. Body cell from `body_atlas.png` (skin, hair, face), already tinted by the user's look.
2. **Outfit** cell from `outfits/<class-id>.png`. Same cell index as the body.

In the app, draw the same `AtlasSprite` cell rect (same source `Rect`) from each atlas, one after the other, at the
same position and scale, with `FilterQuality.none`. The starter outfit pixels of the body atlas are hidden by the
outfit layer, so the body atlas needs no change. Hide the outfit layer to show the starter clothes.

## The four outfits

| Class | Colour | Top | Bottoms | Shoes |
| --- | --- | --- | --- | --- |
| scrapper | orange `#ffa033` | orange tank, tan tape in an X across the chest, tape hem | rust-brown shorts, tape hem | dark scrap boots, tape wrap |
| bruiser | sky `#3fd2ff` | sky track jacket, white side stripes, white collar | navy track pants, white side stripe | white sneakers |
| paladin | lime `#c6ff3d` | lime singlet with a silver plate chest (segment lines, rivets, centre seam) | olive shorts, brown belt, gold buckle | silver-grey boots, lime top edge |
| cablemancer | violet `#a77bff` | dark violet suit, violet piping down the centre and sides, glow collar | dark suit, violet side piping | dark boots, glowing violet sole row |

Shading keeps the starter outfit's 3 steps (highlight, base, shadow), so the outfit reads on every body.
Regenerate with `node tools/moodboard/outfits.mjs`. The script also runs the pixel checks.
