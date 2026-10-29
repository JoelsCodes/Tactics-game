class_name BattleStage
extends Node2D
## The battle screen: the isometric terrain (Terrain, from the tile art), the units drawn with their
## character sheets, neon-blue tile highlights, a diorama finish (tilt-shift, warm grade, vignette)
## and the HUD. All rules go through BattleController; this only shows them and turns taps into calls.
##
## Made for a 16:9 desktop screen: the camera frames the whole battlefield between the HUD's top and
## bottom bands, and follows a unit only if it would leave that space (bigger maps).
##
## A player turn:
##   - the walkable tiles glow; click one to walk there (once per turn)
##   - Abilities: pick the Attack or a skill; its footprint glows; click a tile to aim (the area that
##     would be hit glows, with the damage over each unit); click the same tile again to confirm
##   - the King can also pick Summon <vessel> and click a glowing relic
##   - Wait / End Turn
## Clicking a unit shows it on the Target card (bottom left); the acting unit is on the right card.
## Enemy turns are played by EnemyAI: they walk, show the area they are about to hit, then strike.
##
## The barracks starts a battle by setting BattleStage.pending_game and changing to scenes/battle.tscn;
## at the end, CampaignFlow.finish_battle hands out XP and relics and autosaves, and the result panel
## leads back to the barracks.

enum Mode { IDLE, MOVE, AIM, CONFIRM, SUMMON, ENEMY, BUSY, OVER }

## The game the next battle uses (set by the barracks before the scene change).
static var pending_game: SaveGame

@export var map_path := "res://samples/demo_battlefield.json"
## Pause (seconds) around an enemy's actions so the player can follow them. 0 in tests.
@export var enemy_delay := 0.45
## Tween walks and floating numbers. Off in tests.
@export var animate := true

var game: SaveGame
var map_data: Dictionary  ## the loaded map: size, tiles and settings such as `max_summons`
var grid: TacticalGrid
var battle: BattleController
var terrain: Terrain
var highlights: TileHighlights
var hud: BattleHud
var cam: Camera2D
var fx: Node2D  ## floating numbers
var views := {}  ## BattleUnit -> Character
var mode := Mode.IDLE
var action: BattleAction  ## the attack or skill being aimed
var summoning: VesselData  ## the vessel being summoned
var aim := TacticalGrid.NO_CELL
var selected: BattleUnit  ## shown on the status card
var summary: BattleSummary  ## set when the battle ends

var _touches := {}
var _drag = null
var _pinch = null
var _moved_finger := false


func _ready() -> void:
	game = pending_game if pending_game != null else SaveGame.new_game()
	pending_game = null
	_build_world()
	battle = BattleController.new()
	add_child(battle)
	battle.setup(grid)
	battle.deployment.prop_parent = terrain.field.get_path()
	battle.deployment.relic_placed.connect(_on_relic_placed)
	battle.deployment.unit_deployed.connect(_add_view)
	battle.deployment.vessel_untethered.connect(_on_untethered)
	CampaignFlow.prepare_deployment(game, battle.deployment, int(map_data.get("max_summons", DeploymentManager.DEFAULT_SUMMON_LIMIT)))
	hud = BattleHud.new()
	add_child(hud)
	hud.palette.action_chosen.connect(_on_action_chosen)
	hud.palette.summon_chosen.connect(_on_summon_chosen)
	hud.palette.end_turn_pressed.connect(end_turn)
	hud.palette.cancel_pressed.connect(cancel)
	hud.turn_order.unit_pressed.connect(select)
	hud.rotate_pressed.connect(rotate_view.bind(1))
	hud.return_pressed.connect(_return_to_barracks)
	SampleBattle.populate(self)
	frame_board()
	get_viewport().size_changed.connect(frame_board)
	battle.start()
	next_turn()


## Places an enemy and draws it.
func add_enemy(data: EnemyData, cell: Vector2i) -> BattleUnit:
	var bu := battle.add_enemy(data, cell)
	if bu != null:
		_add_view(bu)
	return bu


# ---------- turns ----------

func next_turn() -> void:
	var bu := battle.next_turn()
	if bu == null:
		_check_end()
		return
	hud.card.show_unit(bu)
	select(null)
	_keep_in_view(bu.cell)
	hud.turn_order.show_turns(battle.turns)
	if bu.team != 0:
		_set_mode(Mode.ENEMY)
		hud.palette.show_enemy_turn(bu)
		_enemy_turn(bu)
		return
	hud.say("%s's turn" % bu.data.display_name)
	_player_commands()


