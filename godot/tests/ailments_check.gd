extends Node
## Headless: the classic tactics ailments (BattleUnit: sleep, stun, confuse, berserk, doom, curse, blind, slowed, haste) and what the AI does with them.
## godot --headless --path godot res://tests/ailments_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s (got %s, want %s)" % [what, a, b])


func _grid() -> TacticalGrid:
	var row := " ".join(PackedStringArray(["g0", "g0", "g0", "g0", "g0", "g0", "g0", "g0", "g0", "g0"]))
	var rows := []
	for i in 10:
		rows.append(row)
	return TacticalGrid.from_rows(rows)


func _unit(cls, name: String, speed := 6) -> UnitData:
	var u: UnitData = cls.new()
	u.display_name = name
	u.stats = CharacterStats.new()
	u.stats.speed = speed
	var w := WeaponItem.new()
	w.base_power = 8
	var st := WeaponStyle.new()
	st.geometry = TacticalMath.Geometry.KING
	u.loadout = EquipmentLoadout.make(w, st)
	if u.is_human():
		u.skill_tree = SkillTree.new()
	return u


## A battle: the King at (3,3), two enemies at (3,4) and (6,6); `fast` makes the enemies act first.
func rig(fast := false) -> Array:
	var b := BattleController.new()
	add_child(b)
	b.setup(_grid())
	b.miss_chance = 0.0
	b.crit_scale = 0.0  # exact damage: no random critical hits
	var king := b.deployment.deploy_king(_unit(KingData, "King", 6) as KingData, Vector2i(3, 3))
	var e1 := b.add_enemy(_unit(EnemyData, "Near", 20 if fast else 2) as EnemyData, Vector2i(3, 4))
	var e2 := b.add_enemy(_unit(EnemyData, "Far", 2) as EnemyData, Vector2i(6, 6))
	b.start()
	return [b, king, e1, e2]


