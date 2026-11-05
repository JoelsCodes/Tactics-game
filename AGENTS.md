# Hollowmark Tactics: notes for any coding agent (ChatGPT, Claude)

The game is in `godot/` (Godot 4.3+), branch `claude/godot-port`, repo `JoelsCodes/tactics-game`. Claude and ChatGPT both work on it.

## Read first
1. `CLAUDE.md` (root): the owner's design rules and working rules. **They apply to every agent, not just Claude.** Do not undo a rule listed under "Design rules the owner has set"; ask the owner first.
2. `godot/HANDOFF.md`: where the last session left off, including what each agent changed and what is not yet tested.
3. `godot/README.md`: how the game is built.

## Working together on one branch
- `git pull --ff-only origin claude/godot-port` before you start and again before you push. The other agent may have pushed.
- Small, focused commits; say in the message what changed. Do not rewrite or force-push the other agent's history.
- Add a short note under your own heading in `godot/HANDOFF.md` for anything the other agent should know (what changed, what you tested, what you did not). Never write that something is tested unless you ran it.
- Do not change the same file area as the other agent without reading their latest commits first.

## Before you push
- Set up Godot and import the project as described in `CLAUDE.md` ("Starting a session").
- Parse-check every GDScript file you edit: `godot --headless --path godot --check-only --script res://path/to/file.gd`. A file that does not parse breaks every scene that uses it (a `var x := ...` the engine cannot infer the type of did exactly that).
- Run the headless test scenes listed in `CLAUDE.md` ("Working rules") that cover what you touched, or all of them for anything under `scripts/` that more than one screen uses. Add or update a test for a new rule.
- Look at a 1920x1080 screenshot (`bash godot/tools/shots.sh ...`) for any change you can see. Say the result was not checked on a real display.
- Speed-ups need a measurement; a change that only "should" be faster is not a result.

## Always
- Never use `pkill -f` or `kill $(pgrep -f ...)` (it kills the shell).
- Do not build visuals before the owner has supplied art or a reference; show the owner before big visual changes.
- Commit trailers: each agent uses its own attribution lines (see its session instructions).
