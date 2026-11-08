class_name GameSession
extends RefCounted
## The game being played across scenes: the story, the world map, the base and the barracks all use `current()`. A story
## battle sets it when it starts; a fresh run of a scene on its own (tests, a scene opened from the editor) loads the newest
## save, or starts the story's party with nothing unlocked.

static var game: SaveGame


static func current() -> SaveGame:
	if game == null:
		var newest := SaveSystem.newest_slot()
		if newest != "":
			var r := SaveSystem.load_slot(newest)
			if r.ok:
				game = r.game
		if game == null:
			game = FirstBattle.chamber_game(FirstBattle.game())
	return game


## Saves the current game into the autosave slot. Returns the result (a failed write keeps the previous autosave whole: SaveSystem writes a
## temporary file and swaps it in), and warns when it fails.
static func autosave() -> Error:
	if game == null:
		return ERR_UNCONFIGURED
	var err := SaveSystem.save_slot(SaveSystem.AUTOSAVE, game)
	if err != OK:
		push_warning("Autosave failed: %s" % error_string(err))
	return err
