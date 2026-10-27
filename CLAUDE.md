# Hollowmark Tactics: notes for Claude

Two versions of one game live in this repo, but **only the Godot version is worked on now**:

- **Godot 4 port** (`godot/`), branch `claude/godot-port`. It is the source of truth for data and rules (`godot/data/game_data.json`, `godot/scripts/rules.gd`). **Read `godot/README.md` first**, including its "Notes for the next session" section.
- **Web version** (repo root: `index.html`, `js/`, `tests/`) is frozen. Do not edit it.

## Before you start
- Ask the owner which version to work on and what the next milestone is (the questions are listed in `godot/README.md`).
- Do not build visuals before the owner has supplied art or a reference. Do not build tooling before confirming which game and repo it is for.
- Keep the session to one milestone. Use small edits, not whole-file rewrites, and look at few, small screenshots.

## Working rules
- Commit and push every change. Commit messages end with the attribution trailers given in the session reminder.
- Edit Godot files directly: data in `godot/data/game_data.json`, rules in `godot/scripts/rules.gd`. Do not run `export_data.js` or `js_trace.js` (they are retired and would overwrite Godot's data). Run the Godot tests (`godot --headless --path godot res://tests/run_tests.tscn`). The six battles in `godot/tests/fixtures/` are now frozen regression traces: if a deliberate rules change alters them, re-record them from the Godot rules rather than from JS.
- Do not change how the game plays (rules, balance, AI) without the owner's approval. The Lullaby AI-vs-AI stalemate is known and left as is.
- Test headless and say that it was not checked on a real phone.
