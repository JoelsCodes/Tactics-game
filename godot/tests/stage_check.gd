extends Node
## Headless checks for the battle screen (scenes/battle.tscn): HUD contents, taps, highlights, summoning,
## the end of the battle. godot --headless --path godot res://tests/stage_check.tscn

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
	SaveSystem.dir = "user://test_saves_stage"
	for f in DirAccess.get_files_at(SaveSystem.dir) if DirAccess.dir_exists_absolute(SaveSystem.dir) else PackedStringArray():
		DirAccess.remove_absolute(SaveSystem.dir + "/" + f)
	edge_flags()
	looks()
	await stage()
	await map_limit()
	print("stage checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func edge_flags() -> void:
	# a 2x1 region: the shared edge is inside, the rest is border (grid space: r -y, g +x, b +y, a -x)
	var region := {Vector2i(1, 1): true, Vector2i(2, 1): true}
	eq(TileHighlights.edge_flags(region, Vector2i(1, 1)), Color(1, 0, 1, 1), "the +x neighbour is shared")
	eq(TileHighlights.edge_flags(region, Vector2i(2, 1)), Color(1, 1, 1, 0), "the other tile: its -x edge is shared")
	eq(TileHighlights.edge_flags({Vector2i(0, 0): true}, Vector2i(0, 0)), Color(1, 1, 1, 1), "a lone tile is all border")


func looks() -> void:
	var p := SampleParty.make()
	eq(UnitLook.sheet_for(p.king), "king", "the King is the king sheet")
	ok(UnitLook.portrait("king") != null and UnitLook.portrait("king").get_width() > 64, "the King's painted portrait")
	eq(UnitLook.sheet_for(p.co_captains[0]), "mira", "Mira has her own sheet")
	var other := CoCaptainData.new()
	other.id = &"someone"
	eq(UnitLook.sheet_for(other), "knight", "other Co-Captains are the knight")
	eq(UnitLook.sheet_for(p.vessels()[0]), "squire", "vessels with a full sheet use it")
	var stray := VesselData.new()
	stray.display_name = "Stray"
	ok(UnitLook.VESSEL_SHEETS.has(UnitLook.sheet_for(stray)), "other vessels pick an old sheet")
	eq(UnitLook.tint_for(p.king).a, 0.0, "no tint on the King")
	ok(UnitLook.tint_for(p.vessels()[0]).a > 0, "vessels are tinted")
	var e := EnemyData.new()
	e.display_name = "Grimkin"
	ok(UnitLook.ENEMY_SHEETS.has(UnitLook.sheet_for(e)) and UnitLook.tint_for(e) == UnitLook.ENEMY_TINT, "enemy look")
	var por := UnitLook.portrait("hero")
	ok(por is AtlasTexture and por.region.size == Vector2(72, 72), "portrait crop")


## A map sets its own summon limit.
func map_limit() -> void:
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://samples/demo_battlefield.json"))
	eq(map.get("max_summons"), 6.0, "the demo map allows six summons")
	map["max_summons"] = 2
	var f := FileAccess.open("user://test_map_limit.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(map))
	f.close()
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.map_path = "user://test_map_limit.json"
	s.enemy_delay = 0.0
	s.animate = false
	add_child(s)
	await get_tree().process_frame
	eq(s.battle.deployment.summon_limit, 2, "the stage reads max_summons from the map")
	var dm := s.battle.deployment
	var king := dm.king
	var vs := s.game.roster.vessels()
	var spots: Array = dm.props.keys()
	while s.battle.current != king:
		s.end_turn()
		await until_player(s)
	king.cell = king.cell  # (the sample relics are within range of the King's start)
	var made := 0
	for i in 3:
		var spot = spots.filter(func(c): return dm.can_summon(vs[i], c) or dm.summon_error(vs[i], c) == "summon limit reached (2)")
		if spot.is_empty():
			break
		if s.battle.summon_vessel(king, vs[i], spot[0]) != null:
			made += 1
	eq(made, 2, "two summons, then the map's limit")
	eq(dm.summons_left(), 0, "none left")
	s.queue_free()
	DirAccess.remove_absolute("user://test_map_limit.json")


func make_stage() -> BattleStage:
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 0.0
	s.animate = false
	add_child(s)
	s.battle.miss_chance = 0.0  # every hit lands: these checks read the damage
	return s


func until_player(s: BattleStage) -> void:
	var n := 0
	while s.battle.current != null and s.battle.current.team != 0 and n < 200:
		await get_tree().process_frame
		n += 1


func stage() -> void:
	var s := make_stage()
	await get_tree().process_frame
	await until_player(s)
	var b := s.battle
	var cur := b.current
	ok(cur != null and cur.team == 0, "a player unit acts")
	# HUD: turn order, status card, palette
	var bar := s.hud.turn_order
	eq(bar.entries, b.turns.upcoming(bar.count), "the turn order shows TurnManager.upcoming")
	eq(bar.entries[0], cur, "the acting unit first")
	ok(bar.entries.any(func(u): return u.data is EnemyData), "enemies are in the queue")
	var card := s.hud.card
	eq(card.unit, cur, "the status card shows the acting unit")
	eq(card.name_label.text, cur.data.display_name.to_upper(), "card name")
	ok(card.class_label.text.begins_with(UnitStatusCard._class_name(cur.data)), "card title starts with the role: %s" % card.class_label.text)
	ok(card.portrait.texture != null, "card portrait")
	eq(card.level_label.text, "LVL %d" % cur.data.level, "card level")
	ok(not s.hud.target_card.visible, "no target card at the start of a turn")
	eq(card.hp_text.text, "%d / %d" % [cur.hp, cur.max_hp()], "card HP")
	eq(card.sp_text.text, "%d / %d" % [cur.sp, cur.max_sp()], "card SP")
	eq(card.xp_text.text, "%d / %d" % [cur.data.exp, cur.data.exp_to_next_level], "card XP")
	ok(not card.tactical.visible, "no vessel data for a human")
	ok(s.hud.result_panel.material is ShaderMaterial, "HUD panels are frosted glass")
	ok(s.board.env.ssao_enabled and s.board.env.volumetric_fog_enabled and s.board.env.adjustment_color_correction == null, "SSAO, volumetric light, natural grade by default")
	ok(s.board.get_node_or_null("Dust") is GPUParticles3D and s.board.get_node_or_null("Mist") != null, "dust motes and floor mist")
	var pal := s.hud.palette
	eq(pal.state, CommandPalette.State.COMMANDS, "commands shown")
	eq(pal.end_button.text, "WAIT", "nothing done yet: Wait")
	ok(not pal.cancel_button.visible, "no Cancel at the start of a turn")
	eq(s.hud.turn_label.text, "TURN 1", "the TURN banner")
	ok(s.hud.objective_label.text.contains("Defeat all enemies"), "the objective")
	var side_slot: Button = pal.summon_button if cur.is_king() else pal.defend_button
	for btn in [pal.attack_button, pal.abilities_button, pal.items_button, side_slot, pal.end_button, pal.move_button]:
		ok(btn.visible and btn.icon != null, "command slot %s" % btn.text)
	ok(pal.summon_button.visible == cur.is_king() and pal.defend_button.visible != cur.is_king(), "the King has SUMMON where others have DEFEND")
	ok(pal.items_button.disabled and not pal.attack_button.disabled, "Items greyed out; Attack ready")
	eq(s.hud.turn_order.now_frame != null, true, "the acting portrait is marked")
	pal.move_pressed.emit()
	eq(pal.state, CommandPalette.State.AIMING, "MOVE shows the walk hint")
	ok(not s.highlights.shown(TileHighlights.Kind.MOVE).is_empty(), "MOVE shows the walkable tiles")
	pal.cancel_button.pressed.emit()
	# moving: the walkable tiles glow; tapping one walks there
	eq(s.mode, BattleStage.Mode.MOVE, "move mode")
	var move := s.highlights.shown(TileHighlights.Kind.MOVE)
	var reach := b.move_range(cur).cells().filter(func(c): return c != cur.cell)
	eq(move.size(), reach.size(), "move highlight = movement range minus the unit's own tile")
	var hl: MeshInstance3D = s.highlights.meshes[TileHighlights.Kind.MOVE]
	ok(hl.mesh != null and hl.mesh.get_faces().size() == move.size() * 6, "one floor quad per highlighted tile")
	ok(hl.mesh.get_faces()[0].y > s.board.top_point(move[0].x, move[0].y).y - 2.0, "the overlay lies on the tile tops")
	var dest: Vector2i = move[move.size() - 1]
	s.tap_cell(dest)
	await get_tree().process_frame
	eq(cur.cell, dest, "tapped tile: walked there")
	ok(b.moved and s.highlights.shown(TileHighlights.Kind.MOVE).is_empty(), "moved; no more move tiles")
	eq(pal.end_button.text, "END TURN", "after moving: End Turn")
	var v: UnitView3D = s.views[cur]
	eq(v.position, s.board.top_point(dest.x, dest.y), "the unit stands on the tile's top")
	ok(v.sprite.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y, "upright billboard")
	eq(s.board.pick(s.board.cam.unproject_position(s.board.top_point(dest.x, dest.y))), dest, "clicking the tile on screen picks it")
	# abilities: the ABILITIES slot opens its list above the bar
	pal.open_list("abilities")
	eq(pal.state, CommandPalette.State.LIST, "list open")
	ok(pal.menu.visible and pal.back_button.visible, "the list panel with Back")
	ok(not pal.list_actions.any(func(a): return a is BattleAction and a.is_attack()), "the Attack is its own button, not in the list")
	ok(not pal.list_actions.any(func(a): return a is VesselData), "no summons in ABILITIES")
	ok(pal.columns.get_child_count() >= 1, "headings and entries (or a 'no skills' note)")
	pal.back_button.pressed.emit()
	eq(pal.state, CommandPalette.State.COMMANDS, "Back closes the list")
	# aim the attack at the nearest thing in reach, or anywhere
	pal.attack_button.pressed.emit()
	eq(s.mode, BattleStage.Mode.AIM, "aiming")
	eq(s.highlights.shown(TileHighlights.Kind.REACH), b.highlights(cur, BattleAction.attack()), "the footprint glows")
	eq(pal.state, CommandPalette.State.AIMING, "palette shows the hint")
	ok(pal.cancel_button.visible, "Cancel shown")
	pal.cancel_button.pressed.emit()
	eq(pal.state, CommandPalette.State.COMMANDS, "cancel goes back")
	ok(s.highlights.shown(TileHighlights.Kind.REACH).is_empty(), "footprint cleared")

	# a planted foe next to the unit: aim, preview, confirm
	var foe_cell := Vector2i.ZERO
	var ft := b.highlights(cur, BattleAction.attack())
	for c in ft:
		if b.grid.can_stand(c):
			foe_cell = c
			break
	var ed := EnemyData.new()
	ed.display_name = "Target Dummy"
	ed.stats = CharacterStats.new()
	ed.stats.speed = 1
	ed.loadout = EquipmentLoadout.make(WeaponItem.new(), WeaponStyle.new())
	ed.exp_reward = 0
	var foe := s.add_enemy(ed, foe_cell)
	ok(foe != null and s.views.has(foe), "a planted foe is drawn")
	s._on_action_chosen(BattleAction.attack())
	s.tap_cell(foe_cell)
	eq(s.mode, BattleStage.Mode.CONFIRM, "first tap aims")
	eq(s.aim, foe_cell, "aim")
	ok(s.highlights.shown(TileHighlights.Kind.AREA).has(foe_cell) and s.highlights.shown(TileHighlights.Kind.AIM) == ([foe_cell] as Array[Vector2i]), "area and aim glow")
	ok(s.fx.get_children().any(func(l): return l.get_meta("preview", false)), "damage preview over the target")
	eq(s.hud.target_card.unit, foe, "the Target card shows the target")
	ok(s.hud.target_card.visible, "Target card shown")
	eq(s.hud.card.unit, cur, "the acting card keeps the acting unit")
	var hp := foe.hp
	s.tap_cell(foe_cell)
	ok(foe.hp < hp, "second tap: attacked (%d -> %d)" % [hp, foe.hp])
	ok(b.acted, "acted")
	ok(not s.fx.get_children().any(func(l): return is_instance_valid(l) and not l.is_queued_for_deletion() and l.get_meta("preview", false)), "previews cleared")
	eq(pal.state, CommandPalette.State.COMMANDS, "back to the commands")
	ok(pal.attack_button.disabled and pal.defend_button.disabled, "Attack and Defend greyed out after acting")
	# enemy turns are played by EnemyAI: after a round, enemies have walked or struck
	var starts := {}
	for e in b.enemies:
		starts[e] = e.cell
	var party_hp := 0
	for u in b.deployment.field_units():
		party_hp += u.hp
	# ending turns until the King's, then summon
	var king := b.deployment.king
	pal.end_button.pressed.emit()
	await until_player(s)
	var guard := 0
	while b.current != king and guard < 50:
		s.end_turn()
		await until_player(s)
		guard += 1
	eq(b.current, king, "the King's turn")
	var moved_enemies := b.enemies.filter(func(e): return starts.has(e) and e.cell != starts[e]).size()
	var hp_now := 0
	for u in b.deployment.field_units():
		hp_now += u.hp
	ok(moved_enemies > 0 or hp_now < party_hp, "enemies engaged (%d walked, party HP %d -> %d)" % [moved_enemies, party_hp, hp_now])
	ok(pal.summon_button.visible and not pal.defend_button.visible and not pal.summon_button.disabled, "the King's SUMMON slot")
	pal.summon_button.pressed.emit()
	eq(pal.list_kind, "summon", "SUMMON opens the vessel list")
	var vessel_idx := -1
	var offered := 0
	for i in pal.list_actions.size():
		if pal.list_actions[i] is VesselData:
			offered += 1
			if vessel_idx < 0:
				vessel_idx = i
	ok(vessel_idx >= 0, "the King's list offers summoning")
	eq(offered, 8, "every vessel the King owns is offered: nothing was picked beforehand")
	eq(b.deployment.summon_limit, 6, "the map's summon limit")
	var column_titles := []
	for c in pal.columns.get_children():
		if c is Label:
			column_titles.append(c.text)
	ok(column_titles.any(func(t): return t.contains("6 LEFT")), "the summon list shows the summons left: %s" % [column_titles])
	if vessel_idx >= 0:
		var vd: VesselData = pal.list_actions[vessel_idx]
		var props_before := b.deployment.props.size()
		ok(not pal.list_buttons[vessel_idx].disabled, "a relic is in range: summon enabled")
		pal.list_buttons[vessel_idx].pressed.emit()
		eq(s.mode, BattleStage.Mode.SUMMON, "summon mode")
		var spots := s.highlights.shown(TileHighlights.Kind.SUMMON)
		ok(not spots.is_empty(), "relics in range glow")
		var spot := spots[0]
		s.tap_cell(spot)
		var vb := b.deployment.unit_of(vd)
		ok(vb != null and vb.cell == spot, "summoned onto the relic")
		eq(b.deployment.props.size(), props_before - 1, "the relic prop is used up")
		ok(s.views.has(vb), "the vessel is drawn")
		ok(s.hud.turn_order.entries.size() > 0, "turn order refreshed")
		ok(not b.acted, "summoning is free")
		eq(b.deployment.summons_left(), 5, "one summon used")
		pal.show_commands(king, b)
		pal.open_list("summon")
		var after := []
		for c in pal.columns.get_children():
			if c is Label:
				after.append(c.text)
		ok(after.any(func(t): return t.contains("5 LEFT")) and not pal.list_actions.has(vd), "the list updates: 5 left, that vessel is gone")
		s.select(vb)
		var tc := s.hud.target_card
		ok(tc.tactical.visible and tc.tactical.text.begins_with("Fade Clock %d / %d" % [vb.fade_clock.turns_left, vb.fade_clock.total]), "vessel card: %s" % tc.tactical.text)
		ok(tc.tactical.text.contains("Severed %d×  ·  Tethered %d×" % [vd.sever_count, vd.tether_count]), "sever and tether counts")
		ok(tc.class_label.text.begins_with("Vessel"), "class shows the role")
		ok(tc.chips.get_children().any(func(c): return c.get_child(0).text.begins_with("Fade")), "a Fade Clock chip")
		s.select(king)
		ok(not tc.visible, "selecting the acting unit hides the Target card")
	# rotating keeps the highlights and the units on their tiles
	s._player_commands()
	var before := s.highlights.shown(TileHighlights.Kind.MOVE)
	s.rotate_view(1)
	await get_tree().process_frame
	eq(s.board.rot, 1, "rotated")
	eq(s.highlights.shown(TileHighlights.Kind.MOVE), before, "same cells after rotating")
	eq(s.views[king].position, s.board.top_point(king.cell.x, king.cell.y), "units stay on their tiles")
	eq(s.board.pick(s.board.cam.unproject_position(s.board.top_point(king.cell.x, king.cell.y))), king.cell, "picking follows the turned view")
	# DEFEND: the acting unit guards and its turn ends; a shield shows over it
	await until_player(s)
	var tries := 0
	while b.current.is_king() and tries < 20:  # the King summons instead of defending
		s.end_turn()
		await until_player(s)
		tries += 1
	var guard_unit := b.current
	ok(pal.defend_button.visible, "DEFEND for a unit that is not the King")
	pal.defend_button.pressed.emit()
	ok(guard_unit.guarding, "Defend: guarding")
	ok(s.views.has(guard_unit) and s.views[guard_unit].guard_icon != null and s.views[guard_unit].guard_icon.visible, "a shield over the guarding unit")
	ok(b.current != guard_unit, "Defend ended the turn")
	# the end: knock out every enemy
	for e in b.enemies:
		e.hp = 1
	var last := b.enemies[0]
	for e in b.enemies:
		if e != last:
			e.hp = 0
	b._check_outcome()
	ok(b.outcome == BattleController.Outcome.ONGOING, "one enemy left")
	last.hp = 0
	b._check_outcome()
	ok(s._check_end(), "victory ends the battle")
	eq(s.mode, BattleStage.Mode.OVER, "over")
	ok(s.hud.result_panel.visible and s.hud.result_title.text == "Victory", "result panel")
	ok(s.summary != null and SaveSystem.exists(SaveSystem.AUTOSAVE), "finished through CampaignFlow (autosaved)")
	ok(not s.hud.palette.visible, "palette hidden")
	s.tap_cell(king.cell)
	eq(s.mode, BattleStage.Mode.OVER, "taps do nothing after the end")
	s.queue_free()
	SaveSystem.delete_slot(SaveSystem.AUTOSAVE)
