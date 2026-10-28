# Hollowmark Tactics (Godot): fresh start

Everything from the first build was deleted on purpose (battle system, rules, classes, maps, menus, campaign, web version). They are still in git history (commit `202b479` and before) if anything is ever wanted back.

What is kept:
- **The art**: source sheets in `art_src/`, the built tiles, characters, props and effects in `assets/`.
- **The pipeline** that cuts them: `tools/art/` and `tools/build_resources.gd`.
- **How they are placed and made to look right**: `scripts/terrain.gd` (isometric terrain), `scripts/character.gd` (one sprite standing on it), the shaders (`unit`, `water`, `lava`), and the notes below.
- A **viewer** (`scenes/viewer.tscn`) that shows a sample map with every character on it. The two maps in `samples/` are terrain test patches, not game maps.
- The Claude Bridge editor plugin (`addons/claude_bridge`, `tools/godot-mcp/`): tooling for driving the Godot editor, not game code.

Open `godot/project.godot` in **Godot 4.3+** and press Play for the barracks. In the terrain viewer (`scenes/viewer.tscn`, F6): drag to pan, pinch or wheel to zoom, Q/E to rotate, Tab for the next sample.

## Files

| Path | What it is |
|---|---|
| `scripts/terrain.gd` | `Terrain`: builds a height map as textured `Polygon2D` blocks in a Y-sorted `field`. Map format, rotation (4 views), `iso`/`ground`/`stand_point`/`terrain_h`, slopes, water/lava shaders, trees, tufts, clouds, pedestal props. |
| `scripts/character.gd` | `Character`: `AnimatedSprite2D` with feet on the origin, shadow, unit shader; front/back frames and mirroring by each animation's `native` direction; waterline. |
| `scripts/viewer.gd`, `scenes/viewer.tscn` | The viewer. |
| `samples/*.json` | Sample maps: `rows` of `<terrain><height>` codes (`g0 g1 W0`), plus optional `smooth`, `hub`, `shadows`, `tufts`, `props`. |
| `shaders/` | `unit` (tint, hue shift, hit flash, KO gray, waterline), `water`, `lava`. |
| `assets/characters/*.tres` | SpriteFrames per character, built from `meta.json`. |
| `tests/check.tscn` | Headless check: samples build in all rotations, every terrain has its textures, every character has all 12 animations. |
| `tests/shot.tscn` | One screenshot of the viewer. |

Terrain codes (`Terrain.LOOK`): `g` grass, `t` grass with a tree, `d` dirt, `s` stone, `r` crag, `c` cinder, `l` lava, `a` sand, `m` mud, `n` snow, `w` shallow water, `W` deep water, `b` bridge, `M` marble, `k` island grass, `v` open sky (cloud puffs).

## Data layer (`scripts/core/`)

Step 1 of the new game: Resources and math only, no UI or combat.

| Class | What it is |
|---|---|
| `TacticalMath` | Levels 0-99, multiplier `1 + 0.02 x level`, proficiency ranks S-F and the 100-point bar, stat modifier math, chess geometry rays (Rook, Bishop, Knight, Queen, King). |
| `StatModifier` | One flat and/or percent change to one stat; stat caps (`LIMITS`: HP 300, SP 30). |
| `ProficiencyTrack` | One proficiency: rank, level, bar. Gain per use = rank gain (S 20 ... C 10 ... F 4) x efficiency. |
| `SkillData` | An active skill as data (SP cost, power, proficiency). |
| `ItemResource` | Base item; `WeaponItem` (bound to the unit, smithing level and tiers), `WeaponStyle` (geometry, stance, reach), `RelicItem` (skill conduit, accessory passive, negative trade-off with per-turn drains). No separate accessories: relics are the accessories. Inventory relics are permanent equipment and never become field props. |
| `CharacterStats` | Classless stats. Max HP = base x level multiplier; Max SP = (5 + Will/2 + Magic/4) x level multiplier, capped at 30, not regenerating. |
| `EquipmentLoadout` | Main Weapon (immutable, smithing-upgraded), Weapon Style, Relic Slot 1, Relic Slot 2 (set in menus from the permanent inventory), and Temp-Relic (vessels only, filled only by tethering in battle). |

Checked by `tests/core_check.tscn`.

## Board layer (`scripts/board/`)

Step 2: grid rules, movement and targeting geometry. No drawing or UI; units plug in later.

