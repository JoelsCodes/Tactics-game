class_name BattleStage
extends Node3D
## The battle screen: the 3D diorama board (Board3D, from the tile art: real block geometry, sun
## shadows, fog, a tilted camera), the units as upright character billboards (UnitView3D), neon-blue
## floor highlights and the HUD. All rules go through BattleController; this only shows them and turns
## taps into calls.
##
## Made for a 16:9 desktop screen. The camera is static (the owner's rule): one lens, angle and distance
## (Board3D.CAMERA_DISTANCE, as in the intro), the whole battlefield centred between the HUD's top and bottom
## bands (lock_camera, shared with the story scenes); it never pans, follows a unit, zooms or turns.
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
## The next battle's map, units and summon rules (set by a story scene); without one it is the sample fight.
static var pending_setup: BattleSetup

@export var map_path := "res://samples/demo_battlefield.json"
## Pause (seconds) around an enemy's actions so the player can follow them. 0 in tests.
@export var enemy_delay := 0.45
## Tween walks and floating numbers. Off in tests.
@export var animate := true

var game: SaveGame
var map_data: Dictionary  ## the loaded map: size, tiles and settings such as `max_summons`
var grid: TacticalGrid
var battle: BattleController
var board: Board3D
var highlights: TileHighlights
var hud: BattleHud
var fx: Node3D  ## floating numbers (Label3D)
var props: Node  ## holds the RelicProp nodes (rule objects, no drawing)
var views := {}  ## BattleUnit -> UnitView3D
var prop_views := {}  ## RelicProp -> Node3D (the crystal on its tile)
var mode := Mode.IDLE
var action: BattleAction  ## the attack or skill being aimed
var summoning: VesselData  ## the vessel being summoned
var aim := TacticalGrid.NO_CELL
var selected: BattleUnit  ## shown on the status card
var summary: BattleSummary  ## set when the battle ends
var round := 1  ## shown as TURN n: goes up when a unit that already acted this round acts again
var _acted_this_round := {}

var _touches := {}
var _drag = null
var _moved_finger := false


func _ready() -> void:
	game = pending_game if pending_game != null else SaveGame.new_game()
	pending_game = null
	var setup := pending_setup
	pending_setup = null
	if setup != null:
		map_path = setup.map_path
	_build_world()
	battle = BattleController.new()
	add_child(battle)
	battle.setup(grid)
	battle.deployment.prop_parent = props.get_path()
	battle.deployment.relic_placed.connect(_on_relic_placed)
	battle.deployment.unit_deployed.connect(_add_view)
	battle.deployment.vessel_untethered.connect(_on_untethered)
	var limit := int(map_data.get("max_summons", DeploymentManager.DEFAULT_SUMMON_LIMIT))
	CampaignFlow.prepare_deployment(game, battle.deployment, setup.max_summons if setup != null else limit)
	hud = BattleHud.new()
	add_child(hud)
	hud.palette.action_chosen.connect(_on_action_chosen)
	hud.palette.summon_chosen.connect(_on_summon_chosen)
	hud.palette.end_turn_pressed.connect(end_turn)
	hud.palette.cancel_pressed.connect(cancel)
	hud.palette.defend_pressed.connect(defend)
	hud.palette.move_pressed.connect(_on_move_pressed)
	hud.turn_order.unit_pressed.connect(select)
	hud.return_pressed.connect(_return_to_barracks)
	if setup != null:
		setup.populate(self)
	else:
		SampleBattle.populate(self)
	battle.start()
	frame_board()
	get_viewport().size_changed.connect(frame_board)
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
	if _acted_this_round.has(bu):
		round += 1
		_acted_this_round.clear()
	_acted_this_round[bu] = true
	hud.set_turn(round)
	hud.card.show_unit(bu)
	select(null)
	for u in views:
		views[u].set_guard(u.guarding)  # a Defend ends when the unit's own turn comes round
	if views.has(bu):
		views[bu].face(board.screen_dir(bu.facing, bu.cell))  # turns toward its nearest foe
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


