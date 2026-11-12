class_name EnemyAI
extends RefCounted
## Enemy turns (and the turns of confused or berserk units). Pure rules: it looks at the battle through BattleController and acts only through
## its calls (move, perform, defend), so it plays by exactly the same rules as the player.
##
## Each turn it tries every tile it can walk to (staying put included), every action it can afford there (the free Attack, its skills) and every
## tile each one can be aimed at, scores what the hits would do (BattleController.preview) plus how safe the tile is, and takes the best.
## If nothing in reach is worth doing it walks toward the foe it most wants by the real road (a distance map round walls and water) or, if foes
## are about and there is nowhere better, guards.
##
## What it values (WEIGHTS, one place to tune):
##   damage to player units, knocking one out, wounded targets (finish them), dangerous targets (the ones that hit hardest are focused), vessels on
##   the field (fragile, their Fade Clock is running), the King, restoring HP to wounded allies, and the ailments and stat changes of its skills
##   (SkillFx.ai_value: never an effect the target already has, never a pointless heal or boost).
## Where it stands: away from the places many foes can reach (more so the more hurt it is, and for casters), high ground, near its own side.
## Flavour (owner's wish, Nov 2026): it likes to use every skill it has: a skill it has not used yet gets a bonus, repeating the last one a small
## penalty, and the SP cost is cheap, but none of that can outweigh a clearly better move (a knockout, a heal, a strong hit).
## What it avoids: hitting its own side (unless berserk), needless walking, standing where it will be killed for nothing.
## Confused units move and act at random; berserk ones hit the nearest unit of either side.

const WEIGHTS := {
	"damage": 1.0,  ## per HP of damage to a player unit
	"knockout": 40.0,  ## knocking a player unit out
	"wounded": 20.0,  ## x the share of HP the target has already lost
	"vessel": 15.0,  ## hitting a vessel on the field (above the King: vessels are the priority)
	"king": 10.0,  ## hitting the King
	"threat": 0.5,  ## x the target's best attack stat x the share of its HP the hit takes: the dangerous ones go first
	"heal": 1.0,  ## per HP actually restored to a wounded ally
	"friendly_fire": 1.5,  ## per HP of damage to its own side (subtracted)
	"friendly_knockout": 60.0,  ## knocking out one of its own side (subtracted)
	"sp": 0.3,  ## per SP spent (subtracted)
	"walk": 0.1,  ## per walking point used (subtracted)
	"danger": 0.35,  ## per point of damage the foes could do to the tile it ends on (subtracted)
	"height": 0.6,  ## per level of high ground over the foes (at most 2)
	"company": 0.3,  ## per ally within two tiles
	"new_skill": 5.0,  ## a skill it has not used yet this battle (flavour)
	"repeat": 3.0,  ## the skill it used last turn again (subtracted)
}
const ROLE_DANGER := {"caster": 1.8, "support": 1.8, "skirmisher": 1.2, "guardian": 0.7, "brute": 0.6}  ## how much each role minds standing in harm's way


