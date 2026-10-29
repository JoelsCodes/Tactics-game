class_name BattleController
extends Node
## The tactical combat loop. Ties the grid, the player's DeploymentManager, the enemies and the
## TurnManager together. No drawing or input: a battle scene calls these and shows the results.
##
## A turn:
##   next_turn()                       -> the unit whose turn it is (relic drains apply now)
##   move_range(u) / move(u, cell)     -> walk once (Move and Jump, through allies, not foes)
##   actions(u) / highlights(u, a)     -> what it can do, and the tiles it can aim at
##   preview(u, a, aim) / perform(...) -> one action: spends SP, resolves the hits in the footprint
##   summon_vessel(king, vessel, cell) -> during the King's turn, free: summon onto a relic prop
##   end_turn()                        -> CT cost; a vessel's Fade Clock -1, untethered at 0
##
## SP works like MP: skills spend their fixed cost from a pool of 15-30 that does not refill during
## battle. A unit without enough SP cannot cast. Weapon styles and stances are fixed before battle (in
## the loadout menus); there is no way to change them during one, and they never change SP costs.
##
## Win when every enemy is down; lose when every player unit on the field is down. A downed King only
## means no more vessels can be summoned.

signal battle_started
signal turn_started(unit: BattleUnit)
signal unit_moved(unit: BattleUnit, path: Array[Vector2i])
signal action_performed(result: ActionResult)
signal unit_knocked_out(unit: BattleUnit)
signal turn_ended(unit: BattleUnit)
signal battle_ended(outcome: Outcome)

enum Outcome { ONGOING, WON, LOST }

## Height levels a unit can reach above or below itself with an action.
const VERTICAL_REACH := 3

var grid: TacticalGrid
var deployment: DeploymentManager
var turns := TurnManager.new()
var enemies: Array[BattleUnit] = []
var current: BattleUnit
var moved := false
var acted := false
var started := false
var rng := RandomNumberGenerator.new()  ## skill level rolls; seed it for repeatable results
var summary := BattleSummary.new()  ## filled in as the battle runs; completed by finish()
var outcome := Outcome.ONGOING


## `dm` is the player's DeploymentManager; one is created (as a child) if none is given.
func setup(board: TacticalGrid, dm: DeploymentManager = null) -> void:
	grid = board
	deployment = dm
	if deployment == null:
		deployment = DeploymentManager.new()
		add_child(deployment)
	deployment.setup(grid)
	deployment.unit_deployed.connect(_on_deployed)
	deployment.vessel_untethered.connect(_on_untethered)
	deployment.relic_lost.connect(func(r): summary.relics_lost.append(r))


## Places an enemy (team 1 unless given). Enemies join the turn order at once if the battle started.
func add_enemy(unit: EnemyData, cell: Vector2i, team := 1) -> BattleUnit:
	if not grid.can_stand(cell):
		return null
	var bu := BattleUnit.new(unit, team)
	grid.place(bu, cell, team)
	bu.cell = cell
	bu.on_field = true
	enemies.append(bu)
	if started:
		turns.add(bu)
	return bu


## Starts the battle: needs the King deployed. Everyone on the field joins the turn order.
func start() -> bool:
	if started or not deployment.ready_to_start():
		return false
	started = true
	for bu in deployment.field_units():
		turns.add(bu)
	for bu in enemies:
		turns.add(bu)
	battle_started.emit()
	return true


func all_units() -> Array[BattleUnit]:
	var out := deployment.field_units()
	out.append_array(enemies)
	return out


# ---------- turns ----------

## Advances to the next unit's turn. Relic drains (SP and HP per turn) apply now; an HP drain never
## knocks a unit out. Returns null when the battle is over or nobody can act.
func next_turn() -> BattleUnit:
	if not started or outcome != Outcome.ONGOING:
		return null
	current = turns.next()
	moved = false
	acted = false
	if current == null:
		return null
	summary.turns += 1
	summary.line(current).turns += 1
	current.guarding = false  # a Defend lasts until the unit's own next turn
	var l := current.data.loadout
	if l:
		current.sp = maxi(0, current.sp - l.sp_drain_per_turn())
		current.hp = maxi(1, current.hp - l.hp_drain_per_turn())
	turn_started.emit(current)
	return current


