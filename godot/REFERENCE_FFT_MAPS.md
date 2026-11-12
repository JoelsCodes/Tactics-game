# How Final Fantasy Tactics builds its maps, and what FFT-like projects do (Nov 2026)

The owner asked for a sweep of FFT-genre tactical RPGs on GitHub, open source or not, to study how their **maps** are built. Nothing was copied: only counts and structure, and no game assets were opened. The one thing that matters most turned up on the second search: there are **tools and a dataset that read FFT's real map data**, so the numbers below are the actual game, not an opinion.

## What was searched
GitHub topics and keywords: tactical-rpg, srpg, strategy-rpg, final-fantasy-tactics, tactics-game, turn-based-tactics, fire-emblem, tactics-ogre, plus FFT map editors and data tools. About 170 repositories turned up. Almost every FFT-like one is small (the biggest, `godot-tactical-rpg`, has 980 stars), and most of those only have a battle loop. The useful ones for maps:

| Repo | What it is | Licence | Use for us |
|---|---|---|---|
| `twentyonepepes/fftbg-maps-statistics` | **All 119 FFT battle maps as data**: every tile's x, y, layer, height, depth and surface, plus the start tiles | none stated | The numbers in this document |
| `Garmichael/GaneshaDx` (40 stars) | A map editor for FFT: shows the exact tile record FFT uses | GPL-3 | The data model |
| `cylleneius/fft_map_to_obj`, `adamrt/fft-software-renderer` | Convert or render FFT maps from the game files | none / none | Confirms how a map is stored (a 3D mesh plus a separate logic grid) |
| `kekel87/pokemon-tactics` | An FFTA-style game with Tiled-authored isometric maps, written up in detail | MIT (code; its art credits are separate) | A working authoring pipeline and its height rules |
| `beese54/diorama-tactics` | Pixel-art "diorama" tactics maps built in code, plus a seeded map generator | none stated | The closest to our look |
| `Project-Tactics/Project-Tactics`, `wuneng117/XSGridEditor` | An FFT-inspired framework, a Unity grid editor | MIT | Little documentation to read; skipped |

Earlier rounds covered Wesnoth, Zemeroth, Ancient Beast, Sulis and `godot-tactical-rpg` (`REFERENCE_TACTICS_GAMES.md`); this one does not repeat them.

## FFT's tile, and how a map is stored
GaneshaDx's `TerrainTile` is the whole record FFT keeps per tile:
- **SurfaceType** (about 45 kinds: stone floor, grassland, rocky cliff, roof, snow, swamp, lava, bridge, stairs, furniture...)
- **Height** and **Thickness** (how deep the block is below the top)
- **Depth** (water depth)
- **SlopeType**: 13 shapes (flat, four inclines, four convex corners, four concave corners) and **SlopeHeight**
- three flags: **Impassable** (cannot walk), **PassThroughOnly** (can cross but not stop), **Unselectable** (the cursor skips it)
- **two layers** (`Level0Tiles`, `Level1Tiles`): a tile can exist at two vertical levels, so a unit can stand on a bridge above another unit.

The picture and the rules are separate: the map is a **3D art mesh** (textured polygons) plus this **invisible logic grid** that the editor lines up with it. Our `Board3D` builds the picture from the tiles, so ours is the other way round.

## The numbers: 119 FFT maps against our 76 battle maps
| | FFT (119 maps) | Ours (76) |
|---|---|---|
| Walkable tiles per map | **median 108**, range 37 to 221 | **median 384**, range 256 to 640 |
| Footprint | 4-16 wide, 5-18 long; typically about 10 x 12 | 16 wide, 16 to 40 long |
| Footprint shape | irregular: median 96% of its bounding box is used, down to 50% | always a full rectangle (100%) |
| Distance between the two start groups | **median 10 tiles** (max 17) | set by the first-turn rule (nearest foe 11 tiles) |
| Start tiles per side | exactly **4** on every map | 1 for the King, 1 for the Co-Captain, and stones |
| Height range inside a map | median **10.5 h** (up to 24 h); 95 of 119 are 3 h or more | median 6 levels (2 to 7) |
| Neighbouring tiles at the same height | **53%** | **75%** |
| Neighbours one step apart (0.5 h or 1 h) | **22%** | 11.5% (no half steps exist) |
| Neighbours three steps or more (cliffs) | about 12% | about 8% |
| Maps with a second walkable layer (bridge, arch, balcony) | **38 of 119 (32%)** | none |
| Distinct surfaces per map | median **4** (1 to 9) | median 5 (3 to 8) |
| Most common surfaces | stone floor 25%, grassland 20%, brick 5%, rocky cliff 5%, roof 5%, stalactite 5%, snow 5% | |
| Tiles with water depth | 5% on average; the odd map is 40% | |

Heights in FFT's data come in half steps (0, 0.5, 1, 1.5...); one full `h` is what a Jump point climbs.

