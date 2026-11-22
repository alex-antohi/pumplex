# Final names sheet

Status: every "Proposed final" name is a design proposal (D9, D14, D27) until the owner confirms. Ids never change.
Sources: demo = `docs/demo/shared/demo.js`, `docs/demo/11-profile.html`. App = `lib/game/content.dart`.
Rule: where demo and app differ, the demo wins (BRIEF.md), unless `decisions.md` says otherwise.

## Classes (D8, D9)

| Equipment | Demo (id: name) | App (id: name) | Proposed final | Reason |
|---|---|---|---|---|
| None | scrapper: Scrapper | speedy: Scrapper | Scrapper | Names match. |
| Basic home gym | bruiser: Bargain Bruiser | rogue: Bargain Bruiser | Bargain Bruiser | Names match. |
| Free weights | paladin: Plate Paladin | warrior: Plate Paladin | Plate Paladin | Names match. |
| Machines | cablemancer: Cablemancer | mage: Cablemancer | Cablemancer | Names match. |

**Decided (D31, 22 Nov 2026):** the ids are the design ids `scrapper, bruiser, paladin, cablemancer`. The app renames `speedy, rogue, warrior, mage` and migrates saved data once.

## Difficulty levels (D14, D28)

| # | Demo (id: name) | App (id: name) | Proposed final | Reason |
|---|---|---|---|---|
| 1 | sofa: Sofa Mode | sofa: Sofa Mode | Sofa Mode | Decided (D28). |
| 2 | warmup: Warm-up Mode | warmup: Warm-up Mode | Warm-up Mode | Decided (D28). |
| 3 | sweat: Sweat Mode | sweat: Sweat Mode | Sweat Mode | Decided (D28). |
| 4 | pain: Pain Mode | pain: Pain Mode | Pain Mode | Decided (D28). |
| 5 | brutal: Brutal Mode | brutal: Brutal Mode | Brutal Mode | Decided (D28). |
| 6 | nightmare: Nightmare Mode | nightmare: Nightmare Mode | Nightmare Mode | Decided (D28). |

**Decided (D28, confirmed again 22 Nov 2026):** the MODE names and ids. The demo's Couch Spawn … Ascended Swolemancer are dropped: they sound like classes, which the owner's naming rule forbids. The demo now matches the app.

## Areas

| Id (demo / app) | Demo | App | Proposed final | Reason |
|---|---|---|---|---|
| riptide / beach | Riptide Shore | Riptide Shore | Riptide Shore | Match. |
| gainsgard / castle | Gainsgard Keep | Gainsgard Keep | Gainsgard Keep | Match. |
| rustbelt / rustbelt | Rustbelt Flats | Rustbelt Flats | Rustbelt Flats | Match. |
| arcade / arcade | Arcade Underpass | Arcade Underpass | Arcade Underpass | Match. |
| frostbite / summit | Frostbite Summit | Frostbite Summit | Frostbite Summit | Match. |

## Gear items (D21: one item per slot, 5 slots)

The demo has 5 slots x 5 rarities = 25 items (one drop per level-up). The app has 10 items with fixed unlock levels. Different systems; the owner decides the gear list (D27).

| Slot | Demo (common to legendary) | App (unlock level) | Proposed final | Reason |
|---|---|---|---|---|
| Head | Sweaty Headband, Bandana of Grit, Chalk Crown, Halo of Pump, Helm of the Final Rep | Sweatband of Mild Effort (2), Crown of Leg Day (8) | Demo list | "Helm of the Final PR" was removed on 22 Nov 2026 (D2: there are no PRs). |
| Top | Stretched Tank, Neon Stringer, Hoodie of Holding, Plate Mail Tee, Mantle of Swole | Tank Top of Vanity (3), Cape of Unearned Confidence (12) | Demo list | Five-rarity ladder. |
| Bottom | Sweatpants, Squat-Proof Shorts, Cargo of Gains, Leggings of Thunder, Greaves of Gravity | Shorts, Too Short (5), Belt of Brace Yourself (18) | Demo list | Same. |
| Shoes | Flat Sneakers, Lifting Flats, Boots of the Stairs, Treads of Torque, Sandals of the Titan | Squeaky Sneakers (4), Boots of Heavy Stomping (15) | Demo list | Same. |
| Weapon | Foam Roller, Jump Rope, Chalk Bag, Kettlebell of Unknown Origin, The Golden Barbell | Protein Shaker +1 (6), Kettlebell of Doom (10) | Demo list | Same. |

App jokes worth moving into the demo list: Sweatband of Mild Effort, Cape of Unearned Confidence, Belt of Brace Yourself.

## Achievements / milestones (D27: list still open)

| Demo (name: unlock) | App (id: name: unlock) | Proposed final | Reason |
|---|---|---|---|
| First blood: 1 session | first_set: First Blood: 1 set | First Blood: first working set | Same name. Sets are the core (D1). |
| On a roll: 5 sessions | days_10: Regular: 10 training days | On a Roll: 5 training days | A "session" is a day (D6). |
| 50 sets club: 50 sets | none | 50 Sets Club | Missing in the app. |
| Overkill: beat a set target | none | Overkill | Missing in the app; fits D19 bonus. |
| Double digits: 10 sessions | days_10 (see above) | Double Digits: 10 training days | Replaces Regular (same goal). |
| Centurion: 100 sets | sets_100: Century of Suffering: 100 sets | Century of Suffering | Funnier; same goal. Keep one. |
| none | streak_4: Month of Iron: 4 weeks in a row | Month of Iron | Missing in the demo; D20 streak. |
| none | level_5: Getting Somewhere: level 5 | Getting Somewhere | Missing in the demo. |

Demo copy "Finish 1 session" and "N more sessions": change to training days (D6, D7).

## Level titles (design proposals, D14)

| Level | Demo | App | Proposed final | Reason |
|---|---|---|---|---|
| 1 | Fresh Spawn | Fresh Spawn | Fresh Spawn | Match. |
| 2 | Sweat Rookie | Sweat Rookie | Sweat Rookie | Match. |
| 3 | Rep Goblin | Rep Goblin | Rep Goblin | Match. |
| 4 | Pump Raider | Pump Raider | Pump Raider | Match. |
| 5 | Iron Ronin | Iron Ronin | Iron Ronin | Match. |
| 6 | Gain Lord | Gain Lord | Gain Lord | Match. |
| 7+ | Mythic Meathead | Mythic Meathead | Mythic Meathead | Match. The last title stays. |

Resolved: "Couch Spawn" is gone (D28), so "Fresh Spawn" (level 1) no longer clashes.
