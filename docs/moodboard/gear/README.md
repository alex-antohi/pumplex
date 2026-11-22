# Gear sprites

Not in the app: gear is removed (D38, 22 Nov 2026). These sprites are a design record.

One **260x640** transparent overlay atlas per item, in `<slot>/<item-id>.png`, e.g. `top/top.cape.png`.
Same layout as `../creator/body_atlas.png`: 52x64 cells, column = fat/25, row = (female ? 5 : 0) + muscle/25.
The 10 items are the `Item(...)` lines in `lib/game/content.dart`. Item ids are the full ids (`head.crown`).
Menu icons: `icons/<item-id>.png`, 24x24, white on transparent (tint them in the app).

| Slot | Items |
| --- | --- |
| head | `head.sweatband` (white and pink band across the forehead), `head.crown` (gold crown with a pink gem) |
| top | `top.tank` (pink tank with white trim), `top.cape` (red mantle and cloth hanging outside both arms) |
| bottom | `bottom.shorts` (pink shorts, white stripes), `bottom.belt` (leather lifting belt, gold buckle) |
| shoes | `shoes.sneakers` (white, pink soles), `shoes.boots` (brown boots, gold strap, steel shafts up the calf) |
| weapon | `weapon.shaker` (protein shaker), `weapon.kettlebell` (steel kettlebell). Both are held in the right hand (the right side of the picture) and hang below it. |

## Layer order (bottom to top)

1. Body cell from `body_atlas.png`.
2. Class outfit cell from `../outfits/<class-id>.png`.
3. Gear: **bottom, top, shoes, head, weapon**. A slot with no item draws nothing, so the outfit shows through.

Draw the same atlas cell rect from each file at the same position, with `FilterQuality.none`. Gear never changes the
body (D21): top, bottom, shoes and head pieces sit on the pixels of the starter clothes, hair and face. The cape,
boot shafts, crown spikes and weapons go slightly outside the body shape but stay inside the 52x64 cell.

The removed design demo's `ITEM_NAMES` list has 5 rarities per slot (25 items). Only the 10 app items are drawn here. For rarity,
tint a sprite or add a glow in the app.
Regenerate with `node tools/moodboard/outfits.mjs`.
