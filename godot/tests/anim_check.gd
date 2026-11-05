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
	extras()
	no_variants()
	standard_size()
	tile_fit()
	await directional_attacks()
	frames_built()
	await villagers()
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
		for d in ["s", "e", "n", "w"]:
			var n := "%s_%s" % [move, d]
			ok(frames.has_animation(n) and frames.get_frame_count(n) >= (1 if move == "idle" else 3), "%s has frames" % n)
			ok(frames.get_animation_loop(n), "%s loops" % n)
	for a in ["attack", "heavy", "cast", "hit", "ko"]:
		ok(frames.has_animation(a) and not frames.get_animation_loop(a), "%s is a one-shot" % a)
	for a in ["attack", "heavy", "cast"]:
		var strike := int(m.anims[a].strike)
		ok(strike > 0 and strike < frames.get_frame_count(a), "%s strike frame %d inside the animation" % [a, strike])
	eq(frames.get_animation_speed("idle_s"), 4.0, "idle 4 fps")
	eq(frames.get_animation_speed("walk_e"), 8.0, "walk 8 fps")
	eq(frames.get_animation_speed("run_w"), 12.0, "run 12 fps")
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
	eq(String(s.animation), "attack_w", "the King's melee swings the way he faces (his own left-facing frames)")
	ok(not s.flip_h, "and is not mirrored")
	ok(not v.act("heavy"), "another action does not cut into a running one")
	s.frame = int(Character.meta("king").anims.attack_w.strike)
	eq(hits, ["attack"], "struck on the strike frame")
	s.frame = int(Character.meta("king").anims.attack_w.strike) + 1
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


## The sheet's bottom section: effects, portraits, sword, illustration.
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


## The colour variations are removed (the owner's decision): no recolored sheets or palettes, every unit is
## drawn from its own sheet, and a save written while units had a look still loads.
func no_variants() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/meta.json"))
	var left := meta.keys().filter(func(k): return meta[k].has("palette") or meta[k].has("palettes"))
	eq(left, [], "no colour variations in meta.json")
	for base in ["king", "vesper", "mira", "squire", "choir", "wraith"]:
		ok(not DirAccess.dir_exists_absolute(CharacterLook.dir(base) + "palettes"), "%s has no palettes folder" % base)
	ok(not ResourceLoader.exists("res://assets/characters/king_red.tres"), "no recolored King")
	eq(UnitLook.sheet_for(KingData.new()), "king", "the King is drawn from his sheet")
	var g := SaveGame.new_game()
	var raw := SaveCodec.encode(g)
	ok(not raw.king.has("palette"), "a save stores no look")
	raw.king["palette"] = "red"  # written by an older version
	var back := SaveCodec.decode(raw)
	ok(back.ok and UnitLook.sheet_for(back.game.roster.king) == "king", "an older save with a look loads, drawn from the King's sheet")


## Every character's SpriteFrames (.tres) holds the frames meta.json lists: re-cut art needs tools/build_resources.gd,
## or the game plays the old frames.
func frames_built() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/meta.json"))
	for ch in meta:
		var fr: SpriteFrames = load("res://assets/characters/%s.tres" % ch)
		var same := true
		for a in meta[ch].anims:
			var want: Array = meta[ch].anims[a].frames
			if not fr.has_animation(a) or fr.get_frame_count(a) != want.size():
				same = false
				continue
			for i in want.size():
				if fr.get_frame_texture(a, i).resource_path != "res://assets/characters/%s/%s" % [ch, want[i]]:
					same = false
		ok(same, "%s.tres matches meta.json (run tools/build_resources.gd)" % ch)


