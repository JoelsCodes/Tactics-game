# Hollowmark Tactics: Godot edition

A Godot 4 port of the web game in the repo root, rebuilt in a tactics-RPG style with real art. **Milestone: battles.** All game data, the full rules engine and AI, the battlefield and the battle controls are ported. The campaign (world map, shop, bazaar, clan management, errands, results/AP) is not ported yet.

Open `godot/project.godot` in **Godot 4.3+**, then press Play. The title screen lists the three story missions. Each one starts with the default clan at a fitting level.

## How it is built

| Path | What it is |
|---|---|
| `scenes/battle.tscn` | Battle scene: sky backdrop, `World` (Y-sorted field, camera, ambience, effects, mood light) and the `HUD`. |
| `scenes/hud.tscn` | HUD layout: turn order, law window, status window, command menu, ability list, target forecast, banners, end screen. |
| `scenes/unit.tscn` | One unit: shadow, team ring, `AnimatedSprite2D` with a palette material, overhead HP. |
| `scenes/title.tscn` | Title screen and mission select. |
| `scripts/world.gd` | Builds each tile as textured `Polygon2D` faces (top plus sides), handles the camera (drag, pinch, wheel, 4-way rotation), picking, highlights, facing arrows, particles, floating numbers, lava lights and per-map ambience. |
| `scripts/battle.gd` | Turn loop and commands (Move / Act / Wait / Undo, targeting, facing), enemy turns, poses and banners. |
| `scripts/hud.gd`, `portrait.gd`, `stat_bar.gd` | HUD logic and widgets. |
| `scripts/looks.gd` | Which sprite and palette each unit gets. |
| `scripts/rules.gd`, `data.gd` | Rules engine (port of `js/engine.js`) and game data (autoloads `Rules`, `Data`). |
| `shaders/` | `unit` (tint, hue shift, hit flash, KO gray, waterline), `water`, `lava`. |
| `ui/theme.tres` | Project theme: Pixelify Sans, blue window frames, gold accents. |
| `assets/characters/*.tres` | SpriteFrames per character, built from `meta.json`: idle/ready/walk/hit `_f` and `_b`, attack, cast, victory, ko. |

## Art

Everything visual comes from the source images in `art_src/` (see `art_src/README.md` for the labeled list). `python3 tools/art/build_art.py` turns them into game assets (needs Python with Pillow, numpy and scipy, about 20 s):

- **Characters** (`tools/art/characters.py`): seven sheets (hero, knight, cardmage, gunman, dino, brute, wolf). Each frame is cut out with soft-edged background removal, scaled so every character's idle pose is the same height, and padded onto one shared canvas with the feet at the same point, so animations swap without jumping. Each character gets 12 animations: idle, ready, walk and hit (front and back versions), attack, cast, victory and ko. `PICKS` in that file chooses which frames from the sheet make each animation, so a different frame order is a one-line change.
- **Terrain** (`tools/art/tiles.py`): fourteen biome sheets. A "block" (center, size and depth of one isometric slab on a sheet) gives the 96x96 top textures from its interior tiles, and its lit and shaded side faces as strips. `TILESHEETS` lists what each sheet contains, and `BLOCKS`, `TOPS`, `SIDES` and `FLAT_TOPS` record the measured regions. Dirt, sand and crag are recolors. Water and lava are textures plus shaders.
- **Props, effects, UI** (`tools/art/build_art.py`): the tree is the canopy from the village sheet, the bridge deck is cut from the bridges sheet, and effect sprites and window frames are generated.

Who is drawn as what (`scripts/looks.gd`): every job maps to one of the seven characters, monsters pick a character plus a tint and size, and enemy clan units get a faint red tint so they read as hostile.

Rebuild after changing the art:

```sh
python3 godot/tools/art/build_art.py
godot --headless --path godot --import
godot --headless --path godot --script res://tools/build_resources.gd   # SpriteFrames + theme
```

The font is Pixelify Sans (SIL Open Font License, `assets/fonts/PixelifySans-OFL.txt`).

## Skills, proficiencies, equipment and the vessel

