# Hollowmark Tactics: notes for Claude

Two versions of one game live in this repo:

- **Web version** (repo root): vanilla JS, no build step. `index.html`, `js/`, tests in `tests/`. Run `node tests/engine.test.js`. It is the source of truth for game data and rules.
- **Godot 4 port** (`godot/`): in progress on branch `claude/godot-port`. **Read `godot/README.md` first**, including its "Notes for the next session" section, before doing any work there.

## Before you start
- Ask the owner which version to work on and what the next milestone is (the questions are listed in `godot/README.md`).
- Do not build visuals before the owner has supplied art or a reference. Do not build tooling before confirming which game and repo it is for.
- Keep the session to one milestone. Use small edits, not whole-file rewrites, and look at few, small screenshots.

## Working rules
- Commit and push every change. Commit messages end with the attribution trailers given in the session reminder.
- Rule or data changes: edit `js/` first, then run `node godot/tools/export_data.js` and, for engine changes, `node godot/tools/js_trace.js`, then the Godot tests (`godot --headless --path godot res://tests/run_tests.tscn`). The six replayed battles must still match.
- Do not change how the game plays (rules, balance, AI) without the owner's approval. The Lullaby AI-vs-AI stalemate is known and left as is.
- Test headless and say that it was not checked on a real phone.
