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
	print("stage checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func edge_flags() -> void:
	# a 2x1 region on a 4x4 board: the shared edge is inside, the rest is border
	var region := {Vector2i(1, 1): true, Vector2i(2, 1): true}
	var f := TileHighlights.edge_flags(region, Vector2i(1, 1), 0, 4, 4)
	eq(f, Color(1, 0, 1, 1), "rotation 0: +x neighbour is the bottom-right edge")
	f = TileHighlights.edge_flags(region, Vector2i(2, 1), 0, 4, 4)
	eq(f, Color(1, 1, 1, 0), "the other tile: its top-left edge is shared")
	for rot in 4:
		var a := TileHighlights.edge_flags(region, Vector2i(1, 1), rot, 4, 4)
		eq(a.r + a.g + a.b + a.a, 3.0, "rotation %d: exactly one inner edge" % rot)
	eq(TileHighlights.edge_flags({Vector2i(0, 0): true}, Vector2i(0, 0), 2, 4, 4), Color(1, 1, 1, 1), "a lone tile is all border")


func looks() -> void:
	var p := SampleParty.make()
	eq(UnitLook.sheet_for(p.king), "hero", "the King is the hero sheet")
	eq(UnitLook.sheet_for(p.co_captains[0]), "knight", "Co-Captains are the knight")
	for v in p.vessels():
		ok(UnitLook.VESSEL_SHEETS.has(UnitLook.sheet_for(v)), "vessel sheet")
		eq(UnitLook.sheet_for(v), UnitLook.sheet_for(v), "stable")
	eq(UnitLook.tint_for(p.king).a, 0.0, "no tint on the King")
	ok(UnitLook.tint_for(p.vessels()[0]).a > 0, "vessels are tinted")
	var e := EnemyData.new()
	e.display_name = "Grimkin"
	ok(UnitLook.ENEMY_SHEETS.has(UnitLook.sheet_for(e)) and UnitLook.tint_for(e) == UnitLook.ENEMY_TINT, "enemy look")
	var por := UnitLook.portrait("hero")
	ok(por is AtlasTexture and por.region.size == Vector2(72, 72), "portrait crop")


func make_stage() -> BattleStage:
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 0.0
	s.animate = false
	add_child(s)
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
	eq(card.name_label.text, cur.data.display_name, "card name")
	eq(card.class_label.text, UnitStatusCard._class_name(cur.data), "card class (the role)")
	eq(card.level_label.text, "Lv %d" % cur.data.level, "card level")
	ok(not s.hud.target_card.visible, "no target card at the start of a turn")
	eq(card.hp_text.text, "%d / %d" % [cur.hp, cur.max_hp()], "card HP")
	eq(card.sp_text.text, "%d / %d" % [cur.sp, cur.max_sp()], "card SP")
	eq(card.xp_text.text, "%d / %d" % [cur.data.exp, cur.data.exp_to_next_level], "card XP")
	ok(not card.tactical.visible, "no vessel data for a human")
	var pal := s.hud.palette
	eq(pal.state, CommandPalette.State.COMMANDS, "commands shown")
	eq(pal.end_button.text, "Wait", "nothing done yet: Wait")
	ok(pal.abilities_button.visible and not pal.cancel_button.visible, "Abilities and Wait")
	# moving: the walkable tiles glow; tapping one walks there
	eq(s.mode, BattleStage.Mode.MOVE, "move mode")
	var move := s.highlights.shown(TileHighlights.Kind.MOVE)
	var reach := b.move_range(cur).cells().filter(func(c): return c != cur.cell)
	eq(move.size(), reach.size(), "move highlight = movement range minus the unit's own tile")
	ok(s.terrain.block(move[0]).get_node_or_null("HL_MOVE") != null, "the overlay sits on the tile block")
	var dest: Vector2i = move[move.size() - 1]
	s.tap_cell(dest)
	await get_tree().process_frame
	eq(cur.cell, dest, "tapped tile: walked there")
	ok(b.moved and s.highlights.shown(TileHighlights.Kind.MOVE).is_empty(), "moved; no more move tiles")
	eq(pal.end_button.text, "End Turn", "after moving: End Turn")
	var v: Character = s.views[cur]
	eq(v.position, s.terrain.ground(dest.x, dest.y) + Vector2(0, 1), "the sprite sorts at the tile's ground point")
	# abilities: the list
	pal.open_list()
	eq(pal.state, CommandPalette.State.LIST, "list open")
	ok(pal.list_actions[0] is BattleAction and pal.list_actions[0].is_attack(), "Attack first")
	eq(pal.list_buttons[0].text, "Attack  ·  free", "attack label")
	ok(pal.back_button.visible and not pal.abilities_button.visible, "Back replaces the commands while the list is open")
	ok(pal.columns.get_child_count() >= 1, "one column per group")
	# aim the attack at the nearest thing in reach, or anywhere
	pal.list_buttons[0].pressed.emit()
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
	pal.open_list()
	ok(pal.list_buttons[0].disabled, "Attack greyed out after acting")
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
	pal.open_list()
	var vessel_idx := -1
	for i in pal.list_actions.size():
		if pal.list_actions[i] is VesselData:
			vessel_idx = i
			break
	ok(vessel_idx >= 0, "the King's list offers summoning")
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
		s.select(vb)
		var tc := s.hud.target_card
		ok(tc.tactical.visible and tc.tactical.text.begins_with("Fade Clock %d / %d" % [vb.fade_clock.turns_left, vb.fade_clock.total]), "vessel card: %s" % tc.tactical.text)
		ok(tc.tactical.text.contains("Severed %d×  ·  Tethered %d×" % [vd.sever_count, vd.tether_count]), "sever and tether counts")
		eq(tc.class_label.text, "Vessel", "class shows the role")
		s.select(king)
		ok(not tc.visible, "selecting the acting unit hides the Target card")
	# rotating keeps the highlights and the units on their tiles
	s._player_commands()
	var before := s.highlights.shown(TileHighlights.Kind.MOVE)
	s.rotate_view(1)
	await get_tree().process_frame
	eq(s.terrain.rot, 1, "rotated")
	eq(s.highlights.shown(TileHighlights.Kind.MOVE), before, "same cells after rotating")
	ok(before.is_empty() or s.terrain.block(before[0]).get_node_or_null("HL_MOVE") != null, "overlays re-attached to the new blocks")
	eq(s.views[king].position, s.terrain.ground(king.cell.x, king.cell.y) + Vector2(0, 1), "units re-placed")
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
