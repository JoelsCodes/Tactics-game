class_name EnemyAI
extends RefCounted
## Enemy turns. Pure rules: it looks at the battle through BattleController and acts only through its
## calls (move, perform), so it plays by exactly the same rules as the player.
##
## Each turn it tries every tile it can walk to (staying put included), every action it can afford
## there (the free Attack, its skills) and every tile each one can be aimed at, scores what the hits
## would do (BattleController.preview) and takes the best. If nothing in reach is worth doing, it walks
## toward the player unit it most wants to reach instead.
##
## What it values (WEIGHTS, one place to tune):
##   damage to player units, knocking one out, wounded targets (finish them), vessels on the field
##   (fragile, they carry relics, their Fade Clock is running), the King (a downed King cannot summon),
##   restoring HP to wounded allies.
## What it avoids: hitting its own side, spending SP when a free attack does as well, walking further
## than it needs to. Skills with no HP effect yet (Tactical, Status) are never chosen.

const WEIGHTS := {
	"damage": 1.0,  ## per HP of damage to a player unit
	"knockout": 40.0,  ## knocking a player unit out
	"wounded": 20.0,  ## x the share of HP the target has already lost
	"vessel": 15.0,  ## hitting a vessel on the field (above the King: vessels are the priority)
	"king": 10.0,  ## hitting the King
	"heal": 1.0,  ## per HP actually restored to a wounded ally
	"friendly_fire": 1.5,  ## per HP of damage to its own side (subtracted)
	"friendly_knockout": 60.0,  ## knocking out one of its own side (subtracted)
	"sp": 0.5,  ## per SP spent (subtracted)
	"walk": 0.1,  ## per walking point used (subtracted)
}


## What the unit will do this turn.
class Plan:
	var move_to := TacticalGrid.NO_CELL  ## NO_CELL: stay where it is
	var action: BattleAction  ## null: no action (only walks, or waits)
	var aim := TacticalGrid.NO_CELL
	var score := 0.0
	var target: BattleUnit  ## the unit it walks toward when it cannot act

	func moves() -> bool:
		return move_to != TacticalGrid.NO_CELL

	func acts() -> bool:
		return action != null


## Plans `bu`'s turn without changing anything.
static func plan(battle: BattleController, bu: BattleUnit) -> Plan:
	var best := Plan.new()
	var foes := _foes(battle, bu)
	if foes.is_empty() or bu.is_down():
		return best
	var origin := bu.cell
	var cells: Array[Vector2i] = [origin]
	var costs := {origin: 0}
	if not battle.moved:
		var r := battle.move_range(bu)
		for c in r.cells():
			if c != origin:
				cells.append(c)
				costs[c] = r.cost_to(c)
	if not battle.acted:
		for c in cells:
			_try_from(battle, bu, c, costs[c], best)
	if best.acts() and best.score > 0.0:
		return best
	# nothing worth doing in reach: walk toward the most wanted foe
	var walk := Plan.new()
	walk.target = pick_target(bu, foes)
	var dest := origin
	for c in cells:
		var d := Vector2(c - walk.target.cell).length()
		var dd := Vector2(dest - walk.target.cell).length()
		if d < dd - 0.001 or (absf(d - dd) <= 0.001 and costs[c] < costs[dest]):
			dest = c
	if dest != origin:
		walk.move_to = dest
	return walk


## Plans and plays `bu`'s turn through `battle` (walk, then act). Returns the plan.
static func take_turn(battle: BattleController, bu: BattleUnit) -> Plan:
	var p := plan(battle, bu)
	if p.moves():
		battle.move(bu, p.move_to)
	if p.acts():
		battle.perform(bu, p.action, p.aim)
	return p


## The foe it most wants to reach: near, wounded, a vessel, the King.
static func pick_target(bu: BattleUnit, foes: Array[BattleUnit]) -> BattleUnit:
	var best: BattleUnit = null
	var best_v := INF
	for f in foes:
		var v := Vector2(f.cell - bu.cell).length() - (1.0 - float(f.hp) / maxi(f.max_hp(), 1)) * 3.0
		if f.is_vessel():
			v -= 2.0
		if f.is_king():
			v -= 1.0
		if v < best_v:
			best_v = v
			best = f
	return best


## How good a previewed action is for `bu`'s side.
static func score_hits(bu: BattleUnit, r: ActionResult) -> float:
	var s := 0.0
	for h in r.hits:
		var t := h.target
		var ally := t.team == bu.team
		if h.heal:
			var restored := mini(h.amount, t.max_hp() - t.hp)
			s += restored * WEIGHTS.heal * (1.0 if ally else -1.0)
		elif ally:
			s -= h.amount * WEIGHTS.friendly_fire + (WEIGHTS.friendly_knockout if h.knocked_out else 0.0)
		else:
			s += h.amount * WEIGHTS.damage + (1.0 - float(t.hp) / maxi(t.max_hp(), 1)) * WEIGHTS.wounded
			if h.knocked_out:
				s += WEIGHTS.knockout
			if t.is_vessel():
				s += WEIGHTS.vessel
			if t.is_king():
				s += WEIGHTS.king
	return s


## Scores every action and aim from `cell` (walking there for a moment and back) into `best`.
static func _try_from(battle: BattleController, bu: BattleUnit, cell: Vector2i, walk_cost: int, best: Plan) -> void:
	var origin := bu.cell
	if cell != origin:
		battle.grid.move_occupant(bu, cell)
		bu.cell = cell
	for a in battle.actions(bu):
		if bu.sp < a.sp_cost() or DamageFormula.effect_of(a.category()) == DamageFormula.Effect.NONE:
			continue
		for aim in battle.highlights(bu, a):
			var r := battle.preview(bu, a, aim)
			if r.hits.is_empty():
				continue
			var s := score_hits(bu, r) - a.sp_cost() * WEIGHTS.sp - walk_cost * WEIGHTS.walk
			if not best.acts() or s > best.score:
				best.score = s
				best.action = a
				best.aim = aim
				best.move_to = cell if cell != origin else TacticalGrid.NO_CELL
	if cell != origin:
		battle.grid.move_occupant(bu, origin)
		bu.cell = origin


static func _foes(battle: BattleController, bu: BattleUnit) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for u in battle.all_units():
		if u.team != bu.team and u.on_field and not u.is_down():
			out.append(u)
	return out
