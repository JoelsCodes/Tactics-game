# What three open-source tactics games teach us (Nov 2026)

Looked at the most-starred open-source tactics games on GitHub that ship their own art: **Battle for Wesnoth** (~7.0k stars), **Ancient Beast** (~1.9k) and **Zemeroth** (~1.5k). Skipped: fheroes2 (HoMM2 engine), OpenXcom and TripleA (as far as I know they ship no art of their own, or are board-game engines). Numbers below are measured from their files (scripts were run once, not kept). **No third-party art was added to this repo**: Wesnoth's art is GPL-2.0+ / CC BY-SA 4.0 and Ancient Beast's is CC BY-SA 4.0 (share-alike); Zemeroth is MIT/Apache. A study copy of a small sample is outside the repo.

## Map layout (Wesnoth, 24 two-player maps measured; ours 70 maps)
| | Wesnoth median | ours |
|---|---|---|
| size | 35 x 29 hexes (992 tiles) | 16 x 24 squares (384) |
| start to start | 23 hexes, movement-cost path 30 (cost / distance 1.26) | nearest enemy 11 squares, path / distance 1.37 |
| ground | 43% flat, 12% shallow water, 7% forest, 4% hill, 2% mountain, 5% hard walls | about 3% trees, 15% of walkable edges are cliffs of 2+ levels, no cover or defence terrain |
| objectives | ~8 villages a side; the nearest three cost 5, 7 and 9 movement from the start | 5 stones (2 in reach at ~6, 2 field, 1 prize) |
| start zone | ~21 castle tiles per player (units deploy anywhere inside it) | fixed start cells |

1. **Fairness comes from objectives, not geometry.** Only 7 of 24 maps are symmetric (median 61% match under a 180 degree turn), yet 22 of 23 split their villages exactly evenly by travel cost. Balance the objectives (stones, the prize) by path cost per side, and let the ground be irregular.
2. **Soft barriers beat hard walls.** 12% shallow water (3 movement) plus forest and hills slow a march without closing it; hard walls are 5%. We only have walls, cliffs and trees.
3. **Terrain should do something.** Wesnoth forest, hills and castles give defence. A cheap version here: +/- hit chance or damage for forest and high ground (height already counts in `hit_percent_for`).
4. **Objectives escalate outward**: the first village is 5 moves away, the next 7, 9: a reason to move every turn.
5. **A deployment zone** instead of fixed start cells gives a map a pre-battle decision.

## Layout generation (Zemeroth, hex radius 5, 91 tiles)
- Each side deploys in **bands**: Front, Middle, Back (`Line::to_range`), so heavies stand forward and casters back with no hand placement; a unit never starts next to an enemy.
- Scenarios are **counts, not coordinates**: `rocky_tiles_count: 10` (random holes), 3 boulders and 3 spike traps as neutral cover, then unit counts by band. Every replay is a different map: useful for our replay-to-grind loop.
- Campaign nodes just raise the counts and add new enemy kinds, and award recruits.

## Animation
- **Wesnoth** hangs every animation on the moment of impact: `start_time=-445` means the wind-up begins 445 ms before the hit; frames are `image:duration` (4 attack frames x 100 ms, a wind-up pose before and after); the sound, the projectile (`missile_frame`, with a diagonal variant) and the defender's reaction are placed on the same clock. Animations are chosen per weapon (`filter_attack name=bow`). Units are 72 x 72 with two views (down and up) mirrored. Our `HitFeedback` already works from the strike frame; a per-weapon timeline would be the next step.
- **Ancient Beast** has no sprite sheets: units are standees animated by code: a **lean away from a blow that grows with the damage** (3 degrees + 0.18 per point, up to 12), a **shatter** on death, an **afterimage trail** when something moves fast, flight at half walking pace per hex.
- **Zemeroth** uses two-frame sprites (idle, attack) and a separate shadow sprite: an attack is lunge half way to the target, weapon flash, lunge back, with the hit chance floated over the attacker; jumps are arcs with the shadow on the ground.

## Tiles
- Wesnoth: 72 x 72 hex tiles; about 5,600 terrain images; each terrain has 6 directional **transition overlays** (n, ne, se, s, sw, nw) in several lengths (abrupt, medium, long), which is how a grass tile blends into water. Our 3D cubes blend with the side strips and wrap; an overlay per biome edge could soften seams.
- Ancient Beast: five 1920 x 1080 painted backdrops under a plain 16 x 9 hex grid; Zemeroth: flat vector sprites on a hex grid.

## Ideas ranked by how well they fit us
1. Damage-scaled lean and a death shatter (cheap, code only: `UnitView3D`).
2. Deployment bands and counts-based neutral cover for replayable maps (`StonePlacement`-style, plus a `Spawn` pass).
3. Cover and defence from terrain (forest, high ground) in `hit_percent_for` and `mitigate`.
4. Soft terrain (shallow water already slows; add forest and brush).
5. A per-weapon impact timeline in `data/hit_profiles.json`.


