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
@export var enemy_delay := 0.3
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
var feedback: HitFeedback  ## how attacks look and sound at the moment of impact (hitstop, recoil, flash, particles, shake, numbers)
var props: Node  ## holds the RelicProp nodes (rule objects, no drawing)
var views := {}  ## BattleUnit -> UnitView3D
var prop_views := {}  ## RelicProp -> Node3D (the crystal on its tile)
var mode := Mode.IDLE
var action: BattleAction  ## the attack or skill being aimed
var summoning: VesselData  ## the vessel being summoned
var _hold_reveal := TacticalGrid.NO_CELL  ## while a summon is being committed: the tile whose vessel waits for the stone's burst
var aim := TacticalGrid.NO_CELL
var selected: BattleUnit  ## shown on the status card
var summary: BattleSummary  ## set when the battle ends
var round := 1  ## shown as TURN n: goes up when a unit that already acted this round acts again
var _acted_this_round := {}
var setup: BattleSetup  ## the story battle's setup; null for the sample fight
var tutorial: BattleTutorial  ## the summon tutorial's hints, in the story's chamber battle
var scenario: ScenarioRules  ## the story battle's own rules (BattleSetup.rules), or null
var bark: StoryBark  ## spoken lines over the fight (reinforcements, a unit fleeing)
var _fled_queue: Array[BattleUnit] = []  ## units that fled this action (BattleController.unit_fled), their exits play when it has been shown
var _start_snapshot: Dictionary  ## the game as the battle began
var _waves_done := {}  ## wave index -> true, once it has arrived
var momentum := Momentum.new()  ## the party's gauge and Chain (see Momentum); spent on a Surge
var rating := BattleRating.new()  ## what the battle's grade is made of (see BattleRating)
var music: BattleMusic
var _surge_for: BattleUnit  ## the unit a Surge is armed on (its Momentum comes back if the turn ends unused)
var _slow_id := 0
var _slow_base := 1.0  ## the engine's time scale before a slow-motion beat
var _slowed := false

## Battle speed (Tab or the SPEED button): how fast the whole fight plays. Saved with the settings.
const SPEEDS: Array[float] = [1.0, 2.0, 3.0]
static var speed := 1.0
static var _speed_loaded := false
## The BATTLE START banner over the first seconds of a fight (the screenshot tools turn it off).
static var show_intro := true

var _touches := {}
var _drag = null
var _moved_finger := false


func _ready() -> void:
	game = pending_game if pending_game != null else SaveGame.new_game()
	pending_game = null
	setup = pending_setup
	pending_setup = null
	GameSession.game = game
	_start_snapshot = SaveCodec.encode(game)  # what the party was before this battle: a lost battle gives all of it back (see _check_end)
	if setup != null:
		map_path = setup.map_path
	_build_world()
	battle = BattleController.new()
	add_child(battle)
	battle.setup(grid)
	battle.turn_ended.connect(_on_turn_ended)
	battle.deployment.prop_parent = props.get_path()
	battle.deployment.relic_placed.connect(_on_relic_placed)
	battle.deployment.unit_deployed.connect(_add_view)
	battle.unit_fled.connect(func(u): _fled_queue.append(u))
	battle.telegraph_set.connect(func(u, tiles):
		highlights.show_cells(TileHighlights.Kind.WARNING, tiles)
		hud.say("%s begins a judgment: leave the marked ground!" % u.data.display_name)
		_float(u, "Judgment! Move off the red tiles", Color(1.0, 0.4, 0.3), true)
		if animate:
			CombatAudio.play(self, "warning")
			hud.callouts.callout("DANGER", Color("#ff5a4a"), 52))
	battle.sword_dropped.connect(_on_sword_dropped)
	battle.sword_collected.connect(_on_sword_collected)
	battle.deployment.vessel_untethered.connect(_on_untethered)
	var limit := int(map_data.get("max_summons", DeploymentManager.DEFAULT_SUMMON_LIMIT))
	CampaignFlow.prepare_deployment(game, battle.deployment, setup.max_summons if setup != null else limit)
	hud = BattleHud.new()
	add_child(hud)
	hud.animate = animate
	hud.bars.setup(board, views)
	hud.gauge.surge_pressed.connect(toggle_surge)
	hud.gauge.speed_pressed.connect(cycle_speed)
	momentum.changed.connect(_refresh_gauge)
	momentum.filled.connect(_on_momentum_full)
	music = BattleMusic.new()
	add_child(music)
	_load_speed()
	hud.gauge.set_speed(speed)
	bark = StoryBark.new()
	add_child(bark)
	hud.palette.action_chosen.connect(_on_action_chosen)
	hud.palette.summon_chosen.connect(_on_summon_chosen)
	hud.palette.end_turn_pressed.connect(end_turn)
	hud.palette.cancel_pressed.connect(cancel)
	hud.palette.defend_pressed.connect(defend)
	hud.palette.move_pressed.connect(_on_move_pressed)
	hud.turn_order.unit_pressed.connect(select)
	hud.return_pressed.connect(_after_battle)
	if setup != null:
		setup.populate(self)
	else:
		SampleBattle.populate(self)
	if setup != null and setup.objective != "":
		hud.set_objective(setup.objective)
	if setup != null and not setup.rules.is_empty():
		scenario = ScenarioRules.new(self, setup.rules)
	if setup != null and setup.tutorial:
		hud.set_objective("Defeat both Ashen Squires")
		tutorial = BattleTutorial.new(self)
		add_child(tutorial)
	battle.start()
	frame_board()
	get_viewport().size_changed.connect(frame_board)
	if animate:
		music.play("battle_theme")
		if speed != 1.0:
			Engine.time_scale = speed
		if show_intro:
			CombatAudio.play(self, "battle_start")
			hud.callouts.banner("Battle Start", hud.objective_label.text.trim_prefix("•  "))
	next_turn()
	if setup != null and animate and not setup.opening_line.is_empty():
		bark.say(setup.opening_line[0], setup.opening_line[1], setup.opening_line[2], 2.4)  # spoken as the fight begins


## Places an enemy and draws it.
func add_enemy(data: EnemyData, cell: Vector2i) -> BattleUnit:
	var bu := battle.add_enemy(data, cell)
	if bu != null:
		_add_view(bu)
	return bu


# ---------- turns ----------

