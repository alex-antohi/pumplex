# Head looks (D45)

Skin tones, hair colours and facial hair for the character creator (tap the head).
Made by `tools/moodboard/looks.mjs` from `../creator/body_atlas.png`. Do not edit these files by hand:
change the script and run

```
node tools/moodboard/looks.mjs
```

It writes the same files here and in `assets/body/looks/` (the app's copy).

## How it works

Every cell of the body atlas draws skin with the same 3 colours and hair with the same 3 colours
(highlight, base, shadow). So a look is a recolour, not new drawing:

| File | What |
| --- | --- |
| `body_<skin>_<hair>.png` | The whole atlas (260×640, same layout) with the skin and hair colours swapped. Light + brown is the source atlas itself, so it has no file here. |
| `beard_<hair>.png` | Transparent overlay, same layout. In each cell the skin under the eyes becomes hair: sideburns on the row 3 below the eyes, then the whole jaw for 3 rows. The skin shade picks the hair shade. |

| Look | Ids | Colours (highlight, base, shadow) |
| --- | --- | --- |
| Skin | `light` (default), `deep` | `#e4bc97 #d39a6a #8c605c`, `#b07a52 #8a5534 #5a3322` |
| Hair | `brown` (default), `blonde` | `#997d6b #5a3424 #462533`, `#f6d77c #d9a93e #9c6a2a` |
| Facial hair | `none` (default), `beard` | The hair colours. Both bodies. |

## For the app

Draw the layers in this order, same cell rect and scale for each, `FilterQuality.none`:
body (`body_<skin>_<hair>.png` or `body_atlas.png`), beard (if any), class outfit.
The ids are saved on the character (`skin`, `hair`, `facialHair`). Ids never change once shipped:
add new looks at the end of a list in the script and in `lib/game/rules.dart`.
