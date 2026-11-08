class_name BattleController
extends Node
## The tactical combat loop. Ties the grid, the player's DeploymentManager, the enemies and the
## TurnManager together. No drawing or input: a battle scene calls these and shows the results.
##
## A turn:
##   next_turn()                       -> the unit whose turn it is (relic drains apply now)
##   move_range(u) / move(u, cell)     -> walk once (Move and the JUMP stat, through allies, not foes)
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
signal unit_faced(unit: BattleUnit)  ## a unit was turned after its move (face)
signal action_performed(result: ActionResult)
signal unit_knocked_out(unit: BattleUnit)
## A sword fell where an enemy went down: it carries that enemy's weapon style and stance (see `swords`).
signal sword_dropped(cell: Vector2i, geometry: int, stance: int)
## A player-side unit ended its turn on a sword: it rises and is gone, and that unit gets its style and stance. `is_new`: new to that unit.
signal sword_collected(unit: BattleUnit, cell: Vector2i, geometry: int, stance: int, is_new: bool)
signal turn_ended(unit: BattleUnit)
## A unit in `fleeing` was brought to its percent of HP: it is gone from the field (hp 0, `fled`), alive. The stage plays its exit.
signal unit_fled(unit: BattleUnit)
signal battle_ended(outcome: Outcome)
signal telegraph_set(user: BattleUnit, tiles: Array)  ## a telegraphed attack was aimed: its tiles are marked until it lands
signal telegraph_landed(user: BattleUnit, tiles: Array)

enum Outcome { ONGOING, WON, LOST }

## Height levels a unit can reach above or below itself with an action.
const VERTICAL_REACH := 3

## Chance that each damaging hit on a target misses (heals never miss). Rolled in perform; a miss takes
## no damage or heal and applies no push, slow or other effect to that target.
const MISS_CHANCE := 0.25
## Terrain negative: a unit that ends its turn standing in water (shallow water) loses this many Move points on its next turn only.
const WADING_SLOW := 1
const HOP_CLIMB := 3  ## levels a Hop (the skill) can climb up; a unit walking without it climbs 1 (drops are free)
const BLIND_BONUS := 0.10  ## a blinded attacker misses 35% instead of 25%
const FULL_BLIND_BONUS := 0.25  ## BLIND: 50%
const MARK_CUT := 0.20  ## a marked target is hit by physical skills with a 5% miss instead of 25%
var miss_chance := MISS_CHANCE  ## per controller: the battle uses the rule; tests that need every hit set 0

var grid: TacticalGrid
var deployment: DeploymentManager
var turns := TurnManager.new()
var enemies: Array[BattleUnit] = []
var current: BattleUnit
var moved := false
var acted := false
var walked := 0  ## move points the walk this turn has used
var walk_budget := -1  ## move points left for a walk that Quick Jab reopened; -1 = the full MOVE stat
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
## Swords lying on the field: cell -> {"geometry", "stance"} of the enemy that fell there. Left-over ones are lost at the end.
var swords := {}
## BattleUnit -> percent of max HP: such a unit is never knocked out; at or below the percent it flees (see _flee).
var fleeing := {}
var telegraphs: Array = []  ## charged attacks waiting for their caster's next turn: {user, action, aim, tiles}
var _landing := false


func add_enemy(unit: EnemyData, cell: Vector2i, team := 1) -> BattleUnit:
	if not grid.can_stand(cell):
		return null
	if unit.stats != null and unit is EnemyData:
		unit.stats.grows = false  # enemy stats are written for their level (CharacterStats.GROWTH)
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
	for bu in all_units():  # the facing a unit is placed with (toward its nearest foe); after that only its own steps turn it
		face_nearest_foe(bu)
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
	walked = 0
	walk_budget = -1
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
	bu.slow = 0  ## a slowing lasts one of its turns
	if grid.terrain(bu.cell) == "w":  ## ... but ending in water slows the next one (terrain negative)
		bu.slow = WADING_SLOW
	_collect_sword_at(bu)  ## ending the turn on a sword takes it
	SupportRules.poison_tick(bu)  ## poison takes its share at the end of the poisoned unit's turn
	SkillFx.tick(bu)  ## burn and regen
	var doomed := bu.has_status(BattleUnit.DOOM) and int(bu.statuses[BattleUnit.DOOM]) <= 1
	bu.tick_statuses()
	if doomed and not bu.is_down():  # the countdown ran out
		bu.hp = 0
		bu.tick_notes.append("Doom!")
		unit_knocked_out.emit(bu)
		_check_outcome()
	current = null
	if bu.is_vessel():
		deployment.end_turn(bu)
		_check_outcome()  # the last vessel fading with the King down loses the battle (found by the balance simulator: it used to hang)
	turn_ended.emit(bu)


