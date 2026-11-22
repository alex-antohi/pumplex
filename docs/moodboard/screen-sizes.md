# Screen sizes: what shrinks, scrolls or hides

Status: proposed, 22 Nov 2026. Rule order: `docs/decisions.md`, then this file.
Base: the design is drawn for a 390x844 phone. It came from the HTML design demo, which is removed (D42).
The CSS names below (`.screen`, `.foot`, `--s4`) are the demo's and are kept as labels. The app does the same in Flutter.

## How the layout works

- `.phone` is a column: top bar, `.screen`, `.foot`.
- Under 460 px wide or 700 px high, `.phone` fills the screen (`100%` x `100dvh`), with no border.
- `.screen` has `flex: 1; min-height: 0; overflow-y: auto`. It is the only part that scrolls.
- The top bar and `.foot` never scroll. `.foot` is about 88 px high (12 + 60 button + 16 padding).
- Spacing tokens (`--s1` 4 ... `--s7` 48) do not change with the phone size.
- Touch targets stay 44 px or more (`.icon-btn` 44; 40 only in dense rows). Never shrink them.

## Rules for every size

| Rule | Value |
|---|---|
| Sprite scale | Whole numbers only: 2, 3 or 4 (cell 52x64 px, so 104x128, 156x192, 208x256). Never 2.5 or 3.2. |
| Image smoothing | `image-rendering: pixelated` always. |
| Area scene art | Scale by whole numbers; crop the sides, never stretch. |
| Fonts | Anton and Space Mono. Body text 13 px or more. Never below 12 px. |
| Side gutter | 16 px (`--s4`) at every size. |
| Horizontal scroll | Never. |
| Too small for scale 2 | Hide the character and keep the text. Do not draw a scale-1 sprite. |

## Small phone 360x640 (viewport about 360x600 after bars)

`.screen` gets about 600 - 56 (top) - 88 (foot) = 450 px. Everything above that scrolls.

| Screen | Shrinks | Scrolls | Hides |
|---|---|---|---|
| Setup 02 character | Sprite 4 -> 3. Sliders keep full width. | The slider list. | Nothing. Style pickers stay. |
| Setup 03 class | Sprite 3 -> 2. | The 4 class cards. | The class tags line under each card. |
| Setup 04 difficulty | Gem rows stay. | The 6 level cards. | The "who it is for" line, except on the selected card. |
| Setup 05 area | Scene preview height x 0.75. Lifter 2. | The 5 area cards. | The area line. |
| Setup 06 summary | Lifter 3 -> 2, final-card lifter 4 -> 3. | The rows. | The joke line. |
| Hub 07 | Sprite 3 -> 2. | The workout card and below. | Nothing. Keep the XP bar. |
| Workout 08 | Sprite 3 -> 2. `.wo-scene` min-height 400 -> 300. Exercise cards 96 -> 80 px. | The exercise card strip sideways; the page under it. | Hint text after the first set. |
| History 10 | Row padding `--s3` -> `--s2`. | The list. | The sprite in the empty state. |
| Profile 11 | Sprite 3 -> 2. | Everything. | Nothing. |
| Menu 12 | Nothing. | The rows. | Nothing. |

The main button stays visible in `.foot` on every screen. If the content does not fit, the content scrolls, not the button.

## Tall phone 412x915 (viewport about 412x850 after bars)

`.screen` gets about 850 - 56 - 88 = 706 px. Do not stretch the layout. Add space, not size.

| Screen | Grows | Scrolls | Hides |
|---|---|---|---|
| Setup 02 character | Sprite stays 4. Extra height goes between sprite and sliders. | Rarely. | Nothing. |
| Setup 03 class | Sprite 3. Cards keep their size. | No. | Nothing. |
| Setup 04 difficulty | Gaps between cards `--s2` -> `--s3`. | No. | Nothing. |
| Setup 05 area | Scene preview height up to x 1.25, in whole-pixel steps. | No. | Nothing. |
| Setup 06 summary | Sprite 3, final-card lifter 4. | No. | Nothing. |
| Hub 07 | The scene grows. Sprite stays 3. | No. | Nothing. |
| Workout 08 | `.wo-scene` grows (it is `flex: 1 1 auto`). Sprite 3, or 4 if the scene is 480 px or more. | The card strip only. | Nothing. |
| History 10 | More rows visible. | The list. | Nothing. |
| Profile 11 | Sprite 3. | Rarely. | Nothing. |
| Menu 12 | Rows keep 56 px. Extra space stays empty at the bottom. | No. | Nothing. |

412 px wide: keep the 16 px gutter. The extra 22 px goes to the content.

## Minimum sprite scale

| Where | Normal | Smallest |
|---|---|---|
| Creator (02) | 4 | 3 |
| Class, summary, hub, workout, history, profile | 3 | 2 |
| Area preview (05) | 2 | 2 |
| Final summary card | 4 | 3 |

Scale 2 (104x128) is the minimum everywhere. If it does not fit, hide the sprite.

## The main button and the Android navigation bar

The removed demo had no safe-area code: its `.foot` bottom padding was a fixed 16 px.
The app must follow these rules:

| Rule | Value |
|---|---|
| Layout mode | Edge to edge. The app draws behind the status and navigation bars. In Flutter, use `SafeArea` / `MediaQuery.padding`. |
| `.foot` bottom padding | `max(16px, env(safe-area-inset-bottom) + 8px)`. In Flutter: `16 + padding.bottom`. |
| `.foot` background | Keep `var(--bg)` to the bottom edge, so no scene shows under the bar. |
| Gesture navigation | Inset is about 24 px. The button sits 8 px above the gesture bar. |
| 3-button navigation | Inset is about 48 px. The button sits 8 px above the buttons. |
| Top bar | Top padding = `env(safe-area-inset-top)`. |
| Toast (`bottom: 96px`) | Becomes `88px + inset-bottom`, so it stays above `.foot`. |
| Keyboard | No text fields in the main flow. If one appears, `.foot` moves above the keyboard. |
| Side insets | Add `env(safe-area-inset-left/right)` to the gutter. Portrait is the only mode in v1. |