- Six placeholder proficiencies (`PROFS` in `data/game_data.json`), each with a level and its own MP pool and MP level. Power and pool size scale by `1 + 0.02 x level`. Jobs are class templates only.
- Equipment slots, in order: **weapon, vessel, accessory, accessory** (`SLOTS` in `rules.gd` is `w`, `a`, `a2`; the vessel exists only in battle as `bu.vessel`). Shields, helms and body armor are gone: their old items became accessories (charms) that keep the reaction and support skills and drop def/hp/res. Weapons and accessories teach skills while worn.
- Vessel: every battle spawns 4-8 field objects. Each is a vessel item: a skill from one category, the basic attack of the same category (`basic_<category>`), and a percent bonus or penalty to one stat (Atk, Def, Mag, Res or Spd; -40 to +40) shown when you pick it. Taking one is free (no move or action) from inside a dome of 30% of the map's longer side. The vessel and its bonus vanish after the battle; each of its skills used 3 times (`SK_NEED`, saved per unit) is kept for good. AI units grab the nearest object when their vessel is empty.
- Remove count (Phantom Brave style): taking a vessel item starts a count of 6 of that unit's turns (`VESSEL.remove`); when it runs out the unit leaves the field for the rest of the battle. Shown as "Remove N" in the status window.
- Titles: every vessel item, and about 35% of enemies, carry a title from `TITLES` (e.g. Brutal: +20% Atk, -10% Def). Its percents apply on top of the vessel bonus.
- Objects are a placeholder gold diamond until there is art. Rules: `spawn_objects`, `roll_vessel`, `objs_in_reach`, `pickup`, `train_vessel` in `rules.gd`.
- The regression battles in `tests/fixtures/` are re-recorded from the Godot rules with `res://tests/record_traces.tscn` after a deliberate rules change.

## Free movement

Units stand anywhere on the map, not just on tile centres: positions are on a sub-grid of thirds of a tile (`SUB` in `rules.gd`), so `bu.x`/`bu.y` are floats and the tile under a unit is the rounded position. `reach()` is a Dijkstra walk over that sub-grid in eight directions with Move as the path-length budget; crossing into another tile obeys Jump, living foes block the way and nobody stops closer than `UNIT_GAP` to another body. Ranges and areas are straight-line distances (`in_range`, `targets_of`); a single-target skill hits the unit nearest the aim point. "Adjacent" (counters, combos, the ranged law) means within `NEAR` (1.25 tiles). Spear "line" attacks no longer need a straight line. In battle, tap anywhere in the blue area to move, or a unit or a spot in range to aim; a ring marks the chosen spot. The AI searches one spot per reachable tile.

## Lift and throw

The Throw command lifts a unit (ally, foe or KO body) or field object within `NEAR` and throws it to an open spot up to `THROW_R` (4) tiles away; it uses the thrower's action. Every throw costs a unit 10% of its max HP (`THROW_DMG`) but never takes it below 30% (`THROW_FLOOR`), so it never kills. Enemy bosses (boss monsters and clan leaders) cannot be lifted.

**Out of bounds:** when a map edge is within throwing range, "Off the map!" throws a unit past it. It still takes the 10%, then leaves the battle. An enemy thrown out counts as defeated (no loot) and every enemy still standing gains `OB_BONUS` (+10%) Atk/Def/Mag per throw ("OB +N%" in its status). An ally thrown out is gone for the battle; an object thrown out is lost.

**Enemy throwing** (`AI_THROW` in `rules.gd`, or `annoying_throw: true` on a map in `MAPS`): `"boss"` (default) picks one random non-boss enemy per battle (`B.thrower`) who throws a player unit that crowds the boss (within 3 tiles), preferably off the map; `"all"` (what `annoying_throw` sets) lets every enemy throw adjacent foes for fun; `"off"` never. Rules: `is_boss`, `throwables`, `can_land`, `ob_point`, `throw_damage`, `throw`, `pick_thrower`, `throw_plan` in `rules.gd`.

## Grass blocks

Grass (`g`) has no per-tile pictures: `bake_ground` in `tools/art/build_art.py` blends the 64 block tops (from `art_src/tiles/grass_blocks.jpg`, cut by `build_grass_blocks`) into one seamless 1024px texture, `ground_grass.png`, with smooth noise choosing lawn, tufted or mossy areas and small flower and stone patches. `world.gd` maps that texture by position (rotated grid coordinates, repeat on), so the ground has no tile borders; grass tiles also have no grid line and are drawn 1.5% larger so neighbours overlap. The dirt sides (`side_blockgrass_l/r.png`) are eight plain block faces cropped inside their outlines and feathered into each other so the cliff runs on without joins; `v0` in `LOOK` skips the grass lip so the dirt shows. The texture repeats about every 10.7 tiles. `blocktop_NN.png` are the intermediate cuts.