## Turns `bu` to face its nearest living foe (an orthogonal board direction). Kept as it is when none is left.
func face_nearest_foe(bu: BattleUnit) -> void:
	var best: BattleUnit = null
	var best_d := 1 << 30
	for f in all_units():
		if f.team == bu.team or f.is_down() or not f.on_field:
			continue
		var d := absi(f.cell.x - bu.cell.x) + absi(f.cell.y - bu.cell.y)
		if d < best_d:
			best_d = d
			best = f
	if best != null:
		bu.facing = dir_toward(bu.cell, best.cell)


## A unit that is asleep or stunned loses its turn: it ends at once (the turn costs what waiting costs). Returns whether it did.
func skip_if_helpless(bu: BattleUnit) -> bool:
	if bu == null or bu != current or not bu.loses_turn():
		return false
	end_turn()
	return true


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
	return grid.reachable(bu.cell, move_budget(bu), bu.stat(StatModifier.Stat.JUMP), bu.team)


## The move points a walk may use now: the full MOVE stat, or what a reopened walk has left.
func move_budget(bu: BattleUnit) -> int:
	if bu.has_status(BattleUnit.ROOT):
		return 0
	var base := walk_budget if walk_budget >= 0 else bu.stat(StatModifier.Stat.MOVE)
	return maxi(0, base - bu.slow)


## Walks the current unit to `cell` (once per turn; a skill with allows_move_after reopens it after the action,
## with the move points the walk left). Returns false if not allowed.
func move(bu: BattleUnit, cell: Vector2i) -> bool:
	if not is_turn_of(bu) or moved or cell == bu.cell:
		return false
	var r := move_range(bu)
	if not r.can_reach(cell):
		return false
	var path := r.path_to(cell)
	var from := path[path.size() - 2] if path.size() > 1 else bu.cell
	walked += r.cost_to(cell)
	grid.move_occupant(bu, cell)
	bu.cell = cell
	bu.facing = dir_toward(from, cell)
	moved = true
	unit_moved.emit(bu, path)
	return true


## Turns a unit toward one of the four directions after it has moved and before it acts (owner, Nov 2026: "pick a direction after movement"), since its
## style and stance hit the way it faces (the Rook, Bishop and Pawn only attack forward). A unit that does not turn keeps the direction of its last step.
## `dir` is a unit step ((1, 0), (-1, 0), (0, 1) or (0, -1)). Returns false when it is not allowed (not its turn, it has not moved, it has acted, a bad direction).
func face(bu: BattleUnit, dir: Vector2i) -> bool:
	if not is_turn_of(bu) or not moved or acted or absi(dir.x) + absi(dir.y) != 1:
		return false
	bu.facing = dir
	unit_faced.emit(bu)
	return true


# ---------- actions ----------

## Everything the unit can use: the basic attack, then its skills (learned and studied skills, relic
## skills including the Temp-Relic, signature skills, enemy skills). Includes skills it cannot afford.
func actions(bu: BattleUnit) -> Array[BattleAction]:
	var out: Array[BattleAction] = [BattleAction.attack()]
	if bu.has_status(BattleUnit.SILENCE):
		return out  # silenced: the basic attack only
	for s in skills_of(bu):
		out.append(BattleAction.use(s))
	return out


