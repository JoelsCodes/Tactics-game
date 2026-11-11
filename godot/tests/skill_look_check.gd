extends Node
## Headless: every skill's effect look (SkillLook) and the library wiring. Physical skills keep their weapon effects, every other skill gets one of the four looks,
## and the names we know come out right.
## godot --headless --path godot res://tests/skill_look_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s: got %s, want %s" % [what, str(a), str(b)])


func _ready() -> void:
	var by_name := {}
	var spread := {}
	for s in SkillLibrary.all():
		by_name[s.display_name] = s
		var look := SkillLook.of(s)
		if s.category == Proficiency.Category.PHYSICAL:
			eq(look, "", "%s (physical) has no library look" % s.display_name)
		else:
			ok(SkillLook.LOOKS.has(look), "%s has a look (%s)" % [s.display_name, look])
			spread[look] = int(spread.get(look, 0)) + 1
	for want in [["Fireball", "fire"], ["Ember Flick", "fire"], ["Inferno", "fire"], ["Frost Lance", "ice"], ["Blizzard", "ice"], ["Absolute Zero", "ice"],
			["Static Snap", "spark"], ["Thunderclap", "spark"], ["Chain Spark", "spark"], ["Heal", "holy"], ["Mend", "holy"], ["Sanctuary", "holy"],
			["Haste", "holy"], ["Rally Cry", "holy"], ["Lullaby", "ice"], ["Hex of Waning", "spark"]]:
		ok(by_name.has(want[0]), "%s exists" % want[0])
		if by_name.has(want[0]):
			eq(SkillLook.of(by_name[want[0]]), want[1], "%s" % want[0])
	print("look spread: ", spread)
	for l in SkillLook.LOOKS:
		ok(int(spread.get(l, 0)) >= 8, "the %s look is used by a fair number of skills (%d)" % [l, int(spread.get(l, 0))])
	ok(SkillLook.of(null) == "", "no skill, no look")
	var own := SkillData.new()
	own.display_name = "Plain Bolt"
	own.category = Proficiency.Category.ELEMENTAL
	own.fx = {"look": "holy"}
	eq(SkillLook.of(own), "holy", "an explicit fx.look wins")
	# the profile carries the look for a non-physical action, never for a physical one
	var a := BattleAction.use(by_name["Fireball"])
	eq(HitFeedback.profile_for(a, "cast", false, 3).get("look", ""), "fire", "a spell's feedback profile names its look")
	var b := BattleAction.use(by_name["Hammer Time"]) if by_name.has("Hammer Time") else BattleAction.attack()
	eq(HitFeedback.profile_for(b, "attack", false, 1).get("look", ""), "", "a physical blow's profile has none")
	print("skill look checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)