## DEFEND: the acting unit guards (half damage until its next turn) and its turn ends.
func defend() -> void:
	var bu := battle.current
	if bu == null or mode == Mode.OVER or bu.team != 0:
		return
	highlights.clear_all()
	_clear_previews()
	if not battle.defend(bu):
		return
	if views.has(bu):
		views[bu].set_guard(true)
	hud.say("%s takes a defensive stance." % bu.data.display_name)
	if _check_end():
		return
	next_turn()


## MOVE: shows the walkable tiles (again) with a hint; Cancel goes back to the commands.
func _on_move_pressed() -> void:
	var bu := battle.current
	if bu == null or battle.moved:
		return
	var cells := battle.move_range(bu).cells().filter(func(c): return c != bu.cell)
	highlights.clear(TileHighlights.Kind.REACH)
	highlights.show_cells(TileHighlights.Kind.MOVE, cells)
	_set_mode(Mode.MOVE)
	hud.palette.show_aiming("Move  ·  click a glowing tile to walk there.")


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
	var v: UnitView3D = views.get(bu)
	if animate and v:
		_set_mode(Mode.BUSY)
		# long moves run; each tile step faces its own screen direction (eight-way sheets pick the drawn
		# direction). The step time matches the cycle so the feet do not slide.
		var gait := "run" if path.size() >= RUN_FROM and v.has_anim("run") else "walk"
		v.play(gait)
		if gait == "run":
			v.spawn_fx("smoke", v.position + Vector3(0, 0.05, 0), 0.5)  # dust kicked up at the start of a run
		var prev := from
		for step in path:
			v.face(board.screen_dir(step - prev, prev))
			var tw := create_tween()
			tw.tween_property(v, "position", board.top_point(step.x, step.y), RUN_STEP if gait == "run" else WALK_STEP)
			await tw.finished
			prev = step
		v.play("idle")
	_place(bu)
	if battle.current == bu and bu.team == 0:
		_player_commands()


## Seconds per tile when walking / running, and the path length from which a unit runs.
const WALK_STEP := 0.3
const RUN_STEP := 0.17
const RUN_FROM := 4


## The animation for an action: the weapon Attack is the melee combo, physical skills the heavy attack,
## everything else a cast.
static func action_anim(a: BattleAction) -> String:
	if a.skill != null and a.skill.animation != "":
		return a.skill.animation
	if a.is_attack():
		return "attack"
	return "heavy" if a.category() == Proficiency.Category.PHYSICAL else "cast"


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
	var v: UnitView3D = views.get(bu)
	var anim := action_anim(a)
	if v:
		v.face(board.screen_dir(bu.facing, bu.cell))
		v.act(anim)
	# units pushed back by the action slide to their new tile (or are placed at once without animation)
	for p in r.pushed:
		var pv: UnitView3D = views.get(p.unit)
		if animate and pv:
			create_tween().tween_property(pv, "position", board.top_point(p.to.x, p.to.y), WALK_STEP)
		else:
			_place(p.unit)
	if animate and v:
		# the numbers, hurt and knockouts show on the attacker's strike frame (the visible impact)
		var shown := [false]
		var show := func(_a = ""):
			if shown[0] or not is_inside_tree():
				return
			shown[0] = true
			_show_hits(bu, r, anim, at)
		v.struck.connect(show, CONNECT_ONE_SHOT)
		get_tree().create_timer(1.6).timeout.connect(show)  # in case the animation is interrupted
	else:
		_show_hits(bu, r, anim, at)
	var names := r.hits.map(func(h): return h.target.data.display_name)
	hud.say("%s used %s%s." % [bu.data.display_name, a.display_name(), (" on " + ", ".join(names)) if not names.is_empty() else ""]
		+ ("  %s gained a skill level." % bu.data.display_name if r.skill_levels_gained > 0 else ""))
	return r


