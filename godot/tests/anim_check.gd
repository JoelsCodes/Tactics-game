extends Node
## Headless checks for character animation (SpriteAnimator, UnitView3D) and the King's eight-direction
## sheet: godot --headless --path godot res://tests/anim_check.tscn

var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s: got %s, want %s" % [what, a, b])


func _ready() -> void:
	directions()
	king_sheet()
	await king_view()
	legacy_view()
	extras()
	await appearance()
	await roster_sheets()
	print("anim checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func directions() -> void:
	# four directions only: the larger axis wins, a diagonal reads as the front (down) or back (up) view
	var want := {Vector2(0, 1): "s", Vector2(1, 1): "s", Vector2(1, 0): "e", Vector2(1, -1): "n",
		Vector2(0, -1): "n", Vector2(-1, -1): "n", Vector2(-1, 0): "w", Vector2(-1, 1): "s"}
	for v in want:
		eq(SpriteAnimator.dir_of(v), want[v], "screen %s" % v)
	eq(SpriteAnimator.dir_of(Vector2(1, 0.3)), "e", "near-horizontal snaps to e")
	eq(SpriteAnimator.dir_of(Vector2(0.9, 0.7)), "e", "the larger axis wins")
	eq(SpriteAnimator.dir_of(Vector2(0.3, -1)), "n", "near-vertical snaps to n")


func king_sheet() -> void:
	var m := Character.meta("king")
	ok(m.get("eight_dir", false), "the King's sheet is eight-direction")
	var frames: SpriteFrames = load("res://assets/characters/king.tres")
	for move in SpriteAnimator.MOVES:
		for d in ["s", "se", "e", "ne", "n", "nw", "w", "sw"]:
			var n := "%s_%s" % [move, d]
			ok(frames.has_animation(n) and frames.get_frame_count(n) >= (1 if move == "idle" else 3), "%s has frames" % n)
			ok(frames.get_animation_loop(n), "%s loops" % n)
	for a in ["attack", "heavy", "cast", "hit", "ko"]:
		ok(frames.has_animation(a) and not frames.get_animation_loop(a), "%s is a one-shot" % a)
	for a in ["attack", "heavy", "cast"]:
		var strike := int(m.anims[a].strike)
		ok(strike > 0 and strike < frames.get_frame_count(a), "%s strike frame %d inside the animation" % [a, strike])
	eq(frames.get_animation_speed("idle_s"), 4.0, "idle 4 fps")
	eq(frames.get_animation_speed("walk_se"), 8.0, "walk 8 fps")
	eq(frames.get_animation_speed("run_sw"), 12.0, "run 12 fps")
	eq(frames.get_animation_speed("dash_e"), 14.0, "dash 14 fps")
	eq(frames.get_animation_speed("attack"), 12.0, "melee 12 fps")
	eq(frames.get_animation_speed("heavy"), 10.0, "heavy 10 fps")
	eq(frames.get_animation_speed("cast"), 8.0, "cast 8 fps")
	eq(frames.get_animation_speed("hit"), 8.0, "hurt 8 fps")
	eq(frames.get_animation_speed("ko"), 6.0, "death 6 fps")
	var size: Vector2 = frames.get_frame_texture("idle_s", 0).get_size()
	var same := true
	for n in frames.get_animation_names():
		for i in frames.get_frame_count(n):
			same = same and frames.get_frame_texture(n, i).get_size() == size
	ok(same, "every frame is on the same canvas (one feet anchor: no jitter between animations)")
	for fx in ["slash", "eruption", "circle", "burst", "smoke"]:
		ok(m.effects.has(fx) and not m.effects[fx].frames.is_empty(), "effect %s" % fx)
	ok(UnitLook.portrait("king") != null, "portrait")


func king_view() -> void:
	var v := UnitView3D.new()
	add_child(v)
	v.setup("king")
	var s := v.sprite
	var want := {Vector2(0, 1): "s", Vector2(1, 1): "s", Vector2(1, 0): "e", Vector2(1, -1): "n",
		Vector2(0, -1): "n", Vector2(-1, -1): "n", Vector2(-1, 0): "w", Vector2(-1, 1): "s"}
	v.play("walk")
	for d in want:
		v.face(d)
		eq(String(s.animation), "walk_" + want[d], "walking toward %s" % want[d])
		ok(not s.flip_h, "directional frames are never mirrored (%s)" % want[d])
	v.face(Vector2.ZERO)
	eq(String(s.animation), "walk_s", "no direction keeps the last facing")
	v.play("idle")
	eq(String(s.animation), "idle_s", "stopping keeps the facing")
	# no restart when asked again
	v.play("walk")
	s.frame = 3
	v.play("walk")
	eq(s.frame, 3, "asking for the playing animation does not restart it")
	# one-shots, strike frame, hurt interrupting
	var hits := []
	v.struck.connect(func(a): hits.append(a))
	v.face(Vector2(-1, 0.2))
	ok(v.act("attack"), "attack starts")
	eq(String(s.animation), "attack", "melee combo")
	ok(s.flip_h, "the attack (drawn facing right) is mirrored to face left")
	ok(not v.act("heavy"), "another action does not cut into a running one")
	s.frame = int(Character.meta("king").anims.attack.strike)
	eq(hits, ["attack"], "struck on the strike frame")
	s.frame = int(Character.meta("king").anims.attack.strike) + 1
	eq(hits.size(), 1, "struck only once")
	ok(v.act("hit"), "hurt interrupts")
	eq(String(s.animation), "hit", "hurt plays")
	s.animation_finished.emit()
	eq(String(s.animation), "walk_w", "after the hurt: back to the movement in the same direction")
	# death holds
	v.play("ko")
	eq(String(s.animation), "ko", "death plays")
	ok(not v.act("hit"), "nothing plays over a knocked-out unit")
	s.animation_finished.emit()
	eq(String(s.animation), "ko", "death holds its last frame")
	v.play("idle")
	eq(String(s.animation), "idle_w", "revived")
	ok(v.spawn_fx("eruption", Vector3.ZERO) != null, "effects play from the sheet")
	await get_tree().process_frame
	v.queue_free()


## The sheet's bottom section: effects, portraits, palettes, sword, illustration, recolored sets.
func extras() -> void:
	var m := Character.meta("king")
	for fx in ["swirl", "slash", "rend", "eruption", "circle", "burst", "smoke"]:
		ok(m.effects.has(fx) and not m.effects[fx].frames.is_empty(), "effect %s" % fx)
		for f in m.effects[fx].frames:
			var img: Image = load(CharacterLook.dir("king") + f).get_image()
			ok(img.get_width() > 8 and img.get_height() > 8, "%s has a size" % f)
			# the keyed effect must keep its glow and show no magenta background
			var pink := 0
			var opaque := 0
			for y in range(0, img.get_height(), 2):
				for x in range(0, img.get_width(), 2):
					var c := img.get_pixel(x, y)
					if c.a > 0.8:
						opaque += 1
						if c.r > 0.85 and c.b > 0.78 and c.g < 0.27:
							pink += 1
			ok(opaque > 10 and pink < 4, "%s: %d opaque, %d magenta-looking" % [f, opaque, pink])
	eq(m.portraits.size(), 5, "five portraits")
	for p in m.portraits:
		var t: Texture2D = load(CharacterLook.dir("king") + p)
		ok(t != null and t.get_width() > 80 and t.get_height() > 80, "%s is cut at its own size" % p)
	ok(CharacterLook.illustration("king").get_width() > 150 and CharacterLook.weapon("king").get_height() > 200, "illustration and sword")
	eq(CharacterLook.looks("king").size(), 9, "nine looks")
	var orig_meta := Character.meta("king")
	var base_frames: SpriteFrames = load("res://assets/characters/king.tres")
	for p in CharacterLook.looks("king"):
		var info := CharacterLook.info("king", p)
		eq(info.swatches.size(), 4, "%s: four swatches" % p)
		ok(CharacterLook.portrait("king", p) != null, "%s portrait" % p)
		if p == "original":
			continue
		var sheet: String = "king_" + p
		var fr: SpriteFrames = load("res://assets/characters/%s.tres" % sheet)
		var meta := Character.meta(sheet)
		eq(meta.size, orig_meta.size, "%s: same canvas (one feet anchor)" % p)
		for a in ["idle_s", "walk_se", "run_w", "attack", "heavy", "cast", "hit", "ko"]:
			eq(fr.get_frame_count(a), base_frames.get_frame_count(a), "%s %s: same frames" % [p, a])
		# really a different look: the outfit's average colour moved
		var ca := _mean_color(base_frames.get_frame_texture("idle_s", 0))
		var cb := _mean_color(fr.get_frame_texture("idle_s", 0))
		var d: float = Vector3(ca.r - cb.r, ca.g - cb.g, ca.b - cb.b).length()
		ok(d > 0.04, "%s is recolored (%.3f)" % [p, d])
		# the silhouette (alpha) is untouched
		var a0 := base_frames.get_frame_texture("walk_e", 1).get_image()
		var a1 := fr.get_frame_texture("walk_e", 1).get_image()
		var same := true
		for y in range(0, a0.get_height(), 2):
			for x in range(0, a0.get_width(), 2):
				if not is_equal_approx(a0.get_pixel(x, y).a, a1.get_pixel(x, y).a):
					same = false
		ok(same, "%s keeps the silhouette" % p)
	# a portrait alone does not change the in-game look; the palette does
	var k := KingData.new()
	eq(UnitLook.sheet_for(k), "king", "default look")
	k.palette = &"red"
	eq(UnitLook.sheet_for(k), "king_red", "a palette chooses the sheet")
	ok(UnitLook.portrait("king_red") == null or UnitLook.portrait("king_red").get_width() > 30, "the portrait follows")
	k.palette = &"nonsense"
	eq(UnitLook.sheet_for(k), "king", "an unknown palette is the original")


func _mean_color(t: Texture2D) -> Color:
	var img := t.get_image()
	var sum := Vector3.ZERO
	var n := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if c.a > 0.9:
				sum += Vector3(c.r, c.g, c.b)
				n += 1
	sum /= maxf(n, 1)
	return Color(sum.x, sum.y, sum.z)


func appearance() -> void:
	var k := SampleParty.make().king
	var m := AppearanceMenu.new()
	add_child(m)
	await get_tree().process_frame
	m.open(k)
	eq(m.swatch_buttons.size(), 9, "nine look buttons")
	m.choose("blue")
	eq(k.palette, &"blue", "choosing sets the King's look")
	eq(UnitLook.sheet_for(k), "king_blue", "and his battle sprite")
	eq(m.sprite.sprite_frames, load("res://assets/characters/king_blue.tres"), "the preview plays the recolored frames")
	ok(m.no_art.visible, "no large illustration for other looks")
	m.choose("original")
	ok(not m.no_art.visible, "the original has one")
	m.choose("bogus")
	eq(k.palette, &"original", "an unknown look is ignored")
	# the look is saved
	var g := SaveGame.new_game()
	g.roster.king.palette = &"green"
	var back := SaveCodec.decode(SaveCodec.encode(g))
	ok(back.ok and back.game.roster.king.palette == &"green", "the look survives a save")
	var raw := SaveCodec.encode(g)
	raw.king.palette = "../../etc"
	eq(SaveCodec.decode(raw).game.roster.king.palette, &"original", "a bad name in a save falls back")
	m.queue_free()


## The five other full sheets: complete animation sets, looks, extras, and who wears them.
func roster_sheets() -> void:
	var frames_names := ["idle", "walk", "run", "dash"]
	for base in ["vesper", "mira", "squire", "choir", "wraith"]:
		var m := Character.meta(base)
		ok(m.get("eight_dir", false), "%s is a directional sheet" % base)
		var fr: SpriteFrames = load("res://assets/characters/%s.tres" % base)
		for mv in frames_names:
			for d in ["s", "se", "e", "ne", "n", "nw", "w", "sw"]:
				ok(fr.has_animation("%s_%s" % [mv, d]) and fr.get_frame_count("%s_%s" % [mv, d]) >= (1 if mv == "idle" else 2), "%s %s_%s" % [base, mv, d])
		for a in ["attack", "heavy", "cast", "hit", "ko"]:
			ok(fr.has_animation(a) and fr.get_frame_count(a) >= 2, "%s %s" % [base, a])
		var size: Vector2 = fr.get_frame_texture("idle_s", 0).get_size()
		ok(fr.get_frame_texture("ko", 0).get_size() == size and fr.get_frame_texture("dash_e", 0).get_size() == size, "%s: one canvas" % base)
		eq(m.portraits.size(), 5, "%s: five portraits" % base)
		ok(CharacterLook.illustration(base) != null and CharacterLook.weapon(base) != null, "%s: illustration and weapon" % base)
		for fx in ["slash", "eruption", "burst", "smoke"]:
			ok(m.effects.has(fx), "%s effect %s" % [base, fx])
		var looks := CharacterLook.looks(base)
		eq(looks.size(), 8, "%s: eight looks" % base)
		for p in looks.slice(1):
			var sheet: String = "%s_%s" % [base, p]
			ok(ResourceLoader.exists("res://assets/characters/%s.tres" % sheet), "%s look %s has its frames" % [base, p])
			eq(Character.meta(sheet).size, m.size, "%s look %s: same canvas" % [base, p])
	eq(Character.meta("choir").anims.attack.native, "right", "the mage's attack is drawn facing right")
	eq(Character.meta("mira").anims.attack.native, "left", "Lyra's attack is drawn facing left")
	var party := SampleParty.make()
	eq(UnitLook.sheet_for(party.co_captains[0]), "mira", "Lyra")
	eq(UnitLook.sheet_for(party.co_captains[1]), "vesper", "Vesper")
	var vs := party.vessels()
	eq([UnitLook.sheet_for(vs[0]), UnitLook.sheet_for(vs[1]), UnitLook.sheet_for(vs[2])], ["squire", "choir", "wraith"], "the vessels' sheets")
	vs[1].palette = &"teal"
	eq(UnitLook.sheet_for(vs[1]), "choir_teal", "a vessel's look")
	var e := EnemyData.new()
	e.display_name = "Grimkin"
	ok(UnitLook.ENEMY_SHEETS.has(UnitLook.sheet_for(e)), "enemies are drawn with the Ashen Squire sheet")
	# Appearance for a vessel, saved
	var menu := AppearanceMenu.new()
	add_child(menu)
	await get_tree().process_frame
	menu.open(vs[2])
	eq(menu.swatch_buttons.size(), 8, "eight looks for the wolf")
	menu.choose("blue")
	eq(vs[2].palette, &"blue", "the wolf's look")
	var g := SaveGame.new_game()
	g.roster.vessels()[2].palette = &"blue"
	g.roster.co_captains[0].palette = &"purple"
	var back := SaveCodec.decode(SaveCodec.encode(g)).game
	ok(back.roster.vessels()[2].palette == &"blue" and back.roster.co_captains[0].palette == &"purple", "looks survive a save")
	menu.queue_free()


func legacy_view() -> void:
	var v := UnitView3D.new()
	add_child(v)
	v.setup("knight")  # an older front/back sheet
	v.play("walk")
	v.face(Vector2(-1, -1))
	eq(String(v.sprite.animation), "walk_b", "older sheets: back frames when facing up")
	v.face(Vector2(1, 1))
	eq(String(v.sprite.animation), "walk_f", "front frames when facing down")
	v.play("run")
	eq(String(v.sprite.animation), "walk_f", "no run in the sheet: walk")
	ok(v.act("heavy") and String(v.sprite.animation) == "attack", "no heavy in the sheet: the attack")
	v.queue_free()
