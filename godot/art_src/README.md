# Source art

The original images behind every game asset. Keep them: `tools/art/build_art.py` rebuilds all of `assets/` from here.

## Characters (`characters/`)

The owner's full sheets (`<name>_sheet.webp`, cut by `tools/art/eight_dir.py` and the extras scripts) and four-direction idle and walk sheets (`<name>_idle_walk_sheet.png`). Rebuild with `bash tools/art/build_characters.sh`.

## Terrain (`tiles/`)

| File | Contents |
|---|---|
| grassland.jpg | Grass chunk, stone pillar, flower tiles |
| grass_stone.jpg | Grass blocks with dirt strata, stone paths, stairs and stone walls |
| village.jpg | Cobbles, dirt, grass tiles, cliffs with stairs, houses, market, well, fences |
| ruins.jpg | Mossy ruin floors, columns, arches, altar, vine walls |
| bridges.jpg | Rope, plank and stone arch bridges over chasms |
| castle.jpg | Marble halls, red carpet, battlements, gates, gargoyles, pillars |
| cave.jpg | Dark cave floor, crystals, stalagmites, underground stream, strata cliffs |
| swamp.jpg | Mud, murky water, roots, logs, mangrove trees |
| ice.jpg | Snow, ice cliffs, frozen lakes, ice crystals |
| desert.jpg | Dunes, cracked earth, sandstone ruins, oasis water |
| interactive.jpg | Pressure plates, levers, chests, warp pads, dungeon floor |
| water.jpg | Deep and shallow water blocks, waterfalls, stone bridges, riverbanks |
| volcanic.jpg | Ash ground, lava cracks, basalt cliffs and stairs, embers |
| sky.jpg | Floating marble and rock islands, crystals, wind vortex, sky pools |
| castle_ruins.jpg | Castle and ruins blocks (8x8): towers, walls, dirt and flagstone blocks; dirt and stone tops and sides |
| mountain_rock.jpg | Mountain rock blocks (8x8): crags, boulders, grassy and snowy rock; crag tops and sides |
| snow_blocks.jpg | Snow blocks (8x8): drifts, snowy dirt, pines, ice; snow terrain |
| sky_cubes.jpg | Sky and cloud cubes (8x8): clear, cloudy, sunset, wind (not used yet) |
| dungeon.jpg | Dungeon interiors (10x10): walls, floors, stairs, doors, cells, rubble (not used yet) |
| volcanic_new.jpg | New volcanic block sheet (8x8): cinder tops and sides, molten faces used for lava tops (`BLOCK_TERRAINS` in `tools/art/build_art.py`) |
| town_marble.jpg | Town marble sheet (8x8): houses, plazas, walls; plain marble block tops used for Skyhold marble |
| village_cobble.jpg | Medieval village sheet: cobbles, dirt paths, cottages (not used yet) |
| sky_islands.jpg | Sky cubes and floating grass islands, bridges, waterfalls (not used yet) |
| cosmic_ruins.jpg | Gold-and-marble ruins over a starfield (not used yet) |
| grass_blocks.jpg | 64 isometric grass blocks (top and dirt sides): plain, tall, moss, flowers, stones, dirt patches and cliff edges. Tops and dirt sides are cut from it for the grass terrain |
| grass_alt.jpg | Flat top-down grass sheet (tufts are cut from it; not used for tiles) |

Used by the three story maps: `grass_stone` (grass, dirt cliffs), `volcanic` (ash, basalt, lava), `water` (deep and shallow water), `village` (tree), `bridges` (deck). The other sheets are labeled and ready for new maps: `castle`, `cave`, `desert`, `ice`, `ruins`, `sky`, `swamp`, `interactive`, `grassland`.