## What the unit will do this turn.
class Plan:
	var move_to := TacticalGrid.NO_CELL  ## NO_CELL: stay where it is
	var action: BattleAction  ## null: no action (only walks, or waits)
	var aim := TacticalGrid.NO_CELL
	var score := 0.0
	var target: BattleUnit  ## the unit it walks toward when it cannot act
	var defend := false  ## nothing to do and foes about: guard
	var face := Vector2i.ZERO  ## the direction to turn to after the walk (ZERO: keep the direction of the last step); picked like the player's (BattleController.face)

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
	var faces := {origin: bu.facing}  ## the facing it would have there: the direction of its last step (the Rook, Bishop and Pawn only attack the way they face)
	if not battle.moved:
		var r := battle.move_range(bu)
		for c in r.cells():
			if c != origin:
				cells.append(c)
				costs[c] = r.cost_to(c)
				var path := r.path_to(c)
				faces[c] = BattleController.dir_toward(path[path.size() - 2] if path.size() > 1 else origin, c)
	if bu.has_status(BattleUnit.CONFUSE):
		return _plan_confused(battle, bu, cells, costs, faces)
	var ctx := {"foes": foes, "pos": {}, "unruly": bu.has_status(BattleUnit.BERSERK), "faces": faces}
	if not battle.acted:
		var turns := StanceRules.uses_facing(battle.geometry_of(bu))  # only the styles that hit the way they face gain from choosing a direction
		for c in cells:
			_try_from(battle, bu, c, costs[c], best, faces[c], ctx)
			if turns:  # it may turn to any of the four directions before it strikes, as the player may (owner, Nov 2026), after a walk or standing still
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if d != faces[c]:
						_try_from(battle, bu, c, costs[c], best, d, ctx)
	# a unit on the player's side (only the simulators play one) takes any real attack it has, as a person would: the danger of the tile only chooses
	# between attacks, it never talks the party out of fighting (enemies keep their caution)
	if best.acts() and (best.score > 0.0 or bu.team == 0):
		bu.ai_stuck = 0
		return best
	# nothing worth doing in reach: walk toward the most wanted foe, by the real road
	var walk := Plan.new()
	walk.target = pick_target(bu, foes)
	var dm: MovementRange = battle.grid.reachable(walk.target.cell, 400, bu.stat(StatModifier.Stat.JUMP), walk.target.team)
	var dest := origin
	ctx["target"] = walk.target
	var dest_score := _approach_score(dm, bu, origin, costs[origin], ctx, battle)
	for c in cells:
		var sc := _approach_score(dm, bu, c, costs[c], ctx, battle)
		if sc < dest_score - 0.001:
			dest = c
			dest_score = sc
	if dest != origin and bu.ai_trail.count(dest) >= 2 and cells.size() > 1:  # it has been here twice lately: a dance with a foe that turns as it turns; break the rhythm
		var others: Array[Vector2i] = cells.filter(func(c): return c != origin and not bu.ai_trail.has(c))
		if not others.is_empty():
			dest = others[randi() % others.size()]
	if dest != origin:
		walk.move_to = dest
		bu.ai_trail.append(dest)
		if bu.ai_trail.size() > 8:
			bu.ai_trail.pop_front()
	elif not battle.acted:
		# it cannot get closer: if foes are about, it guards rather than idles, and if guarding did not help last turn, it steps away to turn round
		for f in foes:
			if absi(f.cell.x - origin.x) + absi(f.cell.y - origin.y) <= f.stat(StatModifier.Stat.MOVE) + 3:
				if bu.ai_stuck >= 1 and cells.size() > 1:
					var far: Array[Vector2i] = cells.filter(func(c): return costs[c] >= 2)
					walk.move_to = far[randi() % far.size()] if not far.is_empty() else cells[1]
					bu.ai_stuck = 0
				else:
					walk.defend = true
					bu.ai_stuck += 1
				break
	return walk


## Lower is better: the road left to the target from `c` (a tile with no road counts as far), the walk it costs, and the danger of standing there.
static func _approach_score(dm: MovementRange, bu: BattleUnit, c: Vector2i, walked: int, ctx: Dictionary, battle: BattleController) -> float:
	var road := dm.cost_to(c)
	var left := float(road) if road >= 0 else 200.0 + Vector2(c - dm.origin).length()
	# the styles that hit along the way they face (Rook, Bishop, Pawn): end the walk in line with the target and looking at it, so that the next turn can strike
	var t: BattleUnit = ctx.target
	var face: Vector2i = ctx.faces.get(c, bu.facing)
	if (c.x == t.cell.x or c.y == t.cell.y) and face == BattleController.dir_toward(c, t.cell) and c != t.cell:
		left -= 2.5
	else:
		left += 2.0  # (a unit standing next to a foe it cannot hit, facing the wrong way, must move to turn: guarding forever would be a stalemate)
	var role: String = (bu.data as EnemyData).ai_role if bu.data is EnemyData else ""
	var shy := 1.0 if role in ["caster", "support"] else 0.0  # only the ones that fight from a distance care where they stand while closing in
	return left + WEIGHTS.walk * walked + _danger(battle, bu, c, ctx.foes) * WEIGHTS.danger * shy * bu.ai_danger_scale


## A confused unit: a random tile it can reach, then a random action it can afford at a random aim that touches somebody (friend or foe).
static func _plan_confused(battle: BattleController, bu: BattleUnit, cells: Array[Vector2i], costs: Dictionary, faces: Dictionary) -> Plan:
	var p := Plan.new()
	var c: Vector2i = cells[randi() % cells.size()]
	var options: Array = []
	var origin := bu.cell
	var old_face := bu.facing
	bu.facing = faces[c]
	if c != origin:
		battle.grid.move_occupant(bu, c)
		bu.cell = c
	if not battle.acted:
		for a in battle.actions(bu):
			if bu.sp < a.sp_cost():
				continue
			for aim in battle.highlights(bu, a):
				if not battle.preview(bu, a, aim).hits.is_empty():
					options.append([a, aim])
	if c != origin:
		battle.grid.move_occupant(bu, origin)
		bu.cell = origin
	bu.facing = old_face
	if c != origin:
		p.move_to = c
	if not options.is_empty():
		var o: Array = options[randi() % options.size()]
		p.action = o[0]
		p.aim = o[1]
		p.score = 1.0
	return p