func next_turn() -> void:
	if _surge_for != null:  # a Surge that was armed and never used: its Momentum comes back
		_surge_aura(_surge_for, false)
		_surge_for = null
		battle.surge_unit = null
		momentum.refund()
	var bu := battle.next_turn()
	hud.bars.current = bu
	if bu == null:
		_check_end()
		return
	if _acted_this_round.has(bu):
		round += 1
		_acted_this_round.clear()
	_acted_this_round[bu] = true
	hud.set_turn(round)
	if scenario != null:
		scenario.on_round(round)
		if _check_end():
			return
	await _arrivals()  # reinforcements due this round
	if battle.telegraphs.any(func(t): return t.user == bu):
		await _land_telegraphs(bu)  # the Warden's charged attack lands before he does anything else
		if _check_end():
			return
	focus_cell(bu.cell)  # a wide map scrolls to whoever acts
	hud.card.show_unit(bu)
	select(null)
	for u in views:
		views[u].set_guard(u.guarding)  # a Defend ends when the unit's own turn comes round
	if views.has(bu):
		views[bu].face(board.screen_dir(bu.facing, bu.cell))  # turns toward its nearest foe
	hud.turn_order.show_turns(battle.turns)
	if bu.loses_turn():  # asleep or stunned: the turn is lost
		_float(bu, "Zzz... asleep" if bu.has_status(BattleUnit.SLEEP) else "Stunned!", Color(0.8, 0.85, 1.0), true)
		hud.say("%s cannot act (%s)." % [bu.data.display_name, SkillFx.status_label(BattleUnit.SLEEP if bu.has_status(BattleUnit.SLEEP) else BattleUnit.STUN).to_lower()])
		if animate:
			await get_tree().create_timer(0.9).timeout
		if is_inside_tree() and battle.current == bu and mode != Mode.OVER:
			end_turn()
		return
	if bu.team != 0 or bu.is_unruly():  # a confused or berserk unit acts by itself, whoever it fights for
		_set_mode(Mode.ENEMY)
		hud.palette.show_enemy_turn(bu)
		_enemy_turn(bu)
		return
	hud.say("%s's turn" % bu.data.display_name)
	if animate:
		CombatAudio.play(self, "turn_player", 1.0, -5.0)
	_player_commands()


## A unit that ended its turn in water is slowed for its next turn (BattleController.WADING_SLOW): say so over it.
func _on_turn_ended(bu: BattleUnit) -> void:
	if bu.last_poison > 0 and views.has(bu):
		_float(bu, "Poison -%d" % bu.last_poison, Color(0.55, 0.9, 0.35), true)
	for n in bu.tick_notes:
		if views.has(bu):
			_float(bu, n, Color(1.0, 0.6, 0.3) if n.begins_with("Burn") or n.begins_with("Doom") else Color(0.5, 1.0, 0.6), true)
	if bu.is_down() and views.has(bu) and not bu.fled:
		views[bu].play("ko")  # a doom that ran out
		views[bu].set_gray(0.45)
	if bu.slow > 0 and not bu.is_down() and grid.terrain(bu.cell) == "w" and views.has(bu):
		_float(bu, "Wading: -%d Move" % bu.slow, Color(0.55, 0.85, 1.0), true)


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
	_face_view(bu)
	highlights.clear_all()
	action = null
	summoning = null
	if not battle.moved:
		var cells := battle.move_range(bu).cells().filter(func(c): return c != bu.cell)
		highlights.show_cells(TileHighlights.Kind.MOVE, cells)
		_set_mode(Mode.MOVE)
	else:
		_set_mode(Mode.IDLE)
		_show_facing()
	hud.palette.show_commands(bu, battle)
	hud.card.show_unit(bu)
	_refresh_gauge()


## After a move and before acting: the four tiles beside the unit light up (the one it already faces brighter), and a click on one turns it that way
## (BattleController.face). Doing nothing keeps the direction of its last step.
func _show_facing() -> void:
	var bu := battle.current
	highlights.clear(TileHighlights.Kind.FACE)
	if bu == null or bu.team != 0 or battle.acted:
		return
	var cells: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if grid.in_bounds(bu.cell + d):
			cells.append(bu.cell + d)
	highlights.show_cells(TileHighlights.Kind.FACE, cells)
	highlights.show_cells(TileHighlights.Kind.AIM, [bu.cell + bu.facing] if grid.in_bounds(bu.cell + bu.facing) else [])
	hud.say("Pick a direction: click a glowing tile beside %s (or press Q / E) to turn, or just choose a command to keep this one." % bu.data.display_name)


const TURN_ORDER: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]


## Turns the acting unit a quarter turn (+1 clockwise on the board's steps, -1 back) at any time before it acts (owner, Nov 2026: Q and E, or a click on the
## unit itself): while aiming, the reach, the aim and the preview are redrawn for the new direction. Returns true when it turned.
func turn_current(step: int) -> bool:
	var bu := battle.current
	if bu == null or bu.team != 0 or mode in [Mode.BUSY, Mode.OVER, Mode.ENEMY, Mode.SUMMON]:
		return false
	var i := TURN_ORDER.find(bu.facing)
	var to := TURN_ORDER[posmod((i if i >= 0 else 0) + step, 4)]
	if not battle.face(bu, to):
		return false
	var v: UnitView3D = views.get(bu)
	if v:
		v.face(board.screen_dir(bu.facing, bu.cell))
	match mode:
		Mode.AIM, Mode.CONFIRM:  # the reach follows the new direction; the old aim and its preview are gone
			aim = TacticalGrid.NO_CELL
			_clear_previews()
			highlights.clear(TileHighlights.Kind.AREA)
			highlights.clear(TileHighlights.Kind.AIM)
			highlights.show_cells(TileHighlights.Kind.REACH, battle.highlights(bu, action))
			_set_mode(Mode.AIM)
		Mode.IDLE:
			highlights.clear(TileHighlights.Kind.AIM)
			highlights.show_cells(TileHighlights.Kind.AIM, [bu.cell + bu.facing] if grid.in_bounds(bu.cell + bu.facing) else [])
	hud.card.show_unit(bu)
	return true


## A tap on one of the four tiles beside the unit turns it that way.
func face_cell(c: Vector2i) -> bool:
	var bu := battle.current
	if bu == null or mode != Mode.IDLE or not highlights.shown(TileHighlights.Kind.FACE).has(c):
		return false
	if not battle.face(bu, c - bu.cell):
		return false
	var v: UnitView3D = views.get(bu)
	if v:
		v.face(board.screen_dir(bu.facing, bu.cell))
	highlights.clear(TileHighlights.Kind.AIM)
	highlights.show_cells(TileHighlights.Kind.AIM, [bu.cell + bu.facing])
	hud.card.show_unit(bu)
	return true


# ---------- taps ----------

## What a tap on a board cell does in the current mode.
func tap_cell(c: Vector2i) -> void:
	var me := battle.current
	if me != null and me.team == 0 and c == me.cell and mode in [Mode.IDLE, Mode.MOVE, Mode.AIM, Mode.CONFIRM] \
			and not (mode in [Mode.AIM, Mode.CONFIRM] and highlights.shown(TileHighlights.Kind.REACH).has(c)):  # a tap on the unit turns it (a self-target is aimed instead)
		if turn_current(1):
			return
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
		Mode.IDLE:
			if face_cell(c):
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
			focus_cell(step)  # the camera goes along with the walk
			CombatAudio.play(self, "step", randf_range(0.85, 1.15), -2.0)
			v.face(board.screen_dir(step - prev, prev))
			var tw := create_tween()
			tw.tween_property(v, "position", board.top_point(step.x, step.y), RUN_STEP if gait == "run" else WALK_STEP)
			await tw.finished
			prev = step
		v.play("idle")
		_face_view(bu)  # the walk ends looking at the nearest enemy (BattleController.move)
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
	hud.palette.show_aiming("%s  ·  %s. Click a glowing tile to aim, click it again to confirm. Q / E turns." % [a.display_name(), "free" if a.sp_cost() == 0 else "%d SP" % a.sp_cost()])


## What the picture of a unit faces: its facing, except that a character with all eight directions (`dirs8`) looks straight at the
## nearest enemy when that enemy lies the way it faces, diagonals included (the logic still faces one of the four).
func _face_view(bu: BattleUnit) -> void:
	var v: UnitView3D = views.get(bu)
	if v == null:
		return
	var look := bu.facing
	if v.animator.dirs8():
		var foe := battle.nearest_foe(bu)
		if foe != null and foe.cell != bu.cell and BattleController.dir_toward(bu.cell, foe.cell) == bu.facing:
			look = foe.cell - bu.cell
	v.face(board.screen_dir(look, bu.cell))