func end_turn() -> void:
	if battle.current == null or mode == Mode.OVER:
		return
	highlights.clear_all()
	_clear_previews()
	battle.end_turn()
	if _check_end():
		return
	next_turn()


## Back from aiming or summoning to the turn's commands.
func cancel() -> void:
	action = null
	summoning = null
	aim = TacticalGrid.NO_CELL
	_clear_previews()
	_player_commands()


func _player_commands() -> void:
	var bu := battle.current
	highlights.clear_all()
	action = null
	summoning = null
	if not battle.moved:
		var cells := battle.move_range(bu).cells().filter(func(c): return c != bu.cell)
		highlights.show_cells(TileHighlights.Kind.MOVE, cells)
		_set_mode(Mode.MOVE)
	else:
		_set_mode(Mode.IDLE)
	hud.palette.show_commands(bu, battle)
	hud.card.show_unit(bu)


# ---------- taps ----------

## What a tap on a board cell does in the current mode.
func tap_cell(c: Vector2i) -> void:
	match mode:
		Mode.MOVE:
			if highlights.shown(TileHighlights.Kind.MOVE).has(c):
				walk(battle.current, c)
				return
		Mode.AIM, Mode.CONFIRM:
			if highlights.shown(TileHighlights.Kind.REACH).has(c):
				if mode == Mode.CONFIRM and c == aim:
					_perform()
				else:
					_aim_at(c)
				return
			cancel()
			return
		Mode.SUMMON:
			if highlights.shown(TileHighlights.Kind.SUMMON).has(c):
				_summon_at(c)
			else:
				cancel()
			return
	var o = grid.occupant(c)
	if o is BattleUnit:
		select(o)


func walk(bu: BattleUnit, c: Vector2i) -> void:
	var path := battle.move_range(bu).path_to(c)
	var from := bu.cell
	if not battle.move(bu, c):
		return
	highlights.clear(TileHighlights.Kind.MOVE)
	var v: Character = views.get(bu)
	if animate and v:
		_set_mode(Mode.BUSY)
		v.play("walk")
		var prev := from
		for step in path:
			var tw := create_tween().set_parallel()
			v.face(IsoProjection.screen_dir(step - prev, terrain.rot))
			var g := terrain.ground(step.x, step.y)
			tw.tween_property(v, "position", g + Vector2(0, 1), 0.14)
			tw.tween_property(v, "lift", g.y - terrain.stand_point(step.x, step.y).y, 0.14)
			await tw.finished
			prev = step
		v.play("idle")
	_place(bu)
	if battle.current == bu and bu.team == 0:
		_player_commands()


func _on_action_chosen(a: BattleAction) -> void:
	var bu := battle.current
	action = a
	var reach := battle.highlights(bu, a)
	highlights.clear(TileHighlights.Kind.MOVE)
	highlights.show_cells(TileHighlights.Kind.REACH, reach)
	_set_mode(Mode.AIM)
	hud.palette.show_aiming("%s  ·  %s. Click a glowing tile to aim, click it again to confirm." % [a.display_name(), "free" if a.sp_cost() == 0 else "%d SP" % a.sp_cost()])


func _aim_at(c: Vector2i) -> void:
	aim = c
	var p := battle.preview(battle.current, action, c)
	highlights.show_cells(TileHighlights.Kind.AREA, p.area.tiles)
	highlights.show_cells(TileHighlights.Kind.AIM, [c])
	_clear_previews()
	for h in p.hits:
		_float(h.target, ("+%d" % h.amount) if h.heal else ("-%d%s" % [h.amount, "  KO" if h.knocked_out else ""]), HudStyle.HP if h.heal else Color.WHITE, false)
	_set_mode(Mode.CONFIRM)
	var o = grid.occupant(c)
	if o is BattleUnit:
		select(o)


func _perform() -> void:
	var r := _resolve(battle.current, action, aim)
	action = null
	if not r.ok:
		hud.say(r.error.capitalize())
		_player_commands()
		return
	if _check_end():
		return
	_player_commands()