## What an action did, shown on the board: effects from the attacker's sheet at the aimed tile (heavy:
## a ground eruption, cast: a magic circle and a burst, melee: a slash), the numbers, hurt and knockouts.
func _show_hits(bu: BattleUnit, r: ActionResult, anim: String, at: Vector2i) -> void:
	var v: UnitView3D = views.get(bu)
	if v and animate and board.in_bounds(at):
		var p := board.top_point(at.x, at.y)
		var own := r.action.skill.effect if r.action != null and r.action.skill != null else ""
		if own != "":  # the skill's own effect replaces the default one for its animation
			v.spawn_fx(own, p + Vector3(0, 0.3, 0), 0.8)
		match "" if own != "" else anim:
			"heavy":
				v.spawn_fx("eruption", p)
				v.spawn_fx("smoke", p + Vector3(0, 0.05, 0), 0.7)  # dust thrown up by the impact
			"cast":
				v.spawn_fx("circle", p + Vector3(0, 0.02, 0))
				v.spawn_fx("burst", p + Vector3(0, 0.4, 0))
			"attack":
				v.spawn_fx("slash", p + Vector3(0, 0.3, 0), 0.8)
	for h in r.hits:
		var tv: UnitView3D = views.get(h.target)
		if h.missed:
			_float(h.target, "Miss", Color(0.75, 0.75, 0.8), true)
			continue
		_float(h.target, ("+%d" % h.amount) if h.heal else str(h.amount), HudStyle.HP if h.heal else Color("#ffd27a"), true)
		if tv == null:
			continue
		if h.knocked_out:
			tv.play("ko")
			tv.set_gray(0.45)
		elif not h.heal:
			tv.act("hit")


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
		# a skill that reopens the walk (Quick Jab): walk again with the move points left
		if battle.walk_budget >= 0 and not battle.moved and battle.current == bu:
			var again := EnemyAI.plan(battle, bu)
			if again.moves():
				await walk(bu, again.move_to)
			if not is_inside_tree() or battle.current != bu:
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
	var map := Terrain.load_map(map_path)
	map_data = map
	board = Board3D.new()
	board.name = "Board"
	add_child(board)
	board.setup(map)
	grid = TacticalGrid.from_map(map)
	highlights = TileHighlights.new(board)
	highlights.name = "Highlights"
	add_child(highlights)
	fx = Node3D.new()
	fx.name = "Numbers"
	add_child(fx)
	props = Node.new()
	props.name = "Props"
	add_child(props)


func _add_view(bu: BattleUnit) -> void:
	if views.has(bu):
		return
	var v := UnitView3D.new()
	board.add_child(v)
	v.setup(UnitLook.sheet_for(bu.data), UnitLook.tint_for(bu.data))
	board.add_upright(v)
	views[bu] = v
	_place(bu)
	battle.face_nearest_foe(bu)
	v.face(board.screen_dir(bu.facing, bu.cell))
	if animate and bu.is_vessel():
		v.set_alpha(0.0)
		create_tween().tween_method(v.set_alpha, 0.0, 1.0, 0.4)


func _place(bu: BattleUnit) -> void:
	var v: UnitView3D = views.get(bu)
	if v:
		v.position = board.top_point(bu.cell.x, bu.cell.y)
		v.set_wading(grid.terrain(bu.cell) == "w")


func _on_untethered(bu: BattleUnit, went_home: bool) -> void:
	var v: UnitView3D = views.get(bu)
	views.erase(bu)
	hud.say("%s faded. %s" % [bu.data.display_name, "Its relic went home." if went_home else "Its relic fell to the ground."])
	if v == null:
		return
	board.uprights.erase(v)
	if animate:
		var tw := create_tween()
		tw.tween_method(v.set_alpha, v.get_alpha(), 0.0, 0.5)
		tw.tween_callback(v.queue_free)
	else:
		v.queue_free()


