class_name SaveSystem
extends RefCounted
## Save files: one JSON file per slot in `dir` (user://saves by default). Writes are safe against a
## crash halfway: the new data goes to a temporary file first, the previous save is kept as `.bak`,
## and a save that cannot be read falls back to that backup.

const AUTOSAVE := "autosave"

## Where saves live. Tests point this somewhere else.
static var dir := "user://saves"


## Slot names are short and plain, so they can never point outside the save folder.
static func valid_slot(slot: String) -> bool:
	if slot.is_empty() or slot.length() > 32:
		return false
	for c in slot:
		if not (c >= "a" and c <= "z" or c >= "0" and c <= "9" or c == "_" or c == "-"):
			return false
	return true


static func path(slot: String) -> String:
	return "%s/%s.json" % [dir, slot]


static func exists(slot: String) -> bool:
	return valid_slot(slot) and FileAccess.file_exists(path(slot))


## Saves `game` into `slot`. `saved_at` is the time to stamp (0 = now). Returns OK or an error.
static func save_slot(slot: String, game: SaveGame, saved_at := 0) -> Error:
	if not valid_slot(slot):
		return ERR_INVALID_PARAMETER
	game.saved_at = saved_at if saved_at > 0 else int(Time.get_unix_time_from_system())
	var err := DirAccess.make_dir_recursive_absolute(dir)
	if err != OK:
		return err
	var final := path(slot)
	var tmp := final + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(SaveCodec.encode(game), "\t", true))
	err = f.get_error()
	f.close()
	if err != OK:
		DirAccess.remove_absolute(tmp)
		return err
	if FileAccess.file_exists(final):
		DirAccess.remove_absolute(final + ".bak")
		DirAccess.rename_absolute(final, final + ".bak")
	return DirAccess.rename_absolute(tmp, final)


## Loads a slot. If the file cannot be read or understood, tries the backup.
static func load_slot(slot: String) -> SaveLoadResult:
	if not valid_slot(slot):
		return SaveLoadResult.new().fail("bad slot name '%s'" % slot)
	var main := path(slot)
	if not FileAccess.file_exists(main) and not FileAccess.file_exists(main + ".bak"):
		return SaveLoadResult.new().fail("no save in slot '%s'" % slot)
	var first := _read_file(main)
	if first.ok:
		return first
	var backup := _read_file(main + ".bak")
	if backup.ok:
		backup.from_backup = true
		return backup
	return first


static func delete_slot(slot: String) -> void:
	if valid_slot(slot):
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path(slot) + suffix):
				DirAccess.remove_absolute(path(slot) + suffix)


## Every slot with a readable save: {slot, saved_at, king, battles_won}, newest first.
static func slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".json"):
			continue
		var slot := file.get_basename()
		if not valid_slot(slot):
			continue
		var r := load_slot(slot)
		if r.ok:
			out.append({"slot": slot, "saved_at": r.game.saved_at, "king": r.game.roster.king.display_name,
				"battles_won": r.game.campaign.battles_won})
	out.sort_custom(func(a, b): return a.saved_at > b.saved_at)
	return out


## The most recently saved slot, or "".
static func newest_slot() -> String:
	var all := slots()
	return all[0].slot if not all.is_empty() else ""


static func _read_file(file_path: String) -> SaveLoadResult:
	if not FileAccess.file_exists(file_path):
		return SaveLoadResult.new().fail("file is missing")
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(file_path)) != OK or not json.data is Dictionary:
		return SaveLoadResult.new().fail("the save file is damaged (not valid JSON)")
	return SaveCodec.decode(json.data)