func _aim_at(c: Vector2i) -> void:
	var av: UnitView3D = views.get(battle.current) if battle.current != null else null
	if av != null and av.animator.dirs8() and c != battle.current.cell:  # the picture turns to the aimed tile, diagonals included
		av.face(board.screen_dir(c - battle.current.cell, battle.current.cell))
	aim = c
	if battle.current != null:
		focus(float(battle.current.cell.y + c.y) / 2.0 + 0.5)  # keep the user and the aimed tile in view
	var p := battle.preview(battle.current, action, c)
	highlights.show_cells(TileHighlights.Kind.AREA, p.area.tiles)
	highlights.show_cells(TileHighlights.Kind.AIM, [c])
	_clear_previews()
	for h in p.hits:
		_float(h.target, ("+%d" % h.amount) if h.heal else ("-%d%s" % [h.amount, "  KO" if h.knocked_out else ""]), HudStyle.HP if h.heal else Color.WHITE, false)
	hud.show_forecast(DamageForecast.make(battle, battle.current, action, c))  # the prediction slides out off the HUD's side
	_set_mode(Mode.CONFIRM)
	var o = grid.occupant(c)
	if o is BattleUnit:
		select(o)


func _perform() -> void:
	var r := await _resolve(battle.current, action, aim)
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
	hud.hide_forecast()
	_clear_previews()
	var bond_with := ""  # the vessel a human is studying this skill from, and the bond with it before this use
	var bond_before := 0
	if a.skill != null and bu.team == 0 and bu.data.is_human() and bu.data.skill_tree != null:
		var study := bu.data.skill_tree.mastery_of(a.skill)
		if study != null and study.mentor_name != "":
			bond_with = study.mentor_name
			bond_before = bu.data.skill_tree.bond_level(bond_with)
	var r := battle.perform(bu, a, at)
	highlights.clear(TileHighlights.Kind.REACH)
	highlights.clear(TileHighlights.Kind.AREA)
	highlights.clear(TileHighlights.Kind.AIM)
	if not r.ok:
		return r
	_record(bu, r)
	var v: UnitView3D = views.get(bu)
	var anim := action_anim(a)
	if v:
		var look_at := bu.facing
		if v.animator.dirs8() and at != bu.cell:  # a character with all eight directions swings toward what it hits, diagonals included
			look_at = at - bu.cell
		v.face(board.screen_dir(look_at, bu.cell))
		v.act(anim)
		if animate:
			feedback.anticipate(bu, a, anim, at)  # the wind-up and the swing sound; the impact itself waits for the strike frame
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
		+ "".join(r.followups.map(func(f): return "  %s follows up%s." % [f.unit.data.display_name, " and misses" if f.hit.missed else ""]))
		+ ("  %s gained a skill level." % bu.data.display_name if r.skill_levels_gained > 0 else "")
		+ ("  %s learned %s for good!" % [bu.data.display_name, r.skill_learned.display_name] if r.skill_learned != null else ""))
	_skill_training(bu, r, bond_with, bond_before)
	if not _fled_queue.is_empty():
		await _play_flees()
	return r


## A telegraphed attack lands (BattleController.land_telegraphs): the marked tiles flash and everyone standing on them takes the blow.
func _land_telegraphs(bu: BattleUnit) -> void:
	var aims: Array = battle.telegraphs.filter(func(t): return t.user == bu).map(func(t): return t.aim)
	var results := battle.land_telegraphs(bu)
	highlights.clear(TileHighlights.Kind.WARNING)
	for i in results.size():
		var r: ActionResult = results[i]
		if not r.ok:
			continue
		var v: UnitView3D = views.get(bu)
		if v:
			v.act("cast")
		_show_hits(bu, r, "heavy", aims[i] if i < aims.size() else bu.cell)
		hud.say("%s's judgment falls!" % bu.data.display_name)
	if animate:
		await get_tree().create_timer(1.2).timeout


## A fleeing unit (Vesper at 40% HP): after the blow has shown, it throws a smoke bomb, says its line and is gone from the field.
func _play_flees() -> void:
	var queue := _fled_queue.duplicate()
	_fled_queue.clear()
	if animate:
		await get_tree().create_timer(1.1).timeout
	for bu in queue:
		var v: UnitView3D = views.get(bu)
		var yields := setup != null and setup.flee_style == "yield"  # the King: no smoke, he stays in view while he speaks
		if v != null and animate:
			if yields:
				v.hold("ko", 2)
			else:
				v.spawn_fx("smoke", v.position + Vector3(0, 0.1, 0), 1.6)
				v.spawn_fx("burst", v.position + Vector3(0, 0.5, 0), 1.3)
			if setup != null and not setup.flee_line.is_empty():
				bark.say(setup.flee_line[0], setup.flee_line[1], setup.flee_line[2], 2.2)
			if yields:
				await get_tree().create_timer(2.6).timeout
			var tw := create_tween()
			tw.tween_method(v.set_alpha, 1.0, 0.0, 0.8)
			await tw.finished
			if setup != null and not setup.flee_line.is_empty():
				await get_tree().create_timer(3.0).timeout
		if v != null:
			v.visible = false
	hud.turn_order.show_turns(battle.turns)


## Reinforcements whose round has come (BattleSetup.waves): they step out of the smoke on their cells (or the nearest free ones).
func _arrivals() -> void:
	if setup == null:
		return
	for i in setup.waves.size():
		var w: Dictionary = setup.waves[i]
		if _waves_done.has(i) or round < int(w.round):
			continue
		_waves_done[i] = true
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var arrived: Array[BattleUnit] = []
		for e in w.enemies:
			var c := _free_near(e[1])
			if c == TacticalGrid.NO_CELL:
				continue
			if not setup.fixed_styles:
				EnemyStyles.assign(e[0], rng)
			var bu := add_enemy(e[0], c)
			if bu != null:
				arrived.append(bu)
				var v: UnitView3D = views[bu]
				v.face(board.screen_dir(bu.facing, bu.cell))
				if animate:
					v.set_alpha(0.0)
					v.spawn_fx("smoke", v.position + Vector3(0, 0.1, 0), 1.2)
					var tw := create_tween()
					tw.tween_method(v.set_alpha, 0.0, 1.0, 0.7)
		hud.turn_order.show_turns(battle.turns)
		if String(w.banner) != "":
			hud.say(String(w.banner))
		if animate and not arrived.is_empty():
			focus_cell(arrived[0].cell)
			var line: Array = w.line
			if not line.is_empty():
				await bark.say(line[0], line[1], line[2])
			else:
				await get_tree().create_timer(0.9).timeout


## A reinforcement (a war standard's soldier, the Hollow Heart's echo) steps out of the smoke on the free tile nearest `c`.
func spawn_enemy_near(data: EnemyData, c: Vector2i) -> BattleUnit:
	var cell := _free_near(c)
	if cell == TacticalGrid.NO_CELL:
		return null
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	EnemyStyles.assign(data, rng)
	var bu := add_enemy(data, cell)
	if bu != null:
		var v: UnitView3D = views[bu]
		v.face(board.screen_dir(bu.facing, bu.cell))
		if animate:
			v.set_alpha(0.0)
			v.spawn_fx("smoke", v.position + Vector3(0, 0.1, 0), 1.0)
			var tw := create_tween()
			tw.tween_method(v.set_alpha, 0.0, 1.0, 0.6)
		hud.turn_order.show_turns(battle.turns)
	return bu