## What the other projects add
- **`pokemon-tactics` (FFTA-like):** maps are authored in **Tiled** as stacked tile layers, one layer per half step of height (`terrain`, `terrain_1`, `terrain_2`... = elevation 0, 0.5, 1.0), with tileset properties `height`, `terrain` and `slope`, and a `spawns` object layer per team. Rules tied to height: a melee blow is blocked when the heights differ by 2 or more; the attacker gets **+1 range per 2 levels above the target** (max +2); a dash stops at a step above 0.5 and a fall hurts. Terrain changes play: water costs 3/4 of the movement, sand and snow add 15% damage to the matching element, swamp halves movement and poisons. A map's start zones are data, and the placement of units is a phase before the battle.
- **`diorama-tactics` (the nearest to our look):** 30 hand-built themed maps (alpine, harbour, ruins, glacier, sky isles...) made **in code**, tile by tile, with "stepped heights with rounded edges", water that falls down cliffs, props and weather, drawn through a small pixel canvas and scaled up. It also has a **seeded generator** ("Wild Lands") that grows a valley, island or coast with rivers, bridges, woods and a village, castle or ruin at 32, 48 or 64 tiles square. Its maps are huge compared with FFT's.
- **Wesnoth, Zemeroth (earlier round):** fairness comes from balancing objectives, and scenarios are counts of things, not coordinates.

## What it says about our maps (my reading; the owner has not seen it)
1. **Our maps are about 3.5 times FFT's size.** FFT's largest map (221 tiles) is smaller than our smallest (256). A battle there is quick because the two sides start about 10 tiles apart with 108 tiles to fight over. Our standard of 16 wide and a median of 24 long is a different kind of battle: long marches, scrolling. If the owner wants the FFT feel, the new maps to try are **10 to 14 wide and 10 to 16 long** (about 100 to 220 tiles).
2. **Our ground is flatter than it looks.** Three quarters of our neighbouring tiles are level, against just over half in FFT. Our total relief is similar (6 levels against FFT's 5 or so full steps), but ours comes as a few big plateaus. FFT gets **rolling** ground: lots of half steps, slopes and stairs. We have no half step at all.
3. **Our islands are always rectangles.** FFT footprints are lop-sided, with cut corners and peninsulas (a third of the maps, 41 of 119, use under 90% of their bounding box). Our void tile (`v`) already exists and the diorama edge handles it, so irregular islands (round arenas, L shapes, crescent ridges) would cost little.
4. **There is no overpass.** A third of FFT maps have a second walkable layer: bridges, arches, balconies, where one unit stands over another. Ours has no layered ground. This is the biggest engine change on the list.
5. **Four starting tiles per side.** FFT gives each side four start tiles and the player chooses who stands where. Ours places the King and the Co-Captain on fixed tiles. A small start zone of 3 to 4 tiles per side would add a decision before the first move without changing the first-turn spacing rule.
6. **Separate "cannot walk", "cannot stop" and "cannot be picked".** Three flags per tile give precise control: pillars you can shoot past but not walk through, bridge tiles you cross but not stop on, tall props the cursor ignores. Ours block by terrain type only.
7. **Terrain should push back.** `pokemon-tactics` makes water, sand, snow and swamp change movement or damage. We only have the shallow-water slow.
8. **Each map has a signature surface.** FFT maps use about 4 surfaces, mostly stone or grass, with one special kind (ice, swamp, lava, salt) showing up in a few. That is what makes a map memorable: ours is already close (5 per map).

## Ranked ideas
1. **Add half steps and ramps** (a `/` or `.5` height in the row format, plus 4 incline directions). Biggest change to how the ground reads and plays, moderate cost: movement, height rules, mesh.
2. **Irregular footprints** with void tiles. Cheap, mostly in the map scripts.
3. **A smaller map class** (about 100 to 200 tiles) next to the big ones, for tight fights.
4. **A start zone of 3 to 4 tiles per side** and a pick of who goes where.
5. **Per-tile flags** (no-walk, pass-through, no-target) in the row format.
6. **Terrain effects** (water, sand, snow, swamp) in movement cost and damage; the `hit_percent_for` height term is already the beginning.
7. **A second walkable layer** for bridges and balconies. Large; only if the owner wants it.

## Limits of this look
- I read the data and the tile model, not the game's pictures: no FFT screenshots or map images were studied.
- I did not run any of the tools. The statistics come from a third-party dataset of the 119 battle maps (it has no licence, so only aggregates are quoted here); heights are in the units that dataset uses (half steps).
- FFT has more maps than the dataset's 119 battle maps (it leaves out story-only and unused maps), and the dataset is for one tool ("FFT Battleground"); I assume it matches the original maps.
- The comparison treats one of our levels as one FFT `h`; that follows our jump and cliff rules but I did not verify it tile by tile.