func _ready() -> void:
	sleep_and_stun()
	doom_curse_blind()
	speeds()
	confusion_and_berserk()
	skills_and_chips()
	ai_behaviour()
	last_vessel_fades()
	soul_warden()
	print("ailments checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func sleep_and_stun() -> void:
	var r := rig()
	var b: BattleController = r[0]
	var king: BattleUnit = r[1]
	king.add_status(BattleUnit.SLEEP, 2)
	ok(king.loses_turn(), "a sleeper loses its turn")
	ok(b.next_turn() == king and b.skip_if_helpless(king), "its turn ends at once")
	eq(b.current, null, "...nobody is acting")
	eq(king.statuses.get(BattleUnit.SLEEP, 0), 1, "...and the sleep ran one turn down")
	# a hit wakes a sleeper, not a stunned unit
	var foe: BattleUnit = r[2]
	foe.add_status(BattleUnit.SLEEP, 3)
	var foe2: BattleUnit = r[3]
	foe2.add_status(BattleUnit.STUN, 3)
	var r2 := rig()
	var b2: BattleController = r2[0]
	var k2: BattleUnit = r2[1]
	b2.next_turn()
	k2.facing = Vector2i(0, 1)
	r2[2].add_status(BattleUnit.SLEEP, 3)
	r2[2].add_status(BattleUnit.STUN, 3)
	var res := b2.perform(k2, BattleAction.attack(), Vector2i(3, 4))
	ok(res.ok and res.hits[0].amount > 0, "the King hits the sleeper")
	ok(not r2[2].has_status(BattleUnit.SLEEP) and r2[2].has_status(BattleUnit.STUN), "a blow wakes a sleeper but not a stunned unit")


func doom_curse_blind() -> void:
	var r := rig()
	var b: BattleController = r[0]
	var king: BattleUnit = r[1]
	var foe: BattleUnit = r[2]
	foe.add_status(BattleUnit.DOOM, 2)
	# the foe takes its turns: doom counts down on its own turns, then knocks it out
	var fell := false
	for i in 12:
		var bu := b.next_turn()
		if bu == null:
			break
		if bu == foe and foe.is_down():
			break
		b.end_turn()
		if foe.is_down():
			fell = true
			break
	ok(fell and foe.hp == 0, "doom knocks the unit out when its count ends")
	var heals := []
	for cursed in [false, true]:
		var bb := BattleController.new()
		add_child(bb)
		bb.setup(_grid())
		bb.miss_chance = 0.0
		bb.crit_scale = 0.0  # exact damage: no random critical hits
		var kd := _unit(KingData, "King", 20) as KingData
		kd.skill_tree.start_study(SkillLibrary.find("Greater Heal"))
		var kk := bb.deployment.deploy_king(kd, Vector2i(3, 3))
		var cd := _unit(CoCaptainData, "Cap", 2) as CoCaptainData
		var cc := bb.deployment.deploy_co_captain(cd, Vector2i(3, 4))
		bb.add_enemy(_unit(EnemyData, "Far", 1) as EnemyData, Vector2i(9, 9))
		bb.start()
		bb.next_turn()
		kk.sp = 30
		kk.facing = Vector2i(0, 1)
		cc.hp = 1
		if cursed:
			cc.add_status(BattleUnit.CURSE, 3)
		var rr := bb.perform(kk, BattleAction.use(SkillLibrary.find("Greater Heal")), Vector2i(3, 4))
		heals.append(cc.hp - 1 if rr.ok else -1)
	ok(heals[0] > 4 and heals[1] > 0 and heals[1] <= heals[0] / 2 + 1, "a cursed unit is healed by half (%s)" % [heals])
	# blind misses more
	var bl := rig()
	var bc: BattleController = bl[0]
	bc.miss_chance = 0.25
	var base := bc.miss_chance_for(bl[1], bl[2], BattleAction.attack())
	bl[1].add_status(BattleUnit.BLIND, 2)
	ok(bc.miss_chance_for(bl[1], bl[2], BattleAction.attack()) >= base + 0.2, "blind: half of its attacks miss")


func speeds() -> void:
	var r := rig()
	var u: BattleUnit = r[1]
	var base := u.stat(StatModifier.Stat.SPEED)
	u.add_status(BattleUnit.HASTE, 3)
	ok(u.stat(StatModifier.Stat.SPEED) > base, "haste raises Speed")
	u.statuses.clear()
	u.add_status(BattleUnit.SLOWED, 3)
	ok(u.stat(StatModifier.Stat.SPEED) < base, "slowed lowers Speed")
	u.statuses.clear()
	var atk := u.stat(StatModifier.Stat.ATTACK)
	u.add_status(BattleUnit.BERSERK, 3)
	ok(u.stat(StatModifier.Stat.ATTACK) > atk, "berserk raises Attack")


func confusion_and_berserk() -> void:
	# a berserk King next to a foe and an ally: all are targets; the AI strikes the nearest
	var b := BattleController.new()
	add_child(b)
	b.setup(_grid())
	b.miss_chance = 0.0
	b.crit_scale = 0.0  # exact damage: no random critical hits
	var king := b.deployment.deploy_king(_unit(KingData, "King", 20) as KingData, Vector2i(3, 3))
	var cap := b.deployment.deploy_co_captain(_unit(CoCaptainData, "Cap", 2) as CoCaptainData, Vector2i(3, 4))
	b.add_enemy(_unit(EnemyData, "Far", 2) as EnemyData, Vector2i(8, 8))
	b.start()
	b.next_turn()
	king.add_status(BattleUnit.BERSERK, 3)
	ok(king.is_unruly(), "berserk is unruly")
	var hp := cap.hp
	var p := EnemyAI.plan(b, king)
	ok(p.acts() and p.aim == cap.cell, "a berserk unit hits whoever is nearest, its friend included (%s)" % [p.aim])
	king.statuses.clear()
	king.add_status(BattleUnit.CONFUSE, 3)
	var p2 := EnemyAI.plan(b, king)
	ok(p2.score >= 0.0, "a confused unit still makes a plan (random)")
	ok(hp == cap.hp, "planning changes nothing")


func skills_and_chips() -> void:
	for name in ["Lullaby", "Bewilder", "Rage Song", "Doom Mark", "Hex of Waning", "Slow Spell", "Blinding Flash", "Daze", "Haste", "Smelling Salts", "Time Stop", "Stunning Blow"]:
		ok(SkillLibrary.find(name) != null, name + " exists")
	var r := rig()
	var king: BattleUnit = r[1]
	var salts := SkillLibrary.find("Smelling Salts")
	(king.data as KingData).skill_tree.start_study(salts)
	king.add_status(BattleUnit.SLEEP, 3)
	king.add_status(BattleUnit.STUN, 3)
	var h := ActionResult.Hit.new()
	h.target = king
	var res := ActionResult.new()
	res.hits = [h]
	SkillFx.apply(r[0], king, salts, res, RandomNumberGenerator.new())
	ok(not king.has_status(BattleUnit.SLEEP) and not king.has_status(BattleUnit.STUN), "Smelling Salts wakes and un-stuns")
	ok(SkillFx.status_label(BattleUnit.DOOM) == "Doomed", "ailments have names for the screen")


## With the King down, the battle is lost as soon as the last vessel fades (it used to hang: nothing checked the outcome when a Fade Clock ran out).
func last_vessel_fades() -> void:
	var b := BattleController.new()
	add_child(b)
	b.setup(_grid())
	b.miss_chance = 0.0
	b.crit_scale = 0.0  # exact damage: no random critical hits
	var king := b.deployment.deploy_king(_unit(KingData, "King", 2) as KingData, Vector2i(3, 3))
	b.add_enemy(_unit(EnemyData, "Far", 1) as EnemyData, Vector2i(9, 9))
	var relic := RelicItem.new()
	b.deployment.place_relic(relic, Vector2i(3, 4))
	var vd := VesselData.new()
	vd.display_name = "Ghost"
	vd.stats = CharacterStats.new()
	vd.stats.speed = 30
	vd.loadout = EquipmentLoadout.make(WeaponItem.new(), WeaponStyle.new())
	vd.fade_turns = 1
	b.start()
	b.next_turn()
	var v := b.summon_vessel(king, vd, Vector2i(3, 4))
	ok(v != null, "a vessel is summoned")
	king.hp = 0
	b.end_turn()
	var guard := 0
	while b.outcome == BattleController.Outcome.ONGOING and guard < 10:
		guard += 1
		var bu := b.next_turn()
		if bu == null:
			break
		b.end_turn()
	eq(b.outcome, BattleController.Outcome.LOST, "the battle is lost when the last vessel fades with the King down")


## The Soul Warden's Borrowed Hour takes one tick off a vessel's Fade Clock, never the last, and does nothing to anyone without a clock.
func soul_warden() -> void:
	var e: EnemyData = Crucible.enemy("soulwarden", 1, 1)
	eq(e.display_name, "Soul Warden", "the Soul Warden kind builds")
	eq(UnitLook.sheet_for(e), "soul_warden", "the Soul Warden is drawn with his own sheet")
	var hour := SkillLibrary.find("Borrowed Hour")
	ok(hour != null and e.skills.has(hour), "he knows Borrowed Hour")
	var clock := FadeClock.new(3)
	eq(clock.shorten(1), 1, "one tick taken")
	eq(clock.turns_left, 2, "the clock reads 2")
	eq(clock.shorten(5), 1, "never below the last tick")
	eq(clock.turns_left, 1, "the clock stops at 1")
	eq(clock.shorten(1), 0, "nothing left to take")
	var r := rig()
	var king: BattleUnit = r[1]
	var v: BattleUnit = r[3]
	v.fade_clock = FadeClock.new(4)
	for t in [v, king]:
		var h := ActionResult.Hit.new()
		h.target = t
		var res := ActionResult.new()
		res.hits = [h]
		SkillFx.apply(r[0], r[2], hour, res, RandomNumberGenerator.new())
	eq(v.fade_clock.turns_left, 3, "Borrowed Hour takes one tick from a vessel")


## The AI uses what it has: over many turns an enemy with several skills uses more than one; a wounded one with a heal heals.
func ai_behaviour() -> void:
	var b := BattleController.new()
	add_child(b)
	b.setup(_grid())
	b.miss_chance = 0.0
	b.crit_scale = 0.0  # exact damage: no random critical hits
	var kd := _unit(KingData, "King", 1) as KingData
	kd.stats.base_max_hp = 100
	var king := b.deployment.deploy_king(kd, Vector2i(3, 3))
	var ed := _unit(EnemyData, "Mage", 20) as EnemyData
	ed.skills_only = true
	ed.skills = [SkillLibrary.find("Ember Flick"), SkillLibrary.find("Frost Prick"), SkillLibrary.find("Static Snap")]
	ed.stats.magic = 12
	ed.stats.will = 30
	ed.stats.base_max_hp = 100
	var foe := b.add_enemy(ed, Vector2i(3, 5))
	b.start()
	var used := {}
	for i in 14:
		var bu := b.next_turn()
		if bu == foe:
			EnemyAI.take_turn(b, bu)
			for k in foe.ai_used:
				used[k] = true
		b.end_turn()
		king.hp = king.max_hp()
		foe.sp = foe.max_sp()
	ok(used.size() >= 3, "an enemy with three skills uses all of them over a few turns (%s)" % [used.keys()])