## A relic on the field: a small crystal floating over its tile with a soft cyan light, bobbing. It goes
## away with its prop (summoned onto, or taken home).
func _on_relic_placed(p: RelicProp) -> void:
	var n := Node3D.new()
	n.position = board.top_point(p.cell.x, p.cell.y)
	board.add_child(n)
	var gem := Sprite3D.new()
	gem.texture = load("res://assets/props/sky_crystal.png")
	gem.pixel_size = 0.85 / gem.texture.get_width()
	gem.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	gem.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	gem.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	gem.shaded = false
	gem.offset = Vector2(0, gem.texture.get_height() / 2.0)
	gem.position.y = 0.05
	n.add_child(gem)
	var light := OmniLight3D.new()
	light.light_color = Color(0.45, 0.9, 1.0)
	light.light_energy = 1.6
	light.omni_range = 2.0
	light.position.y = 0.45
	n.add_child(light)
	prop_views[p] = n
	p.tree_exiting.connect(func():
		prop_views.erase(p)
		if is_instance_valid(n):
			n.queue_free())
	if animate:
		var tw := gem.create_tween().set_loops()
		tw.tween_property(gem, "position:y", 0.22, 1.1).set_trans(Tween.TRANS_SINE)
		tw.tween_property(gem, "position:y", 0.05, 1.1).set_trans(Tween.TRANS_SINE)


func _float(bu: BattleUnit, text: String, col: Color, rises: bool) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = HudStyle.font(true)
	l.font_size = 44
	l.outline_size = 12
	l.modulate = col
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.pixel_size = 0.011
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.render_priority = 10
	l.position = board.top_point(bu.cell.x, bu.cell.y) + Vector3(0, 2.3, 0)
	l.set_meta("preview", not rises)
	fx.add_child(l)
	if rises and animate:
		var tw := l.create_tween().set_parallel()
		tw.tween_property(l, "position:y", l.position.y + 0.6, 0.8)
		tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.4)
		tw.chain().tween_callback(l.queue_free)
	elif rises:
		l.queue_free()


func _clear_previews() -> void:
	for l in fx.get_children():
		if l.get_meta("preview", false):
			l.queue_free()


## Centres the battlefield in the screen space the HUD leaves free at the fixed camera (lock_camera). The camera
## stays there for the whole battle.
func frame_board() -> void:
	if board == null or board.cam == null:
		return
	lock_camera(board, get_viewport().get_visible_rect().size)


## The one camera position (the owner's rule): the fixed lens, angle and distance, the board centred in the
## screen space between the battle HUD's top and bottom bands. Story scenes use it too, so the view does not
## move when a scene turns into a battle. It never pans, zooms or turns.
static func lock_camera(b: Board3D, view: Vector2) -> void:
	var scale := view.y / 1080.0  # the HUD is laid out at 1080p and scales with the screen
	var free := Rect2(Vector2(80, BattleHud.TOP_BAND) * scale, Vector2(view.x - 160 * scale, view.y - (BattleHud.TOP_BAND + BattleHud.BOTTOM_BAND) * scale))
	b.frame_rect(free, view)


func _set_mode(m: Mode) -> void:
	mode = m


# ---------- camera and taps ----------

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		match e.keycode:
			KEY_ESCAPE: cancel()
	elif e is InputEventScreenTouch:
		if e.pressed:
			_touches[e.index] = e.position
			if _touches.size() == 1:
				_drag = e.position
				_moved_finger = false
			elif _touches.size() == 2:
				_moved_finger = true  # a second finger is never a tap
		else:
			_touches.erase(e.index)
			if _touches.is_empty():
				if _drag != null and not _moved_finger:
					_tap(e.position)
				_drag = null
	elif e is InputEventScreenDrag:
		_touches[e.index] = e.position
		if _drag != null and _touches.size() == 1:
			var dv: Vector2 = e.position - _drag
			if not _moved_finger and absf(dv.x) + absf(dv.y) > 10:
				_moved_finger = true
			# a drag is never a tap; it does not move the camera (the camera is static)


func _tap(screen_pos: Vector2) -> void:
	if mode == Mode.BUSY or mode == Mode.OVER or mode == Mode.ENEMY:
		return
	var c := board.pick(screen_pos)
	if c != TacticalGrid.NO_CELL:
		tap_cell(c)
