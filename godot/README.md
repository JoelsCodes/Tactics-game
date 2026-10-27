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

## Keeping the rules in sync with the web version

The JS game stays the source of truth for data:

```sh
node godot/tools/export_data.js   # after editing js/data.js
node godot/tools/js_trace.js      # after changing js/engine.js: re-records the parity battles
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