func skills_of(bu: BattleUnit) -> Array[SkillData]:
	var out: Array[SkillData] = []
	var d := bu.data
	if d is EnemyData and (d as EnemyData).basic_attack_only:
		return out
	if d.skill_tree:
		out.append_array(d.skill_tree.usable_skills())
	if d is CoCaptainData:
		out.append_array((d as CoCaptainData).signature_skills)
	if d is EnemyData:
		if not (d as EnemyData).skills_only:
			out.append_array(SkillLibrary.enemy_pool())  # enemies can use the owner's rank E physical skills
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


## The bare footprint (the style's geometry and reach, no stance) that skills of the other five proficiencies use.
func footprint(bu: BattleUnit, action: BattleAction) -> GeometryPattern:
	return StanceRules.footprint(bu.style(), bu.stance(), bu.facing, VERTICAL_REACH, action.skill)


## Whether the action follows the weapon style and stance (the basic attack and Physical skills) rather than the bare footprint.
func is_styled(action: BattleAction) -> bool:
	return action.skill == null or action.skill.is_physical()


## The unit's weapon style geometry (King without a style).
func geometry_of(bu: BattleUnit) -> TacticalMath.Geometry:
	return bu.style().geometry if bu.style() else TacticalMath.Geometry.KING


## Tiles to highlight: where the action can be aimed.
func highlights(bu: BattleUnit, action: BattleAction) -> Array[Vector2i]:
	if action.skill != null and action.skill.hop:
		return _hop_cells(bu)
	if SkillFx.flag(action.skill, "self_only"):
		return [bu.cell]
	if is_styled(action):
		return StyleResolver.targetable(grid, bu.cell, geometry_of(bu), bu.stance(), bu.facing)
	return GeometryResolver.targetable(grid, bu.cell, footprint(bu, action))


## SP an action spends: its cost, or everything left for the SP Finisher (healing proficiency).
func _sp_spent(bu: BattleUnit, action: BattleAction) -> int:
	if action.skill != null and action.skill.support == "sp_finisher":
		return bu.sp
	return action.sp_cost()


## Why `bu` cannot do `action` at `aim` now, or "".
func action_error(bu: BattleUnit, action: BattleAction, aim: Vector2i) -> String:
	if outcome != Outcome.ONGOING:
		return "the battle is over"
	if _landing:
		return ""  # a telegraphed attack lands as it was aimed
	if action.skill != null and SkillFx.flag(action.skill, "telegraph") and telegraphs.any(func(t): return t.user == bu):
		return "already charging"
	if not is_turn_of(bu):
		return "not this unit's turn"
	if acted:
		return "already acted this turn"
	if action.skill != null and not skills_of(bu).has(action.skill):
		return "skill not available"
	if action.skill != null and bu.has_status(BattleUnit.SILENCE):
		return "silenced"
	if action.skill != null and action.skill.support == "sp_finisher":
		if bu.sp <= 0:
			return "not enough SP"  # it spends all of it, so it needs some
	elif bu.sp < action.sp_cost():
		return "not enough SP"
	if not highlights(bu, action).has(aim):
		return "out of reach"
	return ""