## Base: Skyhold

`base` in `data/game_data.json` (`MAPS`) is a 26x22 hub of floating islands built from the `sky` sheet: a central marble plaza with a sunken pool, a stepped terrace to a portal obelisk in the north, a crystal garden (north-east), an east island with a pool, a west training yard, a south dock and stepping stones, joined by bridges and stairs. New terrain: `M` marble, `k` sky rock, `v` open sky (drawn as cloud puffs). `scenes/base.tscn` (`scripts/base.gd`) shows it with the clan idling about; reach it from the title screen. It is a viewer for now (pan, zoom, rotate); menus come later. Obelisk and crystals are shapes drawn in code until there is art for them. `tests/base_shot.tscn` takes one screenshot of it.

## Data and rules (Godot is the source of truth)

The web version is frozen. Edit `data/game_data.json` and `scripts/rules.gd` directly. The old JS exporters are guarded (`--force`) because running them would overwrite Godot's data with the web version's. Historical notes below describe how the port was first made:

```sh
# retired: export_data.js and js_trace.js (guarded with --force)
```

## Tests

```sh
godot --headless --path godot --import                    # once, to build the import cache
godot --headless --path godot res://tests/run_tests.tscn  # ~20 s
```

- **Data integrity**: the same checks as `tests/engine.test.js`.
- **Parity with the JS engine.** Six seeded AI-vs-AI battles recorded from the JS engine are replayed with the same random sequence, and the state must be identical after every turn. All six match.
- **More seeded AI-vs-AI battles** on all three missions.

`tests/shots.tscn` is a screenshot tour that drives the real UI and plays a battle to the end. It needs a renderer: `xvfb-run -a godot --path godot res://tests/shots.tscn -- out=/tmp/shots`.

## Working on it with Claude

- **In a Claude Code cloud session:** Claude edits the scripts, runs the tests and the screenshot tour, and pushes.
- **On your computer, with the editor open:** the Claude Bridge plugin is enabled in this project. Register the MCP server once, and Claude Code can inspect and edit scenes, write scripts, run the game and take editor screenshots:
  ```sh
  claude mcp add godot -- node /path/to/repo/godot/tools/godot-mcp/server.js
  ```
  The plugin only listens on 127.0.0.1:6550, and only while the editor is open.

## Notes

- Knocked-out bodies can be walked through but not stopped on, in both versions (`reach()`; pinned by a test in `run_tests.gd`).
- The one AI-vs-AI stalemate the JS game has (it only happens when the computer plays both sides) comes from that rule: Briar Ford's ford is two tiles wide, and when bodies lie on both tiles, no standing tile touches the sleeping enemies behind them. The port copies it faithfully.
- The sheets have both front and back views. Units mirror left and right, and turn their back to the camera when facing up the screen.
- Deploy is automatic (first N units). No sound yet.

## Plan for the next four sessions

One milestone per session. The model level is a recommendation: use the strongest model only where a mistake would be hard to spot. Start each session by reading this file and asking the owner the questions in the notes below.

| # | Session | Model | Why |
|---|---|---|---|
| 1 | Polish and ship the battle | Sonnet | Mechanical work with clear checks |
| 2 | Campaign engine | Opus | Correctness-critical, and the save format is hard to change later |
| 3 | Campaign screens | Sonnet | UI built from patterns that already exist |
| 4 | New content, then a final review | Sonnet, then Opus for the review | Content is routine; a review catches what tests cannot |

### Session 1: polish and ship the battle (Sonnet)
- Tune which way each sprite faces (the `native` direction per animation in `tools/art/characters.py` `PICKS` was guessed, not checked), and fix walk poses that face the wrong way.
- Add a unit-selection screen before a mission. Deploy is automatic today (the first N units).
- Export a web build so the game can be played in a browser or on a phone, and publish it as a private artifact for the owner.
- Fix what the owner finds on a real phone (touch, text size, speed).
- Open the pull request for `claude/godot-port`.
- Before starting, get: the owner's notes from playing it on a phone.

