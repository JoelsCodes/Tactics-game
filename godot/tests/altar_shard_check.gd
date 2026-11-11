extends Node
## Headless: the Altar Shard (summoning stone) pictures. The four sheets (assets/sprites/altar_shard/) and their SpriteFrames, AltarShardView's
## sequence (idle, then activate -> summon -> depleted, once, burst once, skippable) and its place in the battle stage: a hover or a cancelled
## summon leaves the stone idle, a confirmed summon makes exactly one vessel (the rules decide at once) and the stone plays out its picture.
## godot --headless --path godot res://tests/altar_shard_check.tscn
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
	SaveSystem.dir = "user://test_saves_shard"
	sheets()
	await view()
	await stage()
	print("altar shard checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func sheets() -> void:
	var sf := AltarShardView.frames()
	ok(sf != null, "the four sheets load")
	if sf == null:
		return
	var lows := []
	for name in ["idle", "activate", "summon", "depleted"]:
		eq(sf.get_frame_count(name), 8, "%s has eight frames" % name)
		eq(sf.get_animation_loop(name), name == "idle", "%s loops only when idle" % name)
		var img := (load(AltarShardView.DIR + "altar_shard_%s.png" % name) as Texture2D).get_image()
		eq(img.get_size(), Vector2i(290 * 8, 570), "%s sheet size" % name)
		ok(img.detect_alpha() != Image.ALPHA_NONE, "%s has transparency" % name)
		eq(img.get_pixel(0, 0).a, 0.0, "%s: no background rectangle" % name)
		for k in 8:  # the stone's foot is on one row in every frame (the base does not drift between animations)
			var low := -1
			for y in range(img.get_height() - 1, -1, -1):
				var hit := false
				for x in range(k * 290, (k + 1) * 290, 2):
					if img.get_pixel(x, y).a > 0.5:
						hit = true
						break
				if hit:
					low = y
					break
			lows.append(low)
	ok(lows.all(func(v): return v == lows[0]), "the base sits on the same row in all 32 frames (%s)" % str(lows.slice(0, 3)))
	eq(lows[0], AltarShardView.BASE_ROW, "and that row is BASE_ROW")


func view() -> void:
	var v := AltarShardView.new()
	add_child(v)
	await get_tree().process_frame
	eq(v.sprite.animation, &"idle", "a new stone idles")
	ok(v.sprite.is_playing(), "and loops")
	eq(v.state, AltarShardView.State.IDLE, "idle state")
	var bursts := [0]
	var ends := [0]
	v.burst.connect(func(): bursts[0] += 1)
	v.finished.connect(func(): ends[0] += 1)
	ok(v.begin_summon(), "a committed summon starts the sequence")
	ok(not v.begin_summon(), "rapid input cannot start it twice")
	eq(v.sprite.animation, &"activate", "it charges first")
	var seen := {}
	for i in 400:
		await get_tree().process_frame
		seen[String(v.sprite.animation)] = true
		if v.state == AltarShardView.State.GONE:
			break
	ok(seen.has("summon") and seen.has("depleted"), "activate, then summon, then depleted all play")
	eq(bursts[0], 1, "the burst is emitted once")
	eq(ends[0], 1, "finished once")
	ok(not v.begin_summon(), "a spent stone cannot be used again")
	v.queue_free()
	# a skip
	var w := AltarShardView.new()
	add_child(w)
	await get_tree().process_frame
	var b2 := [0]
	var e2 := [0]
	w.burst.connect(func(): b2[0] += 1)
	w.finished.connect(func(): e2[0] += 1)
	w.skip()
	eq(w.state, AltarShardView.State.IDLE, "skipping an idle stone does nothing")
	w.begin_summon()
	w.skip()
	w.skip()
	eq(b2[0], 1, "a skip still lets the vessel appear (burst once)")
	eq(e2[0], 1, "and ends the sequence once")
	w.queue_free()


func stage() -> void:
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 0.0
	s.animate = true
	add_child(s)
	await get_tree().process_frame
	var dm := s.battle.deployment
	while s.battle.current != dm.king:
		s.end_turn()
		for i in 60:
			await get_tree().process_frame
	var shards: Array = s.prop_views.values().map(func(n): return n.get_meta("shard"))
	ok(shards.size() >= 2, "the stones are drawn as Altar Shards (%d)" % shards.size())
	ok(shards.all(func(sh): return sh.sprite.animation == &"idle"), "every stone idles")
	var vd: VesselData = s.game.roster.vessels()[0]
	var spots := dm.props.keys().filter(func(c): return dm.can_summon(vd, c))
	ok(not spots.is_empty(), "a stone is in reach")
	var spot: Vector2i = spots[0]
	var prop := dm.prop_at(spot)
	var sh: AltarShardView = s.prop_views[prop].get_meta("shard")
	# choosing a vessel and cancelling leaves every stone idle
	s._on_summon_chosen(vd)
	s.cancel()
	ok(shards.all(func(x): return x.state == AltarShardView.State.IDLE), "a cancelled summon preview leaves the stones idle")
	eq(dm.summons_made, 0, "and costs nothing")
	# a confirmed summon
	var before := dm.summons_made
	s.summoning = vd
	s._summon_at(spot)
	eq(dm.summons_made, before + 1, "one confirmed summon, one summon made")
	eq(dm.vessels.size(), 1, "exactly one vessel")
	var vb := dm.unit_of(vd)
	ok(vb != null and vb.cell == spot, "the vessel stands on the stone's tile at once (the rules do not wait for the picture)")
	ok(sh.is_busy(), "the stone plays its sequence")
	var vv: UnitView3D = s.views[vb]
	ok(vv != null, "the vessel has a view")
	for i in 400:
		await get_tree().process_frame
		if not is_instance_valid(sh) or sh.state == AltarShardView.State.GONE:
			break
	for i in 30:
		await get_tree().process_frame
	ok(not is_instance_valid(sh), "the sequence ends and the spent stone's picture is removed")
	eq(dm.vessels.size(), 1, "still exactly one vessel")
	ok(shards.filter(func(x): return is_instance_valid(x) and x != sh).all(func(x): return x.state == AltarShardView.State.IDLE), "the other stones are still idle")
	# a second summon with a click-skip
	var vd2: VesselData = s.game.roster.vessels()[1]
	var spots2 := dm.props.keys().filter(func(c): return dm.can_summon(vd2, c))
	if not spots2.is_empty():
		var sh2: AltarShardView = s.prop_views[dm.prop_at(spots2[0])].get_meta("shard")
		s.summoning = vd2
		s._summon_at(spots2[0])
		var click := InputEventMouseButton.new()
		click.pressed = true
		s._unhandled_input(click)
		ok(not is_instance_valid(sh2) or sh2.state == AltarShardView.State.GONE, "a click skips the picture")
		eq(dm.vessels.size(), 2, "and never loses or doubles a summon")
	s.queue_free()