## `c` itself when it can be stood on, else the nearest free tile within three.
func _free_near(c: Vector2i) -> Vector2i:
	for r in 4:
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if absi(dx) + absi(dy) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if grid.in_bounds(n) and grid.can_stand(n) and not grid.is_occupied(n):
					return n
	return TacticalGrid.NO_CELL


## What an action did, shown on the board: effects from the attacker's sheet at the aimed tile (heavy:
## a ground eruption, cast: a magic circle and a burst, melee: a slash), the numbers, hurt and knockouts.
func _show_hits(bu: BattleUnit, r: ActionResult, anim: String, at: Vector2i) -> void:
	focus(float(bu.cell.y + at.y) / 2.0 + 0.5)
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
				if not v.slash_in_frames():
					v.spawn_fx("slash", p + Vector3(0, 0.3, 0), 0.8)
	if animate and feedback != null:  # hitstop, recoil, flash, particles, shake, numbers and sounds, all on this one instant
		feedback.play_hits(bu, r, anim, at)
		_juice(bu, r)
		_show_followups(r)
		return
	for h in r.hits:
		var tv: UnitView3D = views.get(h.target)
		if h.missed:
			_float(h.target, "Resisted" if h.resisted else "Miss", Color(0.75, 0.75, 0.8), true)
			continue
		var text := ""
		if h.amount > 0:
			text = ("+%d" % h.amount) if h.heal else str(h.amount)
		for n in h.notes:  # a cure, poison, a buff: named on screen (Chance! names its stat)
			text = n if text == "" else text + "  " + n
		if text != "":
			_float(h.target, text, (HudStyle.HP if h.heal else Color("#ffd27a")) if h.amount > 0 else Color(0.9, 0.9, 1.0), true)
		if tv == null:
			continue
		if h.knocked_out:
			tv.play("ko")
			tv.set_gray(0.45)
	for fu in r.followups:
		var ftv: UnitView3D = views.get(fu.hit.target)
		if fu.hit.knocked_out and ftv != null:
			ftv.play("ko")
			ftv.set_gray(0.45)


## The pincer's follow-ups, one after the other a beat after the blow: each ally across from the attacker turns to the target (the picture only),
## swings its basic attack, and the half-damage hit is shown like any other. Then it looks the way it did before.
func _show_followups(r: ActionResult) -> void:
	for fu in r.followups:
		await get_tree().create_timer(0.24).timeout
		if not is_inside_tree():
			return
		var fv: UnitView3D = views.get(fu.unit)
		var t: BattleUnit = fu.hit.target
		if fv != null:
			var d := Vector2i(signi(t.cell.x - fu.unit.cell.x), signi(t.cell.y - fu.unit.cell.y))
			fv.face(board.screen_dir(d, fu.unit.cell))
			fv.act("attack")
		feedback.number(fu.unit, "Follow-up!", "note")
		CombatAudio.play(self, "swing_sword", 1.1)
		await get_tree().create_timer(0.18).timeout
		if not is_inside_tree():
			return
		var fr := ActionResult.new()
		fr.ok = true
		fr.action = BattleAction.attack()
		fr.hits.append(fu.hit)
		feedback.play_hits(fu.unit, fr, "attack", t.cell)
		await get_tree().create_timer(0.25).timeout
		if is_inside_tree() and fv != null and not fu.unit.is_down():
			fv.face(board.screen_dir(fu.unit.facing, fu.unit.cell))


## An enemy's turn, played by EnemyAI: walk, show the area it is about to hit, strike, end the turn.
func _enemy_turn(bu: BattleUnit) -> void:
	if scenario != null and await scenario.enemy_turn(bu):
		return
	var p := EnemyAI.plan(battle, bu)
	if enemy_delay > 0.0:
		await get_tree().create_timer(enemy_delay * 0.5).timeout
	if p.moves():
		await walk(bu, p.move_to)
	if not is_inside_tree() or battle.current != bu:
		return
	if p.face != Vector2i.ZERO and battle.face(bu, p.face):  # it turns toward its target before striking
		var ev: UnitView3D = views.get(bu)
		if ev:
			ev.face(board.screen_dir(bu.facing, bu.cell))
		if enemy_delay > 0.0:
			await get_tree().create_timer(enemy_delay * 0.3).timeout
	if p.acts():
		if enemy_delay > 0.0:
			var area := battle.preview(bu, p.action, p.aim).area
			highlights.show_cells(TileHighlights.Kind.AREA, area.tiles)
			highlights.show_cells(TileHighlights.Kind.AIM, [p.aim])
			await get_tree().create_timer(enemy_delay).timeout
			if not is_inside_tree() or battle.current != bu:
				return
		EnemyAI._remember(bu, p.action)
		await _resolve(bu, p.action, p.aim)
		if _check_end():
			return
		# a skill that reopens the walk (Quick Jab): walk again with the move points left
		if battle.walk_budget >= 0 and not battle.moved and battle.current == bu:
			var again := EnemyAI.plan(battle, bu)
			if again.moves():
				await walk(bu, again.move_to)
			if not is_inside_tree() or battle.current != bu:
				return
	elif p.defend and battle.defend(bu):
		if views.has(bu):
			views[bu].set_guard(true)
		hud.say("%s takes a defensive stance." % bu.data.display_name)
		if enemy_delay > 0.0:
			await get_tree().create_timer(enemy_delay * 0.5).timeout
		if _check_end():
			return
		next_turn()
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
	var dm := battle.deployment
	var shard: AltarShardView = null
	var prop := dm.prop_at(c)
	if animate and prop != null and prop_views.has(prop):
		shard = prop_views[prop].get_meta("shard", null)
	_hold_reveal = c if shard != null and dm.can_summon(summoning, c) else TacticalGrid.NO_CELL  # the vessel waits for the stone's burst
	var v := battle.summon_vessel(battle.current, summoning, c)  # the rules decide, at once; what follows is only the picture
	_hold_reveal = TacticalGrid.NO_CELL
	highlights.clear(TileHighlights.Kind.SUMMON)
	if v != null:
		hud.say("%s is tethered to %s." % [v.data.display_name, v.temp_relic().display_name])
		if animate:
			CombatAudio.play(self, "summon")
			var vv: UnitView3D = views.get(v)
			if shard != null and vv != null and shard.begin_summon():
				vv.set_alpha(0.0)
				for ch in shard.get_parent().get_children():
					if ch is Label3D:
						ch.hide()  # the skill label goes with the used stone
				shard.burst.connect(func():
					if is_instance_valid(vv):
						create_tween().tween_method(vv.set_alpha, 0.0, 1.0, 0.3), CONNECT_ONE_SHOT)
			elif vv != null:
				vv.set_alpha(1.0)
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
	if scenario != null:
		scenario.check()
	if battle.outcome == BattleController.Outcome.ONGOING:
		return false
	_set_mode(Mode.OVER)
	highlights.clear_all()
	hud.bars.current = null
	var won := battle.outcome == BattleController.Outcome.WON
	if won:  # the grade, and the bonus XP it adds to the pool before the pool is handed out
		rating.finish(battle.summary, battle.enemies.size(), round, momentum.best_chain)
		battle.summary.rating = rating
		battle.summary.exp_bonus = rating.bonus_for(battle.summary.exp_pool)
		battle.summary.exp_pool += battle.summary.exp_bonus
		if setup != null and setup.map_id != "":
			battle.summary.new_best = game.campaign.record_grade(setup.map_id, rating.grade)
	commit_story_win(game, setup, battle.outcome)  # a story mission won: the map, its unlocks and the story it still owes, before the autosave
	battle.summary.collection_have = SkillCollection.collected(game)
	battle.summary.collection_total = SkillCollection.total()
	summary = CampaignFlow.finish_battle(game, battle)  # a replay earns and saves like any battle
	if battle.outcome == BattleController.Outcome.LOST:
		# a lost battle earns nothing (owner, Nov 2026): the skill progress, XP and relics made in it are taken back, whether the player retries or leaves
		var back := SaveCodec.decode(_start_snapshot)
		if back.ok:
			game = back.game
			GameSession.game = game
			SaveSystem.save_slot(SaveSystem.AUTOSAVE, game)
	if setup != null:
		var lost := "World map" if setup.world else "Try again"
		hud.return_button.text = "Continue" if won else lost
	else:
		hud.return_button.text = "Return to the barracks"
	if animate:
		_end_show(won)  # the last blow is seen, then the fanfare and the results
	else:
		hud.show_result(summary)
		for bu in views:
			if not bu.is_down() and bu.team == 0 and won:
				views[bu].play("victory")
	return true