## Performs an action through the BattleController and shows it: the user's attack or cast animation,
## the numbers, hits and knockouts, a message. Used for the player and for enemies.
func _resolve(bu: BattleUnit, a: BattleAction, at: Vector2i) -> ActionResult:
	_clear_previews()
	var r := battle.perform(bu, a, at)
	highlights.clear(TileHighlights.Kind.REACH)
	highlights.clear(TileHighlights.Kind.AREA)
	highlights.clear(TileHighlights.Kind.AIM)
	if not r.ok:
		return r
	var v: Character = views.get(bu)
	if v:
		v.face(IsoProjection.screen_dir(bu.facing, terrain.rot))
		v.act("attack" if a.category() == Proficiency.Category.PHYSICAL else "cast")
	for h in r.hits:
		var tv: Character = views.get(h.target)
		_float(h.target, ("+%d" % h.amount) if h.heal else str(h.amount), HudStyle.HP if h.heal else Color("#ffd27a"), true)
		if tv == null:
			continue
		if h.knocked_out:
			tv.play("ko")
			(tv.sprite.material as ShaderMaterial).set_shader_parameter("gray", 0.45)
		elif not h.heal:
			tv.act("hit")
	var names := r.hits.map(func(h): return h.target.data.display_name)
	hud.say("%s used %s%s." % [bu.data.display_name, a.display_name(), (" on " + ", ".join(names)) if not names.is_empty() else ""]
		+ ("  %s gained a skill level." % bu.data.display_name if r.skill_levels_gained > 0 else ""))
	return r


## An enemy's turn, played by EnemyAI: walk, show the area it is about to hit, strike, end the turn.
func _enemy_turn(bu: BattleUnit) -> void:
	var p := EnemyAI.plan(battle, bu)
	if enemy_delay > 0.0:
		await get_tree().create_timer(enemy_delay * 0.5).timeout
	if p.moves():
		await walk(bu, p.move_to)
	if not is_inside_tree() or battle.current != bu:
		return
	if p.acts():
		if enemy_delay > 0.0:
			var area := battle.preview(bu, p.action, p.aim).area
			highlights.show_cells(TileHighlights.Kind.AREA, area.tiles)
			highlights.show_cells(TileHighlights.Kind.AIM, [p.aim])
			await get_tree().create_timer(enemy_delay).timeout
			if not is_inside_tree() or battle.current != bu:
				return
		_resolve(bu, p.action, p.aim)
		if _check_end():
			return
	else:
		hud.say("%s %s." % [bu.data.display_name, "advances" if p.moves() else "waits"])
	if enemy_delay > 0.0:
		await get_tree().create_timer(enemy_delay).timeout
	if is_inside_tree() and battle.current == bu and mode != Mode.OVER:
		end_turn()


func _on_summon_chosen(v: VesselData) -> void:
	summoning = v
	var dm := battle.deployment
	var spots := dm.props.keys().filter(func(c): return dm.can_summon(v, c))
	highlights.clear(TileHighlights.Kind.MOVE)
	highlights.show_cells(TileHighlights.Kind.SUMMON, spots)
	_set_mode(Mode.SUMMON)
	hud.palette.show_aiming("Summon %s: click a glowing relic." % v.display_name)


func _summon_at(c: Vector2i) -> void:
	var v := battle.summon_vessel(battle.current, summoning, c)
	highlights.clear(TileHighlights.Kind.SUMMON)
	if v != null:
		hud.say("%s is tethered to %s." % [v.data.display_name, v.temp_relic().display_name])
		hud.turn_order.show_turns(battle.turns)
	summoning = null
	_player_commands()


## Shows a unit on the Target card (bottom left); the acting unit stays on the right card. null, or the
## acting unit itself, hides the Target card.
func select(bu: BattleUnit) -> void:
	selected = bu
	hud.target_card.show_unit(bu if bu != battle.current else null)
	if bu != null and bu == battle.current:
		hud.card.show_unit(bu)


# ---------- the end ----------

func _check_end() -> bool:
	if battle.outcome == BattleController.Outcome.ONGOING:
		return false
	_set_mode(Mode.OVER)
	highlights.clear_all()
	summary = CampaignFlow.finish_battle(game, battle)
	hud.show_result(summary)
	for bu in views:
		if not bu.is_down() and bu.team == 0 and battle.outcome == BattleController.Outcome.WON:
			views[bu].play("victory")
	return true


func _return_to_barracks() -> void:
	get_tree().change_scene_to_file("res://scenes/barracks.tscn")


# ---------- drawing ----------

func _build_world() -> void:
	var sky := CanvasLayer.new()
	sky.layer = -10
	add_child(sky)
	var bg := TextureRect.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color("#2b4a6b"), Color("#0e1726")])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 256
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.add_child(bg)
	terrain = Terrain.new()
	add_child(terrain)
	var map := Terrain.load_map(map_path)
	map_data = map
	terrain.show_map(map)
	grid = TacticalGrid.from_map(map)
	highlights = TileHighlights.new(terrain)
	add_child(highlights)
	terrain.rebuilt.connect(_after_rotate)
	fx = Node2D.new()
	fx.z_index = 100
	add_child(fx)
	var mood := CanvasModulate.new()  # warm afternoon light over the whole field
	mood.color = Color(1.0, 0.97, 0.92)
	add_child(mood)
	cam = Camera2D.new()
	cam.zoom = Vector2.ONE * 1.4
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	add_child(cam)
	var finish := CanvasLayer.new()
	finish.layer = 5
	add_child(finish)
	var rect := ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/diorama.gdshader")
	rect.material = m
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	finish.add_child(rect)