## Ends the current turn: pays CT for what it did, then a vessel's Fade Clock goes down by 1 (at 0 it
## is untethered: Sever Count +1, its relic goes home 25% or drops on its tile).
func end_turn() -> void:
	if current == null:
		return
	var bu := current
	turns.end_turn(bu, moved, acted)
	current = null
	if bu.is_vessel():
		deployment.end_turn(bu)
	turn_ended.emit(bu)


## Defend: the unit guards (half damage, DamageFormula.GUARD_PERCENT) until its next turn, and its
## turn ends. Counts as its action for the turn order. Not after acting.
func defend(bu: BattleUnit) -> bool:
	if not is_turn_of(bu) or acted or bu.is_down():
		return false
	bu.guarding = true
	acted = true
	end_turn()
	return true


func is_turn_of(bu: BattleUnit) -> bool:
	return bu != null and bu == current


# ---------- moving ----------

func move_range(bu: BattleUnit) -> MovementRange:
	return grid.reachable(bu.cell, bu.stat(StatModifier.Stat.MOVE), bu.stat(StatModifier.Stat.JUMP), bu.team)


## Walks the current unit to `cell` (once per turn; a skill with allows_move_after reopens it after the action).
## Returns false if not allowed.
func move(bu: BattleUnit, cell: Vector2i) -> bool:
	if not is_turn_of(bu) or moved or cell == bu.cell:
		return false
	var r := move_range(bu)
	if not r.can_reach(cell):
		return false
	var path := r.path_to(cell)
	var from := path[path.size() - 2] if path.size() > 1 else bu.cell
	grid.move_occupant(bu, cell)
	bu.cell = cell
	bu.facing = dir_toward(from, cell)
	moved = true
	unit_moved.emit(bu, path)
	return true


# ---------- actions ----------

## Everything the unit can use: the basic attack, then its skills (learned and studied skills, relic
## skills including the Temp-Relic, signature skills, enemy skills). Includes skills it cannot afford.
func actions(bu: BattleUnit) -> Array[BattleAction]:
	var out: Array[BattleAction] = [BattleAction.attack()]
	for s in skills_of(bu):
		out.append(BattleAction.use(s))
	return out


func skills_of(bu: BattleUnit) -> Array[SkillData]:
	var out: Array[SkillData] = []
	var d := bu.data
	if d.skill_tree:
		out.append_array(d.skill_tree.usable_skills())
	if d is CoCaptainData:
		out.append_array((d as CoCaptainData).signature_skills)
	if d is EnemyData:
		out.append_array((d as EnemyData).skills)
	if d.loadout:
		out.append_array(d.loadout.skills())
	var seen: Array[SkillData] = []
	for s in out:
		if not seen.has(s):
			seen.append(s)
	return seen


## Level a unit uses a skill at: its tree level for studied/learned skills, 0 otherwise.
func skill_level(bu: BattleUnit, skill: SkillData) -> int:
	if skill == null or bu.data.skill_tree == null:
		return 0
	return bu.data.skill_tree.skill_level(skill)


## The footprint for this unit and action: weapon style geometry, stance applied to attacks and
## Physical skills.
func footprint(bu: BattleUnit, action: BattleAction) -> GeometryPattern:
	return StanceRules.footprint(bu.style(), bu.stance(), bu.facing, VERTICAL_REACH, action.skill)


## Tiles to highlight: where the action can be aimed.
func highlights(bu: BattleUnit, action: BattleAction) -> Array[Vector2i]:
	return GeometryResolver.targetable(grid, bu.cell, footprint(bu, action))


## Why `bu` cannot do `action` at `aim` now, or "".
func action_error(bu: BattleUnit, action: BattleAction, aim: Vector2i) -> String:
	if outcome != Outcome.ONGOING:
		return "the battle is over"
	if not is_turn_of(bu):
		return "not this unit's turn"
	if acted:
		return "already acted this turn"
	if action.skill != null and not skills_of(bu).has(action.skill):
		return "skill not available"
	if bu.sp < action.sp_cost():
		return "not enough SP"
	if not highlights(bu, action).has(aim):
		return "out of reach"
	return ""