## The end of the battle, played out: the music stops on the last blow, a beat for it to land, the party's victory pose and the
## fanfare (or the defeat sting), then the results.
func _end_show(won: bool) -> void:
	music.stop(0.4)
	hud.palette.hide_palette()
	await get_tree().create_timer(RESULT_DELAY if won else RESULT_DELAY * 1.3, true, false, true).timeout
	if not is_inside_tree():
		return
	end_slowmo()
	if speed != 1.0:
		Engine.time_scale = 1.0  # the results play at their own pace
	for bu in views:
		if not bu.is_down() and bu.team == 0 and won:
			views[bu].play("victory")
	if won:
		music.play("victory_fanfare", false, "results_loop", 0.0)
	else:
		music.play("defeat_sting", false, "", 0.0)
	hud.show_result(summary)


const RESULT_DELAY := 1.5  ## seconds (real time) between the last blow and the results


## A story mission won (not a replay): clears the map (and opens what it unlocks) and records the post-battle scene it owes as the campaign's
## pending story, so the autosave that follows (CampaignFlow.finish_battle) holds both. Closing the game on the victory screen then loses
## nothing: loading plays the pending scene (WorldData.resume_pending_story). Nothing happens for a loss or a replay.
static func commit_story_win(g: SaveGame, s: BattleSetup, outcome: BattleController.Outcome) -> void:
	if g == null or s == null or s.replay or outcome != BattleController.Outcome.WON:
		return
	if s.map_id != "":
		WorldData.clear_map(g.campaign, s.map_id)
	if s.on_win_scene != "":
		g.campaign.pending_story = s.on_win_scene


## The result panel's button: a story battle won goes on to its next scene with the game as it is now (XP,
## levels), one lost is fought again from the start; the sample fight goes back to the barracks.
func _after_battle() -> void:
	if setup != null and battle.outcome == BattleController.Outcome.WON and setup.on_win != "":
		Cutscene3D.carried_game = game
		var owed := game.campaign.pending_story if game.campaign.pending_story != "" else setup.on_win_scene  # the saved pending story first
		if owed != "":
			StoryScene.queued = owed
			StoryScene.then_battle = null
			get_tree().change_scene_to_file("res://scenes/story_scene.tscn")
			return
		get_tree().change_scene_to_file(setup.on_win)
	elif setup != null and battle.outcome == BattleController.Outcome.LOST and setup.world:
		get_tree().change_scene_to_file("res://scenes/world_map.tscn")
	elif setup != null and battle.outcome == BattleController.Outcome.LOST:
		pending_game = game
		pending_setup = setup
		get_tree().reload_current_scene()
	else:
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
	feedback = HitFeedback.new()
	feedback.name = "HitFeedback"
	add_child(feedback)
	feedback.setup(board, fx, views)
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
		if bu.cell != _hold_reveal:  # (a vessel summoned onto a stone appears at the stone's burst instead: _summon_at)
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


## A sword where an enemy fell: the owner's sword sprite, slightly transparent, bobbing a little with a faint glow, tagged with the
## style and stance it carries. Height SWORD_HEIGHT world units (the King is about 1.9, a tile is 1): shorter than the King and about
## 0.4 of a tile wide (the tile rule).
const SWORD_HEIGHT := 1.1
const SWORD_ALPHA := 0.7
var sword_views := {}  ## cell -> Node3D


func _on_sword_dropped(cell: Vector2i, geometry: int, stance: int) -> void:
	var n := Node3D.new()
	n.position = board.top_point(cell.x, cell.y)
	board.add_child(n)
	var sw := Sprite3D.new()
	sw.texture = load("res://assets/props/sword_drop.png")
	sw.pixel_size = SWORD_HEIGHT / sw.texture.get_height()
	sw.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sw.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sw.transparency = 0.0
	sw.shaded = false
	sw.modulate = Color(1, 1, 1, SWORD_ALPHA)
	sw.offset = Vector2(0, sw.texture.get_height() / 2.0)
	sw.position.y = 0.12
	sw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(sw)
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 0.75, 1.0)
	light.light_energy = 0.9
	light.omni_range = 1.6
	light.position.y = 0.5
	n.add_child(light)
	var tag := Label3D.new()
	tag.text = "%s · %s" % [StanceRules.style_name(geometry), StanceRules.stance_name(stance)]
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.font = Typography.ui("semibold")  # the world labels use the same Inter as the HUD
	tag.pixel_size = 0.0055
	tag.font_size = 34
	tag.outline_size = 12
	tag.modulate = Color(0.8, 0.9, 1.0)
	tag.position.y = SWORD_HEIGHT + 0.3
	n.add_child(tag)
	sword_views[cell] = n
	if animate:
		sw.modulate.a = 0.0
		var tw := sw.create_tween()
		tw.tween_property(sw, "modulate:a", SWORD_ALPHA, 0.4)
		var bob := sw.create_tween().set_loops()
		bob.tween_property(sw, "position:y", 0.24, 1.2).set_trans(Tween.TRANS_SINE)
		bob.tween_property(sw, "position:y", 0.12, 1.2).set_trans(Tween.TRANS_SINE)


