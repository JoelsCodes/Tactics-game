# Source art

The original images behind every game asset. Keep them: `tools/art/build_art.py` rebuilds all of `assets/` from here.

## Characters (`characters/`)

Each sheet is one character: WALK (front and back, 3 rows), READY, STAND, ATTACK, CAST, HIT, KO.

| File | Character | Plays as |
|---|---|---|
| hero.jpg | Blond swordswoman with a glowing blue sword | Squire, Spellblade, Fencer |
| knight.jpg | Silver-haired knight in a red cape | Knight, Mender |
| cardmage.jpg | White-haired card caster in a denim jacket | Arcanist, Sage and other casters |
| gunman.jpg | Red-haired man in a dark suit with a pistol | Archer, Rogue, Gunner and other ranged jobs |
| dino.jpg | Green saurian | Warrior, Cleric and other Saurian jobs; Ooze (tinted) |
| brute.jpg | Red horned beast | Grimkin; Sandmaw (tinted) |
| wolf.jpg | Grey wolfman | Wolfhound; Animist, Moss Knight |

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
| grass_blocks.jpg | 64 isometric grass blocks (top and dirt sides): plain, tall, moss, flowers, stones, dirt patches and cliff edges. Tops and dirt sides are cut from it for the grass terrain |
| grass_alt.jpg | Flat top-down grass sheet (tufts are cut from it; not used for tiles) |

Used by the three story maps: `grass_stone` (grass, dirt cliffs), `volcanic` (ash, basalt, lava), `water` (deep and shallow water), `village` (tree), `bridges` (deck). The other sheets are labeled and ready for new maps: `castle`, `cave`, `desert`, `ice`, `ruins`, `sky`, `swamp`, `interactive`, `grassland`.
