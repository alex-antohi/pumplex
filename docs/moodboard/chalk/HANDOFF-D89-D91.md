# Design handoff: the class lights your gear (D89), with D90 and D91

Date: 25 Nov 2026. For the design team. Source of truth: `docs/decisions.md`, rows D89, D90 and D91. Nothing here is built yet.

The mockup `04-class-lights-gear.html` / `.png` in this folder shows the idea. The owner accepted it as a direction. The final look is yours.

## The idea

The class is a hint, never a filter. No lift is ever hidden. The class shows which gear is yours, and puts your gear first.

A new user learns the class by looking at the rack: **lit = my class.**

## What to design

### 1. The gear rack in CHALK (changes D87)

- The rack title carries the class name, for example "ECHIPAMENT PALADIN", with a short hint: "APRINS = CLASA TA" / "LIT = YOUR CLASS".
- The class's tools are **lit** and come **first**. The other tools are **dim**, but they still work with one tap.
- A dim tool must still look tappable. It must look different from a tool that gives 0 results (a clash).
- Bodyweight is lit for every class.
- **My gear:** a long-press on a tool adds it to the lifter's gear, or removes it. An added tool looks lit and has a small mark, so the lifter sees it is their own addition. The rack needs a short hint for the long-press.
- The rack has 11 slots: Bodyweight, Dumbbell, Barbell, EZ Bar, Kettlebell, Cable, Machine, Smith Machine, Bands, Ball, and **Rings/TRX (new)**. The towel is no longer a slot; it stays a search word.

Class gear (lit by default):

| Class | Lit tools |
|---|---|
| Haiduc (Scrapper) | Bodyweight, Rings/TRX |
| Bătăuș la Reducere (Bargain Bruiser) | Bodyweight, Dumbbell, Kettlebell, Bands, Ball |
| Paladin de Discuri (Plate Paladin) | Bodyweight, Barbell, EZ Bar, Dumbbell, Kettlebell |
| Cablomant (Cablemancer) | Bodyweight, Machine, Cable, Smith Machine |

### 2. The move words on the first screen

- The first 5 move words follow the class, then "+n" for the rest.
- BENCH (ÎMPINS LA PIEPT) becomes a move word.
- The code gives the 5 words per class. Design only needs room for 5 words and "+n".

### 3. The results (loot cards)

- Cards that use the lifter's gear come first. There is **no divider and no label** between "my gear" and the rest.
- Inside a card, the variations of the lifter's gear come first.
- A variation that fits the lifter's gear has a small **class mark**. The mockup uses one lime shield for every class. Decide: one mark for all classes, or one badge per class.
- One card can now mix tools, so each variation needs to show its tool (the mockup uses the small tool icon).
- The class pays no extra XP. The mark is only a sign.

### 4. The HARD badge (D91)

- Each exercise gets a difficulty score from 1 to 6, one per mode (Sofa … Nightmare).
- An exercise shows **HARD** when its score is above the lifter's mode.
- The badge today is a placeholder. It needs a final look, on the loot card and on the Today card.

### 5. One new icon

- A pixel icon for **Rings/TRX**, in the style of `assets/icons/tools/*.png` (made by `tools/tool_icons.mjs`).
- Romanian label: INELE / TRX (propose the final word).

## What goes away

- Class-greyed chips on a Today card.
- The "shows for" (APARE LA) line on the FORGE loot card.
- The towel slot in the rack.

## Fixed by the owner (do not change)

- No class filter, and no MY GEAR / ALL GEAR switch.
- Dim tools stay tappable.
- The lifter can edit their gear with a long-press.
- My-gear cards first, with no divider.
- A class mark only; no XP bonus.
- The first 5 move words follow the class.

## Yours to decide

- How lit, dim, "added by me" and "0 results" look, so that the four states are clear.
- The class mark: one for all, or one per class.
- The HARD badge.
- The hint texts and where they sit. Keep the first screen light: today it has 27 things to tap, and the target is 24 or fewer.
- Romanian wording for the new texts (the current ones are a first draft).

## What the code side does (not design work)

- The lit rule per class, the saved "my gear" list, and the order of cards and variations.
- The exercise list rebuild and the 1–6 scores (`docs/exercise-list-plan.md`).
- The XP rule with six tiers (D91).

## Open with the design team

- The FORGE redesign (D88) is in progress on `design-fixes`. This handoff does not change it, except for the "shows for" line.
