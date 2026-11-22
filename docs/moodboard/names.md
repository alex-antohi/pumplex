# Final names sheet

Status: every "Proposed final" name is a design proposal (D9, D14, D27) until the owner confirms. Ids never change.
Source: the app (`lib/game/content.dart`). The "Demo" columns are the removed HTML design demo (D42), kept as a record.
Rule: the app and `decisions.md` win. A "Proposed final" name that differs from the app is only a proposal.

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