## What the action would do, without changing anything (ignores whose turn it is).
func preview(bu: BattleUnit, action: BattleAction, aim: Vector2i, mult := -1.0) -> ActionResult:
	var r := ActionResult.new()
	r.action = action
	if action.skill != null and action.skill.hop:
		r.area = TargetArea.new()
		r.area.aim = aim
		r.area.tiles = [aim]
		r.ok = aim == hop_destination(bu)
		r.sp_spent = action.sp_cost()
		return r
	if SkillFx.flag(action.skill, "self_only"):
		r.area = TargetArea.new()
		r.area.origin = bu.cell
		r.area.aim = bu.cell
		r.area.tiles = [bu.cell]
		r.area.occupants = [bu]
	elif is_styled(action):
		r.area = StyleResolver.affected(grid, bu.cell, geometry_of(bu), bu.stance(), bu.facing, aim)
	else:
		r.area = GeometryResolver.affected(grid, bu.cell, footprint(bu, action), aim)
	if not r.area.is_empty() and SkillFx.num(action.skill, "blast") > 0:  # a blast also reaches the tiles around the aimed one
		for c in SkillFx.blast_tiles(grid, r.area.aim, SkillFx.num(action.skill, "blast")):
			if c != bu.cell and not r.area.tiles.has(c):
				r.area.tiles.append(c)
	r.ok = not r.area.is_empty()
	r.sp_spent = _sp_spent(bu, action)
	var effect := DamageFormula.effect_of(action.category())
	var lv := skill_level(bu, action.skill)
	var support := SupportRules.is_support(action.skill)
	for t in r.area.tiles:
		var target = grid.occupant(t)
		var fx := SkillFx.has(action.skill)
		if not target is BattleUnit or target.is_down() or (effect == DamageFormula.Effect.NONE and not support and not fx):
			continue
		if (support or fx or SkillFx.needs_target(action.skill)) and not SupportRules.may_target(bu, target, action.skill):
			continue
		var h := ActionResult.Hit.new()
		h.target = target
		h.tile = t
		if support:
			SupportRules.preview(bu, target, action.skill, h, r.area, t, lv)
			r.hits.append(h)
			continue
		h.heal = effect == DamageFormula.Effect.HEAL or (effect == DamageFormula.Effect.NONE and action.skill.allies_only)
		h.amount = 0 if effect == DamageFormula.Effect.NONE else DamageFormula.amount(bu, target, action, lv, r.area, t, mult)
		if fx:
			h.amount = SkillFx.adjust(bu, target, action.skill, h.amount, h.heal)
		if action.skill != null and action.skill.spare and not h.heal:
			h.amount = mini(h.amount, maxi(0, target.hp - 1))  # Pity Pity: never takes the target below 1 HP
		h.knocked_out = not h.heal and h.amount >= target.hp
		r.hits.append(h)
	return r


## Performs the current unit's action: spends SP, applies the hits, levels the skill by use.
func perform(bu: BattleUnit, action: BattleAction, aim: Vector2i) -> ActionResult:
	var err := action_error(bu, action, aim)
	if err != "":
		return ActionResult.refused(err)
	if action.skill != null and SkillFx.flag(action.skill, "telegraph") and not _landing:
		# a telegraphed attack (the Soul Warden's Final Absolution): the aim is marked now, the blow lands when the caster's next turn comes
		var pre := preview(bu, action, aim)
		bu.sp -= pre.sp_spent
		acted = true
		telegraphs.append({"user": bu, "action": action, "aim": aim, "tiles": pre.area.tiles.duplicate()})
		telegraph_set.emit(bu, pre.area.tiles)
		pre.hits.clear()
		pre.ok = true
		return pre
	# a physical skill rolls its rank multiplier inside the band on every use
	var mult := action.skill.roll(rng) if action.skill != null and action.skill.is_physical() else -1.0
	var r := preview(bu, action, aim, mult)
	if (SupportRules.is_support(action.skill) or SkillFx.needs_target(action.skill)) and r.hits.is_empty():
		return ActionResult.refused("no valid target there")
	for h in r.hits:
		if not h.heal and not SkillFx.never_misses(action.skill) and rng.randf() < miss_chance_for(bu, h.target, action):
			h.missed = true
			h.amount = 0
			h.knocked_out = false
	if SupportRules.is_support(action.skill):
		SupportRules.roll(bu, r, action.skill, rng)
	if SkillFx.has(action.skill):
		SkillFx.roll(r, action.skill, rng)
	bu.sp -= r.sp_spent  # attacking does not turn the unit: its facing is its last step (or where it was placed)
	acted = true
	if action.skill != null and action.skill.hop:
		r.pushed.append({"unit": bu, "from": bu.cell, "to": aim})  # the stage slides it there
		grid.move_occupant(bu, aim)
		bu.cell = aim
	# Quick Jab (allows_move_after): the walk is open again with the move points the first walk left
	if action.skill != null and action.skill.allows_move_after and moved and bu.stat(StatModifier.Stat.MOVE) > walked:
		walk_budget = bu.stat(StatModifier.Stat.MOVE) - walked
		moved = false
	for h in r.hits:
		if h.missed:
			continue
		if h.heal:
			if h.target.has_status(BattleUnit.CURSE):
				h.amount = h.amount / 2  # a cursed unit is healed by half
			h.amount = mini(h.amount, h.target.max_hp() - h.target.hp)
			h.target.hp += h.amount
		else:
			h.amount = mini(h.amount, h.target.hp - 1 if fleeing.has(h.target) else h.target.hp)  # a fleeing unit is never finished off
			h.knocked_out = h.knocked_out and not fleeing.has(h.target)
			h.target.hp -= h.amount
			if h.amount > 0:
				h.target.statuses.erase(BattleUnit.SLEEP)  # a blow wakes the sleeper
			if fleeing.has(h.target) and h.target.hp * 100 <= h.target.max_hp() * int(fleeing[h.target]):
				_flee(h.target)
	if SkillFx.has(action.skill):
		SkillFx.apply(self, bu, action.skill, r, rng)
	_push_back(bu, action, r)
	_slow_hits(action, r)
	_retreat(bu, action, aim, r)
	_inflict(bu, action, r)
	if action.skill != null and bu.is_vessel():  # a vessel learns by using any skill: relic or stone, no study needed
		var tree := Mentorship.tree_of(bu.data)
		var pr := tree.practice_skill(action.skill, bu.data.stats, bu.data.loadout, rng)
		r.skill_levels_gained = pr.levels
		if pr.learned:
			r.skill_learned = action.skill
	elif action.skill != null and bu.data.skill_tree != null:
		r.skill_levels_gained = bu.data.skill_tree.use_skill(action.skill, bu.data.stats, 1, bu.data.loadout, rng)
	summary.add_action(bu, r)
	action_performed.emit(r)
	for h in r.hits:
		if h.knocked_out:
			unit_knocked_out.emit(h.target)
			_drop_sword(h.target)
	_check_outcome()
	return r