### Session 2: campaign engine (Opus)
- Port the non-visual logic of `js/game.js`: save and load, shop buy and sell, bazaar crafting, mission progression, rewards, AP and job unlocks, errands, recruits, jail and bail.
- Back it with tests that replay the JS version, the way `tests/run_tests.gd` already does for battles. There are no screens in this session, so the tests are the review.
- Decide the save format carefully. It is hard to change once players have saves.
- Before starting, get: the owner's decision on the Lullaby stalemate (see Notes).

### Session 3: campaign screens (Sonnet)
- World map and travel, town (shop, bazaar, pub), clan list, unit screen (jobs, abilities, equipment) and the results screen.
- Build them in the existing blue-window style (`ui/theme.tres`, `scripts/hud.gd` widgets). If the unit screen runs long, split it into a second session.
- Before starting, get: UI icons or a reference for how the menus should look, if the owner has them.

### Session 4: new content and final review (Sonnet, then Opus)
- Build one or two new maps from the unused biomes (castle, cave, ice, desert, ruins, sky, swamp), with missions. The sheets are already labeled in `art_src/tiles/`.
- Add sound, and any new monster or job art the owner has made by then (`tools/art/characters.py` and `scripts/looks.gd`).
- Finish with an Opus code review over the whole port.
- Before starting, get: new sheets (monsters, jobs, back views) and the choice of biomes.

### When to use a cheaper model
Haiku is only for tiny jobs: README edits, renaming files, one-line fixes. Do not use it for the main sessions.

## Notes for the next session (lessons from the first one)

The first session spent a lot of tokens on avoidable detours. Read this before starting, and ask the owner the questions below first.

### What went wrong, and what to do instead

1. **Check which game and repo before building anything.** The first request was "build a connector for Godot". The connector was built before it was clear that the game was a JavaScript project in a different repo. Ask which game, which repo and which engine first.
2. **Get the art or style reference before building visuals.** A full code-drawn renderer was built and then deleted when real art arrived. Ask for art, or a screenshot of the target look, before writing any rendering code.
3. **Measure images with rulers, not by eye.** Tile and sprite regions were guessed from thumbnails and had to be redone several times. Draw a coordinate grid over the sheet first (see `tools/art/tiles.py` for how blocks are described) and only then write the recipe.
4. **Make small edits, not whole-file rewrites.** `build_art.py` was rewritten three times and `battle.gd` twice. Use targeted edits unless most of the file really changes.
5. **Look at fewer, smaller screenshots.** Check one crop per change, not a full contact sheet every time. The headless tests (`tests/run_tests.tscn`) catch rule bugs without any images.
6. **Keep sessions short, one milestone each.** Every turn re-reads the whole conversation, so long sessions get more expensive each turn. Good session boundaries: rules and data, art pipeline, campaign screens, map building.
7. **Use the right model for the job.** Rules porting and tricky debugging suit a stronger model. Mechanical work (cutting sprites, wiring textures, README edits) is fine on a cheaper one.

### Questions to put to the owner at the start

- Which repo and branch do I work on, and is the Godot port the target or the web game?
- What should the next milestone be: campaign screens (world map, shop, clan, results), a new map from an unused biome (castle, cave, desert, ice, ruins, sky, swamp), or polish?
- Do you have art for what I will build (monsters, remaining jobs, back views, UI, icons)? In what format? Six-pose or full sheets on a flat background work, and transparent PNG is better than JPG.
- Is there a reference screenshot or game for the look you want?
- Should the Lullaby stalemate be fixed (it changes how the game plays), and if so, how?
- Pull request now, or keep pushing to the branch?
- Do you want sound and music, and if so, your own files or free licensed ones?
- Have you tried it on a real phone? Anything off with touch, text size, speed or facing?

### Things the owner can do that save the most work

- Say up front which repo and engine.
- Send art before asking for visuals.
- Start a new session per milestone and point it at this file.
- Say when a task is mechanical, so it can be done lean.
- Run the game in Godot 4.3+ once and report problems.

### Practical setup

- Godot 4.3 is not installed in a fresh container. Download the Linux build from the official GitHub releases and run it headless. The sandbox may ask for permission the first time.
- Headless tests: see "Tests" above. Screenshots need a renderer: `xvfb-run -a godot --path godot res://tests/shots.tscn -- out=/tmp/shots`.
- The art pipeline needs Python with Pillow, numpy and scipy.