| Class | What it is |
|---|---|
| `IsoProjection` | Grid <-> screen math (tile size, height step, 4 view rotations, draw depth, picking the tile under a point, top or cliff side). `Terrain` uses it, so drawing and picking agree. |
| `TacticalGrid` | Cells, heights, terrain, obstacles, occupancy and teams. Walking search (Move, Jump, terrain cost; through allies, not foes) returning a `MovementRange` with costs and paths. Built from the same map format as `Terrain`. |
| `GeometryPattern` | A footprint: rays from `TacticalMath.geometry_rays` (Rook, Bishop, Knight, Queen, King, Pawn), plus jumps, pierce, splash and vertical reach. |
| `GeometryResolver` | Walks a pattern over a grid: targetable tiles, the `TargetArea` (tiles and occupants) of an aimed attack, occupants in reach, chess-style move tiles. |
| `StanceRules` | Table of what each stance does. Stances change only the footprint, tile selection and damage of physical attacks and skills; never stats or SP costs; magical skills ignore them. Impact: reach -1, cross splash, 100% / 50% damage. Pierce: reach +1, hits 1 tile behind, 90% / 75%. Axe: cleaves the 2 tiles beside, 110% / 50%. (aimed tile / other hit tiles) |
| `StanceComponent` | Node for a unit: holds the WeaponStyle and active stance, rebuilds the footprint when the stance changes (`stance_changed`, `footprint_changed`); `footprint_for(skill)` and `damage_at(...)` apply the stance to physical attacks only. |

Line rules: a ray ends at the board edge, open sky, an obstacle, a tile more than `vertical_reach` (3) above the unit, or the first unit on it (which can be hit). Knights jump over everything. Terrain: deep water, lava, trees and sky cannot be stood on; trees and placed obstacles block lines; shallow water and mud cost 2 to walk.

Checked by `tests/board_check.tscn`.

## Units layer (`scripts/units/`)

Step 3: who fights, deployment limits and vessel decay. No drawing or UI.

| Class | What it is |
|---|---|
| `UnitData` | Lasting unit definition (stats, loadout). Subclasses: `KingData` (the Commander; `vessel_roster`), `CoCaptainData` (permanent human, signature skills, no decay), `VesselData` (summoned onto relics; `fade_turns` 5 and the permanent `sever_count`). |
| `BattleUnit` | A unit in one battle: HP, SP, cell, and for vessels the Fade Clock, its King and `temp_relic()`. It is the occupant on the `TacticalGrid`. |
| `FadeClock` | The in-battle countdown: -1 every time the vessel ends its turn (paused while knocked out); at 0 the vessel is untethered. |
| `DeploymentManager` | Node enforcing 1 King (required), at most 1 Co-Captain, up to 6 Vessels, and running the relic cycle below. |
| `RelicProp` | A relic lying on a tile (Node2D, no drawing yet). Does not block the tile. |

