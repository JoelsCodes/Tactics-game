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
