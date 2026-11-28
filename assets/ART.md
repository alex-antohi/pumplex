# Swap the art

Every drawing in the app is one PNG file in `assets/`. The app draws each PNG
into a fixed box in logical art pixels (BoxFit.fill, nearest neighbour). So:

1. Keep the file name and folder.
2. Draw the new PNG at a whole-number multiple of the base size (2x, 3x).
   The base sizes are in `tools/app/art_base_sizes.json`.
3. Use the same multiple for all files of one set (one area, one atlas group).
   Atlases (body, looks, outfits) keep the 5 x 10 cell grid; a cell is
   52 x 64 at 1x, 104 x 128 at 2x.
4. Keep transparent pixels where the old art had them (hit boxes, the
   lifter's feet, the LED window and the mark spots do not move).
5. Run `node tools/app/art_check.mjs`. It fails on a wrong size.
6. Run the app (hot restart). No code change is needed.

Icons: also put the new PNG in `assets/icons/2.0x/` and `assets/icons/3.0x/`
(the same file in all three), or Flutter shows the old variant on dense screens.

Add a NEW file: add it to `pubspec.yaml` and the code, then run
`node tools/app/art_check.mjs --write`.
- `sky.png` (175 x 60 base): optional strip above the scene in the area card.