## The owner's size standard: every character with the new idle and walk is drawn as tall as the King
## (idle figure px x meta.scale = idle_walk_sheet.STANDARD_FIGURE, 120).
func standard_size() -> void:
	for ch in ["king", "mira", "squire", "sorc", "robin", "redwolf", "warden", "vesper", "wraith", "merc", "villager_man", "villager_girl", "villager_kid", "mechanic"]:
		var fr: SpriteFrames = load("res://assets/characters/%s.tres" % ch)
		var hs: Array = []
		for d in ["s", "e", "n", "w"]:
			var img := fr.get_frame_texture("idle_" + d, 0).get_image()
			var r := img.get_used_rect()
			hs.append(r.size.y)
		hs.sort()
		var drawn: float = (hs[1] + hs[2]) / 2.0 * float(Character.meta(ch).scale)
		ok(absf(drawn - 120.0) <= 2.0, "%s is drawn as tall as the King (%.1f px, want 120)" % [ch, drawn])


## The owner's tile rule (Nov 2026): every unit fits inside one tile and none is taller than the King. The Eater and the Boar are
## scaled to the tile (idle and walk frames at most TILE_WIDTH wide), so they are much shorter than the King. A tile is 90.5 in
## these units (frame px x meta.scale). Lunar, the Red Wolf and the Sorceress were drawn before the rule and are wider in idle: not
## changed without the owner's say.
const ENEMY_NINE := ["stone_colossus", "forest_wolf", "moss_slime", "goblin_scavenger", "ironhollow_sentinel", "ashen_wyvern", "hollowmark_assassin", "riverband_brute", "hooded_cutthroat", "soul_warden"]
const ENEMY_NAMES := [["Stone Colossus", "stone_colossus"], ["Forest Wolf", "forest_wolf"], ["Moss Slime", "moss_slime"], ["Goblin Scavenger", "goblin_scavenger"],
	["Ironhollow Sentinel", "ironhollow_sentinel"], ["Ashen Wyvern", "ashen_wyvern"], ["Hollowmark Assassin", "hollowmark_assassin"],
	["Riverband Brute", "riverband_brute"], ["Hooded Cutthroat", "hooded_cutthroat"], ["Soul Warden", "soul_warden"]]


func tile_fit() -> void:
	for ch in ["eater", "boar"] + ENEMY_NINE:
		var fr: SpriteFrames = load("res://assets/characters/%s.tres" % ch)
		var sc: float = float(Character.meta(ch).scale)
		var w := 0
		var h := 0
		for kind in ["idle", "walk"]:
			for d in ["s", "e", "n", "w"]:
				var a: String = kind + "_" + d
				for i in fr.get_frame_count(a):
					var r := fr.get_frame_texture(a, i).get_image().get_used_rect()
					w = maxi(w, r.size.x)
					h = maxi(h, r.size.y)
		ok(float(w) * sc <= 90.5, "%s fits one tile (%.1f wide, tile 90.5)" % [ch, float(w) * sc])
		ok(float(h) * sc <= 122.0, "%s is no taller than the King (%.1f, King 120)" % [ch, float(h) * sc])


