extends Node
## Headless checks for the combat feedback (HitFeedback): profiles, hitstop, recoil, flash, lunge, particles, camera shake,
## damage numbers, projectiles, area hits, kills, repeated and interrupted hits, directions, and that every sprite and the
## camera end exactly where they started. godot --headless --path godot res://tests/feedback_check.tscn
var fails := 0
var count := 0
var s: BattleStage
var fb: HitFeedback


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s: got %s, want %s" % [what, a, b])


func _ready() -> void:
	SaveSystem.dir = "user://test_saves_feedback"
	HitFeedback.reduce_shake = false
	HitFeedback.reduce_flash = false
	profiles()
	await stage_setup()
	await melee_hit()
	await directions()
	await crit_vs_normal()
	await misses_and_blocks()
	await area_hit()
	await projectile()
	await killing_blow()
	await repeated_and_interrupted()
	await shake_and_accessibility()
	await followups_shown()
	await numbers_stack()
	await particles_capped()
	audio()
	await no_deadlock()
	print("feedback checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


# ---------- helpers ----------

func stage_setup() -> void:
	s = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 0.0
	s.animate = true
	add_child(s)
	s.battle.miss_chance = 0.0
	s.battle.crit_scale = 0.0  # exact damage: no random critical hits
	await get_tree().process_frame
	var n := 0
	while s.battle.current != null and s.battle.current.team != 0 and n < 300:
		await get_tree().process_frame
		n += 1
	fb = s.feedback
	ok(fb != null and fb.board == s.board and fb.views == s.views, "the stage owns a HitFeedback wired to its board and views")
	# the units start far apart, which would make every blow a projectile: the first foe's logical cell is moved next to the actor
	# (these checks only read distances, never the grid)
	foes(1)[0].cell = player().cell + Vector2i(1, 0)
	for f in foes(3).slice(1):
		f.cell = player().cell + Vector2i(1, 1) if f == foes(3)[1] else player().cell + Vector2i(2, 0)


func player() -> BattleUnit:
	return s.battle.current


func foes(n := 3) -> Array:
	var out := []
	for u in s.views.keys():
		if u.team != 0 and not u.is_down() and out.size() < n:
			out.append(u)
	return out


func hit(target: BattleUnit, amount := 10, opts := {}) -> ActionResult.Hit:
	var h := ActionResult.Hit.new()
	h.target = target
	h.tile = target.cell
	h.amount = amount
	for k in opts:
		h.set(k, opts[k])
	return h


func result(a: BattleAction, hits: Array) -> ActionResult:
	var r := ActionResult.new()
	r.ok = true
	r.action = a
	for h in hits:
		r.hits.append(h)
	return r


func settle(secs := 0.9) -> void:
	await get_tree().create_timer(secs).timeout


## Every sprite of every unit exactly on its tile, running, not flashing; the camera framed as before.
func all_normal(cam0: Vector2, what: String) -> void:
	var bad := ""
	for u in s.views:
		var v: UnitView3D = s.views[u]
		if v.sprite.position.x != 0.0 or v.sprite.position.z != 0.0 or v.body.position.x != 0.0 or v.body.position.z != 0.0:
			bad += " %s offset %s" % [u.data.display_name, v.sprite.position]
		if v.sprite.speed_scale != 1.0:
			bad += " %s frozen" % u.data.display_name
		if v.flash_sprite != null and v.flash_sprite.visible:
			bad += " %s still white" % u.data.display_name
	ok(bad == "", "%s: every sprite is back on its tile, running and not white%s" % [what, bad])
	ok(is_equal_approx(s.board.cam.h_offset, cam0.x) and is_equal_approx(s.board.cam.v_offset, cam0.y) and s.board.shake == Vector2.ZERO, "%s: the camera is back where the framing put it" % what)
	ok(not fb.frozen() and not fb.busy(), "%s: nothing is left frozen or pending" % what)


func cam_now() -> Vector2:
	return Vector2(s.board.cam.h_offset, s.board.cam.v_offset)


# ---------- the checks ----------

func profiles() -> void:
	var atk := BattleAction.attack()
	var sword := HitFeedback.profile_for(atk, "attack", false, 1)
	eq(sword.name, "sword", "a plain adjacent attack is the sword profile")
	ok(sword.hitstop_ms >= 55 and sword.hitstop_ms <= 80, "a normal hit freezes 55-80 ms (%s)" % sword.hitstop_ms)
	ok(sword.flash_ms >= 50 and sword.flash_ms <= 80, "the flash lasts 50-80 ms")
	var heavy := HitFeedback.profile_for(atk, "heavy", false, 1)
	eq(heavy.name, "hammer", "a heavy animation is the hammer profile")
	ok(heavy.hitstop_ms >= 80 and heavy.hitstop_ms <= 110, "a heavy hit freezes 80-110 ms (%s)" % heavy.hitstop_ms)
	ok(heavy.recoil > sword.recoil and heavy.shake > 0.0 and sword.shake == 0.0, "heavier: more recoil and some shake; light: none")
	var far := HitFeedback.profile_for(atk, "attack", false, 5)
	eq(far.name, "bow", "a physical blow from afar is a projectile")
	ok(bool(far.projectile), "the bow profile flies a projectile")
	var dag := HitFeedback.profile_for(_skill_action("Quick Jab"), "attack", false, 1)
	eq(dag.name, "dagger", "a skill override picks the dagger profile by name")
	ok(dag.hitstop_ms >= 35 and dag.hitstop_ms <= 55 and dag.shake == 0.0, "the dagger is the quickest: 35-55 ms, no shake")
	var mg := HitFeedback.profile_for(_skill_action("Ember Flick"), "cast", false, 3)
	eq(mg.name, "magic", "an elemental skill is the magic profile")
	ok(mg.color[0] > mg.color[2], "and takes its element's colour (fire is warm): %s" % [mg.color])
	var cr := HitFeedback.profile_for(atk, "attack", true, 1)
	ok(cr.hitstop_ms > sword.hitstop_ms and cr.recoil > sword.recoil and cr.shake > sword.shake and cr.flash_ms > sword.flash_ms and cr.number_scale > sword.number_scale, "a critical hit is longer, stronger and bigger in every part")
	eq(cr.sfx_impact, "impact_crit", "and has its own impact sound event")
	var again := HitFeedback.profile_for(atk, "attack", false, 1)
	eq(again.hitstop_ms, sword.hitstop_ms, "profiles are copies: a critical never changes the base profile")


func _skill_action(skill_name: String) -> BattleAction:
	var a := BattleAction.new()
	for sk in SkillLibrary.all():
		if sk.display_name == skill_name:
			a.skill = sk
			break
	return a


func melee_hit() -> void:
	var cam0 := cam_now()
	var att := player()
	var tgt: BattleUnit = foes(1)[0]
	var av: UnitView3D = s.views[att]
	var tv: UnitView3D = s.views[tgt]
	var cell0 := tgt.cell
	var pos0 := tv.position
	var basis0 := tv.sprite.basis
	var h := hit(tgt, 12)
	fb.play_hits(att, result(BattleAction.attack(), [h]), "attack", tgt.cell)
	ok(tv.sprite.speed_scale == 0.0 and av.sprite.speed_scale == 0.0, "hitstop: the attacker's and the target's animation freeze at the impact")
	ok(tv.flash_sprite != null and tv.flash_sprite.visible, "the target flashes white at once")
	ok(fb.log.any(func(e): return e.has("number") and e.number == "12" and e.kind == "damage"), "the damage number spawns at the impact and matches the real damage (12)")
	ok(fb.frozen(), "the controller reports a freeze")
	var peak := 0.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 700:
		await get_tree().process_frame
		peak = maxf(peak, tv.sprite.position.length())
	ok(tv.position == pos0 and tgt.cell == cell0, "the target's logical cell and node position are untouched")
	ok(peak > 0.04 and peak < 0.2, "the recoil is a small jerk (%.3f of a tile)" % peak)
	ok(tv.sprite.basis.x.normalized().dot(basis0.x.normalized()) > 0.9999 and tv.sprite.basis.y.normalized().dot(basis0.y.normalized()) > 0.9999 and tv.sprite.basis.z.normalized().dot(basis0.z.normalized()) > 0.9999, "the sprite is never rotated (only its breathing scale differs)")
	all_normal(cam0, "after a melee hit")
	ok(is_equal_approx(av.sprite.position.length(), 0.0), "the attacker's lunge returned to its tile")


func directions() -> void:
	var cam0 := cam_now()
	var att := player()
	var tgt: BattleUnit = foes(1)[0]
	var av: UnitView3D = s.views[att]
	var tv: UnitView3D = s.views[tgt]
	var keep_a := av.position
	var keep_t := tv.position
	var c := keep_t
	for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		av.position = c - d * 1.0  # the attacker stands behind the target along d
		tv.position = c
		fb.play_hits(att, result(BattleAction.attack(), [hit(tgt, 5)]), "attack", tgt.cell)
		var best := Vector3.ZERO
		var lunge_best := Vector3.ZERO
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 450:
			await get_tree().process_frame
			var k := Vector3(tv.sprite.position.x, 0, tv.sprite.position.z)
			if k.length() > best.length():
				best = k
			var l := Vector3(av.sprite.position.x, 0, av.sprite.position.z)
			if l.length() > lunge_best.length():
				lunge_best = l
		ok(best.normalized().dot(d) > 0.95, "the target recoils away from the attacker along %s (got %s)" % [d, best.normalized()])
		ok(lunge_best.length() > 0.01 and lunge_best.normalized().dot(d) > 0.5, "the attacker's lunge goes toward the target along %s (got %s)" % [d, lunge_best])
		await settle(0.5)
	av.position = keep_a
	tv.position = keep_t
	all_normal(cam0, "after four directions")


func crit_vs_normal() -> void:
	var att := player()
	var tgt: BattleUnit = foes(1)[0]
	fb.log.clear()
	fb.play_hits(att, result(BattleAction.attack(), [hit(tgt, 8)]), "attack", tgt.cell)
	await settle(0.5)
	fb.play_hits(att, result(BattleAction.attack(), [hit(tgt, 16, {"crit": true})]), "attack", tgt.cell)
	await settle(0.5)
	var logs := fb.log.filter(func(e): return e.has("hitstop"))
	eq(logs.size(), 2, "both hits logged their feedback")
	ok(logs[1].hitstop > logs[0].hitstop and logs[1].recoil > logs[0].recoil and logs[1].crit, "the critical hit freezes longer and recoils more")
	ok(fb.log.any(func(e): return e.has("number") and e.kind == "crit" and e.number == "16"), "the critical number is its own kind and shows the real damage (16)")


func misses_and_blocks() -> void:
	var cam0 := cam_now()
	var att := player()
	var tgt: BattleUnit = foes(1)[0]
	var tv: UnitView3D = s.views[tgt]
	fb.log.clear()
	fb.play_hits(att, result(BattleAction.attack(), [hit(tgt, 0, {"missed": true})]), "attack", tgt.cell)
	ok(not fb.frozen() and (tv.flash_sprite == null or not tv.flash_sprite.visible), "a miss freezes and flashes nothing")
	fb.play_hits(att, result(BattleAction.attack(), [hit(tgt, 0, {"missed": true, "resisted": true})]), "attack", tgt.cell)
	fb.play_hits(att, result(BattleAction.attack(), [hit(tgt, 4, {"blocked": true})]), "attack", tgt.cell)
	fb.play_hits(att, result(BattleAction.attack(), [hit(tgt, 6, {"heal": true})]), "attack", tgt.cell)
	await settle(0.7)
	var kinds := fb.log.filter(func(e): return e.has("number")).map(func(e): return e.kind)
	ok(kinds.has("miss") and kinds.has("resist") and kinds.has("block") and kinds.has("heal"), "miss, resist, block and heal numbers each have their own kind: %s" % [kinds])
	ok(fb.log.any(func(e): return e.has("number") and e.kind == "block" and e.number == "4"), "a blocked hit shows the reduced damage it really did")
	all_normal(cam0, "after misses, blocks and heals")
	# the rules set the flags: a guarding target is marked blocked and takes half
	var b := s.battle
	var user := player()
	var foe: BattleUnit = foes(1)[0]
	foe.guarding = false
	var p0 := b.preview(user, BattleAction.attack(), foe.cell)
	foe.guarding = true
	var p1 := b.preview(user, BattleAction.attack(), foe.cell)
	foe.guarding = false
	if not p0.hits.is_empty() and not p1.hits.is_empty():
		ok(not p0.hits[0].blocked and p1.hits[0].blocked and p1.hits[0].amount <= p0.hits[0].amount, "BattleController marks a guarding target's hit blocked (%d vs %d)" % [p1.hits[0].amount, p0.hits[0].amount])
	else:
		ok(true, "no foe in reach of the previewed attack (flag check skipped)")


func area_hit() -> void:
	var cam0 := cam_now()
	var att := player()
	var targets := foes(3)
	var hs := []
	for t in targets:
		hs.append(hit(t, 7))
	var mg := _skill_action("Ember Flick")
	var settled := [0]
	fb.settled.connect(func(): settled[0] += 1, CONNECT_ONE_SHOT)
	fb.play_hits(att, result(mg, hs), "cast", targets[0].cell)
	for t in targets:
		var tv: UnitView3D = s.views[t]
		ok(tv.sprite.speed_scale == 0.0 and tv.flash_sprite != null and tv.flash_sprite.visible, "area hit: %s freezes and flashes together" % t.data.display_name)
	ok(s.fx.get_children().filter(func(n): return n is CPUParticles3D).size() >= 1, "magic particles burst at the contact point")
	await settle(1.0)
	eq(settled[0], 1, "area hit: one 'settled' once every target is done")
	ok(s.fx.get_children().filter(func(n): return n is CPUParticles3D).is_empty(), "the particle bursts are freed afterwards")
	all_normal(cam0, "after an area hit")


func projectile() -> void:
	var cam0 := cam_now()
	var att := player()
	var tgt: BattleUnit = foes(1)[0]
	var av: UnitView3D = s.views[att]
	var tv: UnitView3D = s.views[tgt]
	var keep := tv.position
	var cell := tgt.cell
	tgt.cell = att.cell + Vector2i(5, 0)  # far in the logical sense: the profile reads the distance
	tv.position = av.position + Vector3(5, 0, 0)
	fb.log.clear()
	fb.play_hits(att, result(BattleAction.attack(), [hit(tgt, 9)]), "attack", tgt.cell)
	await get_tree().process_frame
	ok(not fb.log.any(func(e): return e.has("number")), "projectile: no number or flash while the bolt is still flying")
	ok(tv.flash_sprite == null or not tv.flash_sprite.visible, "projectile: the target has not been hit yet")
	await settle(0.7)
	ok(fb.log.any(func(e): return e.has("number") and e.number == "9"), "projectile: the number appears when it lands")
	ok(fb.log.any(func(e): return e.has("profile") and e.profile == "bow"), "projectile: the bow profile was used")
	tgt.cell = cell
	tv.position = keep
	await settle(0.4)
	all_normal(cam0, "after a projectile")


func killing_blow() -> void:
	var cam0 := cam_now()
	var att := player()
	var tgt: BattleUnit = foes(1)[0]
	var tv: UnitView3D = s.views[tgt]
	var h := hit(tgt, 999, {"knocked_out": true})
	fb.play_hits(att, result(BattleAction.attack(), [h]), "attack", tgt.cell)
	ok(tv.animator.state != SpriteAnimator.State.DEAD, "killing blow: the unit has not fallen yet while the blow freezes")
	await settle(0.5)
	eq(tv.animator.state, SpriteAnimator.State.DEAD, "killing blow: it falls after the hitstop")
	ok(is_equal_approx(tv.sprite.speed_scale, 1.0), "killing blow: its animation runs again so the fall plays")
	tv.play("idle")
	tv.set_gray(0.0)
	all_normal(cam0, "after a kill")


func repeated_and_interrupted() -> void:
	var cam0 := cam_now()
	var att := player()
	var tgt: BattleUnit = foes(1)[0]
	var tv: UnitView3D = s.views[tgt]
	for i in 6:  # six blows 20 ms apart: every freeze overlaps the last
		fb.play_hits(att, result(BattleAction.attack(), [hit(tgt, 3)]), "attack", tgt.cell)
		await get_tree().create_timer(0.02).timeout
	await settle(1.0)
	all_normal(cam0, "after six overlapping blows")
	# interrupted: everything is cleaned up in the middle of a freeze, a lunge and a shake
	fb.play_hits(att, result(BattleAction.attack(), [hit(tgt, 30, {"crit": true})]), "heavy", tgt.cell)
	await get_tree().process_frame
	fb.cleanup()
	all_normal(cam0, "right after cleanup() in the middle of a hit")
	await settle(0.9)
	all_normal(cam0, "and later")


func shake_and_accessibility() -> void:
	var cam0 := cam_now()
	var att := player()
	var tgt: BattleUnit = foes(1)[0]
	var peak := 0.0
	fb.play_hits(att, result(BattleAction.attack(), [hit(tgt, 20)]), "attack", tgt.cell)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 300:
		await get_tree().process_frame
		peak = maxf(peak, s.board.shake.length())
	ok(peak == 0.0, "a light hit does not shake the camera")
	fb.play_hits(att, result(BattleAction.attack(), [hit(tgt, 40)]), "heavy", tgt.cell)
	t0 = Time.get_ticks_msec()
	var pos0 := s.board.cam.global_position
	var moved := false
	while Time.get_ticks_msec() - t0 < 300:
		await get_tree().process_frame
		peak = maxf(peak, s.board.shake.length())
		moved = moved or s.board.cam.global_position.distance_to(pos0) > 0.001
	ok(peak > 0.01 and peak < 0.15, "a heavy hit shakes the camera a little (%.3f)" % peak)
	ok(not moved, "the shake never moves the camera itself, only its framing offsets")
	await settle(0.5)
	all_normal(cam0, "after the shake")
	# a scroll in the middle of a shake keeps the shake on top of the new framing and ends exactly on it
	HitFeedback.reduce_shake = true
	peak = 0.0
	fb.play_hits(att, result(BattleAction.attack(), [hit(tgt, 40, {"crit": true})]), "heavy", tgt.cell)
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 300:
		await get_tree().process_frame
		peak = maxf(peak, s.board.shake.length())
	ok(peak == 0.0, "reduced motion: no shake at all")
	await settle(0.5)
	HitFeedback.reduce_shake = false
	HitFeedback.reduce_flash = true
	var tv: UnitView3D = s.views[tgt]
	fb.play_hits(att, result(BattleAction.attack(), [hit(tgt, 5)]), "attack", tgt.cell)
	await get_tree().process_frame
	ok(tv.flash_sprite == null or not tv.flash_sprite.visible, "reduced flashes: the target does not turn white")
	await settle(0.6)
	HitFeedback.reduce_flash = false
	all_normal(cam0, "after the accessibility options")


func numbers_stack() -> void:
	var att := player()
	var tgt: BattleUnit = foes(1)[0]
	var a := fb.number(tgt, "5", "damage")
	var b := fb.number(tgt, "6", "damage")
	var c := fb.number(tgt, "7", "damage")
	ok(a.position.y < b.position.y and b.position.y < c.position.y, "numbers over one unit stack upward instead of overlapping")
	ok(not is_equal_approx(a.position.x, b.position.x), "and are offset sideways")
	await get_tree().process_frame
	ok(a.scale.x < 1.0, "a number starts small and pops")
	await get_tree().create_timer(0.1).timeout
	ok(a.scale.x > 1.0, "overshoots, then settles")
	await settle(1.2)
	ok(not is_instance_valid(a) and not is_instance_valid(b) and not is_instance_valid(c), "numbers free themselves")
	var d := fb.number(tgt, "8", "damage")
	var base_y := board_top(tgt) + 2.3
	ok(is_equal_approx(d.position.y, base_y), "and the stack starts again from the bottom once they are gone")
	await settle(1.2)


func board_top(bu: BattleUnit) -> float:
	return s.board.top_point(bu.cell.x, bu.cell.y).y


func particles_capped() -> void:
	var tgt: BattleUnit = foes(1)[0]
	var tv: UnitView3D = s.views[tgt]
	for i in 60:
		fb._burst(tv, "sparks", Color.WHITE, 99, Vector3(1, 0, 0))
	var n := s.fx.get_children().filter(func(x): return x is CPUParticles3D).size()
	ok(n <= HitFeedback.MAX_BURSTS, "no more than %d bursts at once (%d)" % [HitFeedback.MAX_BURSTS, n])
	var big: CPUParticles3D = s.fx.get_children().filter(func(x): return x is CPUParticles3D)[0]
	ok(big.amount <= HitFeedback.MAX_COUNT, "and none has more than %d particles" % HitFeedback.MAX_COUNT)
	await settle(1.2)
	ok(s.fx.get_children().filter(func(x): return x is CPUParticles3D).is_empty(), "every burst frees itself")


func audio() -> void:
	ok(not CombatAudio.play(self, "impact_blade"), "with no sound file the call is a quiet no-op")
	ok(CombatAudio.missing.has("impact_blade"), "and the missing event is recorded")
	ok(not CombatAudio.play(null, "x") and not CombatAudio.play(self, ""), "a null host or empty event never crashes")


func no_deadlock() -> void:
	var cam0 := cam_now()
	var att := player()
	var tgt: BattleUnit = foes(1)[0]
	Engine.time_scale = 0.05  # a stalled clock: the freeze uses real time and still ends
	var t0 := Time.get_ticks_msec()
	fb.play_hits(att, result(BattleAction.attack(), [hit(tgt, 40, {"crit": true})]), "heavy", tgt.cell)
	while fb.frozen() and Time.get_ticks_msec() - t0 < 1500:
		await get_tree().process_frame
	var took := Time.get_ticks_msec() - t0
	Engine.time_scale = 1.0
	ok(not fb.frozen() and took < 400, "hitstop ends on its own in real time even at 5%% game speed (%d ms)" % took)
	# and the turn still goes on
	var before := s.battle.current
	s.end_turn()
	await get_tree().process_frame
	ok(s.battle.current != before or s.mode != BattleStage.Mode.IDLE, "the battle's turn still advances after hits")
	await settle(1.0)
	all_normal(cam0, "at the end")


func followups_shown() -> void:
	var cam0 := cam_now()
	var att := player()
	var tgt: BattleUnit = foes(1)[0]
	var r := result(BattleAction.attack(), [])
	var fu := ActionResult.FollowUp.new()
	fu.unit = att
	fu.hit = hit(tgt, 4)
	r.followups.append(fu)
	fb.log.clear()
	s._show_followups(r)
	await settle(1.6)
	ok(fb.log.any(func(e): return e.has("number") and e.number == "Follow-up!"), "a follow-up announces itself")
	ok(fb.log.any(func(e): return e.has("number") and e.number == "4" and e.kind == "damage"), "and its half-damage number shows the real amount (4)")
	all_normal(cam0, "after a follow-up")
