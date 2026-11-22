# Fonts (handoff item 2)

The two PUMPLEX typefaces, as files, so the app works offline (D3).
Downloaded on 22 November 2026 from Google's official font repository,
[github.com/google/fonts](https://github.com/google/fonts) (`ofl/anton`, `ofl/spacemono`).

| File | Family | Weight | Use |
| --- | --- | --- | --- |
| `Anton-Regular.ttf` | Anton | 400 | Display: titles, buttons, numbers that shout. Always uppercase. |
| `SpaceMono-Regular.ttf` | Space Mono | 400 | Body text. |
| `SpaceMono-Bold.ttf` | Space Mono | 700 | Kickers, labels, emphasis in body text. |

No italics: no screen uses them.

## Licence

Both fonts use the SIL Open Font License 1.1: `OFL-Anton.txt` and `OFL-SpaceMono.txt`.
Ship each licence file with the font in the app. The fonts may be bundled and
embedded freely; they may not be sold on their own.

## For the app

Copy the three `.ttf` files to `assets/fonts/` and register them in `pubspec.yaml`:

```yaml
flutter:
  fonts:
    - family: Anton
      fonts:
        - asset: assets/fonts/Anton-Regular.ttf
    - family: Space Mono
      fonts:
        - asset: assets/fonts/SpaceMono-Regular.ttf
        - asset: assets/fonts/SpaceMono-Bold.ttf
          weight: 700
```

Then set `kDisplay = 'Anton'` and `kMono = 'Space Mono'` in `lib/pumplex.dart`
(now `sans-serif-condensed` and `monospace`, the phone's own fonts).

The demo (`docs/demo/shared/pumplex.css`) loads these same files, so the demo and the app use the same type.