---

# Second round: games closer to ours (Nov 2026)
Searched GitHub topics for tactical RPG / SRPG / Final Fantasy Tactics / Fire Emblem clones. Almost everything with FFT-like rules is small (under 100 stars); the biggest are **godot-tactical-rpg** (980 stars, MIT, Godot 4, 3D grid), **Sulis** (493, Rust, GPL-3.0, a full tactical RPG with classes and abilities) and **PixelSRPG-Forge** (460, an art pack). Also looked at Project-Tactics (39, an unfinished FFT-inspired C++ framework: a map demo, no rules to learn from).

## Use nothing from PixelSRPG-Forge
Its README says the assets are "collected from various sources including internet downloads and commercial purchases" and that the author is "not certain about the copyright status". The MIT licence covers only the folder layout. Do not use it, even as reference art.

## godot-tactical-rpg (MIT, placeholder art only)
- About 4,100 lines: grid movement, one attack, a "super basic" AI, camera pan/zoom/rotate, controller support. Far behind our rules (we already have styles, skills, ailments, pincers, accuracy).
- One idea worth keeping: **maps are authored as meshes and the tiles are detected from them** (the visible top faces of a Blender mesh become walkable tiles, found by ray casts), instead of typed text. Our maps are ASCII rows made by Python generators; a mesh-to-map importer would let the owner sculpt a diorama and get the data.
- Code is split into Resource (data), Service (logic) and Node (view), per feature; that is the same direction as our `scripts/battle` vs `scripts/stage`.

## Sulis (GPL-3.0): the closest rules to ours, and an honest art ledger
- **Accuracy** (`data/rules.yml`, `stat_list.rs`): a roll of 1-100 plus the attacker's accuracy minus the defender's defense (both base 30) gives a result: above 55 a **hit**, above 20 up to 55 a **graze** (half damage), 20 or less a **miss**; a roll in the top 3% can crit (1.7x). **A graze is a soft miss**: the blow still counts for half. Flanking gives +10 accuracy, hidden +20. This is the owner's complaint about misses, solved a different way: fewer outright misses, not more hits. We could turn a missed roll into a graze for 50% damage (keeping the 75% floor for full hits), so a bad roll never feels like nothing.
- **Flanking** is the angle between two attackers around the target (over 150 degrees): our pincer, by another definition (any two enemies on opposite sides, not only adjacent ones).
- **Armour** is a table of diminishing returns (8, 15, 21, 27, 31... 95% reduction cap): the same idea as our `mitigate` (offense x 100 / (100 + 4 x defense)); theirs has a hard 95% cap.
- **Action points**: 4,000 a turn, move 100 a tile, attack 2,000: a turn can be move-move-attack or three smaller actions; XP table up to level 40 is a curve (100, 300, 600, 1300, 2100...).
- **Data-driven everything**: abilities, classes, AI behaviours (`ai_melee`, `ai_ranged`, `ai_mage`, `ai_defender`) are YAML files with scripts: the same split as our `EnemyData.ai_role`.
- **Art ledger**: `docs/attribution.csv` lists the author, licence and OpenGameArt link of every asset. 46 sources are CC0 and 42 are CC-BY; the tilesets are mostly CC-BY-SA (LPC), the creature sheets partly Wesnoth GPL. The CC0 and CC-BY leads are in `REFERENCE_FREE_ART_LEADS.md` (links only; nothing downloaded).

## What changes the plan
1. Try **graze** (half damage on a missed roll) before raising accuracy further.
2. A **mesh-to-map importer** is the one authoring idea from these projects that we lack.
3. Free art that is clearly licensed exists (CC0 particles, icons, sounds, item sprites); the leads file is the shortlist. Anything share-alike needs the owner's decision first.


## Map layout of the two closest (measured Nov 2026)
- **Sulis**: 71 exploration areas, not battle maps. Outdoors median 128 x 128 tiles (the engine's cap; a medium creature is 2 x 2 tiles, so about 64 x 64 creatures), underground 128 x 84, indoors 78 x 86, smallest 34 x 30. Fights happen where the party meets an **encounter**: a rectangle (8 x 8) placed on the map plus a weighted table (`forest_troll_encampment`: a unique leader always, 3 to 4 more drawn from five kinds with a limit per kind, `auto_spawn`). Median 3 encounters per outdoor area, 4 underground, about 0 indoors; 2 exits and 1 trigger per area. Eleven painted layers (base, border, walls, props, objects, decoration, aerial...). Layout is hand-painted; the enemy mix is rolled.
- **godot-tactical-rpg**: one hand-modelled demo arena of about 100 tiles (14 x 21 footprint) with about 24 distinct heights including half steps, 4 player pawns against 5, all placed by hand as scene nodes. No generation, no balance rules.
- Neither has a layout rule that we lack except Sulis's **weighted encounter tables with per-kind limits and a guaranteed leader**, which would replace our fixed enemy lists for replays.