## Plans and plays `bu`'s turn through `battle` (walk, then act). Returns the plan. A sleeping or stunned unit just loses the turn.
static func take_turn(battle: BattleController, bu: BattleUnit) -> Plan:
	if battle.skip_if_helpless(bu):
		return Plan.new()
	var p := plan(battle, bu)
	if p.moves():
		battle.move(bu, p.move_to)
	if p.face != Vector2i.ZERO:
		battle.face(bu, p.face)
	if p.acts():
		_remember(bu, p.action)
		battle.perform(bu, p.action, p.aim)
		# a skill that reopens the walk (Quick Jab): walk again with the move points left
		if battle.walk_budget >= 0 and not battle.moved and battle.current == bu:
			var again := plan(battle, bu)
			if again.moves():
				battle.move(bu, again.move_to)
	elif p.defend:
		battle.defend(bu)
	return p


## What it has used, for the flavour bonus.
static func _remember(bu: BattleUnit, a: BattleAction) -> void:
	if a.skill != null:
		bu.ai_used[a.skill.display_name] = int(bu.ai_used.get(a.skill.display_name, 0)) + 1
		bu.ai_last = a.skill.display_name
	else:
		bu.ai_last = ""


## The foe it most wants to reach: near, wounded, a vessel, the King.
static func pick_target(bu: BattleUnit, foes: Array[BattleUnit]) -> BattleUnit:
	var best: BattleUnit = null
	var best_v := INF
	for f in foes:
		var v := Vector2(f.cell - bu.cell).length() - (1.0 - float(f.hp) / maxi(f.max_hp(), 1)) * 3.0
		if bu.team == 0:
			var w := objective_weight(f)
			if w < 0.0:
				continue  # never walk at a unit that must not fall
			v -= w * 0.5  # the party heads for the objective
		if f.is_vessel():
			v -= 2.0
		if f.is_king():
			v -= 1.0
		if v < best_v:
			best_v = v
			best = f
	return best


## How good a previewed action is for `bu`'s side. `unruly`: a berserk unit, to whom everybody is a foe.
static func score_hits(bu: BattleUnit, r: ActionResult, unruly := false) -> float:
	var s := 0.0
	for h in r.hits:
		var t := h.target
		var ally := t.team == bu.team and not unruly
		s += SkillFx.ai_value(bu, h, r.action.skill) if r.action != null else 0.0
		if h.heal:
			var restored := mini(h.amount, t.max_hp() - t.hp)
			s += restored * WEIGHTS.heal * (1.0 if ally else -1.0)
		elif ally:
			s -= h.amount * WEIGHTS.friendly_fire + (WEIGHTS.friendly_knockout if h.knocked_out else 0.0)
		else:
			s += h.amount * WEIGHTS.damage + (1.0 - float(t.hp) / maxi(t.max_hp(), 1)) * WEIGHTS.wounded
			s += WEIGHTS.threat * maxf(t.stat(StatModifier.Stat.ATTACK), t.stat(StatModifier.Stat.MAGIC)) * minf(1.0, float(h.amount) / maxi(t.hp, 1))
			if h.knocked_out:
				s += WEIGHTS.knockout
			if t.is_vessel():
				s += WEIGHTS.vessel
			if t.is_king():
				s += WEIGHTS.king
			if bu.team == 0:
				var w := objective_weight(t)
				s += w + (w if h.knocked_out else 0.0)
	return s


## The battle's objective, for a unit on the player's side (only the simulators play one; the game leaves it empty): a target's
## EnemyData.behavior ("carrier", "device", "standard") or display name -> extra score for hitting it (negative: must not be hit).
static var party_objective := {}


static func objective_weight(t: BattleUnit) -> float:
	if party_objective.is_empty() or not (t.data is EnemyData):
		return 0.0
	var w := float(party_objective.get(t.data.display_name, 0.0))
	if w == 0.0:
		w = float(party_objective.get((t.data as EnemyData).behavior, 0.0))
	return w