## The Ashen Squire, the King, Vesper, Lunar and the Sorceress swing the way they face: a four-frame attack for each of the four directions (the
## owner's sheets, tools/art/attack_sheet.py), picked by the animator, never mirrored, the strike on the slash frame,
## drawn at their size with their feet where their idle's are.
func directional_attacks() -> void:
	for ch in ["squire", "king", "vesper", "wraith", "sorc", "eater", "boar", "merc"] + ENEMY_NINE:
		var m := Character.meta(ch)
		var fr: SpriteFrames = load("res://assets/characters/%s.tres" % ch)
		for d in ["s", "e", "n", "w"]:
			var n: String = "attack_" + d
			ok(fr.has_animation(n) and fr.get_frame_count(n) == 4 and not fr.get_animation_loop(n), "%s %s is a four-frame one-shot" % [ch, n])
			eq(int(m.anims[n].strike), 2, "%s %s strikes on the slash frame" % [ch, n])
			var idle := fr.get_frame_texture("idle_" + d, 0).get_image().get_used_rect()
			var rest := fr.get_frame_texture(n, 0).get_image().get_used_rect()
			ok(absi((idle.position.y + idle.size.y) - (rest.position.y + rest.size.y)) <= 3, "%s %s: feet on the idle's row (%s vs %s)" % [ch, n, idle, rest])
			ok(absf(float(rest.size.y) - float(idle.size.y)) <= 12.0, "%s %s: as tall as the idle (%d vs %d px)" % [ch, n, rest.size.y, idle.size.y])
		var v := UnitView3D.new()
		add_child(v)
		v.setup(ch)
		ok(v.slash_in_frames(), "%s: his arc is in his frames, so the game adds no slash on top" % ch)
		var s := v.sprite
		for want in {Vector2(1, 0): "e", Vector2(-1, 0): "w", Vector2(0, 1): "s", Vector2(0, -1): "n"}.keys():
			v.face(want)
			ok(v.act("attack"), "%s attack starts" % ch)
			eq(String(s.animation), "attack_" + SpriteAnimator.dir_of(want), "%s attacking toward %s" % [ch, want])
			ok(not s.flip_h, "%s's attack is never mirrored (%s)" % [ch, want])
			s.animation_finished.emit()
		await get_tree().process_frame
		v.queue_free()


## The villagers and the mechanic (NpcLook): scene fillers with only idle and walk, in four directions, drawn at the King's height.
func villagers() -> void:
	eq(NpcLook.SHEETS, ["villager_man", "villager_girl", "villager_kid", "mechanic"] as Array[String], "the four NPC sheets, in the order the owner sent them")
	for ch in NpcLook.SHEETS:
		var m := Character.meta(ch)
		var fr: SpriteFrames = load("res://assets/characters/%s.tres" % ch)
		var frames := 4 if ch == "mechanic" else 5
		for d in ["s", "e", "n", "w"]:
			for kind in ["idle", "walk", "run"]:
				var n := "%s_%s" % [kind, d]
				ok(fr.has_animation(n) and fr.get_frame_count(n) == frames and fr.get_animation_loop(n), "%s %s: %d looping frames" % [ch, n, frames])
		ok(not fr.has_animation("attack") and not fr.has_animation("attack_s"), "%s has no attacks: it is not a battle unit" % ch)
		ok(NpcLook.is_npc(ch) and not NpcLook.is_npc("king"), "%s is an NPC" % ch)
		ok(UnitLook.portrait(ch) != null, "%s has a portrait for the dialogue box" % ch)
		# every frame is cut cleanly: no magenta left, the feet on one row
		var bottoms: Array = []
		for d in ["s", "e", "n", "w"]:
			for k in frames:
				var img := fr.get_frame_texture("walk_" + d, k).get_image()
				var r := img.get_used_rect()
				ok(r.size.y > 40 and r.size.x > 12, "%s walk_%s frame %d has a figure (%s)" % [ch, d, k, r])
				bottoms.append(r.position.y + r.size.y)
				var magenta := 0
				for y in range(r.position.y, r.position.y + r.size.y):
					for x in range(r.position.x, r.position.x + r.size.x):
						var c := img.get_pixel(x, y)
						if c.a > 0.5 and c.r > 0.9 and c.b > 0.85 and c.g < 0.35:
							magenta += 1
				ok(magenta == 0, "%s walk_%s frame %d: no magenta left" % [ch, d, k])
		bottoms.sort()
		ok(bottoms[-1] - bottoms[0] <= 6, "%s: the feet stay on one row in every frame (%d to %d)" % [ch, bottoms[0], bottoms[-1]])
		# on the board: it walks and runs facing the way it goes, and stands idle
		var v := UnitView3D.new()
		add_child(v)
		v.setup(ch)
		for want in {Vector2(1, 0): "e", Vector2(-1, 0): "w", Vector2(0, 1): "s", Vector2(0, -1): "n"}.keys():
			v.face(want)
			v.play("walk")
			eq(String(v.sprite.animation), "walk_" + SpriteAnimator.dir_of(want), "%s walking toward %s" % [ch, want])
			v.play("run")
			eq(String(v.sprite.animation), "run_" + SpriteAnimator.dir_of(want), "%s running toward %s" % [ch, want])
			ok(not v.sprite.flip_h, "%s is never mirrored (%s)" % [ch, want])
		v.play("idle")
		ok(String(v.sprite.animation).begins_with("idle_"), "%s idles" % ch)
		await get_tree().process_frame
		v.queue_free()


