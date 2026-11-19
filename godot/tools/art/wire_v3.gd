extends SceneTree
## Rebuilds assets/characters/alaric_v3.tres and the "alaric_v3" entry of assets/characters/meta.json (replaced in place, inserted before "alaric_v2" the
## first time; nothing else in the file is touched). Run after tools/art/build_v3_from_strip.gd (idle) and any tools/art/cut_anim_v3.gd, and a Godot --import.
## An animation listed in assets/characters/alaric_v3/anims.json uses its own frames; every other alaric_v2 animation shows its direction's idle pose.
const ROOT := "res://assets/characters/"
const SCALE := 1.15  ## sprite scale in meta: 1 sheet pixel is about one screen pixel at 1080p with the 45 degree lens


func _dir_of(anim: String) -> String:
	var d := anim.get_slice("_", anim.get_slice_count("_") - 1)
	return {"f": "s", "b": "n"}.get(d, d)


func _base_of(anim: String) -> String:
	return anim.substr(0, anim.length() - _dir_of(anim).length() - 1) if anim.find("_") >= 0 else anim


## [frame textures, frame paths relative to the sheet] for one animation name.
func _frames_of(anim: String, cfg: Dictionary) -> Array:
	var d := _dir_of(anim)
	var tex := []
	var paths := []
	var base := _base_of(anim)
	if cfg.has(base):
		for i in int(cfg[base]["frames"]):
			var p := "animations/%s/%s_%s_%d.png" % [base, base, d, i]
			tex.append(load(ROOT + "alaric_v3/" + p))
			paths.append(p)
	else:
		var p := "animations/idle/idle_%s_0.png" % d
		tex.append(load(ROOT + "alaric_v3/" + p))
		paths.append(p)
	return [tex, paths]


func _init() -> void:
	var cfg_path := ProjectSettings.globalize_path(ROOT + "alaric_v3/anims.json")
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
		var base := _base_of(a)
		sf.add_animation(a)
		sf.set_animation_speed(a, float(cfg[base]["fps"]) if cfg.has(base) else v2.get_animation_speed(a))
		sf.set_animation_loop(a, bool(cfg[base]["loop"]) if cfg.has(base) else v2.get_animation_loop(a))
		for t in fr[0]:
			sf.add_frame(a, t)
	ResourceSaver.save(sf, ROOT + "alaric_v3.tres")
	var path := ProjectSettings.globalize_path(ROOT + "meta.json")
	var text := FileAccess.get_file_as_string(path)
	var all: Dictionary = JSON.parse_string(text)
	var m: Dictionary = all["alaric_v2"].duplicate(true)
	m["size"] = [128, 128]
	m["anchor"] = [64, 112]
	m["scale"] = SCALE
	for k in m["anims"]:
		var an: Dictionary = m["anims"][k]
		var base := _base_of(k)
		var fr := _frames_of(k, cfg)
		an["frames"] = fr[1]
		if cfg.has(base):
			an["fps"] = cfg[base]["fps"]
			an["loop"] = cfg[base]["loop"]
			if cfg[base].has("strike"):
				an["strike"] = cfg[base]["strike"]
			elif an.has("strike"):
				an["strike"] = mini(int(an["strike"]), fr[1].size() - 1)
		elif an.has("strike"):
			an["strike"] = 0
	var block := JSON.stringify({"alaric_v3": m}, "  ")
	block = block.substr(1, block.length() - 2).strip_edges(true, true)
	var old_start := text.find("\n  \"alaric_v3\": {")
	var anchor := "\n  \"alaric_v2\": {"
	var at := text.find(anchor)
	if old_start >= 0 and old_start < at:
		text = text.erase(old_start + 1, at - old_start)  # drop the previous v3 block (up to the v2 line)
		at = text.find(anchor)
	text = text.insert(at + 1, "  " + block + ",\n")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("wired alaric_v3 (", cfg.keys(), ")")
	quit(0)
