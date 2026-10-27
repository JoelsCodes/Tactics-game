# Handoff (for the next session)

Branch `claude/godot-port`, repo `JoelsCodes/Tactics-game`. Read `CLAUDE.md` and `godot/README.md` first. **Only the Godot version is worked on; the web version in the repo root is frozen.** Godot data and rules are the source of truth: `godot/data/game_data.json` and `godot/scripts/rules.gd`.

## Owner's working style
- Wants short replies: "done" plus the few things that changed or need a decision. No process explanations.
- Avoid screenshots unless needed. Be token-efficient; ask when asking is cheaper than guessing.
- Run the tests, say it was not checked on a real phone, commit and push every change.

## Setup in a fresh container
- Godot 4.3: download `Godot_v4.3-stable_linux.x86_64.zip` from the godotengine GitHub releases, put the binary at `/usr/local/bin/godot` (needs permission the first time). `pip install scipy` for the art pipeline.
- Tests: `godot --headless --path godot --import` once, then `godot --headless --path godot res://tests/run_tests.tscn` (about 50 s, 564 checks, all passing at handoff).
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

## Known placeholders and open decisions
- Numbers I chose that the owner may tune: `SK_NEED` 3, `PF_NEED` = 2 + level, `OB_BONUS` 10, `THROW_R` 4, remove count 6, enemy title chance 35%, the 10 titles, the six basic attacks, vessel object look (gold diamond).
- `annoying_throw` is not enabled on any map yet. Ask which map.
- The recorded regression battles reflect all the above; changing a number means re-recording them.
- Skills still carry a `job` field (used for enemy extra skills and the vessel skill pool); skills with `rng: "w"` are left out of the vessel pool.

## Next up
1. **World map (Final Fantasy Tactics Advanced style).** The owner will upload a painted map image. Data exists (`LOCS`, `ROUTES` in game data: Harrowgate town, Briar Ford, Cinder Quarry, Mirewood Hollow). Plan: put the image in `art_src/` and `assets/`, place a node per location and draw routes, a party marker that walks the route, then start that location's battle (town opens Skyhold); replace the title screen's mission list with the map. Do not build visuals before the image arrives.
2. **Content from Gemini.** The owner is having Gemini write weapons, accessories and skills as JSON using prompts drafted in the previous session. When pasted back: validate field names and references, merge into `game_data.json`, assign categories, run the tests. The data test fails on unknown skill ids and bad slots.
3. Campaign engine and screens (save/load, shop, bazaar, errands, recruits; unit screen with the new equipment/proficiencies) are still not ported; the README's old session plan lists them but predates the changes above.
4. Not checked on a real phone yet: tap-anywhere moving, throw targeting, text size, speed.