## The five other full sheets: complete animation sets, extras, and who wears them.
func roster_sheets() -> void:
	var frames_names := ["idle", "walk", "run", "dash"]
	for base in ["vesper", "mira", "squire", "choir", "wraith"]:
		var m := Character.meta(base)
		ok(m.get("eight_dir", false), "%s is a directional sheet" % base)
		var fr: SpriteFrames = load("res://assets/characters/%s.tres" % base)
		for mv in frames_names:
			for d in ["s", "e", "n", "w"]:
				ok(fr.has_animation("%s_%s" % [mv, d]) and fr.get_frame_count("%s_%s" % [mv, d]) >= (1 if mv == "idle" else 2), "%s %s_%s" % [base, mv, d])
		for a in ["attack", "heavy", "cast", "hit", "ko"]:
			ok(fr.has_animation(a) and fr.get_frame_count(a) >= 2, "%s %s" % [base, a])
		var size: Vector2 = fr.get_frame_texture("idle_s", 0).get_size()
		ok(fr.get_frame_texture("ko", 0).get_size() == size and fr.get_frame_texture("dash_e", 0).get_size() == size, "%s: one canvas" % base)
		eq(m.portraits.size(), 5, "%s: five portraits" % base)
		ok(CharacterLook.illustration(base) != null and CharacterLook.weapon(base) != null, "%s: illustration and weapon" % base)
		for fx in ["slash", "eruption", "burst", "smoke"]:
			ok(m.effects.has(fx), "%s effect %s" % [base, fx])
	eq(Character.meta("choir").anims.attack.native, "right", "the mage's attack is drawn facing right")
	eq(Character.meta("mira").anims.attack.native, "left", "Lyra's attack is drawn facing left")
	var party := SampleParty.make()
	eq(UnitLook.sheet_for(party.co_captains[0]), "sorc", "the Sorceress")
	eq(UnitLook.sheet_for(SampleParty.lyra()), "mira", "Lyra, a vessel")
	var vesper := EnemyData.new()
	vesper.display_name = "Vesper"
	eq(UnitLook.sheet_for(vesper), "vesper", "Vesper is an enemy character: she is drawn with her own sheet")
	ok(CharacterLook.base_of(SampleParty.make().co_captains[1]) != "vesper", "and no party unit wears her sheet")
	var vs := party.vessels()
	eq([UnitLook.sheet_for(vs[0]), UnitLook.sheet_for(vs[1]), UnitLook.sheet_for(vs[2])], ["squire", "choir", "wraith"], "the vessels' sheets")
	var e := EnemyData.new()
	e.display_name = "Grimkin"
	ok(UnitLook.ENEMY_SHEETS.has(UnitLook.sheet_for(e)), "enemies are drawn with the Ashen Squire sheet")
	var robin := EnemyData.new()
	robin.display_name = "Robin"
	eq(UnitLook.sheet_for(robin), "robin", "Robin is an enemy with his own sheet")
	var rm := Character.meta("robin")
	var rf: SpriteFrames = load("res://assets/characters/robin.tres")
	for a in ["idle_s", "walk_e", "run_w", "attack", "heavy", "cast", "hit", "ko"]:
		ok(rf.has_animation(a) and rf.get_frame_count(a) >= 1, "robin %s" % a)
	eq(rm.portraits.size(), 5, "robin: five portraits")
	ok(CharacterLook.illustration("robin") != null and CharacterLook.weapon("robin") != null, "robin: illustration and sword")
	var bram: VesselData = party.vessels().filter(func(v): return v.display_name == "Bram")[0]
	eq(UnitLook.sheet_for(bram), "warden", "Bram (the vessel once called Warden) is drawn from the warden sheet")
	var wolf := EnemyData.new()
	wolf.display_name = "Red Wolf"
	eq(UnitLook.sheet_for(wolf), "redwolf", "the Red Wolf is an enemy with his own sheet")
	var wf: SpriteFrames = load("res://assets/characters/redwolf.tres")
	for a in ["idle_s", "walk_w", "run_e", "attack", "heavy", "cast", "hit", "ko"]:
		ok(wf.has_animation(a) and wf.get_frame_count(a) >= 1, "redwolf %s" % a)
	eq(Character.meta("redwolf").portraits.size(), 5, "redwolf: five portraits")
	ok(CharacterLook.illustration("redwolf") != null and CharacterLook.weapon("redwolf") == null, "redwolf: illustration, no weapon")
	var eater := EnemyData.new()
	eater.display_name = "Eater"
	eq(UnitLook.sheet_for(eater), "eater", "the Eater is an enemy with its own sheet")
	var ef: SpriteFrames = load("res://assets/characters/eater.tres")
	for a in ["idle_s", "idle_n", "walk_w", "run_e", "dash_s", "attack", "heavy", "cast", "hit", "ko"]:
		ok(ef.has_animation(a) and ef.get_frame_count(a) >= 1, "eater %s" % a)
	eq(Character.meta("eater").portraits.size(), 5, "eater: five portraits")
	ok(CharacterLook.illustration("eater") != null and CharacterLook.weapon("eater") == null, "eater: illustration, no weapon")
	for pair in ENEMY_NAMES:  # the nine enemy sheets (tools/art/enemy_sheets.py): each is an enemy with its own sheet, portrait and illustration
		var foe := EnemyData.new()
		foe.display_name = pair[0]
		eq(UnitLook.sheet_for(foe), pair[1], "%s is an enemy with its own sheet" % pair[0])
		var ff: SpriteFrames = load("res://assets/characters/%s.tres" % pair[1])
		for a in ["idle_s", "idle_n", "idle_w", "idle_e", "walk_s", "walk_w", "run_e", "dash_n", "attack", "attack_e", "heavy", "cast", "hit", "ko"]:
			ok(ff.has_animation(a) and ff.get_frame_count(a) >= 1, "%s %s" % [pair[1], a])
		ok(CharacterLook.illustration(pair[1]) != null and UnitLook.portrait(pair[1]) != null, "%s: illustration and portrait" % pair[1])
	var boar := EnemyData.new()
	boar.display_name = "Boar"
	eq(UnitLook.sheet_for(boar), "boar", "the Boar is an enemy with its own sheet")
	var bf: SpriteFrames = load("res://assets/characters/boar.tres")
	for a in ["idle_s", "walk_w", "run_e", "dash_n", "attack", "heavy", "cast_w", "hit_e", "ko_n"]:
		ok(bf.has_animation(a) and bf.get_frame_count(a) >= 1, "boar %s" % a)
	ok(CharacterLook.illustration("boar") != null and CharacterLook.weapon("boar") == null, "boar: illustration, no weapon")
	var mf: SpriteFrames = load("res://assets/characters/merc.tres")
	for a in ["idle_s", "walk_w", "run_e", "dash_n", "attack", "heavy", "cast", "hit", "ko", "attack_w"]:
		ok(mf.has_animation(a) and mf.get_frame_count(a) >= 1, "merc %s" % a)
	eq(CharacterLook.BY_ID.get(&"merc"), "merc", "Merc (a vessel) is drawn from the merc sheet")
	ok(CharacterLook.illustration("merc") != null, "merc: illustration")