## What the action would do, without changing anything (ignores whose turn it is).
func preview(bu: BattleUnit, action: BattleAction, aim: Vector2i, mult := -1.0) -> ActionResult:
	var r := ActionResult.new()
	r.action = action
	r.area = GeometryResolver.affected(grid, bu.cell, footprint(bu, action), aim)
	r.ok = not r.area.is_empty()
	r.sp_spent = action.sp_cost()
	var effect := DamageFormula.effect_of(action.category())
	var lv := skill_level(bu, action.skill)
	for t in r.area.tiles:
		var target = grid.occupant(t)
		if not target is BattleUnit or target.is_down() or effect == DamageFormula.Effect.NONE:
			continue
		var h := ActionResult.Hit.new()
		h.target = target
		h.tile = t
		h.heal = effect == DamageFormula.Effect.HEAL
		h.amount = DamageFormula.amount(bu, target, action, lv, r.area, t, mult)
		h.knocked_out = not h.heal and h.amount >= target.hp
		r.hits.append(h)
	return r


## Performs the current unit's action: spends SP, applies the hits, levels the skill by use.
func perform(bu: BattleUnit, action: BattleAction, aim: Vector2i) -> ActionResult:
	var err := action_error(bu, action, aim)
	if err != "":
		return ActionResult.refused(err)
	# a physical skill rolls its rank multiplier inside the band on every use
	var mult := action.skill.roll(rng) if action.skill != null and action.skill.is_physical() else -1.0
	var r := preview(bu, action, aim, mult)
	bu.sp -= r.sp_spent
	bu.facing = dir_toward(bu.cell, aim)
	acted = true
	# Quick Jab (allows_move_after): the walk is open again, so the unit can move after the action
	if action.skill != null and action.skill.allows_move_after:
		moved = false
	for h in r.hits:
		if h.heal:
			h.amount = mini(h.amount, h.target.max_hp() - h.target.hp)
			h.target.hp += h.amount
		else:
			h.amount = mini(h.amount, h.target.hp)
			h.target.hp -= h.amount
	if action.skill != null and bu.data.skill_tree != null:
		r.skill_levels_gained = bu.data.skill_tree.use_skill(action.skill, bu.data.stats, 1, bu.data.loadout, rng)
	summary.add_action(bu, r)
	action_performed.emit(r)
	for h in r.hits:
		if h.knocked_out:
			unit_knocked_out.emit(h.target)
	_check_outcome()
	return r


# ---------- vessels ----------

## During the King's turn, summons a vessel onto the relic prop on `cell` (see DeploymentManager). Free:
## it does not use his move or action, so he can summon more than once. The vessel joins the turn order
## at CT 0; its Tether Count goes up by 1. A downed King cannot summon.
func summon_vessel(king: BattleUnit, vessel: VesselData, cell: Vector2i) -> BattleUnit:
	if not is_turn_of(king) or not king.is_king():
		return null
	return deployment.summon_vessel(vessel, cell)


## Ends the battle and returns its summary. Vessels still on the field roll 10% to take their relic
## home; props left on the field are lost. Every relic sent home this battle (25% untether rolls and
## the 10% end rolls) goes into `roster`'s permanent inventory if a roster is given. On a victory the
## enemy XP pool is divided among the units that took part (ExperienceSystem), levelling them up.
func finish(roster: PartyRoster = null) -> BattleSummary:
	for bu in all_units():
		summary.line(bu).knocked_out = bu.is_down()
	summary.outcome = outcome
	ExperienceSystem.distribute(summary)
	summary.relics_secured = deployment.end_battle()
	if roster:
		roster.receive_relics(summary.relics_secured)
	return summary


func _on_deployed(bu: BattleUnit) -> void:
	if bu.is_vessel():
		summary.line(bu).tethers += 1
	if started:
		turns.add(bu)


func _on_untethered(v: BattleUnit, _home: bool) -> void:
	summary.line(v).severs += 1
	turns.remove(v)


func _check_outcome() -> void:
	if outcome != Outcome.ONGOING:
		return
	var ours := deployment.field_units()
	if not ours.is_empty() and ours.all(func(u): return u.is_down()):
		outcome = Outcome.LOST
	elif not enemies.is_empty() and enemies.all(func(e): return e.is_down()):
		outcome = Outcome.WON
	if outcome != Outcome.ONGOING:
		battle_ended.emit(outcome)


## Orthogonal board direction from `a` toward `b` (the larger axis wins; ties go to x).
static func dir_toward(a: Vector2i, b: Vector2i) -> Vector2i:
	var d := b - a
	if d == Vector2i.ZERO:
		return Vector2i(0, 1)
	if absi(d.x) >= absi(d.y):
		return Vector2i(signi(d.x), 0)
	return Vector2i(0, signi(d.y))
