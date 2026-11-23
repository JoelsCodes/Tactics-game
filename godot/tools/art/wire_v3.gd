extends SceneTree
## Rebuilds assets/characters/<sheet>.tres and the "<sheet>" entry of assets/characters/meta.json for a 4x-master sheet (`alaric_v3` unless a sheet name
## is given: `godot --headless --path godot --script res://tools/art/wire_v3.gd -- [sheet name]`; replaced in place, inserted before "alaric_v2" the
## first time; nothing else in the file is touched). Run after tools/art/build_v3_from_strip.gd (idle) and any tools/art/cut_anim_v3.gd, and a Godot --import.
## An animation listed in assets/characters/<sheet>/anims.json uses its own frames; run and dash borrow the walk cycle, played faster (BORROW), until
## they have sheets of their own; every other alaric_v2 animation shows its direction's idle pose. A sheet other than alaric_v3 (Rex, Nov 2026) takes
## alaric_v2's animation list and meta with only its own portrait (portraits/portrait_01.png, when there is one) and no expressions.
const ROOT := "res://assets/characters/"
var sheet := "alaric_v3"
const SCALE := 1.15  ## sprite scale in meta: 1 sheet pixel is about one screen pixel at 1080p with the 45 degree lens
const BORROW := {"run": ["walk", 12.0], "dash": ["walk", 14.0]}  ## stand-in: animation -> [its source in anims.json, fps]


func _dir_of(anim: String) -> String:
	var d := anim.get_slice("_", anim.get_slice_count("_") - 1)
	return {"f": "s", "b": "n"}.get(d, d)


## The anims.json entry an animation draws from: its own, or the one it borrows.
func _src_of(base: String, cfg: Dictionary) -> String:
	if not cfg.has(base) and BORROW.has(base) and cfg.has(BORROW[base][0]):
		return BORROW[base][0]
	return base


func _base_of(anim: String) -> String:
	return anim.substr(0, anim.length() - _dir_of(anim).length() - 1) if anim.find("_") >= 0 else anim


## [frame textures, frame paths relative to the sheet] for one animation name.
func _frames_of(anim: String, cfg: Dictionary) -> Array:
	var d := _dir_of(anim)
	var tex := []
	var paths := []
	var base := _src_of(_base_of(anim), cfg)
	if cfg.has(base):
		for i in int(cfg[base]["frames"]):
			var p := "animations/%s/%s_%s_%d.png" % [base, base, d, i]
			tex.append(load(ROOT + sheet + "/" + p))
			paths.append(p)
	else:
		var p := "animations/idle/idle_%s_0.png" % d
		tex.append(load(ROOT + sheet + "/" + p))
		paths.append(p)
	return [tex, paths]


func _init() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		sheet = OS.get_cmdline_user_args()[0]
	var cfg_path := ProjectSettings.globalize_path(ROOT + sheet + "/anims.json")
	var cfg := {}
	if FileAccess.file_exists(cfg_path):
		cfg = JSON.parse_string(FileAccess.get_file_as_string(cfg_path))
	var v2 := load(ROOT + "alaric_v2.tres") as SpriteFrames
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for a in v2.get_animation_names():
		var fr := _frames_of(a, cfg)
		if fr[0].has(null):
			push_error("import the frames first (%s)" % a)
			quit(1)
			return
		var own := _base_of(a)
		var base := _src_of(own, cfg)
		sf.add_animation(a)
		var fps := float(BORROW[own][1]) if base != own else (float(cfg[base]["fps"]) if cfg.has(base) else v2.get_animation_speed(a))
		sf.set_animation_speed(a, fps)
		sf.set_animation_loop(a, bool(cfg[base]["loop"]) if cfg.has(base) else v2.get_animation_loop(a))
		for t in fr[0]:
			sf.add_frame(a, t)
	ResourceSaver.save(sf, ROOT + sheet + ".tres")
	var path := ProjectSettings.globalize_path(ROOT + "meta.json")
	var text := FileAccess.get_file_as_string(path)
	var all: Dictionary = JSON.parse_string(text)
	var m: Dictionary = all["alaric_v2"].duplicate(true)
	m["size"] = [128, 128]
	m["anchor"] = [64, 112]
	m["scale"] = SCALE
	for k in m["anims"]:
		var an: Dictionary = m["anims"][k]
		var own := _base_of(k)
		var base := _src_of(own, cfg)
		var fr := _frames_of(k, cfg)
		an["frames"] = fr[1]
		if cfg.has(base):
			an["fps"] = BORROW[own][1] if base != own else cfg[base]["fps"]
			an["loop"] = cfg[base]["loop"]
			if cfg[base].has("strike"):
				an["strike"] = cfg[base]["strike"]
			elif an.has("strike"):
				an["strike"] = mini(int(an["strike"]), fr[1].size() - 1)
		elif an.has("strike"):
			an["strike"] = 0
	if sheet != "alaric_v3":  # its own portrait when it has one (portraits/portrait_01.png), no expressions
		for k in ["portrait", "portraits", "portrait_names"]:
			m.erase(k)
		if ResourceLoader.exists(ROOT + sheet + "/portraits/portrait_01.png"):
			m["portrait"] = "portraits/portrait_01.png"
			m["portraits"] = ["portraits/portrait_01.png"]
	var block := JSON.stringify({sheet: m}, "  ")
	block = block.substr(1, block.length() - 2).strip_edges(true, true)
	var old_start := text.find("\n  \"%s\": {" % sheet)
	if old_start >= 0:  # drop the previous block (up to the next top-level entry)
		var next := text.find("\n  \"", old_start + 1)
		text = text.erase(old_start + 1, next - old_start)
	var at := text.find("\n  \"alaric_v2\": {")
	text = text.insert(at + 1, "  " + block + ",\n")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("wired ", sheet, " (", cfg.keys(), ")")
	quit(0)