The relic cycle:
1. Field relics lie on tiles as props (`place_relic`; which relics and where will come from each map's options). No unit can pick them up.
2. The King summons a vessel from his roster onto a prop (`summon_vessel(vessel, cell)`). The vessel is tethered: it stands in the prop's place and the relic goes into its Temp-Relic slot (its skill, passives and drawbacks apply). The tile must be within 30% of the map's longer side of the King (straight-line) and free, and the King must be standing.
3. The vessel's Fade Clock starts at 5 and goes down by 1 each time it ends its turn (`end_turn`), paused while it is knocked out. At 0 it is untethered automatically, the only way a vessel is untethered: its permanent Sever Count goes up by 1 and it cannot be summoned again this battle.
4. On untether: 25% the relic goes home to the permanent inventory; otherwise it reappears as a prop on the vessel's tile, ready for another vessel.
5. End of battle (`end_battle`): each vessel still on the field takes its Temp-Relic home 10% of the time, otherwise the relic is lost; props left on the field are lost. Inventory relics in Relic Slots 1 and 2 stay equipped.

Checked by `tests/units_check.tscn`.

## Proficiencies, mentorship and the barracks (Step 4)

- **Six proficiencies** (`Proficiency`): Physical, Elemental, Healing, Tactical, Status, Void. Every skill has one (`SkillData.category`); a character has a level 0-99 in each (`ProficiencyTrack`). Weapon attacks and Physical skills train Physical and follow the stance; the other five ignore stance.
- **Five equipment slots** (`EquipmentLoadout`): Main Weapon, Weapon Style, Relic Slot 1, Relic Slot 2, Temp-Relic (vessels only).
- **Skill mastery** (`SkillMastery`, `SkillTree` on each human's `UnitData.skill_tree`): starting a study puts the skill at level 0; filling its 100-point bar takes it to level 1, which is learning it. Nothing else is required.
- **Mentorship** (`Mentorship`): a human (King or Co-Captain) picks a vessel from the party (`PartyRoster`) and one of the skills on its relics as the active study. Each battle the human fights in adds the proficiency gain for that category (C rank: 10, about 10 battles per skill; `award_battle_study`, to be called by the battle results). Switching studies keeps progress.
- **Barracks** (`scenes/barracks.tscn`, the main scene; `BarracksScreen`, `MentorshipMenu`): lists Commanders and Vessels; each Commander has a Mentorship button that opens the sub-menu (proficiency levels, current study, vessels, their relic skills, details, Study button, learned skills). Uses `SampleParty` until there is a save system. Plain default controls until there is a menu art reference.

Checked by `tests/mentorship_check.tscn` (rules and driving the menus). Screenshot: `xvfb-run -a godot --path godot res://tests/ui_shot.tscn -- out=/home/user/x.png mentor=0`.

## Tests

```sh
godot --headless --path godot --import                    # once, to build the import cache
godot --headless --path godot res://tests/check.tscn
godot --headless --path godot res://tests/core_check.tscn
godot --headless --path godot res://tests/board_check.tscn
godot --headless --path godot res://tests/units_check.tscn
godot --headless --path godot res://tests/mentorship_check.tscn
xvfb-run -a godot --path godot res://tests/shot.tscn -- out=/home/user/x.png sample=0 zoom=.8 rot=0
```

## Art pipeline

Everything visual comes from the source images in `art_src/` (see `art_src/README.md` for the labeled list). `python3 tools/art/build_art.py` turns them into game assets (needs Python with Pillow, numpy and scipy, about 20 s):

- **Characters** (`tools/art/characters.py`): seven sheets (hero, knight, cardmage, gunman, dino, brute, wolf). Each frame is cut out with soft-edged background removal, scaled so every character's idle pose is the same height, and padded onto one shared canvas with the feet at the same point, so animations swap without jumping. Each character gets 12 animations: idle, ready, walk and hit (front and back versions), attack, cast, victory and ko. `PICKS` in that file chooses which frames from the sheet make each animation, so a different frame order is a one-line change.
- **Terrain** (`tools/art/tiles.py`): fourteen biome sheets. A "block" (center, size and depth of one isometric slab on a sheet) gives the 96x96 top textures from its interior tiles, and its lit and shaded side faces as strips. `TILESHEETS` lists what each sheet contains, and `BLOCKS`, `TOPS`, `SIDES` and `FLAT_TOPS` record the measured regions. Dirt, sand and crag are recolors. Water and lava are textures plus shaders.
- **Props and effects** (`tools/art/build_art.py`): the tree is the canopy from the village sheet, the bridge deck is cut from the bridges sheet, and the shadow, light dot and cloud puffs are generated.

Rebuild after changing the art:

```sh
python3 godot/tools/art/build_art.py
godot --headless --path godot --import
godot --headless --path godot --script res://tools/build_resources.gd   # SpriteFrames
```

## Characters

- Seven sheets (`art_src/characters/`): hero, knight, cardmage, gunman, dino, brute, wolf. Each frame is cut out, scaled so every idle pose is the same height (`BODY_H` 136 in `tools/art/characters.py`) and padded onto one shared canvas with the feet at `meta.json` `anchor`. `Character` sets `sprite.offset` so the anchor sits on the node's origin, then places the node at `Terrain.stand_point(x, y)`.
- Drawn at half size (`SPRITE_SCALE` .5). One standard size for every fighter; variants differ by tint and hue (`unit` shader), not by size. The JPG sheets look soft on phones: new transparent PNG sheets should be cut at a higher `BODY_H` with a matching lower `SPRITE_SCALE`.
- Facing: down the screen uses `_f` frames, up the screen `_b` frames; left/right is a mirror. Each animation's `native` direction in `PICKS` was guessed, not checked.
- Standing in shallow water: the shader's `cut` hides the feet below the waterline and the shadow is hidden.
- Add characters to `terrain.field` (Y-sorted) so they overlap blocks correctly.

## Terrain: how it is made to look right

- Each tile is a block: a top face and the two visible side faces, `TW` 32 / `TH` 16 half-size, `HS` 14 per height level, sides always reaching `BASE` below level 0.
- Every flat-top terrain is **one baked seamless texture** mapped by position (no per-tile pictures, no grid lines, tops 1.5% larger so neighbours overlap). Side strips are 4 tiles wide and wrap seamlessly, so cliff faces run on without joins. Water, lava and bridges stay level and use per-tile textures (water and lava through shaders, lava adds a point light).
- Any new biome should follow this standard.

### Grass

Grass (`g`) has no per-tile pictures: `bake_ground` in `tools/art/build_art.py` blends the 64 block tops (from `art_src/tiles/grass_blocks.jpg`, cut by `build_grass_blocks`) into one seamless 1024px texture, `ground_grass.png`, with smooth noise choosing lawn, tufted or mossy areas and small flower and stone patches. `terrain.gd` maps that texture by position (rotated grid coordinates, repeat on), so the ground has no tile borders; grass tiles also have no grid line and are drawn 1.5% larger so neighbours overlap. The dirt sides (`side_blockgrass_l/r.png`) are eight plain block faces cropped inside their outlines and feathered into each other so the cliff runs on without joins; `v0` in `LOOK` skips the grass lip so the dirt shows. The texture repeats about every 10.7 tiles. `blocktop_NN.png` are the intermediate cuts.

### Smooth hills

Maps are smooth by default (`smooth: false` turns it off). A smooth map draws terrain as slopes instead of cliff steps: each tile corner takes the mean height of the tiles around it (`_vh`, `_corner_heights` in `terrain.gd`), so neighbouring tops share edges, and the top is shaded by its slope (`SLOPE_SHADE`, light from behind). The sides always reach the same base level, so only the map border shows earth. Characters stand on the slopes (`terrain_h`, bilinear over the corners; `stand_point`).

### Block sheets

New tile art comes as isometric block sheets (an n x n grid of blocks on a dark background). `BLOCK_TERRAINS` in `tools/art/build_art.py` says, per terrain, which sheet and which cells give its tops and which give its side strip; `build_block_terrains` cuts the middle of each top face (`block_top`) and blends the faces into one wrapping strip (`block_side_strip`), then the terrain is baked seamless like grass. In use now: grass (`grass_blocks`), cinder and lava (`volcanic_new`; lava tops come from the molten faces), dirt and stone (`castle_ruins`: dark soil, flagstones), crag (`mountain_rock`), snow (`snow_blocks`, terrain `n`), marble (`town_marble`). `cut_block` only removes background connected to the cell edge, so dark soil and cracks inside a block stay. Still on the old art: sand, mud, water, bridges, Skyhold's rock sides, clouds. Saved for later biomes: `dungeon` (10x10), `sky_cubes`, `village_cobble`, `sky_islands`, `cosmic_ruins`.

### Floating islands (`hub: true`)

The rim tiles `k` are floating-island grass (`isle`, tops from `sky_islands`), every cliff under the islands, marble and bridges uses the islands' rocky undersides (`side_island`, built by `rect_side_strip` because island bottoms are not cube faces), marble tops come from `town_marble`, and the portal obelisk and crystal markers are pedestals cut whole from `cosmic_ruins` (`SHEET_SPRITES` -> `props/sky_obelisk.png`, `props/sky_crystal.png`). The sky-cube clouds kept their cube outline, so the drawn cloud puffs stay.

## Lessons from the first build

1. Check which game and repo before building anything.
2. Get the art or a style reference before writing rendering code.
3. Measure images with rulers (draw a coordinate grid over the sheet), not by eye.
4. Make small edits, not whole-file rewrites.
5. Look at few, small screenshots; use the headless check for the rest.
6. Keep sessions short, one milestone each.

## Setup in a fresh container

- Godot 4.3: download `Godot_v4.3-stable_linux.x86_64.zip` from the godotengine GitHub releases and put the binary at `/usr/local/bin/godot`.
- The art pipeline needs Python with Pillow, numpy and scipy.
- Claude Bridge (optional, with the editor open on your computer): `claude mcp add godot -- node /path/to/repo/godot/tools/godot-mcp/server.js`. It only listens on 127.0.0.1:6550.