## What the foes could do to `bu` on `cell` next turn: each one that can walk and swing there adds its usual hit (a rough number).
static func _danger(battle: BattleController, bu: BattleUnit, cell: Vector2i, foes: Array[BattleUnit]) -> float:
	var total := 0.0
	for f in foes:
		var d := absi(f.cell.x - cell.x) + absi(f.cell.y - cell.y)
		if d <= f.stat(StatModifier.Stat.MOVE) + 2:
			var power := maxi(f.stat(StatModifier.Stat.ATTACK), f.stat(StatModifier.Stat.MAGIC))
			var weapon := f.data.loadout.weapon_power() if f.data.loadout else 0
			total += maxf(1.0, float(DamageFormula.scaled(DamageFormula.mitigate(weapon + power, bu.stat(StatModifier.Stat.DEFENSE)))) * 0.7)
	return total


## How good it is to end the turn on `cell` (apart from the action): safe, high, among friends. Cached per planning.
static func _position(battle: BattleController, bu: BattleUnit, cell: Vector2i, ctx: Dictionary) -> float:
	var cache: Dictionary = ctx.pos
	if cache.has(cell):
		return cache[cell]
	var role: String = (bu.data as EnemyData).ai_role if bu.data is EnemyData else ""
	var hurt := 1.0 + (1.0 - float(bu.hp) / maxi(bu.max_hp(), 1)) * 2.0
	var v := -_danger(battle, bu, cell, ctx.foes) * WEIGHTS.danger * hurt * float(ROLE_DANGER.get(role, 1.0)) * bu.ai_danger_scale
	var high := 0.0
	for f in ctx.foes:
		high = maxf(high, battle.grid.height(cell) - battle.grid.height(f.cell))
	v += WEIGHTS.height * clampf(high, 0.0, 2.0)
	var near := 0
	for u in battle.all_units():
		if u != bu and u.team == bu.team and not u.is_down() and u.on_field and absi(u.cell.x - cell.x) + absi(u.cell.y - cell.y) <= 2:
			near += 1
	v += WEIGHTS.company * near * (2.0 if role == "guardian" else 1.0)
	if role == "caster" or role == "support":  # keeps its distance
		for f in ctx.foes:
			if absi(f.cell.x - cell.x) + absi(f.cell.y - cell.y) <= 2:
				v -= 3.0
	v = clampf(v, -6.0, 4.0)  # where it stands can tip a close call, never talk it out of a good attack (a hurt unit that only runs is a stalemate)
	cache[cell] = v
	return v


## Scores every action and aim from `cell` (walking there for a moment and back) into `best`.
static func _try_from(battle: BattleController, bu: BattleUnit, cell: Vector2i, walk_cost: int, best: Plan, face: Vector2i, ctx: Dictionary) -> void:
	var origin := bu.cell
	var old_face := bu.facing
	bu.facing = face
	if cell != origin:
		battle.grid.move_occupant(bu, cell)
		bu.cell = cell
	var place := _position(battle, bu, cell, ctx)
	for a in battle.actions(bu):
		if bu.sp < a.sp_cost() or (DamageFormula.effect_of(a.category()) == DamageFormula.Effect.NONE and not SkillFx.has(a.skill)):
			continue
		var flavour := 0.0
		if a.skill != null:  # it likes to use all it has: new skills are fun, the same one again is dull
			var used := int(bu.ai_used.get(a.skill.display_name, 0))
			flavour = WEIGHTS.new_skill if used == 0 else (WEIGHTS.new_skill * 0.4 if used == 1 else 0.0)
			if bu.ai_last == a.skill.display_name:
				flavour -= WEIGHTS.repeat
		for aim in battle.highlights(bu, a):
			var r := battle.preview(bu, a, aim)
			if r.hits.is_empty():
				continue
			var base := score_hits(bu, r, ctx.unruly)
			if base <= 0.0:
				continue  # nothing gained: flavour never makes a pointless move
			var first: BattleUnit = r.hits[0].target
			if not r.hits[0].heal and first != bu:  # a blow that is likelier to land is worth more: behind the target beats in front of it
				base *= battle.hit_percent_for(bu, first, a) / 100.0
			var s := base + flavour + place - a.sp_cost() * WEIGHTS.sp - walk_cost * WEIGHTS.walk
			if not best.acts() or s > best.score:
				best.score = s
				best.action = a
				best.aim = aim
				best.move_to = cell if cell != origin else TacticalGrid.NO_CELL
				best.face = face if face != ctx.faces[cell] else Vector2i.ZERO
	if cell != origin:
		battle.grid.move_occupant(bu, origin)
		bu.cell = origin
	bu.facing = old_face


static func _foes(battle: BattleController, bu: BattleUnit) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	var any := bu.has_status(BattleUnit.BERSERK) or bu.has_status(BattleUnit.CONFUSE)
	for u in battle.all_units():
		if u != bu and (any or u.team != bu.team) and u.on_field and not u.is_down():
			out.append(u)
	return out
