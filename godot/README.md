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
| `shaders/` | `unit` (palette swap, hit flash, KO gray, waterline), `water`, `lava`. |
| `ui/theme.tres` | Project theme: Pixelify Sans, blue window frames, gold accents. |
| `assets/characters/*.tres` | SpriteFrames: `idle` (alternates two idle poses), `ready`, `attack`, `cast`, `victory`. |

## Art

The source images are in `art_src/`: three character sheets and an isometric terrain sheet. `tools/art/build_art.py` turns them into game assets (needs Python with Pillow and numpy):

- **Characters:** each pose is cut out with soft-edged background removal and scaled to one height. Every pose is padded to the same canvas with the feet at the same point, so switching poses never makes the sprite jump. It also crops a portrait.
- **Terrain:** the isometric top faces are unwarped into square textures (16 grass variants from the 4×4 chunk), and the side faces into strips with the grass lip and rock strata. Dirt, sand, swamp, crag and cinder are recolors. Water and lava are shaders.
- **Extras:** generated tree, bridge planks, effect sprites, window frames and the title backdrop.

Who uses which sheet (`scripts/looks.gd`):

- **Swordswoman:** your melee jobs.
- **Card mage:** your ranged and magic jobs.
- **Demon:** every enemy.

The unit shader recolors one hue band per sheet (the sword glow, the jacket, the cape) to the job's or monster's color from the game data, like FFT palette swaps. Boss and big monsters are drawn larger. More character sheets can be added the same way, one per job or monster, by adding them to `build_art.py` and `looks.gd`.

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

- The sheets have front and three-quarter views only, so units mirror left and right but have no back view.
- The JS game has an AI-vs-AI stalemate, which the port copies faithfully. A KO'd unit's body blocks its tile (`reach()` counts KO'd units), and an AI caster can keep re-casting Lullaby. It only matters when the AI plays both sides.
- Deploy is automatic (first N units). No sound yet.