func _add_view(bu: BattleUnit) -> void:
	if views.has(bu):
		return
	var v := Character.new()
	terrain.field.add_child(v)
	v.setup(UnitLook.sheet_for(bu.data), UnitLook.tint_for(bu.data))
	views[bu] = v
	_place(bu)
	if bu.team != 0:
		bu.facing = Vector2i(-1, 0)
	v.face(IsoProjection.screen_dir(bu.facing, terrain.rot))
	if animate and bu.is_vessel():
		v.modulate.a = 0.0
		create_tween().tween_property(v, "modulate:a", 1.0, 0.4)


func _place(bu: BattleUnit) -> void:
	var v: Character = views.get(bu)
	if v:
		_put_on_tile(v, bu.cell)
		v.set_wading(grid.terrain(bu.cell) == "w")


## Puts a unit or prop on a tile: the node at the tile's ground point (so it sorts with the terrain
## blocks), drawn raised by the tile's height.
func _put_on_tile(n: Node2D, c: Vector2i) -> void:
	var g := terrain.ground(c.x, c.y)
	n.position = g + Vector2(0, 1)  # just in front of its own tile block
	var lift := g.y - terrain.stand_point(c.x, c.y).y
	if n is Character:
		(n as Character).lift = lift
	else:
		for ch in n.get_children():
			if ch is Node2D:
				ch.set_meta("base_y", ch.get_meta("base_y", ch.position.y))
				ch.position.y = ch.get_meta("base_y") - lift


func _on_untethered(bu: BattleUnit, went_home: bool) -> void:
	var v: Character = views.get(bu)
	views.erase(bu)
	hud.say("%s faded. %s" % [bu.data.display_name, "Its relic went home." if went_home else "Its relic fell to the ground."])
	if v == null:
		return
	if animate:
		var tw := create_tween()
		tw.tween_property(v, "modulate:a", 0.0, 0.5)
		tw.tween_callback(v.queue_free)
	else:
		v.queue_free()


## A relic on the field: a small crystal on its tile, with a soft glow that bobs.
func _on_relic_placed(p: RelicProp) -> void:
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/fx/soft_dot.png")
	glow.modulate = Color(0.45, 0.9, 1.0, 0.7)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	glow.position = Vector2(0, -14)
	p.add_child(glow)
	var gem := Sprite2D.new()
	gem.texture = load("res://assets/props/sky_crystal.png")
	gem.scale = Vector2.ONE * (28.0 / gem.texture.get_width())
	gem.offset = Vector2(0, -gem.texture.get_height() / 2.0)
	p.add_child(gem)
	_put_on_tile(p, p.cell)
	if animate:
		var tw := gem.create_tween().set_loops()
		tw.tween_property(gem, "offset:y", gem.offset.y - 10.0, 1.1).set_trans(Tween.TRANS_SINE)
		tw.tween_property(gem, "offset:y", gem.offset.y, 1.1).set_trans(Tween.TRANS_SINE)


func _float(bu: BattleUnit, text: String, col: Color, rises: bool) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.position = terrain.stand_point(bu.cell.x, bu.cell.y) + Vector2(-20, -92)
	l.set_meta("preview", not rises)
	fx.add_child(l)
	if rises and animate:
		var tw := l.create_tween().set_parallel()
		tw.tween_property(l, "position:y", l.position.y - 26, 0.8)
		tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.4)
		tw.chain().tween_callback(l.queue_free)
	elif rises:
		l.queue_free()


func _clear_previews() -> void:
	for l in fx.get_children():
		if l.get_meta("preview", false):
			l.queue_free()


## The camera turns in quarter steps; the terrain is rebuilt and everything is placed again.
func rotate_view(dir: int) -> void:
	terrain.rotate_view(dir)


func _after_rotate() -> void:
	for bu in views:
		_place(bu)
		views[bu].face(IsoProjection.screen_dir(bu.facing, terrain.rot))
	for c in battle.deployment.props if battle else {}:
		_put_on_tile(battle.deployment.props[c], c)
	frame_board()


