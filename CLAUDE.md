# Hollowmark Tactics: notes for Claude

**Fresh start (Oct 2026).** The owner had everything from the first build deleted: battle system, rules, classes, maps, menus, campaign and the web version. Only the art and how it is placed are kept. The old code is in git history (`202b479` and before); do not restore any of it unless the owner asks.

Work is in `godot/` (Godot 4.3+), branch `claude/godot-port`. **Read `godot/README.md` first.**

## Before you start
- Ask the owner what to build next. There is no game design in the repo now; do not assume the old one.
- Do not build visuals before the owner has supplied art or a reference.
- Keep the session to one milestone. Use small edits, not whole-file rewrites, and look at few, small screenshots.

## Working rules
- Commit and push every change. Commit messages end with the attribution trailers given in the session reminder.
- New terrain or biomes follow the terrain standard in `godot/README.md` (seamless baked tops, wrapping side strips, smooth hills by default).
- Run `godot --headless --path godot res://tests/check.tscn`, `res://tests/core_check.tscn` , `res://tests/board_check.tscn` , `res://tests/units_check.tscn` and `res://tests/mentorship_check.tscn` before pushing. Test headless and say that it was not checked on a real phone.
- Never use `pkill -f`.