## Lands every telegraphed attack `bu` charged on its last turn (call at the start of its turn); returns what each one did.
func land_telegraphs(bu: BattleUnit) -> Array[ActionResult]:
	var out: Array[ActionResult] = []
	for t in telegraphs.filter(func(t): return t.user == bu):
		telegraphs.erase(t)
		if bu.is_down():
			continue
		var was := acted
		_landing = true
		acted = false
		var r := perform(bu, t.action, t.aim)
		_landing = false
		acted = was
		bu.sp += r.sp_spent  # it was paid for when the aim was marked
		telegraph_landed.emit(bu, t.tiles)
		out.append(r)
	return out


## A fleeing unit reaches its HP percent: it leaves the field alive (counted as beaten, no sword), and the stage is told.
func _flee(bu: BattleUnit) -> void:
	fleeing.erase(bu)
	bu.fled = true
	bu.hp = 0
	grid.remove(bu)
	unit_fled.emit(bu)


## An enemy that goes down leaves its tile (the body is gone, the tile can be walked on) and a sword there with its style and stance.
func _drop_sword(bu: BattleUnit) -> void:
	if bu.team == 0 or not enemies.has(bu):
		return
	grid.remove(bu)
	var s := bu.style()
	if s == null:
		return
	swords[bu.cell] = {"geometry": s.geometry, "stance": bu.stance()}
	sword_dropped.emit(bu.cell, s.geometry, bu.stance())


## A player-side unit ends its turn on a sword (walking over one is not enough): it takes it, and only that unit gets its style and stance.
func _collect_sword_at(bu: BattleUnit) -> void:
	if bu.team != 0 or bu.is_down() or not swords.has(bu.cell):
		return
	var c := bu.cell
	var sw: Dictionary = swords[c]
	swords.erase(c)
	var key := PartyRoster.style_key(sw.geometry, sw.stance)
	var is_new := not bu.data.known_style_keys().has(key)
	for f in summary.styles_found:
		if f.unit == bu and f.key == key:
			is_new = false
	if is_new:
		summary.styles_found.append({"unit": bu, "key": key})
	sword_collected.emit(bu, c, sw.geometry, sw.stance, is_new)