## Frames the whole battlefield in the screen space the HUD leaves free (between its top and bottom
## bands), as large as fits. On big maps the zoom stops at MIN_ZOOM and the camera follows units.
const MIN_ZOOM := 0.7
const MAX_ZOOM := 2.6


func frame_board() -> void:
	if terrain == null or cam == null:
		return
	var box := _board_rect()
	var view := get_viewport_rect().size
	var scale := view.y / 1080.0  # the HUD is laid out at 1080p and scales with the screen
	var free := Vector2(view.x - 160 * scale, view.y - (BattleHud.TOP_BAND + BattleHud.BOTTOM_BAND) * scale)
	var z := clampf(minf(free.x / box.size.x, free.y / box.size.y), MIN_ZOOM, MAX_ZOOM)
	cam.zoom = Vector2.ONE * z
	var shift := (BattleHud.BOTTOM_BAND - BattleHud.TOP_BAND) * scale / 2.0  # the free space sits a little high
	cam.position = box.get_center() + Vector2(0, shift / z)
	cam.reset_smoothing()


## The battlefield's outline on screen at zoom 1 (all tile tops and sides).
func _board_rect() -> Rect2:
	var r := Rect2()
	var first := true
	for y in [0, grid.depth - 1]:
		for x in [0, grid.width - 1]:
			for p in [terrain.ground(x, y) + Vector2(0, (Terrain.BASE + 1) * Terrain.HS), terrain.iso(x, y, 4)]:
				for d in [Vector2(-Terrain.TW, -Terrain.TH), Vector2(Terrain.TW, Terrain.TH)]:
					var q: Vector2 = p + d
					r = Rect2(q, Vector2.ZERO) if first else r.expand(q)
					first = false
	return r


## Pans just enough to keep a cell inside the free screen space (only matters on maps too big to fit).
func _keep_in_view(c: Vector2i) -> void:
	var view := get_viewport_rect().size
	var scale := view.y / 1080.0
	# where the cell is on screen, from the camera's own position (the canvas transform lags a frame)
	var p := (terrain.stand_point(c.x, c.y) - cam.position) * cam.zoom + view / 2.0
	var safe := Rect2(Vector2(120, BattleHud.TOP_BAND) * scale, view - Vector2(240, BattleHud.TOP_BAND + BattleHud.BOTTOM_BAND) * scale)
	if not safe.has_point(p):
		cam.position = terrain.stand_point(c.x, c.y) + Vector2(0, (BattleHud.BOTTOM_BAND - BattleHud.TOP_BAND) * scale / 2.0 / cam.zoom.y)


func _set_mode(m: Mode) -> void:
	mode = m


# ---------- camera and taps ----------

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		match e.keycode:
			KEY_Q: rotate_view(-1)
			KEY_E: rotate_view(1)
			KEY_ESCAPE: cancel()
	elif e is InputEventScreenTouch:
		if e.pressed:
			_touches[e.index] = e.position
			if _touches.size() == 1:
				_drag = [e.position, cam.position]
				_moved_finger = false
			elif _touches.size() == 2:
				var ps: Array = _touches.values()
				_pinch = {"d": maxf(1.0, ps[0].distance_to(ps[1])), "z": cam.zoom.x}
				_moved_finger = true
		else:
			_touches.erase(e.index)
			if _touches.size() < 2:
				_pinch = null
			if _touches.is_empty():
				if _drag != null and not _moved_finger:
					_tap(e.position)
				_drag = null
	elif e is InputEventScreenDrag:
		_touches[e.index] = e.position
		if _touches.size() == 2 and _pinch != null:
			var ps: Array = _touches.values()
			cam.zoom = Vector2.ONE * clampf(_pinch.z * ps[0].distance_to(ps[1]) / _pinch.d, 0.5, MAX_ZOOM)
		elif _drag != null and _touches.size() == 1:
			var dv: Vector2 = e.position - _drag[0]
			if absf(dv.x) + absf(dv.y) > 10:
				_moved_finger = true
			if _moved_finger:
				cam.position = _drag[1] - dv / cam.zoom.x
				cam.reset_smoothing()
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		cam.zoom = Vector2.ONE * clampf(cam.zoom.x * (1.1 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 0.9), 0.5, MAX_ZOOM)


func _tap(screen_pos: Vector2) -> void:
	if mode == Mode.BUSY or mode == Mode.OVER or mode == Mode.ENEMY:
		return
	var world := get_canvas_transform().affine_inverse() * screen_pos
	var c := IsoProjection.pick(grid, world, terrain.rot)
	if c != TacticalGrid.NO_CELL:
		tap_cell(c)
