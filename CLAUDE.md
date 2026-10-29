# Hollowmark Tactics: notes for Claude

**Fresh start (Oct 2026).** The owner had everything from the first build deleted: battle system, rules, classes, maps, menus, campaign and the web version. Only the art and how it is placed are kept. The old code is in git history (`202b479` and before); do not restore any of it unless the owner asks.

Work is in `godot/` (Godot 4.3+), branch `claude/godot-port`. **Read `godot/README.md` first.**

## Before you start
- Ask the owner what to build next. There is no game design in the repo now; do not assume the old one.
- Do not build visuals before the owner has supplied art or a reference.
- Keep the session to one milestone. Use small edits, not whole-file rewrites, and look at few, small screenshots.

## Design rules the owner has set (do not undo)
- Loadout slots are exactly: Main Weapon, Weapon Style, Relic Slot 1, Relic Slot 2, plus the vessels-only Temp-Relic. Everything is set in the out-of-battle menus; nothing changes in battle.
- No pre-battle screen. The King is fixed on every mission; the player picks the Co-Captain in the barracks.
- Vessels are not pre-selected: the King summons any vessel he owns during battle, up to the map's summon limit (default 6, every summon counts).

## Working rules
- Commit and push every change. Commit messages end with the attribution trailers given in the session reminder.
- New terrain or biomes follow the terrain standard in `godot/README.md` (seamless baked tops, wrapping side strips, smooth hills by default).
- The battle screen is a 3D board (`Board3D`, Forward+ renderer). Screenshots need Vulkan (`mesa-vulkan-drivers` in a container without a GPU). The 2D `Terrain` is only the viewer now.
- Run `godot --headless --path godot res://tests/check.tscn`, `res://tests/core_check.tscn`, `res://tests/board_check.tscn` , `res://tests/units_check.tscn` , `res://tests/mentorship_check.tscn` , `res://tests/battle_check.tscn` , `res://tests/save_check.tscn` , `res://tests/exp_check.tscn` , `res://tests/stage_check.tscn`, `res://tests/ai_check.tscn` and `res://tests/anim_check.tscn` (and `python3 godot/tools/art/test_magenta_key.py` and `test_eight_dir.py` after art tool changes) before pushing. Test headless, check layout changes with a 1920x1080 screenshot, and say that it was not checked on a real display. The game targets a 16:9 desktop screen, not phones.
- New character sheets from the owner: follow `.claude/skills/add-character-sheet/SKILL.md`; `bash godot/tools/art/build_characters.sh` rebuilds all characters. Do not spend time tuning the colour-look recolors.
- Never use `pkill -f`.
