# Borderlands vibe reference (for PUMPLEX)

Date: 21 November 2026. Status: research notes v0.1.
Purpose: explain the "Borderlands vibe" that PUMPLEX aims for, so other agents can cross-check art, UI and tone.
Visual board: [`borderlands_palette.html`](borderlands_palette.html) (open it in a browser).
Our own style spec stays in [`README.md`](README.md) and [`palette.json`](palette.json).

> **Inspiration only.** Do not copy Borderlands names, characters (Claptrap, Psychos),
> logos, the Vault symbol, fonts, art or screenshots into PUMPLEX. Take the *rules*
> (outlines, loud colour, loot tiers, jokes), not the *things*.

## Sources and how sure we are

| Tag | Meaning |
| --- | --- |
| **[W]** | Read on the page on 21 Nov 2026. |
| **[M]** | Measured: the colour comes from the wiki's own CSS, or from sampled pixels. |
| **[G]** | General knowledge of the games. The pages I read do not say it. Check before you rely on it. |

Pages read:

- Wikipedia: [Borderlands (2009)](https://en.wikipedia.org/wiki/Borderlands_(video_game)), [Borderlands 2](https://en.wikipedia.org/wiki/Borderlands_2), [Borderlands 4](https://en.wikipedia.org/wiki/Borderlands_4)
- Borderlands Fandom wiki: [Rarity](https://borderlands.fandom.com/wiki/Rarity), [Manufacturer](https://borderlands.fandom.com/wiki/Manufacturer), [Elemental damage](https://borderlands.fandom.com/wiki/Elemental_damage), [Claptrap](https://borderlands.fandom.com/wiki/Claptrap), [Psycho (BL2)](https://borderlands.fandom.com/wiki/Psycho_(Borderlands_2)), [Pandora](https://borderlands.fandom.com/wiki/Pandora), [Classes in BL2](https://borderlands.fandom.com/wiki/Classes/Borderlands_2)

Note for agents: plain HTTP fetches of `borderlands.fandom.com` return **402**. The in-app
browser can read the pages. Image files on `static.wikia.nocookie.net` return **403** when you open them directly
(hotlink block). So use the wiki file pages in the picture list below. Do not embed the raw image URLs.

## 1. The look in one paragraph

Borderlands is a **cel-shaded, comic-book** shooter. It uses **hand-drawn textures** and an engine change
that **outlines the main shapes** in black [W]. Inside the outlines, surfaces have hand-drawn ink
hatching and painted grit, like concept art put straight into the game [G]. BL2 calls this the
**"concept art style"**: real-world shapes, drawn like a comic [W]. The world is a dirty sci-fi
wasteland. The loot, the UI and the jokes are loud and colourful on top of it.

## 2. How the style happened (why it matters for us)

- The first game started realistic, with a brown, muted palette. Testers said it looked like Fallout 3 or Rage.
  The brown look also clashed with the crazy content [W].
- At about 75% done, Brian Martel's small team secretly built a cel-shaded prototype. The short film
  *Codehunters* (Ben Hibon) was one inspiration. A comic-book artist then refined the look [W].
- The change pushed the release from 2008 to 2009 [W].
- BL2 (2012) added more colour and more biomes (ice, grassland) because BL1 was nearly all desert.
  Each gun maker got its own "trademark style" [W].
- BL4 (2025, Unreal Engine 5) keeps a "pseudo-cel-shaded" look. Its art director calls the planet
  "high-tech but lo-fi" [W].

**Lesson for PUMPLEX:** a stylised look made a generic game stand out. "Realistic and brown" is the
failure mode. Our dark violet base with neon clothes already avoids it. Keep the ink outline as the one thing
that holds everything together.

## 3. Visual rules we can borrow

| Borderlands rule | Source | PUMPLEX version |
| --- | --- | --- |
| Thick black outline on main shapes | [W] | Already rule 1: 1 px `#0b0414` ink on sprites. |
| Flat toon bands, not smooth shading | [W] cel-shaded | Already rule 2: 3 flat tones, light from top-left. |
| Hand-drawn hatching and grit inside shapes | [G] | Optional: a 1-colour hatch texture on large dark panels only. Never on sprites (pixel art stays clean). |
| Dirty world, loud loot | [W]/[G] | Dark grounds, neon only on clothes and rewards (rule 3). |
| Every brand has a look you can read at a glance | [W] | Each class (= equipment) gets one shape language and one main neon. See section 6. |
| Rarity colour on every item | [W] | Use the same ladder for the set marks and the difficulty rungs. See section 4. |
| Freeze-frame **character intro card**: the action stops, the name and a joke subtitle appear as a sprayed or stencilled tag | [G] | Show it on class pick and on level-up. Use our own type (Anton), not theirs. |
| Hand-lettered, chunky, slightly distressed display type | [G] | Anton plus a hard offset shadow (already on our boards). Add a spray or stencil texture only on title cards. |
| Enemy silhouettes you can read from far away (Psycho = white mask, buzz-axe) | [W] | Give each "boss" workout a mask-like face and one big prop. |

## 4. Rarity ladder (colours measured from the wiki)

The series uses the standard RPG order in every game: white, green, blue, purple, orange [W].
The hex codes are the colours that the Fandom wiki uses for each tier name [M]. They are close to the in-game colours, not exact copies.

| Tier | Game(s) | Wiki hex | Closest PUMPLEX neon |
| --- | --- | --- | --- |
| Common (white) | all | `#969696` | `#c9b8e8` muted text |
| Uncommon (green) | all | `#3dd20b` | Lime `#c6ff3d` |
| Rare (blue) | all | `#2f78ff` | Sky `#3fd2ff` |
| Epic (purple) | all | `#ab46ff` | Violet `#a77bff` |
| Legendary (orange) | all | `#ff9600` | Orange `#ffa033` |
| Legendary (yellow) | BL1 only | `#f0ee56` | — |
| Legendary (dark orange) | BL1 only | `#dc7800` | Orange shadow `#a6643c` |
| Pearlescent (cyan) | BL1 DLC, BL2 UVHM, BL4 | `#00ffff` | Sky highlight `#88dff3` |
| E-tech (magenta) | BL2, TPS | `#ff00ff` | Pink `#ff5fb0` |
| Seraph (pink) | BL2 DLC | `#ff69b4` | Pink `#ff5fb0` |
| Glitch (pink) | TPS DLC | `#ff69b4` | Pink `#ff5fb0` |
| Cursed (teal) | BL2 DLC | `#00cccc` | — |
| Effervescent (rainbow; wiki shows red) | BL2 DLC | `#ff0000` | Animate through all 5 neons |

**Good news:** the PUMPLEX neons already line up with the rarity ladder:
lime → sky → violet → orange, with pink as the special tier. Players know this ladder from many games.
So we can use it without explaining it.

Ideas (not decided):

- Colour a finished exercise by its working-set count: 1 set common, 2 lime, 3 sky, 4 violet, 5+ orange.
- A "pearlescent" or "effervescent" reward for a rare event, for example a 30-day comeback. Show it as a colour-cycle shimmer.

## 5. Elemental colours (measured from the wiki)

| Element | Game(s) | Wiki hex |
| --- | --- | --- |
| Explosive / Radiation | all / BL3–4 | `#d2c600` |
| Incendiary (fire) | all | `#d88600` |
| Shock | all | `#00a3d8` |
| Corrosive | all | `#7ecb40` |
| Slag | BL2 | `#e08aff` |
| Cryo | TPS, BL3–4 | `#78cad2` |
| Dark Magic | Wonderlands | `#ff4763` |

Use: a second colour code for workout *types* (for example cardio = fire, strength = explosive,
mobility = cryo). Only adopt this if one ladder (rarity) is not enough. Two colour codes on one screen is too much.

## 6. Manufacturers = brand personalities (map to our classes)

In BL2 each gun maker has its own gimmick and look [W]. In PUMPLEX, **class = equipment** (app brief 4.1).
So each equipment class can borrow the *idea* of a manufacturer: one gimmick, one material, one tone.

| Maker | Gimmick [W] | Look [W] | Possible PUMPLEX class match (idea only) |
| --- | --- | --- | --- |
| Jakobs | high damage, semi-auto, never elemental | wood stock, unpainted, worn, Wild West | Barbell: old-school, heavy, few big sets |
| Torgue | explosive rounds, high damage | thick barrels, hot-rod paint, brand stickers, loud | Dumbbells / "bro" class: LOUD, all caps |
| Vladof | fire rate rises while you hold the trigger | Russian style, skeleton stocks, revolution slogans | Kettlebell: high reps, "comrade" tone |
| Maliwan | always elemental | curved, bright contrast, mecha parts, poetic names | Cables / machines: sleek, high-tech |
| Hyperion | gets more accurate as you fire | long polygons, one bold stripe, corporate names | Gym machines: clean, "corporate" jokes |
| Dahl | burst fire when you aim | military camo, rails, army names | Calisthenics: drill-sergeant tone |
| Tediore | throw the gun to reload | boxy, cheap plastic, stencil logo, store-brand names | Bands / home kit: cheap, cheerful |
| Bandit / Scav | huge mags, poor stats | junk-built, warm colours, shark-teeth nose art, misspelled names | Bodyweight / "no gear": scrappy, DIY |

In BL1 the colours were even simpler [W]: Hyperion = red, Maliwan = blue, Jakobs = orange-brown,
Vladof = orange + black, Torgue = dark grey, Tediore = matte grey, Atlas = white, S&S = yellow + black.

## 7. World and characters (for tone)

- **Pandora:** a barren, desolate wasteland at the edge of civilisation, full of dangerous creatures [W].
  It has desert valleys, snowy or ash-covered mountains, canyons and plateaus [W].
  The Arid Badlands have cactus-like plants with glowing orange "eyes" [W].
- **Claptrap:** a CL4P-TP robot by Hyperion. It is overenthusiastic and brags a lot, but it is also lonely and a coward [W].
  It is yellow, with one wheel and one eye [G]. It is the model for an annoying-but-lovable helper voice.
- **Psychos:** bandit front-liners with buzz-axes and grenades. They wear white masks, crude armour and tattoos.
  They shout odd one-liners [W]. They are the model for a readable, funny enemy silhouette.
- **Classes (BL2):** each Vault Hunter has **one signature Action Skill** and **three skill trees** [W].
  For example, Maya (Siren) has Phaselock with Cataclysm / Harmony / Motion trees. Salvador (Gunzerker)
  dual-wields, with Brawn / Gun Lust / Rampage trees.
  → PUMPLEX mapping: each class = one signature move (its hero exercise) + 3 growth paths (for example strength / size / stamina).
- **Tone:** BL2 humour (writer Anthony Burch) is loud, crude, self-aware and full of jokes [W].
  BL4 reviewers called it "more sensible" and less juvenile [W]. For PUMPLEX, aim for BL2 energy without the crude parts:
  funny, never mean about bodies.
- **Opening music energy:** BL1 opens on "Ain't No Rest for the Wicked" by Cage the Elephant [W]. Think dusty rock with a swagger.

## 8. Picture list (open in a browser; do not copy into the repo)

Raw image URLs return 403, so these are the wiki pages that show each picture.

| Shows | Link |
| --- | --- |
| BL2 Vault Hunters line-up (Zer0, Salvador, Maya, Axton, Gaige, Krieg) | [Classes in BL2](https://borderlands.fandom.com/wiki/Classes/Borderlands_2) |
| Psycho bandits, 5 gang variants (silhouettes, masks) | [Psycho (BL2)](https://borderlands.fandom.com/wiki/Psycho_(Borderlands_2)), [Gallery: Bandits](https://borderlands.fandom.com/wiki/Gallery:_Bandits) |
| Claptrap in BL1, BL2, BL3, BL4 and TPS (how one mascot evolves) | [Claptrap](https://borderlands.fandom.com/wiki/Claptrap) |
| Claptrap freeze-frame intro card (TPS) — the title-card style | [Claptrap](https://borderlands.fandom.com/wiki/Claptrap) (first image under the intro) |
| Pandora from orbit, surface close-up, Eridium scar, region maps | [Pandora](https://borderlands.fandom.com/wiki/Pandora) |
| All manufacturer logos (old and BL3 redesign) | [Manufacturer](https://borderlands.fandom.com/wiki/Manufacturer) (top) |
| Concept art for each gun maker (Dahl, Hyperion, Jakobs, Maliwan, Tediore, Torgue, Vladof) | [Manufacturer](https://borderlands.fandom.com/wiki/Manufacturer) → BL2 gallery |
| BL3 weapon line-ups for each maker | [Manufacturer](https://borderlands.fandom.com/wiki/Manufacturer) → BL3 gallery |
| Box art (a Psycho on BL1, BL2 and BL4 covers); Zer0 concept art; BL2 Gunzerker screenshot | Wikipedia pages in "Sources" above |

## 9. Sampled world tones (approximate)

These come from 80 px samples of wiki thumbnails [M]. They are rough. Use them only as a reference for mood.
Do not treat them as a spec.

| Tone | Hex | Seen in |
| --- | --- | --- |
| Ink black | `#050208` | Pandora key art, logos |
| Bone / dust | `#ecd7d0` | Pandora surface |
| Dusty mauve | `#ad9293` | Pandora surface |
| Rust brown | `#6b5033` | BL2 Claptrap scene |
| Dark rust | `#4b2d19` | BL2 Claptrap scene |
| Steel blue | `#5288b7` | BL2 Vault Hunters art |
| Bandit-mask grey | `#b8b8b9` | Psycho art |

PUMPLEX does **not** use these desert tones as its base. Our base is the violet night palette. If we ever add a
"wasteland" world, take the dust and rust tones from here, then push their shadows to violet (rule 4).

## 10. Quick checklist for agents

- [ ] Every character and big UI shape has a dark ink outline.
- [ ] Shading is flat bands, with no soft gradients.
- [ ] Neon colour means "reward" or "clothes". The background stays dark.
- [ ] Reward colours follow the rarity ladder: muted → lime → sky → violet → orange → pink (special).
- [ ] Each class reads at a glance: one shape language, one neon, one gimmick.
- [ ] Big moments (class pick, level-up) get a freeze-frame title card with a joke subtitle.
- [ ] The text is loud and funny, never mean about bodies.
- [ ] No Borderlands names, logos, characters, fonts or images ship in the app.