## A player unit ended its turn on the sword: it rises quickly above the unit, fading, and is gone; the style and stance are that unit's now.
func _on_sword_collected(bu: BattleUnit, cell: Vector2i, geometry: int, stance: int, is_new: bool) -> void:
	var n: Node3D = sword_views.get(cell)
	sword_views.erase(cell)
	var what := "%s · %s" % [StanceRules.style_name(geometry), StanceRules.stance_name(stance)]
	hud.say("%s took the sword: %s%s" % [bu.data.display_name, what, " is unlocked for %s!" % bu.data.display_name if is_new else " (already known)."])
	if n == null:
		return
	if animate:
		CombatAudio.play(self, "sword_get")
		var sw := n.get_child(0) as Sprite3D
		var tw := n.create_tween().set_parallel(true)
		tw.tween_property(n, "position:y", n.position.y + 2.6, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(sw, "modulate:a", 0.0, 0.45)
		tw.chain().tween_callback(n.queue_free)
	else:
		n.queue_free()


## A relic on the field: a small crystal floating over its tile with a soft cyan light, bobbing. It goes
## away with its prop (summoned onto, or taken home).
func _on_relic_placed(p: RelicProp) -> void:
	var n := Node3D.new()
	n.position = board.top_point(p.cell.x, p.cell.y)
	board.add_child(n)
	var shard := AltarShardView.new()  # the animated stone: idle loop; activate, summon and depleted when it is used
	shard.stretch = board.unit_stretch()
	n.add_child(shard)
	shard.scale = Vector3.ONE * board.unit_size_at(n.position, shard.sprite.pixel_size, shard.stretch)  # the same perspective correction the units get: a stone far up the board is as tall on screen as one near the camera
	var light := OmniLight3D.new()
	light.light_color = Color(0.45, 0.9, 1.0)
	light.light_energy = 1.6
	light.omni_range = 2.0
	light.position.y = 0.45
	n.add_child(light)
	shard.light = light
	n.set_meta("shard", shard)
	var prize := StonePlacement.is_prize(p.relic)
	if prize:  # the prize stone, deep in the enemy's ground: gold, a little larger
		shard.tint = Color(1.0, 0.86, 0.45)
		shard.scale *= 1.2
		light.light_color = Color(1.0, 0.8, 0.35)
		light.light_energy = 2.4
		light.omni_range = 2.6
	if p.relic != null and p.relic.skill != null:  # which skill the stone carries, its rank, and whether it is new to the party
		var sk: SkillData = p.relic.skill
		var fresh := SkillCollection.is_new(game, sk)
		var tag := Label3D.new()
		tag.text = "%s%s\nRank %s  ·  %s%s" % ["★ " if prize else "", sk.display_name, SkillCollection.rank_letter(sk), Proficiency.short_name(sk.category), "  ·  NEW" if fresh else ""]
		tag.line_spacing = -6.0
		n.set_meta("skill", sk)
		n.set_meta("fresh", fresh)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.font = Typography.ui("semibold")
		tag.pixel_size = 0.0055
		tag.font_size = 36
		tag.outline_size = 12
		tag.modulate = Color(1.0, 0.86, 0.5) if prize else (Color(0.75, 0.95, 1.0) if sk.rank == SkillData.Rank.E else SkillCollection.rank_color(sk).lightened(0.25))
		tag.position.y = 3.3  # above the stone (it stands as tall as a character)
		n.add_child(tag)
	prop_views[p] = n
	shard.finished.connect(func():
		if is_instance_valid(n):
			n.queue_free())
	p.tree_exiting.connect(func():
		prop_views.erase(p)
		if is_instance_valid(n) and not shard.is_busy():  # a stone being used finishes its sequence first (the rule object is gone, the picture is not)
			n.queue_free())


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
	var view := get_viewport().get_visible_rect().size
	lock_camera(board, view)
	scroll_range = board.scroll_range(free_rect(view), view)
	scrolling = scroll_range.x <= scroll_range.y
	if scrolling:  # a map wider than the screen: the camera follows the action along it (same lens, angle and distance)
		if not _scroll_started:
			_scroll_started = true
			var k := battle.deployment.king if battle != null and battle.deployment != null else null
			_goal_z = float(k.cell.y) + 0.5 if k != null else board.map.d / 2.0
			_cam_z = clampf(_goal_z, scroll_range.x, scroll_range.y)
		board.scroll_to(_cam_z, scroll_range, free_rect(view), view)


## A map wider than the screen scrolls along its long side (owner, Nov 2026: the one exception to the static camera besides the base).
## `scroll_range` is the (min, max) camera position along it (Board3D.scroll_range), `scrolling` is false for a map that fits.
var scroll_range := Vector2(INF, -INF)
var scrolling := false
var _scroll_started := false
var _cam_z := 0.0  ## where the camera is aimed along the long side now
var _goal_z := 0.0  ## where it is heading (the acting unit, the walk, the aimed tile, the keys)
var _mouse_seen := false  ## the mouse has moved, so its position means something (edge scrolling)
const SCROLL_EASE := 7.0  ## how fast the camera catches up with its goal (per second)
const SCROLL_KEYS := 14.0  ## tiles per second with the arrow keys or A / D
const SCROLL_EDGE := 28.0  ## pixels from the side of the screen where the mouse scrolls it (at 1080p)


## Sends the camera toward the tile column `z` (clamped to the board). A no-op on a map that fits.
func focus(z: float) -> void:
	if scrolling:
		_goal_z = clampf(z, scroll_range.x, scroll_range.y)


func focus_cell(c: Vector2i) -> void:
	focus(float(c.y) + 0.5)


func _process(delta: float) -> void:
	if not scrolling or board == null or board.cam == null:
		return
	var step := 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		step -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		step += 1.0
	var view := get_viewport().get_visible_rect().size
	if _mouse_seen and step == 0.0:
		var mp := get_viewport().get_mouse_position()
		var edge := SCROLL_EDGE * view.y / 1080.0
		if mp.y >= 0.0 and mp.y <= view.y:
			if mp.x >= 0.0 and mp.x < edge:
				step = -1.0
			elif mp.x <= view.x and mp.x > view.x - edge:
				step = 1.0
	if step != 0.0:
		_goal_z = clampf(_goal_z + step * SCROLL_KEYS * delta, scroll_range.x, scroll_range.y)
	if absf(_goal_z - _cam_z) > 0.004:
		_cam_z = lerpf(_cam_z, _goal_z, 1.0 - exp(-SCROLL_EASE * delta))
		if absf(_goal_z - _cam_z) <= 0.004:
			_cam_z = _goal_z
		board.scroll_to(_cam_z, scroll_range, free_rect(view), view)


## The one camera position (the owner's rule): the fixed lens, angle and distance, the board centred in the
## screen space between the battle HUD's top and bottom bands. Story scenes use it too, so the view does not
## move when a scene turns into a battle. It never pans, zooms or turns.
static func lock_camera(b: Board3D, view: Vector2) -> void:
	b.frame_rect(free_rect(view), view)


## The screen space between the battle HUD's top and bottom bands (and a margin at the sides): where the board is framed.
static func free_rect(view: Vector2) -> Rect2:
	var scale := view.y / 1080.0  # the HUD is laid out at 1080p and scales with the screen
	return Rect2(Vector2(80, BattleHud.TOP_BAND) * scale, Vector2(view.x - 160 * scale, view.y - (BattleHud.TOP_BAND + BattleHud.BOTTOM_BAND) * scale))


func _set_mode(m: Mode) -> void:
	mode = m
	if m != Mode.IDLE and highlights != null:
		highlights.clear(TileHighlights.Kind.FACE)  # the facing tiles belong to the idle moment after a move
	if m != Mode.CONFIRM and hud != null:
		hud.hide_forecast()  # the prediction stays only while a tile is aimed


# ---------- camera and taps ----------

func _unhandled_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventKey and e.pressed):
		for n in board.get_children().filter(func(x): return x.has_meta("shard")):
			var sh = n.get_meta("shard", null)
			if sh != null and is_instance_valid(sh) and sh.is_busy():
				sh.skip()  # the summon is already decided: a click or key skips the picture of it
	if e is InputEventMouseMotion:
		_mouse_seen = true
	if e is InputEventKey and e.pressed:
		match e.keycode:
			KEY_ESCAPE: cancel()
			KEY_Q: turn_current(-1)
			KEY_E: turn_current(1)
			KEY_F: toggle_surge()
			KEY_TAB: cycle_speed()
			KEY_M:  # music on or off
				music.set_muted(not BattleMusic.muted)
				hud.say("Music %s." % ("off" if BattleMusic.muted else "on"))
			KEY_N:  # sound effects on or off
				CombatAudio.muted = not CombatAudio.muted
				BattleMusic.save_settings()
				hud.say("Sound effects %s." % ("off" if CombatAudio.muted else "on"))
			KEY_F6:  # accessibility: camera shake on or off
				HitFeedback.reduce_shake = not HitFeedback.reduce_shake
				HitFeedback.save_settings()
				hud.say("Camera shake %s." % ("off" if HitFeedback.reduce_shake else "on"))
			KEY_F7:  # accessibility: white hit flashes on or off
				HitFeedback.reduce_flash = not HitFeedback.reduce_flash
				HitFeedback.save_settings()
				hud.say("Hit flashes %s." % ("off" if HitFeedback.reduce_flash else "on"))
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


