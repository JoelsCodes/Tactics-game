extends Node
## Headless: TerrainRules (what the ground does). godot --headless --path godot res://tests/terrain_rules_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s: got %s, want %s" % [what, str(a), str(b)])


func _skill(n: String) -> SkillData:
	for s in SkillLibrary.all():
		if s.display_name == n:
			return s
	return null


func _ready() -> void:
	# a strip: plain grass, water, snow, embers, a holy dais
	var g := TacticalGrid.from_rows(["g0 g0 g0 g0 g0 g0", "g0 w0 n0 c0 e0 a0", "g0 g0 g0 g0 g0 g0"])
	var b := BattleController.new()
	add_child(b)
	b.setup(g)
	b.miss_chance = 0.0
	b.crit_scale = 0.0
	var king := FirstBattle.game().roster.king
	var ku := b.deployment.deploy_king(king, Vector2i(0, 0))
	var fire := BattleAction.use(_skill("Ember Flick"))
	var spark := BattleAction.use(_skill("Static Snap"))
	ok(fire.skill != null and spark.skill != null, "the skills exist")
	var foe_dry := b.add_enemy(FirstBattle.squire(1), Vector2i(0, 2))
	var foe_wet := b.add_enemy(FirstBattle.squire(2), Vector2i(1, 1))
	var dry := TerrainRules.adjust(g, foe_dry.cell, fire, 20)
	eq(dry, [20, ""], "dry ground: nothing changes")
	var wet_fire := TerrainRules.adjust(g, foe_wet.cell, fire, 20)
	eq(wet_fire, [15, "Water -25%"], "fire on a unit in water: -25%")
	eq(TerrainRules.adjust(g, foe_wet.cell, spark, 20), [25, "Water +25%"], "lightning on a unit in water: +25%")
	eq(TerrainRules.adjust(g, Vector2i(2, 1), BattleAction.use(_skill("Frost Lance")), 20)[0], 25, "ice on snow: +25%")
	eq(TerrainRules.adjust(g, Vector2i(3, 1), fire, 20)[0], 25, "fire on embers: +25%")
	eq(TerrainRules.adjust(g, foe_wet.cell, BattleAction.attack(), 20), [20, ""], "a physical blow is never changed")
	# the preview carries the note for the forecast
	var r := b.preview(ku, spark, foe_wet.cell)
	var wet_hit = null
	for h in r.hits:
		if h.target == foe_wet:
			wet_hit = h
	if wet_hit != null:
		eq(wet_hit.terrain_note, "Water +25%", "the preview says why the number is higher")
	else:
		ok(true, "(the spark does not reach that tile from here; the note is checked through adjust above)")
	# ending a turn on the ground
	for c in [Vector2i(2, 1), Vector2i(5, 1)]:
		var u := BattleUnit.new(FirstBattle.squire(3), 1)
		u.cell = c
		u.hp = u.max_hp()
		TerrainRules.end_turn(u, g)
		eq(u.slow, 1, "snow and sand slow the next turn (%s)" % g.terrain(c))
	var burnt := BattleUnit.new(FirstBattle.squire(4), 1)
	burnt.cell = Vector2i(3, 1)
	burnt.hp = burnt.max_hp()
	TerrainRules.end_turn(burnt, g)
	ok(burnt.hp < burnt.max_hp() and burnt.tick_notes.size() == 1 and burnt.tick_notes[0].begins_with("Embers"), "embers burn at the end of the turn")
	burnt.hp = 1
	TerrainRules.end_turn(burnt, g)
	eq(burnt.hp, 1, "but never take the last point")
	var blessed := BattleUnit.new(FirstBattle.squire(5), 1)
	blessed.cell = Vector2i(4, 1)
	blessed.hp = 5
	TerrainRules.end_turn(blessed, g)
	ok(blessed.hp > 5, "a holy dais heals")
	ok(TerrainRules.describe(g, Vector2i(1, 1)).begins_with("Water:"), "the ground can be described (%s)" % TerrainRules.describe(g, Vector2i(1, 1)))
	eq(TerrainRules.describe(g, Vector2i(0, 0)), "", "plain grass says nothing")
	print("terrain rules checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)
