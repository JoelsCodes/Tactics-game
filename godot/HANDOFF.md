# Hand-off (Oct 30 2026)

Where the work stands after the last session, for the next one. Read with `CLAUDE.md` and `godot/README.md`.

## How the owner works
- **Commit and push only when the owner says "push".** The stop hook asks for a commit after every turn; answer it in one line, do not commit.
- The owner sends art as chat images and asks for screenshots often: use `bash godot/tools/shots.sh` (intro, hallway, return, first, second, battle, nearfar) and send the frames. Say each time that it was not checked on a real display.
- Show the result before moving on; keep replies short and plain.

## Rules the owner set this session (do not undo)
- **Four directions only** (down, right, up, left). Diagonal frames are never used.
- **Every character is as tall as the King** (`idle_walk_sheet.STANDARD_FIGURE`, 120 px). New idle/walk sheets go through `idle_walk_sheet.build`.
- **The King's colours are never edited.** Colour variations are removed for good: do not cut, bake or offer them.
- **The camera is locked**: one lens (28 degrees), angle (-50), distance (`Board3D.CAMERA_DISTANCE`, 36) and framing (`BattleStage.lock_camera`) in scenes and battles. No pan, follow, zoom or rotate. Maps must fit the view.
- **No flat cut-out props on the 3D board**: the owner found them fake. The prop catalogue (`assets/props/`, `tools/art/props.py`, `PropView3D`) exists but no map uses it.
- **Tile art should come as cubes** (one cube per piece). Isometric arches, stairs and statues are not used as terrain.
- The owner writes the story and the dialogue; use their lines word for word.

## The game now
Play starts the opening, all in `scenes/` and `scripts/stage/`:
1. `intro.tscn` (forest): the King walks to the ruins, two Ashen Squires follow; after "I smell a hurt rat, I think he went in there!" it fades slowly into
2. `hallway.tscn`: the King walks in; a squire appears at the entrance ("Here by the hallway!"), lunges; the King hops back, leaps in and slashes, pushing it 3 tiles back. Then
3. **First battle** (`FirstBattle.setup`): the King alone at level 1 vs one squire (basic attack only), no summoning, no summon stones. A win (Continue) leads to
4. `hallway_return.tscn`: the King runs in, walks to the middle ("I will not falter here"); two squires come in, one steps forward ("You stop!"). Then
5. **Second battle** (`FirstBattle.second_setup`): the King as the first battle left him vs two squires. **Nothing comes after it yet**: a win goes back to the barracks. Ask the owner what is next.

A lost story battle restarts (Try again). Story battles are built with `BattleSetup` (`on_win` names the next scene); scenes extend `Cutscene3D`.

## Characters
King (Aldric), Lyra (sheet id `mira`), Vesper, Ashen Squire, Hollow Choir, Lantern Wraith, Sorceress (`sorc`), Bram (sheet id `warden`, renamed from Warden), Shade, Lancer, Blade; enemies Robin and the Red Wolf (`UnitLook.ENEMY_CHARACTERS`; in the sample fight). New four-direction idle/walk: King, Lyra, Squire, Sorceress, Bram, Robin, Red Wolf. Vesper, Choir, Wraith and the placeholder vessels still use their older, slightly taller sheets.

## Maps and tiles
- `samples/intro_forest.json` (opening forest), `samples/intro_ruins.json` (the 8x10 abandoned castle hallway the opening uses), `samples/abandoned_hallway.json` (the same hallway saved as a replayable map; **the owner will say what it is for**), `samples/demo_battlefield.json` (sample fight from the barracks).
- Abandoned castle tiles (`tools/art/castle_tiles.py`, from `art_src/tiles/abandoned_castle_*.jpg`): `f` floor (one slab, the owner's choice), `h` overgrown, `e` carved, `o` framed, `q` brick wall.
- Maps may set `"backdrop": "radial_black"` (the hallway does).

## Open questions for the owner
- What happens after the second battle.
- What `abandoned_hallway.json` is for.
- Whether the barracks should be reachable from the story (nothing leads to it now except a win of the second battle).

## Tests
The 13 scenes listed in `CLAUDE.md` (including `intro_check` and `hallway_check`) and the two art tests all passed at the last push (`b4470e3`).
