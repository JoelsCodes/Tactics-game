# Hollowmark Tactics: Godot edition

A Godot 4 port of the web game in the repo root. **Milestone 1: battles.** All game data, the full rules engine and AI, the isometric battle view and the battle controls are ported. The campaign (world map, shop, bazaar, clan management, errands, results/AP) is not ported yet.

Open `godot/project.godot` in **Godot 4.3+**, then press Play. The title screen lists the three story missions. Each one starts with the default clan at a fitting level.

## What's in it

| File | What it does |
|---|---|
| `data/game_data.json` | All game data, exported from `js/data.js`. Do not edit by hand. |
| `scripts/data.gd` | Autoload `Data`: loads the JSON (`Data.JOBS`, `Data.AB`, `Data.MAPS`, ...). |
| `scripts/rules.gd` | Autoload `Rules`: line-by-line port of `js/engine.js`, plus battle setup from `js/game.js`. |
| `scripts/battle_view.gd` | Isometric renderer (port of `js/render.js`): height map, rotation, pan/zoom/pinch, tap picking, effects. |
| `scripts/art.gd` | Procedural sprites and drawing helpers (no image assets, same as the web version). |
| `scripts/battle.gd` | Battle screen: turn loop, Move / Act / Wait / facing, targeting with previews, enemy turns, laws and cards. |
| `scripts/title.gd`, `scripts/ui.gd` | Mission select; theme and widgets (colors match the web CSS). |
| `addons/claude_bridge/` | Editor plugin that lets Claude drive the Godot editor (see below). |

## Keeping the two versions in sync

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
- **Parity with the JS engine.** `tools/js_trace.js` records six seeded AI-vs-AI battles (two per mission) from the JS engine. The Godot test replays them with the same random sequence and requires identical positions, HP, MP, CT and statuses after every turn. All six match.
- **More seeded AI-vs-AI battles** on all three missions.

`tests/shots.tscn` is a screenshot tour that drives the real UI and plays a battle to the end. It needs a renderer: `xvfb-run -a godot --path godot res://tests/shots.tscn -- out=/tmp/shots`.

## Working on it with Claude

- **In a Claude Code cloud session** (how this port was made): Claude edits the scripts, runs the headless tests and the screenshot tour, and pushes.
- **On your computer, with the editor open**: the Claude Bridge plugin is enabled in this project. Register the MCP server once, and Claude Code (or Claude Desktop) can read the scene tree, add and edit nodes, write scripts, run the game and take editor screenshots:
  ```sh
  claude mcp add godot -- node /path/to/repo/godot/tools/godot-mcp/server.js
  ```
  The plugin only listens on 127.0.0.1:6550, and only while the editor is open.

## Known differences and notes

- In water, the web version clips the unit sprite at the waterline. Here a water-colored ellipse covers the feet.
- The web version's JS game has an AI-vs-AI stalemate that the port faithfully copies. A KO'd unit's body blocks its tile for movement (`reach()` counts KO'd units), and an AI caster can keep re-casting Lullaby. It only matters when the AI plays both sides; in normal play you control your team.
- Deploy is automatic (first N units); the web version lets you choose.
