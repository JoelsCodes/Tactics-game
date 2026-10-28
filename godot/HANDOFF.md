# Handoff (for the next session)

Branch `claude/godot-port`, repo `JoelsCodes/Tactics-game`. Read `CLAUDE.md` and `godot/README.md` first. **Only the Godot version is worked on; the web version in the repo root is frozen.** Godot data and rules are the source of truth: `godot/data/game_data.json` and `godot/scripts/rules.gd`.

## Owner's working style
- Wants short replies: "done" plus the few things that changed or need a decision. No process explanations.
- Avoid screenshots unless needed. Be token-efficient; ask when asking is cheaper than guessing.
- Run the tests, say it was not checked on a real phone, commit and push every change.

## Setup in a fresh container
- Godot 4.3: download `Godot_v4.3-stable_linux.x86_64.zip` from the godotengine GitHub releases, put the binary at `/usr/local/bin/godot` (needs permission the first time). `pip install scipy` for the art pipeline.
- Tests: `godot --headless --path godot --import` once, then `godot --headless --path godot res://tests/run_tests.tscn` (about 90 s, 565 checks, all passing at handoff).
- Screenshots (only when needed): `xvfb-run -a godot --path godot res://tests/shots.tscn -- out=/home/user/shots`; one shot of the base: `res://tests/base_shot.tscn -- out=... zoom=.5`.
- Regression battles in `godot/tests/fixtures/` are frozen. After a deliberate rules change that alters battles, re-record: `godot --headless --path godot res://tests/record_traces.tscn`.
- Never use `pkill -f`. The JS exporters (`export_data.js`, `js_trace.js`) are retired and refuse to run without `--force`; do not run them.

## What exists (all in `rules.gd` unless noted)
- **Proficiencies:** six placeholder categories (strike, shot, arcane, mend, ward, trick; `PROFS`), each with a level and its own MP pool and MP level. Power and pool size scale by `1 + 0.02 x level`; uses level them up (`pf_need`). Jobs are class templates only (no AP or mastery).
- **Equipment:** weapon, vessel, accessory, accessory (`SLOTS` = `w`, `a`, `a2`). Armor, helms and shields were converted to accessory charms. Weapons and accessories teach skills while worn.
- **Vessel:** 4-8 field objects spawn per battle. Each is a vessel item: one skill of a category, the category's basic attack (`basic_<cat>`), a percent stat bonus (-40..+40 on one stat) and a title. Taking one is free, within a dome of 30% of the map's longer side. Using each skill 3 times (`SK_NEED`) keeps it for good; the item vanishes after battle. A unit that takes one starts a 6-turn Remove count (`VESSEL.remove`), then leaves the field.
- **Titles:** 10 in `TITLES`; on vessel items and ~35% of enemies.
- **Free movement:** units stand on a thirds-of-a-tile grid; Dijkstra reach (Move = walk length, Jump between tiles), straight-line ranges and areas, tap anywhere to move or aim. See README "Free movement".
- **Lift and throw:** Throw command; 10% max HP per throw, never below 30%; bosses can't be lifted; off the map = out of bounds (unit removed, enemy counts as defeated, remaining enemies +10% Atk/Def/Mag). AI: `AI_THROW = "boss"` (one random enemy throws to protect the boss), `annoying_throw: true` on a map makes every enemy throw. See README "Lift and throw".
- **Skyhold base:** 26x22 floating-island hub (`MAPS.base`), scene `scenes/base.tscn`, reachable from the title screen. A viewer only; the obelisk and crystals are shapes drawn in code.

- **Terrain look (the standard for every map and tile sheet):** smooth hills by default (`smooth` in `MAPS`, Skyhold opts out); every flat-top terrain is one baked seamless texture mapped by position (no per-tile pictures, grid lines or gaps); side strips wrap seamlessly; water, lava and bridges stay level. See README "Grass blocks", "Smooth hills", "Seamless terrain", "Block sheets". `CLAUDE.md` asks every new biome to follow it.
- **New tile art (owner's block sheets, in `art_src/tiles/`):** `BLOCK_TERRAINS` in `tools/art/build_art.py` lists, per terrain, which sheet cells give its tops and sides. In use: grass (`grass_blocks`), cinder and lava (`volcanic_new`), dirt and stone (`castle_ruins`), crag (`mountain_rock`), snow (`snow_blocks`, new terrain `n`, unused by maps), marble (`town_marble`), Skyhold island grass and rock (`sky_islands`), Skyhold crystal shrines (`cosmic_ruins`, `SHEET_SPRITES`). Saved for later biomes: `dungeon` (10x10), `sky_cubes`, `village_cobble`. Still old art: sand, mud, water, bridges, cloud puffs (sky-cube clouds looked like boxes).
- Rebuild art: `python3 godot/tools/art/build_art.py` (needs Pillow, numpy, scipy), then `godot --headless --path godot --import`. Grass test map: `tests/grass_test.tscn` (24x20). One screenshot of a map: `xvfb-run -a godot --path godot res://tests/base_shot.tscn -- out=/home/user/x.png map=grasstest zoom=.6` (omit `map=` for Skyhold).
- **Fighters:** one standard size (all scales 1.0 in `scripts/looks.gd`). Sprites are still cut from the old JPG character sheets (`tools/art/characters.py`, `BODY_H` 136, drawn at half size), which look soft on phones.

## Known placeholders and open decisions
- Numbers I chose that the owner may tune: `SK_NEED` 3, `PF_NEED` = 2 + level, `OB_BONUS` 10, `THROW_R` 4, remove count 6, enemy title chance 35%, the 10 titles, the six basic attacks, vessel object look (gold diamond).
- `annoying_throw` is not enabled on any map yet. Ask which map.
- The recorded regression battles reflect all the above; changing a number means re-recording them.
- Skills still carry a `job` field (used for enemy extra skills and the vessel skill pool); skills with `rng: "w"` are left out of the vessel pool.

## Next up
1. **Character art.** The owner will send new character sheets as PNGs (transparent, same frame size, same scale). Ask them to send in a new message (images sent mid-turn are not saved to disk) and which rows are walk, idle, attack, cast, hit, KO. Re-cut at higher resolution so units stay sharp on phones (raise `BODY_H`, lower `SPRITE_SCALE` in `unit.gd` to match); keep one standard size.
2. **World map (FFTA style).** Waiting on a painted map image from the owner. Data exists (`LOCS`, `ROUTES`). Plan: nodes per location, routes, a walking party marker, start the battle (town opens Skyhold); replace the title's mission list.
3. **More tile art** as sheets arrive (sand, mud, water, bridges). Add to `BLOCK_TERRAINS`, check one screenshot for seams.
4. Content from Gemini (weapons, accessories, skills as JSON) when pasted back: validate and merge into `game_data.json`.
5. Campaign engine and screens (save/load, shop, bazaar, errands, recruits, unit screen) not ported yet.
6. Not checked on a real phone: free movement taps, throwing, smooth hills, text size, speed.