# ---------- Momentum, Surge, the grade, and the moments that make a blow count ----------

## Takes a performed action into the Momentum gauge and the battle's rating (the rules side: it runs with or without animation).
func _record(bu: BattleUnit, r: ActionResult) -> void:
	momentum.on_action(bu, r, bu.team == 0 and not bu.is_unruly())
	rating.on_action(bu, r)
	if r.surged:
		_surge_aura(bu, false)
		_surge_for = null
	_refresh_gauge()


func _refresh_gauge() -> void:
	if hud == null or hud.gauge == null or battle == null:
		return
	hud.gauge.show_state(momentum, _can_surge(), _surge_for != null)


func _can_surge() -> bool:
	var bu := battle.current
	return bu != null and bu.team == 0 and not bu.is_unruly() and not battle.acted and momentum.is_full() \
		and mode in [Mode.IDLE, Mode.MOVE, Mode.AIM, Mode.CONFIRM]


func _on_momentum_full() -> void:
	if not animate:
		return
	CombatAudio.play(self, "surge_ready")
	hud.callouts.callout("MOMENTUM MAX", Color("#ffd86a"), 46, 0.9)


## SURGE (F or the button): the acting player unit spends the full gauge; its next damaging action this turn cannot miss and is
## critical on every target (BattleController.surge_unit). Pressed again before attacking, the Surge is called off and the gauge
## comes back; so does it when the turn ends unused. Returns true when something changed.
func toggle_surge() -> bool:
	var bu := battle.current
	if bu == null or bu.team != 0 or bu.is_unruly() or not (mode in [Mode.IDLE, Mode.MOVE, Mode.AIM, Mode.CONFIRM]):
		return false
	if _surge_for == bu:
		battle.surge_unit = null
		_surge_for = null
		momentum.refund()
		_surge_aura(bu, false)
		hud.say("Surge called off.")
		if animate:
			CombatAudio.play(self, "ui_back")
	elif _can_surge() and momentum.spend():
		battle.surge_unit = bu
		_surge_for = bu
		_surge_aura(bu, true)
		hud.say("%s surges: the next attack cannot miss and is critical!" % bu.data.display_name)
		if animate:
			CombatAudio.play(self, "surge")
			hud.callouts.callout("SURGE", Color("#ff9a3d"), 64)
			hud.callouts.flash(Color(1.0, 0.7, 0.3, 0.3), 0.35)
	else:
		return false
	_refresh_gauge()
	if mode == Mode.CONFIRM and aim != TacticalGrid.NO_CELL:
		_aim_at(aim)  # the forecast follows: 100% to hit, a sure critical
	return true


## The glow on a unit a Surge is armed on: embers rising round it and a warm light, until the blow is struck or the Surge is called off.
func _surge_aura(bu: BattleUnit, on: bool) -> void:
	var v: UnitView3D = views.get(bu)
	if v == null or not is_instance_valid(v):
		return
	var old := v.get_node_or_null("SurgeAura")
	if old != null:
		old.queue_free()
	if not on or not animate:
		return
	var n := Node3D.new()
	n.name = "SurgeAura"
	v.add_child(n)
	var ps := CPUParticles3D.new()
	ps.amount = 20
	ps.lifetime = 0.8
	ps.mesh = HitFeedback._quad_mesh(0.11)
	ps.material_override = HitFeedback._material("magic")
	ps.color = Color(1.0, 0.55, 0.15)
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	ps.emission_sphere_radius = 0.5
	ps.direction = Vector3.UP
	ps.spread = 12.0
	ps.gravity = Vector3(0, 1.2, 0)
	ps.initial_velocity_min = 0.8
	ps.initial_velocity_max = 1.6
	ps.scale_amount_min = 0.6
	ps.scale_amount_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ps.color_ramp = ramp
	ps.position.y = 0.3
	n.add_child(ps)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 0.45
	light.omni_range = 1.4
	light.position.y = 0.9
	n.add_child(light)


## What makes a blow count, at the moment it lands (presentation only; BattleController has already decided everything): the
## callouts (SURGE, CRITICAL, PINCER, DOUBLE KO), a beat of slow motion and a shake on a knockout, the XP an enemy was worth
## rising off it, and the finishing blow of the battle: a longer slow motion, a white flash and its own callout.
func _juice(bu: BattleUnit, r: ActionResult) -> void:
	var ours := bu.team == 0
	var crit := false
	var kos := 0
	var ally_fell := false
	var heavy := false
	for h in r.hits:
		if h.heal or h.missed or h.amount <= 0:
			continue
		crit = crit or h.crit
		heavy = heavy or h.amount * 5 >= h.target.max_hp() * 2  # 40% of its life in one blow
		if h.knocked_out:
			if h.target.team != bu.team:
				kos += 1
			ally_fell = ally_fell or h.target.team == 0
			_xp_pop(h.target)
	var pincer := false
	for f in r.followups:
		if f.hit.missed or f.hit.amount <= 0:
			continue
		pincer = true
		if f.hit.knocked_out:
			kos += 1
			ally_fell = ally_fell or f.hit.target.team == 0
			_xp_pop(f.hit.target, 0.9)
	var final_blow := battle.outcome != BattleController.Outcome.ONGOING
	var said := false
	if final_blow and battle.outcome == BattleController.Outcome.WON:
		hud.callouts.callout("FINISHING BLOW", Color("#ffe27a"), 72, 1.1)
		hud.callouts.flash(Color(1, 1, 1, 0.6), 0.5)
		feedback.shake(Vector2(1, 0.4), 0.12, 0.3)
		slowmo(0.22, 0.75)
		said = true
	else:
		if r.surged:
			hud.callouts.callout("SURGE!", Color("#ff9a3d"), 66)
			hud.callouts.flash(Color(1.0, 0.75, 0.35, 0.4), 0.3)
			feedback.shake(Vector2(1, 0.3), 0.1, 0.24)
			said = true
		elif crit:
			hud.callouts.callout("CRITICAL!", Color("#ff6a3d") if ours else Color("#ff4a4a"), 58)
			said = true
		if pincer:
			hud.callouts.callout("PINCER!", Color("#7fe6ff"), 54)
			said = true
		if kos >= 2:
			hud.callouts.callout(["", "", "DOUBLE KO!", "TRIPLE KO!"][kos] if kos <= 3 else "RAMPAGE!", Color("#ffe27a"), 62)
			said = true
		if kos > 0 or ally_fell:
			feedback.shake(Vector2(1, 0.3), 0.07 if not r.surged else 0.1, 0.2)
			slowmo(0.35, 0.22 if kos < 2 else 0.34)
		elif heavy:
			feedback.shake(Vector2(1, 0.2), 0.045)
	if said:
		CombatAudio.play(self, "callout", 1.0, -3.0)


