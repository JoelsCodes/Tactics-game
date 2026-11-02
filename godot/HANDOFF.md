# Hand-off (Oct 30 2026)

Where the work stands after the last session, for the next one. Read with `CLAUDE.md` and `godot/README.md`.

## How the owner works
- **Commit and push finished work** (the owner dropped the old "only when I say push" rule in Nov 2026). The stop hook asks for a commit after every turn.
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
Play starts the opening (reworked Nov 2026), all in `scenes/` and `scripts/stage/`:
1. `intro.tscn` (forest): two lines of narration, then Alaric (the King unit is called **Alaric** now) runs from the squires, is hurt and weak (stumbles, slumps, limps), and goes into the ruins; a squire says "I smell a hurt rat, I think he went in there!". Then
2. `hallway.tscn`: Alaric limps in; a squire appears at the entrance ("Here by the hallway!"), lunges; he hops back, leaps in and slashes, pushing it 3 tiles back. Then
3. **First battle** (`FirstBattle.setup`): Alaric alone at level 1, **Rook weapon style**, vs one squire (basic attack only), no summoning. A win (Continue) leads to
4. `hallway_return.tscn`: Alaric slumped, iron boots sound, he limps to the far doors. Then
5. `chamber.tscn` (map `samples/ruins_chamber.json`): he enters the dead-end room, slumps by the altar, his bleeding hand falls on it, a flash, Bram and Lyra step out; the owner's dialogue (word for word); they dissolve, two squires walk in. Then
6. **Chamber battle** (`FirstBattle.chamber_setup`): Alaric vs two squires with two summon stones and `BattleTutorial` hints (summon Bram and Lyra). A win leads to
7. `base.tscn`: Alaric, Bram and Lyra talk about making the chamber the base (**dialogue drafted by Claude, the owner has not seen it**); the story opens the riverbank. Then
8. `world_map.tscn`: the world map (below). The base is a place on it.

Drafted by Claude, not by the owner (ask before keeping): the narration lines (intro and return scenes, "There was nowhere left to run.", the boots line), the base dialogue, the tutorial hint texts, Bram's and Lyra's skills and numbers (`FirstBattle.bram()` / `lyra()`), the summon stone relic.

## The world map and the base (Nov 2026)
- `WorldData` (`scripts/world/world_data.gd`) lists the places and their maps and levels; `CampaignState.areas_unlocked` and `map_records` (saved by `SaveCodec`) hold the progress. Places: the Hollow Base, the Ruined Keep (maps: hallway, chamber), Riverbank (map: the crossing, 3 levels, a placeholder using the sample fight), and two fogged unknown places (Thornmoor, Saltglass Coast: placeholders). **The place and map names, the blurbs and the level names are Claude's placeholders.**
- Unlocking: clearing the hallway opens the keep, clearing the chamber opens the base, the base conversation opens the riverbank (`WorldData.UNLOCKED_BY_CLEARING`, `BaseCutscene`). A story map can be played from the world map only once the story cleared it.
- First play of a map writes down the party's levels (`record_first_play`, done by `BattleStage`). A replay (`WorldData.game_for`) is a copy of the game with each unit at those levels, vessels that were not there left out, no story beats or tutorial, and nothing it earns is kept or saved (`BattleSetup.replay`). The enemies are the map's own set; **randomised enemies are left for later**. What "picks a level" means is my reading: each map has numbered levels (battles); the story maps have one, the crossing has three (stronger foes).
- `WorldMapScreen` / `WorldMapArt`: the chart is drawn in code (sea, islands, routes, fog): **procedural placeholder art**, no art was supplied; the owner may send their own map.
- `BaseArea` (`scenes/base_area.tscn`, `samples/base.json`, made by `tools/make_base_map.py`): **30x30** (the owner asked for it after seeing 15x15), free movement (WASD / arrows, Shift runs, click walks along a path, E uses things). The altar opens the barracks, the gate the world map; Bram and Lyra talk (**lines drafted by Claude**). The camera follows Alaric here only (the owner's choice, same lens/angle/distance, stops at the map's edges: `Board3D.follow`). The barracks has a Base button back.
- `GameSession` holds the game across scenes.

A lost story battle restarts (Try again). Story battles are built with `BattleSetup` (`on_win` names the next scene, `tutorial` shows the hints); scenes extend `Cutscene3D`.

## Characters
King (Alaric), Lyra (sheet id `mira`), Vesper, Ashen Squire, Hollow Choir, Lantern Wraith, Sorceress (`sorc`), Bram (sheet id `warden`, renamed from Warden), Shade, Lancer, Blade; enemies Robin and the Red Wolf (`UnitLook.ENEMY_CHARACTERS`; in the sample fight). New four-direction idle/walk: King, Lyra, Squire, Sorceress, Bram, Robin, Red Wolf. Vesper, Choir, Wraith and the placeholder vessels still use their older, slightly taller sheets.

## Maps and tiles
- `samples/intro_forest.json` (opening forest), `samples/intro_ruins.json` (the 8x10 abandoned castle hallway the opening uses), `samples/abandoned_hallway.json` (the same hallway saved as a replayable map; **the owner will say what it is for**), `samples/demo_battlefield.json` (sample fight from the barracks).
- Abandoned castle tiles (`tools/art/castle_tiles.py`, from `art_src/tiles/abandoned_castle_*.jpg`): `f` floor (one slab, the owner's choice), `h` overgrown, `e` carved, `o` framed, `q` brick wall.
- The ruins maps (hallway, chamber) use the default gradient backdrop now; the castle around the hallway was dropped (`outside_castle.gd` is unused). Maps may still set `"backdrop": "radial_black"` or `"sky"`.
- **Cutaway rim:** every map's outer edge shows a cross-section 2.6 units deep (soil, masonry or bedrock bands, `Board3D._cutaway`).
- **Spacing:** every battle starts with nobody in reach of anybody on turn one (`tests/spacing_check.gd`). The hallway fight starts 7 tiles apart (the slash drives the squire 6 tiles back), the chamber 9+, the sample fight 9+.

## Open questions for the owner
- What comes after the base conversation (it goes to the barracks now), (Lyra is a vessel now; the sample party's first Co-Captain is a placeholder Sorceress).
- What `abandoned_hallway.json` is for.
- Whether the barracks is the base screen the conversation points to (the base scene ends in it).

## Tests
The 15 scenes listed in `CLAUDE.md` (including `intro_check`, `hallway_check` and `chamber_check`) all pass headless; the two art tests were not touched.
