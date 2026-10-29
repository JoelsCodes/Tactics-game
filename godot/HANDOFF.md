# Handoff

Branch `claude/godot-port`, last commit `7a2feab`. Read `CLAUDE.md` (repo root) and `README.md` first. Everything below is pushed; the tree was clean.

## State
Steps 1-8 and the later rule changes are done and tested: data/resources, grid + chess-vector geometry + stances, King / Co-Captains / Vessels with Fade Clock and sever/tether counts, proficiencies + mentorship, turn order + SP-as-MP + enemy AI, damage + extraction, barracks + versioned saves, XP/levels 1-99, battle HUD, no mid-battle stance change, no pre-battle screen, Co-Captain chosen in barracks, King summons any owned vessel in battle (30% range rule, per-map `max_summons`, default 6, every summon counts).

Latest work (HD-2D look, see README "Lighting and finish" and "UI art"):
- `scripts/terrain.gd`: vertex-baked light, per-corner AO and cast shadow (`corner_shade`), constants `AO_PER_LEVEL`, `SHADOW_*`, `*_LIGHT`.
- `shaders/terrain_face.gdshader` (stone detail), `diorama.gdshader` (bloom, grade, grain), `tile_highlight.gdshader` (neon floor, premul blend).
- `tools/art/build_ui.py` generates `assets/ui/*` (needs Pillow, numpy, scipy: `pip install scipy`). `HudStyle` uses textured nine-slice panels, buttons, bars; Cinzel + Lato fonts in `assets/fonts/`.
- No `WorldEnvironment`: it is 3D-only; effects are emulated in 2D (told to the owner).

## Latest: the battle screen is 3D (Forward+)
- `scripts/stage/board_3d.gd` (`Board3D`): block terrain from the map and tile art, warm sun with soft shadows, omni fills, sky gradient, fog, SSAO, glow, DoF, tilted perspective camera (pitch -50, 28 degree lens), quarter-turn orbit, zoom, pan, ray picking, framing between the HUD bands.
- `unit_view_3d.gd` / `tree_view_3d.gd`: upright billboards (nearest filter, stretched by 1/cos(pitch) so they keep their drawn proportions), shadow-only capsules. `tile_highlights.gd` + `shaders/tile_highlight_3d.gdshader`: neon floor highlights as meshes.
- `project.godot` renderer is `forward_plus`: needs Vulkan. In this container: `apt-get install -y mesa-vulkan-drivers` for screenshots (slow software rendering).
- The 2D `Terrain`/`Character` and 2D lighting shaders remain for the viewer only.
- Not ported to 3D yet: smooth slopes, animated water/lava, pedestal props, clouds and island maps.

## Verify before pushing
`godot --headless --path godot --import` (after any texture/font change; `.import` files are gitignored), then the ten test scenes listed in `CLAUDE.md` plus `python3 godot/tools/art/test_magenta_key.py`. At handoff all pass (check 0 failed, core 89, board 116, units 6091, mentorship 61, battle 124, save 177, exp 102, stage 101, ai 40). Screenshots: `xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --resolution 1920x1080 res://tests/battle_shot.tscn -- out=/path.png step=move|aim|...` and `ui_shot.tscn` (`mentor=0`, `loadout=N`). Never checked on a real display.

## Open items / ideas
- Owner has not reacted to the HD-2D result yet: expect tuning requests (panel opacity, glow strength, shadow strength, bloom). Knobs: `build_ui.py` palette/alpha, shader uniforms, terrain constants.
- Highlight glow does not extend outward past the region border (would need an enlarged polygon); not done.
- Small cards use 40px nine-slice margins, so very short panels look cramped (spare-relic cards); menu layouts could get more padding or a thinner `panel_small` texture.
- Turn-order frames still use flat `HudStyle.box()` (gold/team-color borders), by design for team colors; could get textured frames (`portrait_frame.png` exists, unused).
- `assets/fonts/LICENSE.txt` lacks the full OFL text (could not be downloaded); add it.
- Anchor-relic assumption (field relic props become Temp-Relic) was flagged to the owner, never answered.
- Terrain textures themselves were not repainted; richness comes from lighting only.

## Rules to keep
Owner-set design rules in `CLAUDE.md` (5 loadout slots, no pre-battle screen, fixed King, live summoning). Commit and push every change with the trailers from the session reminder. Never `pkill -f`. Keep sessions to one milestone, small edits, few small screenshots.
