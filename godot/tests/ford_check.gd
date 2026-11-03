extends Node
## Headless: the Riverbank level 1 story scene (FordCutscene) plays to its end in the 19x19 town (villagers and the mechanic run about, Merc
## and Vesper with two squires behind, the owner's lines word for word, Vesper steps forward, Merc steps back and walks off and vanishes,
## Vesper sends the squires after Merc); the world map plays it only the first time level 1 of the Ford is picked, after which the battle
## loads (a squire, two Eaters and a Boar).
## godot --headless --path godot res://tests/ford_check.tscn
var fails := 0
var count := 0
var done := false
var beats: Array[String] = []
var said := {}  ## beat -> [speaker, line] shown a moment after it


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func _ready() -> void:
	# the world map plays the scene once
	var c := CampaignState.new()
	c.unlock_area(&"riverbank")
	ok(WorldData.cutscene_for(c, "ford", 1) == "res://scenes/ford_intro.tscn", "the first time the Ford's level 1 is picked, the scene plays")
	ok(WorldData.cutscene_for(c, "mill", 1) == "" and WorldData.cutscene_for(c, "ford", 2) == "", "no other map or level has one")
	ok(WorldData.map_state(c, "ford") == "mission", "the Ford is startable")
	Engine.time_scale = 4.0
	var game := FirstBattle.chamber_game(FirstBattle.game())
	game.campaign.unlock_area(&"riverbank")
	GameSession.game = game
	Cutscene3D.carried_game = game
	var s: FordCutscene = load("res://scenes/ford_intro.tscn").instantiate()
	s.go_on = false
	add_child(s)
	s.finished.connect(func(): done = true)
	s.beat.connect(func(b):
		beats.append(b)
		await get_tree().create_timer(0.4).timeout
		if is_instance_valid(s):
			said[b] = [s.speaker.text, s.line.text])
	ok(s.board.map.w == 19 and s.board.map.d == 19, "the town is 19x19")
	ok(s.merc.char_name == "merc" and s.vesper.char_name == "vesper" and s.squires.size() == 2, "Merc, Vesper and two squires")
	ok(s.merc.position.is_equal_approx(s.board.top_point(9, 8)) and s.vesper.position.is_equal_approx(s.board.top_point(9, 10)), "Merc and Vesper two tiles apart in the middle")
	ok(s.squires.all(func(q): return q.position.z > s.vesper.position.z), "the squires stand behind Vesper, farther from Merc")
	ok(s.folk.size() == 6 and s.folk.filter(func(v): return v.char_name == NpcLook.MECHANIC).size() == 1 and s.folk.filter(func(v): return NpcLook.is_npc(v.char_name)).size() == 6, "four villagers, a second kid and the mechanic")
	var starts: Array[Vector3] = []
	for v in s.folk:
		starts.append(v.position)
	var waited := 0.0
	var moved := 0
	var running := false
	while not done and waited < 160.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
		if waited > 6.0 and moved == 0:
			for i in s.folk.size():
				if s.folk[i].position.distance_to(starts[i]) > 0.5:
					moved += 1
			for v in s.folk:
				running = running or String(v.sprite.animation).begins_with("run")
	Engine.time_scale = 1.0
	ok(done, "the scene reaches its end (%.1fs)" % waited)
	ok(moved >= 5 and running, "the townsfolk run about (%d moved, running %s)" % [moved, running])
	ok(beats == ["start", "merc1", "merc2", "merc3", "step", "merc4", "vesper2", "back", "leaves", "gone", "orders", "end"], "its steps in order (%s)" % [beats])
	ok(said.get("merc1", []) == ["MERC", "I saw it. We gathered resources for the little village and your men just burned it for no good reason!"], "Merc's first line, word for word (%s)" % [said.get("merc1")])
	ok(said.get("merc2", []) == ["MERC", "We have raised hundreds to gather supplies to bring to all these places and for what!"], "Merc continues (%s)" % [said.get("merc2")])
	ok(said.get("merc3", []) == ["MERC", "Not even the best we had was good enough to rescue one person!"], "and again (%s)" % [said.get("merc3")])
	ok(said.get("step", []) == ["VESPER", "Now now, we can help you find new people to support. Why, the world is a place full of those who need help."], "Vesper after her step forward (%s)" % [said.get("step")])
	ok(said.get("merc4", []) == ["MERC", "I must have lost myself for a second there, apologies. I have just never seen so many bodies in my life."], "Merc's apology (%s)" % [said.get("merc4")])
	ok(said.get("vesper2", [""])[1].begins_with("Yes that must be a terrible sight") and said["vesper2"][1].ends_with("new trading route?"), "Vesper's offer (%s)" % [said.get("vesper2")])
	ok(said.get("back", [""])[1].begins_with("Actually I've already embarrassed myself enough.") and said["back"][1].ends_with("misunderstanding."), "Merc's leave (%s)" % [said.get("back")])
	ok(said.get("orders", []) == ["VESPER", "Oliver wouldn't want to have this news spread. Follow him and solve the issue."], "Vesper's order (%s)" % [said.get("orders")])
	ok(s.vesper.position.is_equal_approx(s.board.top_point(9, 9)), "Vesper took one step forward, onto the medallion")
	ok(not s.merc.visible and s.merc.get_alpha() < 0.01, "Merc walked away and vanished")
	ok(s.squires.all(func(q): return q.position.distance_to(s.board.top_point(8, 11)) > 1.0 and q.position.distance_to(s.board.top_point(10, 11)) > 1.0), "the squires set off after Merc")
	ok(game.campaign.is_scene_seen(&"ford_intro"), "the scene marks itself seen")
	ok(WorldData.cutscene_for(game.campaign, "ford", 1) == "", "so the next pick loads the level")
	var back := SaveCodec.decode(SaveCodec.encode(game))
	ok(back.ok and back.game.campaign.is_scene_seen(&"ford_intro"), "and it is saved")
	s.queue_free()
	# the level that loads: a squire, two Eaters and a Boar
	var setup := WorldData.setup_for("ford", 1, false)
	var names: Array = setup.enemies.map(func(e): return e[0].display_name)
	names.sort()
	ok(names == ["Boar", "Eater", "Eater", "Ashen Squire"] or names == ["Ashen Squire", "Boar", "Eater", "Eater"], "the Ford's foes: a squire, two Eaters and a Boar (%s)" % [names])
	var look := EnemyData.new()
	look.display_name = "Eater"
	ok(UnitLook.sheet_for(look) == "eater", "an Eater is drawn with the slime")
	look.display_name = "Boar"
	ok(UnitLook.sheet_for(look) == "boar", "a Boar with the boar")
	print("ford checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)
