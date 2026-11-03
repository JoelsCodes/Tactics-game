extends Node
## The sword drops (owner, Nov 2026): an enemy that goes down leaves a sword with its weapon style and stance; a player-side unit that
## steps on it takes it (the sword rises and is gone) and the party can equip that style and stance from then on, saved with the game.
## godot --headless --path godot res://tests/sword_check.tscn

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
	logic()
	asset_size()
	await menu()
	print("sword checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func _board() -> TacticalGrid:
	var rows := []
	for y in 10:
		rows.append(" ".join(PackedStringArray(["g0", "g0", "g0", "g0", "g0", "g0", "g0", "g0", "g0", "g0"])))
	return TacticalGrid.from_rows(rows)


## A battle: Alaric (Rook, Pierce, facing north) at (5, 5) and a foe with the given style at (5, 3).
func _battle(game: SaveGame, foe_geo: TacticalMath.Geometry, foe_stance: WeaponStyle.Stance) -> Array:
	var b := BattleController.new()
	add_child(b)
	b.setup(_board())
	b.miss_chance = 0.0
	var kd := game.roster.king
	var rook := WeaponStyle.new()  # a Rook with Pierce for the test; the collection still has Rook Impact
	rook.stance = WeaponStyle.Stance.PIERCE
	kd.loadout.weapon_style = rook
	var king := b.deployment.deploy_king(kd, Vector2i(5, 5))
	var ed := FirstBattle.squire(1)
	ed.stats.speed = 1
	var st := WeaponStyle.new()
	st.geometry = foe_geo
	st.stance = foe_stance
	ed.loadout.weapon_style = st
	var foe := b.add_enemy(ed, Vector2i(5, 3))
	foe.hp = 1
	var far := FirstBattle.squire(1)  # a second enemy far away keeps the battle going after the first falls
	far.stats.speed = 1
	b.add_enemy(far, Vector2i(9, 0))
	kd.stats.speed = 30
	b.known_styles = game.roster.known_style_keys()
	b.start()
	b.next_turn()
	king.facing = Vector2i(0, -1)
	return [b, king, foe]


func _to_turn(b: BattleController, u: BattleUnit) -> void:
	for i in 20:
		if b.next_turn() == u:
			return
		b.end_turn()


func logic() -> void:
	var game := FirstBattle.game()
	var t := _battle(game, TacticalMath.Geometry.PAWN, WeaponStyle.Stance.AXE)
	var b: BattleController = t[0]
	var king: BattleUnit = t[1]
	var foe: BattleUnit = t[2]
	var dropped := []
	b.sword_dropped.connect(func(c, g, s): dropped.append([c, g, s]))
	var found := []
	b.sword_collected.connect(func(u, c, g, s, n): found.append([u, c, g, s, n]))
	ok(not game.roster.knows_style(TacticalMath.Geometry.PAWN, WeaponStyle.Stance.AXE), "the party does not have Pawn Axe yet")
	b.perform(king, BattleAction.attack(), Vector2i(5, 4))
	ok(foe.is_down(), "the foe is down")
	eq(dropped, [[Vector2i(5, 3), TacticalMath.Geometry.PAWN, WeaponStyle.Stance.AXE]], "a sword falls on its tile with its style and stance")
	ok(b.grid.occupant(Vector2i(5, 3)) == null and b.grid.can_stand(Vector2i(5, 3)), "the body leaves the tile: it can be walked on")
	# an enemy walking over it takes nothing
	b._collect_swords(foe, [Vector2i(5, 3)] as Array[Vector2i])
	ok(b.swords.has(Vector2i(5, 3)) and found.is_empty(), "only the player's side picks swords up")
	# the next turn the King steps on it
	b.end_turn()
	_to_turn(b, king)
	ok(b.move(king, Vector2i(5, 3)), "the King walks onto the sword's tile")
	eq(found.size(), 1, "the sword is taken")
	eq([found[0][1], found[0][2], found[0][3], found[0][4]], [Vector2i(5, 3), TacticalMath.Geometry.PAWN, WeaponStyle.Stance.AXE, true], "it is Pawn Axe, and new")
	ok(b.swords.is_empty(), "the sword is gone")
	eq(b.summary.styles_found, ["PAWN:AXE"] as Array[String], "the battle's summary lists the find")
	ok(not game.roster.knows_style(TacticalMath.Geometry.PAWN, WeaponStyle.Stance.AXE), "it joins the party's styles when the battle ends")
	b.finish(game.roster)
	ok(game.roster.knows_style(TacticalMath.Geometry.PAWN, WeaponStyle.Stance.AXE) and game.roster.known_style_keys().has("ROOK:IMPACT"), "Pawn Axe is collected on top of Rook Impact")
	ok(not game.roster.learn_style(TacticalMath.Geometry.PAWN, WeaponStyle.Stance.AXE), "learning it again changes nothing")
	# saved with the game
	var back := SaveCodec.decode(SaveCodec.encode(game)).game
	ok(back.roster.knows_style(TacticalMath.Geometry.PAWN, WeaponStyle.Stance.AXE), "the collection is saved")
	# a style the party already has: the pickup says so
	var g2 := FirstBattle.game()
	g2.roster.learn_style(TacticalMath.Geometry.KNIGHT, WeaponStyle.Stance.PIERCE)
	var t2 := _battle(g2, TacticalMath.Geometry.KNIGHT, WeaponStyle.Stance.PIERCE)
	var b2: BattleController = t2[0]
	var again := []
	b2.sword_collected.connect(func(u, c, g, s, n): again.append(n))
	b2.perform(t2[1], BattleAction.attack(), Vector2i(5, 4))
	b2.end_turn()
	_to_turn(b2, t2[1])
	b2.move(t2[1], Vector2i(5, 3))
	eq(again, [false], "a style the party already has is not new")
	eq(b2.summary.styles_found.size(), 0, "and is not listed again")


## The sword is drawn within the tile rule: shorter than the King (about 1.9 world units) and inside one tile (1 unit) in width.
func asset_size() -> void:
	var tex: Texture2D = load("res://assets/props/sword_drop.png")
	ok(tex != null, "the sword sprite is there")
	if tex == null:
		return
	var h: float = BattleStage.SWORD_HEIGHT
	var w: float = h * tex.get_width() / tex.get_height()
	ok(h < 1.9, "the sword is shorter than the King (%.2f)" % h)
	ok(w <= 1.0, "the sword fits one tile (%.2f wide)" % w)


## The loadout menu equips any found style on any unit.
func menu() -> void:
	var game := FirstBattle.game()
	game.roster.learn_style(TacticalMath.Geometry.QUEEN, WeaponStyle.Stance.PIERCE)
	var m := LoadoutMenu.new()
	add_child(m)
	await get_tree().process_frame
	m.open(game.roster.king, game.roster)
	m.slot_list.select(EquipmentLoadout.Slot.WEAPON_STYLE)
	m._on_slot_selected(EquipmentLoadout.Slot.WEAPON_STYLE)
	eq(m.choice_list.item_count, 2, "two found styles to choose from")
	ok(m.choice_list.get_item_text(0).contains("equipped"), "what is equipped comes first")
	m.choice_list.select(1)
	m._on_choice_selected(1)
	ok(not m.apply_button.disabled, "a different style can be equipped")
	m._on_apply()
	var s := game.roster.king.loadout.weapon_style
	eq([s.geometry, s.stance], [TacticalMath.Geometry.QUEEN, WeaponStyle.Stance.PIERCE], "Alaric now holds Queen Pierce")
	ok(game.roster.knows_style(TacticalMath.Geometry.ROOK, WeaponStyle.Stance.IMPACT), "...and still has Rook Impact in the collection")
	m.queue_free()