## "+N XP" rising off a beaten enemy, in gold, a moment after it falls.
func _xp_pop(target: BattleUnit, delay := 0.55) -> void:
	if not (target.data is EnemyData) or target.team == 0:
		return
	var xp := (target.data as EnemyData).exp_reward
	if xp <= 0:
		return
	await get_tree().create_timer(delay, true, false, true).timeout
	if is_inside_tree() and feedback != null:
		var l := feedback.number(target, "+%d XP" % xp, "note", 1.1)
		if l != null:
			l.modulate = HudStyle.XP


## A beat of slow motion: the whole picture runs at `factor` for `secs` of real time, then at its own speed again.
func slowmo(factor: float, secs: float) -> void:
	if not animate:
		return
	_slow_id += 1
	var id := _slow_id
	if not _slowed:
		_slow_base = Engine.time_scale
		_slowed = true
	Engine.time_scale = _slow_base * factor
	await get_tree().create_timer(secs, true, false, true).timeout
	if id == _slow_id:
		end_slowmo()


func end_slowmo() -> void:
	if _slowed:
		_slowed = false
		_slow_id += 1
		Engine.time_scale = _slow_base


## Tab or the SPEED button: the next battle speed (1x, 2x, 3x). Kept for the next battles (user://settings.cfg).
func cycle_speed() -> void:
	var i := SPEEDS.find(speed)
	speed = SPEEDS[(i + 1) % SPEEDS.size()]
	end_slowmo()
	if mode != Mode.OVER:
		Engine.time_scale = speed
	hud.gauge.set_speed(speed)
	hud.say("Battle speed %dx." % int(speed))
	var cf := ConfigFile.new()
	cf.load(HitFeedback.SETTINGS_PATH)
	cf.set_value("battle", "speed", speed)
	cf.save(HitFeedback.SETTINGS_PATH)


static func _load_speed() -> void:
	if _speed_loaded:
		return
	_speed_loaded = true
	var cf := ConfigFile.new()
	if cf.load(HitFeedback.SETTINGS_PATH) == OK:
		var s := float(cf.get_value("battle", "speed", 1.0))
		speed = s if SPEEDS.has(s) else 1.0


func _exit_tree() -> void:
	if _slowed:
		end_slowmo()
	if animate and speed != 1.0 and is_equal_approx(Engine.time_scale, speed):
		Engine.time_scale = 1.0  # the battle's speed stays in the battle


# ---------- skills: training made visible, the mastery card, the journal, Mentor Bonds ----------

## After a player unit used a skill: the progress strip, and when the skill reached level 1 the SKILL MASTERED card, the journal
## entry and (for a human) the Mentor Bond with the vessel it was studied from.
func _skill_training(bu: BattleUnit, r: ActionResult, bond_with: String, bond_before: int) -> void:
	if bu.team != 0 or r.action == null or r.action.skill == null:
		return
	var skill := r.action.skill
	if not r.skill_before.is_empty() and r.skill_after != r.skill_before:
		hud.feed.progress(bu.data.display_name, skill, r.skill_before, r.skill_after, animate)
		if animate and r.skill_learned == null and int(r.skill_after[0]) > int(r.skill_before[0]):
			_float(bu, "%s  Lv %d" % [skill.display_name, int(r.skill_after[0])], Color(1.0, 0.9, 0.5), true)
			CombatAudio.play(self, "reward", 1.0, -4.0)
	var bond := ""
	if bond_with != "" and bu.data.skill_tree != null and bu.data.skill_tree.bond_level(bond_with) > bond_before:
		bond = "Mentor Bond with %s: Level %d  (+%d%% study speed from %s)" % [bond_with, bu.data.skill_tree.bond_level(bond_with), roundi(bu.data.skill_tree.bond_bonus(bond_with) * 100.0), bond_with]
		hud.say(bond)
	if r.skill_learned == null:
		if bond != "" and animate:
			hud.callouts.callout("MENTOR BOND  LV %d" % bu.data.skill_tree.bond_level(bond_with), Color("#7fe6ff"), 44, 1.0)
			CombatAudio.play(self, "reward")
		return
	game.campaign.record_skill(skill.display_name, bu.data.display_name, _skill_source(bu, skill), _place_name())
	hud.feed.mastered(bu.data.display_name, skill, mastery_note(bu, skill), bond, animate)
	if animate:
		CombatAudio.play(self, "level_up")
		hud.callouts.flash(Color(1.0, 0.9, 0.5, 0.25), 0.4)
		var v: UnitView3D = views.get(bu)
		if v != null:
			feedback._burst(v, "magic", Color(1.0, 0.85, 0.4), 20, Vector3.ZERO)
			feedback._burst(v, "heal", Color(1.0, 0.95, 0.7), 14, Vector3.ZERO)
		feedback.number(bu, "Mastered!", "note", 1.2)


## What mastering `skill` opens for `bu`: a vessel's skill can be taught (who can study it now); a human's is its own for good.
func mastery_note(bu: BattleUnit, skill: SkillData) -> String:
	if not bu.is_vessel():
		var m := SkillCollection.mastery(bu.data, skill)
		var from := " from %s" % m.mentor_name if m != null and m.mentor_name != "" else ""
		return "Learned for good%s: usable in every battle, and it keeps levelling with use." % from
	var students: Array[String] = []
	for h in game.roster.humans():
		if h.skill_tree == null or not h.skill_tree.is_learned(skill):
			students.append(h.display_name)
	if students.is_empty():
		return "Kept for good: %s can use it in every battle, with or without the relic." % bu.data.display_name
	return "Available for mentorship: %s can now study it from %s." % [_and_list(students), bu.data.display_name]


static func _and_list(names: Array[String]) -> String:
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[-1]


## Where a mastered skill came from, for the journal.
func _skill_source(bu: BattleUnit, skill: SkillData) -> String:
	if not bu.is_vessel():
		var m := SkillCollection.mastery(bu.data, skill)
		return "studied from %s" % m.mentor_name if m != null and m.mentor_name != "" else "studied"
	if bu.data.loadout != null:
		for relic in bu.data.loadout.relics():
			if relic.skill == skill:
				return "a summon stone" if relic.display_name == SummonStone.NAME else "the relic %s" % relic.display_name
	return "practice"


## The map's name on the world map ("" for a battle that is not on it).
func _place_name() -> String:
	if setup == null or setup.map_id == "":
		return ""
	return String(WorldData.map(setup.map_id).get("name", ""))
