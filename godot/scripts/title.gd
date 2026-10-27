extends Control
## Title screen: logo, the three heroes, and the story missions. The campaign
## (map, shop, clan) is not ported yet, so each mission starts with the default clan.

const HERO_SPOTS := [["cardmage", -.30, 1.0], ["hero", 0.0, 1.15], ["demon", .30, 1.0]]

var _heroes: Array = []


func _ready() -> void:
	var col: VBoxContainer = %Column
	var logo := Label.new()
	logo.text = "HOLLOWMARK"
	logo.theme_type_variation = "TitleLabel"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(logo)
	var sub := Label.new()
	sub.text = "T A C T I C S"
	sub.theme_type_variation = "HeaderLabel"
	sub.add_theme_font_size_override("font_size", 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 230)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	var head := Label.new()
	head.text = "Story missions"
	head.theme_type_variation = "SectionLabel"
	col.add_child(head)
	for i in Data.MISSIONS.size():
		var ms: Dictionary = Data.MISSIONS[i]
		var stage := i
		var law := "Ban %s  ·  Favor %s" % [Data.LAWS[ms.law.ban].name, Data.LAWS[ms.law.fav].name]
		col.add_child(Hud.ListRow.make({"name": ms.name, "cost": "Lv %d" % (1 + i * 2),
			"desc": "%s\n%s  ·  %s  ·  %d units" % [ms.brief, Data.MAPS[ms.map].name, law, ms.deploy], "cb": func(): _start(stage)}, func(_t): pass))
	var tip := Label.new()
	tip.text = "Tap Move, then a blue tile. Act opens your abilities; tap a target twice to confirm. Drag to pan, pinch to zoom, use the side buttons to rotate."
	tip.theme_type_variation = "SmallLabel"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tip)
	for spec in HERO_SPOTS:
		var s := AnimatedSprite2D.new()
		s.sprite_frames = load("res://assets/characters/%s.tres" % spec[0])
		var meta := Looks.meta(spec[0])
		s.offset = Vector2(0, meta.size[1] / 2.0 - meta.anchor[1])
		s.scale = Vector2.ONE * spec[2]
		s.flip_h = spec[0] == "demon"
		s.play("idle")
		s.set_frame_and_progress(randi() % 2, randf())
		$Heroes.add_child(s)
		_heroes.append([s, spec])
	resized.connect(_place)
	_place()


func _place() -> void:
	for h in _heroes:
		h[0].position = Vector2(size.x * (.5 + h[1][1]), 330)


func _process(_d: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in _heroes.size():
		_heroes[i][0].position.y = 330 + sin(t * 1.6 + i) * 2.0


func _start(stage: int) -> void:
	var Battle = load("res://scripts/battle.gd")
	Battle.stage = stage
	get_tree().change_scene_to_file("res://scenes/battle.tscn")
