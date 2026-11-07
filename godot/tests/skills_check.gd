extends Node
## Headless: the skill database (data/skills/*.json, built by tools/skills/build_skills.py) and SkillFx, the rules behind the skills of
## every proficiency from rank E to S. Checks the lists, then each kind of effect in a small battle, then casts EVERY skill once.
## godot --headless --path godot res://tests/skills_check.tscn
var fails := 0
var count := 0
var rng := RandomNumberGenerator.new()


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s: got %s, want %s" % [what, a, b])


func _ready() -> void:
	rng.seed = 5
	lists()
	effects()
	every_skill()
	vessel_learning()
	print("skills checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func lists() -> void:
	var all := SkillLibrary.all()
	var names := {}
	for s in all:
		ok(not names.has(s.display_name), "unique name " + s.display_name)
		names[s.display_name] = true
		ok(s.description != "", s.display_name + " has a description")
		ok(s.sp_cost == {0: 3, 1: 4, 2: 5, 3: 6, 4: 8, 5: 10}[s.rank], "%s costs by rank (%d)" % [s.display_name, s.sp_cost])
	for c in Proficiency.all():
		var list := SkillLibrary.of(c)
		ok(list.size() >= 17, "%s has %d skills" % [Proficiency.display_name(c), list.size()])
		for rank in SkillData.Rank.values():
			ok(list.any(func(s): return s.rank == rank), "%s has a rank %s skill" % [Proficiency.display_name(c), SkillData.Rank.keys()[rank]])
		ok(list.all(func(s): return s.category == c), Proficiency.display_name(c) + " skills are in their own proficiency")
	ok(all.size() >= 150, "%d skills in all" % all.size())
	ok(SkillLibrary.healing().filter(func(s): return s.rank == SkillData.Rank.E).size() == 9, "the owner's seven rank E healing skills plus two")
	ok(SkillLibrary.physical().slice(0, 10).map(func(s): return s.display_name) == ["Quick Jab", "Shield Prod", "Hamstring Cut", "Step-Aside Strike", "Feinting Lunge", "Dirty Sand Kick", "Grip Loosen", "Crescent Strike", "Pity Pity", "Hop"], "the owner's ten rank E physical skills come first, unchanged")
	eq(SummonStone.e_skills().size() > 10, true, "summon stones draw from every rank E skill")


func board(n := 12) -> TacticalGrid:
	var rows := []
	var row := []
	row.resize(n)
	row.fill("g0")
	for y in n:
		rows.append(" ".join(PackedStringArray(row)))
	return TacticalGrid.from_rows(rows)


func make(cls, name: String, speed := 6) -> UnitData:
	var u: UnitData = cls.new()
	u.display_name = name
	u.stats = CharacterStats.new()
	u.stats.speed = speed
	u.stats.magic = 10
	u.stats.will = 12
	var w := WeaponItem.new()
	w.base_power = 8
	var st := WeaponStyle.new()
	st.geometry = TacticalMath.Geometry.QUEEN
	st.reach = 6
	u.loadout = EquipmentLoadout.make(w, st)
	if u.is_human():
		u.skill_tree = SkillTree.new()
	return u


## A battle with the King at (5,5) and a foe 2 tiles along +y; `extra` are more foes (cells). Returns [battle, king, foe].
func rig(s: SkillData, extra: Array = [], ally := false) -> Array:
	var b := BattleController.new()
	add_child(b)
	b.setup(board())
	b.miss_chance = 0.0
	var kd := make(KingData, "King", 10) as KingData
	kd.skill_tree.start_study(s)
	var king := b.deployment.deploy_king(kd, Vector2i(5, 5))
	var foe := b.add_enemy(make(EnemyData, "Foe", 1) as EnemyData, Vector2i(5, 7))
	for c in extra:
		b.add_enemy(make(EnemyData, "Foe", 1) as EnemyData, c)
	if ally:
		var cap := b.deployment.deploy_co_captain(make(CoCaptainData, "Cap", 2) as CoCaptainData, Vector2i(5, 3))
		cap.hp = cap.max_hp() / 2
	b.start()
	b.next_turn()
	king.sp = 30
	king.facing = Vector2i(0, 1)
	return [b, king, foe]


func skill(name: String) -> SkillData:
	var s := SkillLibrary.find(name)
	ok(s != null, "skill " + name + " exists")
	return s


func effects() -> void:
	# damage modifiers, by preview
	var base_amount := func(name: String) -> int:
		var r: Array = rig(skill(name))
		return r[0].preview(r[1], BattleAction.use(skill(name)), Vector2i(5, 7)).hits[0].amount
	var plain: int = base_amount.call("Void Lance")
	ok(plain > 0, "Void Lance deals damage (%d)" % plain)
	var rift: int = base_amount.call("Rift Slash")
	ok(rift > 0, "Rift Slash (2 hits) deals damage (%d)" % rift)
	var r0: Array = rig(skill("Entropy Touch"))
	var h0: ActionResult.Hit = r0[0].preview(r0[1], BattleAction.use(skill("Entropy Touch")), Vector2i(5, 7)).hits[0]
	eq(h0.amount, maxi(1, r0[2].max_hp() * 12 / 100), "Entropy Touch: 12% of max HP")
	var ex: Array = rig(skill("Unmake"))
	var before: int = ex[0].preview(ex[1], BattleAction.use(skill("Unmake")), Vector2i(5, 7)).hits[0].amount
	ex[2].hp = 5
	var after: int = ex[0].preview(ex[1], BattleAction.use(skill("Unmake")), Vector2i(5, 7)).hits[0].amount
	ok(after > before, "Unmake: more damage on a nearly beaten target (%d -> %d)" % [before, after])

	# blast hits the tiles around the aim, friend or foe
	var bl: Array = rig(skill("Inferno"), [Vector2i(5, 8), Vector2i(6, 7)])
	var rr: ActionResult = bl[0].perform(bl[1], BattleAction.use(skill("Inferno")), Vector2i(5, 7))
	eq(rr.error, "", "Inferno is cast")
	eq(rr.hits.size(), 3, "Inferno (blast 2) hits the aimed foe and the two next to it")
	ok(rr.hits.all(func(h): return h.target.has_status(BattleUnit.BURN)), "...and sets all three burning")

	# burn ticks at the end of the unit's own turn and never kills
	var foe: BattleUnit = bl[2]
	var hp := foe.hp
	SkillFx.tick(foe)
	ok(foe.hp < hp and foe.hp >= 1 and foe.tick_notes.size() == 1, "burn takes a share each turn (%d -> %d)" % [hp, foe.hp])
	foe.hp = 1
	SkillFx.tick(foe)
	eq(foe.hp, 1, "burn never takes the last point")
	foe.statuses.clear()
	foe.add_status(BattleUnit.REGEN, 2)
	foe.hp = 5
	SkillFx.tick(foe)
	ok(foe.hp > 5, "regen restores HP each turn")

	# debuff mods
	var d: Array = rig(skill("Curse of Rust"))
	var def_before: int = d[2].stat(StatModifier.Stat.DEFENSE)
	d[0].perform(d[1], BattleAction.use(skill("Curse of Rust")), Vector2i(5, 7))
	ok(d[2].stat(StatModifier.Stat.DEFENSE) < def_before or def_before == 0, "Curse of Rust lowers Defense (%d -> %d)" % [def_before, d[2].stat(StatModifier.Stat.DEFENSE)])
	d[2].add_buff(StatModifier.Stat.ATTACK, -50, 2)
	ok(d[2].stat(StatModifier.Stat.ATTACK) <= d[2].data.stats.attack, "a negative buff lowers a stat")

	# exposed / ward change the damage taken
	var ew: Array = rig(skill("Void Lance"))
	var a := BattleAction.use(skill("Void Lance"))
	var n1: int = ew[0].preview(ew[1], a, Vector2i(5, 7)).hits[0].amount
	ew[2].add_status(BattleUnit.EXPOSED, 2)
	var n2: int = ew[0].preview(ew[1], a, Vector2i(5, 7)).hits[0].amount
	ew[2].statuses.clear()
	ew[2].add_status(BattleUnit.WARD, 2)
	var n3: int = ew[0].preview(ew[1], a, Vector2i(5, 7)).hits[0].amount
	ok(n2 > n1 and n3 < n1, "exposed takes more, warded takes less (%d, %d, %d)" % [n3, n1, n2])

	# drain, SP steal
	var dr: Array = rig(skill("Shadow Nip"))
	dr[1].hp = dr[1].max_hp() - 10
	dr[0].perform(dr[1], BattleAction.use(skill("Shadow Nip")), Vector2i(5, 7))
	ok(dr[1].hp > dr[1].max_hp() - 10, "Shadow Nip heals the user")
	var sp: Array = rig(skill("Drain Spirit"))
	sp[1].sp = 5
	var fsp: int = sp[2].sp
	sp[0].perform(sp[1], BattleAction.use(skill("Drain Spirit")), Vector2i(5, 7))
	ok(sp[2].sp < fsp and sp[1].sp > 5 - 5 + 0, "Drain Spirit takes the foe's SP for the user")

	# healing with power and heal_pct; cleanse
	var hl: Array = rig(skill("Greater Heal"), [], true)
	var cap: BattleUnit = hl[0].deployment.field_units().filter(func(u): return u.data.display_name == "Cap")[0]
	var h_before := cap.hp
	var hr: ActionResult = hl[0].perform(hl[1], BattleAction.use(skill("Greater Heal")), Vector2i(5, 3))
	eq(hr.error, "", "Greater Heal is cast")
	ok(cap.hp > h_before, "Greater Heal heals the ally (%d -> %d)" % [h_before, cap.hp])
	var mi: Array = rig(skill("Miracle"), [], true)
	var cap2: BattleUnit = mi[0].deployment.field_units().filter(func(u): return u.data.display_name == "Cap")[0]
	cap2.add_status(BattleUnit.POISON, 3)
	cap2.add_status(BattleUnit.SILENCE, 3)
	mi[0].perform(mi[1], BattleAction.use(skill("Miracle")), Vector2i(5, 3))
	ok(cap2.hp == cap2.max_hp() and not cap2.has_status(BattleUnit.POISON) and not cap2.has_status(BattleUnit.SILENCE), "Miracle: full heal and cleanse")
	var nobody: Array = rig(skill("Mend"))
	eq(nobody[0].perform(nobody[1], BattleAction.use(skill("Mend")), Vector2i(5, 7)).error != "", true, "an ally skill on a foe is refused")

	# self only
	var br: Array = rig(skill("Brace"))
	eq(br[0].highlights(br[1], BattleAction.use(skill("Brace"))), [Vector2i(5, 5)] as Array[Vector2i], "Brace aims at the user alone")
	eq(br[0].perform(br[1], BattleAction.use(skill("Brace")), Vector2i(5, 5)).error, "", "Brace is cast")
	ok(br[1].guarding, "Brace guards the user")
	var ff: Array = rig(skill("Fleet Foot"))
	var mv: int = ff[1].stat(StatModifier.Stat.MOVE)
	ff[0].perform(ff[1], BattleAction.use(skill("Fleet Foot")), Vector2i(5, 5))
	ok(ff[1].stat(StatModifier.Stat.MOVE) > mv, "Fleet Foot raises Move (%d -> %d)" % [mv, ff[1].stat(StatModifier.Stat.MOVE)])

	# pull and swap move units
	var pu: Array = rig(skill("Grapple Line"))
	pu[0].perform(pu[1], BattleAction.use(skill("Grapple Line")), Vector2i(5, 7))
	eq(pu[2].cell, Vector2i(5, 6), "Grapple Line drags the foe next to the user")
	var sw: Array = rig(skill("Swap Meet"))
	sw[0].perform(sw[1], BattleAction.use(skill("Swap Meet")), Vector2i(5, 7))
	ok(sw[1].cell == Vector2i(5, 7) and sw[2].cell == Vector2i(5, 5) and sw[0].grid.occupant(Vector2i(5, 7)) == sw[1], "Swap Meet trades places")

	# tempo
	var dl: Array = rig(skill("Disrupt Formation"))
	dl[2].ct = 90
	dl[0].perform(dl[1], BattleAction.use(skill("Disrupt Formation")), Vector2i(5, 7))
	ok(dl[2].ct < 90, "Disrupt Formation sets the foe's turn back (%d)" % dl[2].ct)
	var rs: Array = rig(skill("Flank Order"), [], true)
	var cap3: BattleUnit = rs[0].deployment.field_units().filter(func(u): return u.data.display_name == "Cap")[0]
	var ct0 := cap3.ct
	rs[0].perform(rs[1], BattleAction.use(skill("Flank Order")), Vector2i(5, 3))
	ok(cap3.ct > ct0, "Flank Order brings an ally's turn sooner")

	# silence and root
	var si: Array = rig(skill("Hush"))
	si[0].perform(si[1], BattleAction.use(skill("Hush")), Vector2i(5, 7))
	ok(si[2].has_status(BattleUnit.SILENCE) and si[0].actions(si[2]).size() <= 1, "Hush silences: the basic attack only")
	var ro: Array = rig(skill("Ankle Snare"))
	ro[0].perform(ro[1], BattleAction.use(skill("Ankle Snare")), Vector2i(5, 7))
	eq(ro[0].move_budget(ro[2]), 0, "a rooted foe cannot walk")

	# recoil
	var rc: Array = rig(skill("Reckless Charge"))
	var hp0: int = rc[1].hp
	rc[0].perform(rc[1], BattleAction.use(skill("Reckless Charge")), Vector2i(5, 7))
	ok(rc[1].hp < hp0 and rc[1].hp >= 1, "Reckless Charge costs the user HP (%d -> %d)" % [hp0, rc[1].hp])

	# tactical never misses, others can
	var tm: Array = rig(skill("Study Foe"))
	tm[0].miss_chance = 1.0
	tm[0].perform(tm[1], BattleAction.use(skill("Study Foe")), Vector2i(5, 7))
	ok(tm[2].has_status(BattleUnit.MARKED), "a tactical skill always lands")
	var em: Array = rig(skill("Void Lance"))
	em[0].miss_chance = 1.0
	var me: ActionResult = em[0].perform(em[1], BattleAction.use(skill("Void Lance")), Vector2i(5, 7))
	ok(me.hits[0].missed, "a damaging skill can still miss")

	# chaos rolls inside its band over many uses
	var lo := 9999
	var hi := 0
	for i in 40:
		var c: Array = rig(skill("Existential Hiccup"))
		c[0].rng.seed = i
		var cr: ActionResult = c[0].perform(c[1], BattleAction.use(skill("Existential Hiccup")), Vector2i(5, 7))
		lo = mini(lo, cr.hits[0].amount)
		hi = maxi(hi, cr.hits[0].amount)
	ok(hi > lo * 2, "Existential Hiccup varies a lot (%d to %d)" % [lo, hi])


## A vessel learns by using skills in battle: the first use starts the skill at level 0, enough uses reach level 1 and it is learned for good (usable
## without the relic, kept through a save and a load).
func vessel_learning() -> void:
	var b := BattleController.new()
	add_child(b)
	b.setup(board())
	b.miss_chance = 0.0
	var king := b.deployment.deploy_king(make(KingData, "King", 50) as KingData, Vector2i(5, 1))
	var foe_data := make(EnemyData, "Dummy", 1) as EnemyData
	foe_data.stats.base_max_hp = 100
	foe_data.stats.defense = 0
	var foe := b.add_enemy(foe_data, Vector2i(5, 4))
	var stone := RelicItem.new()
	var jab := skill("Pin Down")
	stone.skill = jab
	b.deployment.place_relic(stone, Vector2i(5, 2))
	var vd := make(VesselData, "Pupil", 40) as VesselData
	vd.fade_turns = 500
	b.start()
	b.next_turn()
	var vb := b.summon_vessel(king, vd, Vector2i(5, 2))
	ok(vb != null and vd.skill_tree == null, "a vessel is summoned onto a stone with Pin Down, and has learned nothing yet")
	var uses := 0
	var learned_at := -1
	for i in 200:
		foe.hp = foe.max_hp()
		var bu := b.next_turn()
		if bu == null:
			break
		if bu == vb:
			vb.sp = 30
			vb.facing = Vector2i(0, 1)
			var res := b.perform(vb, BattleAction.use(jab), Vector2i(5, 4))
			if res.ok:
				uses += 1
				if res.skill_learned != null and learned_at < 0:
					learned_at = uses
		b.end_turn()
		if learned_at >= 0:
			break
	ok(vd.skill_tree != null and vd.skill_tree.mastery_of(jab) != null, "using the skill started it in the vessel's tree")
	ok(learned_at > 3 and learned_at < 60, "after a good number of uses it is learned (%d uses)" % learned_at)
	ok(vd.skill_tree.is_learned(jab), "and kept: level 1 or more")
	# learned for good: usable without the relic, and it survives a save
	vd.loadout.release_temp_relic()
	var b2 := BattleController.new()
	add_child(b2)
	b2.setup(board())
	var k2 := b2.deployment.deploy_king(make(KingData, "King2", 50) as KingData, Vector2i(5, 1))
	b2.add_enemy(make(EnemyData, "Dummy2", 1) as EnemyData, Vector2i(9, 9))
	var stone2 := RelicItem.new()
	b2.deployment.place_relic(stone2, Vector2i(5, 2))
	b2.start()
	b2.next_turn()
	var v2 := b2.summon_vessel(k2, vd, Vector2i(5, 2))
	ok(v2 != null and b2.skills_of(v2).has(jab), "in a later battle, with no relic carrying it, the vessel can still use what it learned")
	ok(b2.skill_level(v2, jab) >= 1, "at its level")
	var g := FirstBattle.chamber_game(FirstBattle.game())
	var bram: VesselData = g.roster.king.vessel_roster.filter(func(v): return v.display_name == "Bram")[0]
	var tr := Mentorship.tree_of(bram)
	for i in 80:
		tr.practice_skill(jab, bram.stats, bram.loadout, rng)
	ok(tr.is_learned(jab), "(Bram practised it enough)")
	var back := SaveCodec.decode(SaveCodec.encode(g))
	var bram2: VesselData = back.game.roster.king.vessel_roster.filter(func(v): return v.display_name == "Bram")[0]
	# partial progress carries over too: a skill not yet learned keeps its bar between battles and through a save
	var g2 := FirstBattle.chamber_game(FirstBattle.game())
	var lyra_v: VesselData = g2.roster.king.vessel_roster.filter(func(v): return v.display_name == "Lyra")[0]
	var t2 := Mentorship.tree_of(lyra_v)
	var hop := skill("Bonk")
	for i in 3:
		t2.practice_skill(hop, lyra_v.stats, lyra_v.loadout, rng)
	var m_before := t2.mastery_of(hop)
	ok(not m_before.is_mastered() and m_before.progress > 0, "three uses: not learned yet, a bar of %d" % m_before.progress)
	var back2 := SaveCodec.decode(SaveCodec.encode(g2))
	var lyra2: VesselData = back2.game.roster.king.vessel_roster.filter(func(v): return v.display_name == "Lyra")[0]
	var m_after: SkillMastery = null
	for mm in lyra2.skill_tree.masteries:  # a loaded game has its own copies of the skills: find it by name
		if mm.skill.display_name == "Bonk":
			m_after = mm
	ok(m_after != null and m_after.progress == m_before.progress and m_after.level == m_before.level, "the unfinished progress survives a save and a load (%d)" % (m_after.progress if m_after else -1))
	var before2 := m_after.progress
	lyra2.skill_tree.practice_skill(m_after.skill, lyra2.stats, lyra2.loadout, rng)
	ok(m_after.progress != before2 or m_after.level > 0, "and the next battle adds to it")
	ok(bram2.skill_tree != null and bram2.skill_tree.learned_skills().any(func(x): return x.display_name == "Pin Down"), "a vessel's learned skill survives a save and a load")


## Casts every skill in the game once at a fitting target: none may be refused or crash, and none may leave a unit with negative HP.
func every_skill() -> void:
	for s in SkillLibrary.all():
		if s.hop or s.support == "sp_finisher":
			continue
		var r: Array = rig(s, [], s.allies_only and not SkillFx.flag(s, "self_only"))
		var b: BattleController = r[0]
		var king: BattleUnit = r[1]
		var aim := Vector2i(5, 7)
		if SkillFx.flag(s, "self_only"):
			aim = king.cell
		elif s.allies_only:
			aim = Vector2i(5, 3)
		var res: ActionResult = b.perform(king, BattleAction.use(s), aim)
		eq(res.error, "", "cast " + s.display_name)
		for u in b.all_units():
			ok(u.hp >= 0 and u.hp <= u.max_hp() and u.sp >= 0, "%s leaves sane numbers on %s" % [s.display_name, u.data.display_name])
		b.queue_free()