## Push (Shield Prod): a standing target next to the user is moved `push` tiles straight away from it. A
## target with no free tile to land on (wall, unit, void) stays where it is.
func _push_back(bu: BattleUnit, action: BattleAction, r: ActionResult) -> void:
	var push := action.skill.push if action.skill != null else 0
	if push <= 0:
		return
	for h in r.hits:
		var t := h.target
		var off := t.cell - bu.cell
		if h.missed or h.heal or t.is_down() or absi(off.x) + absi(off.y) != 1:
			continue
		var dest := t.cell + off * push
		if not grid.can_stand(dest):
			continue
		var from := t.cell
		grid.move_occupant(t, dest)
		t.cell = dest
		r.pushed.append({"unit": t, "from": from, "to": dest})


## Slow (Hamstring Cut): every target that is hit and survives loses `slow` movement points on its next turn.
func _slow_hits(action: BattleAction, r: ActionResult) -> void:
	var slow := action.skill.slow if action.skill != null else 0
	if slow <= 0:
		return
	for h in r.hits:
		if not h.missed and not h.heal and not h.target.is_down():
			h.target.slow = maxi(h.target.slow, slow)


## Retreat (Step-Aside Strike): the user steps 1 tile diagonally backward from `aim` if a free tile is there;
## otherwise it stays. Recorded in `pushed` so the stage slides it like a pushed unit.
func _retreat(bu: BattleUnit, action: BattleAction, aim: Vector2i, r: ActionResult) -> void:
	if action.skill == null or not action.skill.retreat:
		return
	var off := aim - bu.cell
	if off == Vector2i.ZERO:
		return
	var back := Vector2i(-signi(off.x), -signi(off.y))
	var steps: Array[Vector2i] = [back]
	if back.x == 0:
		steps = [Vector2i(1, back.y), Vector2i(-1, back.y)]
	elif back.y == 0:
		steps = [Vector2i(back.x, 1), Vector2i(back.x, -1)]
	for s in steps:
		var to := bu.cell + s
		if grid.can_stand(to):
			var from := bu.cell
			grid.move_occupant(bu, to)
			bu.cell = to
			r.pushed.append({"unit": bu, "from": from, "to": to})
			return


## Chance that a hit by `bu` on `target` misses: the base chance, plus the attacker's mild blind, minus the
## mark on a physically hit target.
func miss_chance_for(bu: BattleUnit, target: BattleUnit, action: BattleAction) -> float:
	var c := miss_chance
	if bu.has_status(BattleUnit.MILD_BLIND):
		c += BLIND_BONUS
	if bu.has_status(BattleUnit.BLIND):
		c += FULL_BLIND_BONUS
	if target.has_status(BattleUnit.MARKED) and action.category() == Proficiency.Category.PHYSICAL:
		c -= MARK_CUT
	return clampf(c, 0.0, 1.0)


## Gives the status the skill inflicts (Marked, Mild blind) to every unit it hits and that is not missed.
func _inflict(bu: BattleUnit, action: BattleAction, r: ActionResult) -> void:
	var s := action.skill
	if s == null or s.status == "":
		return
	for h in r.hits:
		if h.missed or h.heal or h.target.is_down():
			continue
		var turns := s.status_turns if s.status_turns > 0 else rng.randi_range(1, 3)
		h.target.add_status(s.status, turns)


## Where a Hop lands: the tile 1 ahead (its facing) if it can be stood on and is at most HOP_CLIMB levels above.
func hop_destination(bu: BattleUnit) -> Vector2i:
	var to := bu.cell + bu.facing
	if grid.can_stand(to) and grid.height(to) - grid.height(bu.cell) <= HOP_CLIMB:
		return to
	return TacticalGrid.NO_CELL


func _hop_cells(bu: BattleUnit) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var d := hop_destination(bu)
	if d != TacticalGrid.NO_CELL:
		out.append(d)
	return out


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
	swords.clear()  # swords nobody ended a turn on are lost
	for f in summary.styles_found:  # each unit keeps the styles it found
		var s := PartyRoster.style_from_key(f.key)
		if s != null:
			(f.unit as BattleUnit).data.learn_style(s.geometry, s.stance)
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
