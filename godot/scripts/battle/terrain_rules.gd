class_name TerrainRules
extends RefCounted
## What the ground a unit stands on does to it (owner, Nov 2026: "we currently have water but nothing else, add whatever you feel works"). One table,
## read by BattleController: where the unit ENDS its turn (a slowed next turn, embers that burn, a holy dais that heals) and what a skill's look
## (SkillLook: fire, ice, spark, holy) does to a unit standing on the ground (water conducts lightning and damps fire, snow feeds ice, embers feed fire,
## a dais strengthens holy healing). Walking costs stay in TacticalGrid.MOVE_COST (shallow water and mud cost 2 a step).
##
##   code  ground          ending a turn there                      a skill's look against a unit on it
##   w     shallow water   -1 Move next turn                         spark +25%, fire -25%
##   a     sand            -1 Move next turn                         -
##   n     snow            -1 Move next turn                         ice +25%, fire -15%
##   c     embers/cinder   loses 5% max HP (never the last point)    fire +25%, ice -25%
##   e     holy dais       regains 5% max HP                         holy +25% (heals and holy blows)
##   m     mud             - (it costs 2 a step already)             -
## Physical blows and skills without a look are never changed.

const RULES := {
	"w": {"name": "Water", "slow": 1, "look": {"spark": 1.25, "fire": 0.75}},
	"a": {"name": "Sand", "slow": 1},
	"n": {"name": "Snow", "slow": 1, "look": {"ice": 1.25, "fire": 0.85}},
	"c": {"name": "Embers", "burn_pct": 5, "look": {"fire": 1.25, "ice": 0.75}},
	"e": {"name": "Holy dais", "heal_pct": 5, "look": {"holy": 1.25}},
}


static func rule(grid: TacticalGrid, c: Vector2i) -> Dictionary:
	return RULES.get(grid.terrain(c), {}) if grid != null else {}


## The skill-look multiplier for a target standing on `c` (1.0 when the ground does nothing to that look).
static func look_mult(grid: TacticalGrid, c: Vector2i, action: BattleAction) -> float:
	if action == null or action.skill == null or action.category() == Proficiency.Category.PHYSICAL:
		return 1.0
	var look := SkillLook.of(action.skill)
	if look == "":
		return 1.0
	return float(rule(grid, c).get("look", {}).get(look, 1.0))


## `amount` changed by the ground under the target, and the note that explains it ("Water +25%"), or "" when nothing changed.
static func adjust(grid: TacticalGrid, target_cell: Vector2i, action: BattleAction, amount: int) -> Array:
	var m := look_mult(grid, target_cell, action)
	if is_equal_approx(m, 1.0) or amount <= 0:
		return [amount, ""]
	var pct := roundi((m - 1.0) * 100.0)
	return [maxi(1, roundi(amount * m)), "%s %s%d%%" % [String(rule(grid, target_cell).name), "+" if pct > 0 else "", pct]]


## What the ground does to `bu` as its turn ends there: sets its slow for next turn, takes or gives HP. Notes go to `bu.tick_notes`.
static func end_turn(bu: BattleUnit, grid: TacticalGrid) -> void:
	if bu.is_down():
		return
	var r := rule(grid, bu.cell)
	if r.is_empty():
		return
	if int(r.get("slow", 0)) > 0:
		bu.slow = maxi(bu.slow, int(r.slow))
	if int(r.get("burn_pct", 0)) > 0:
		var d := mini(maxi(1, bu.max_hp() * int(r.burn_pct) / 100), maxi(0, bu.hp - 1))
		if d > 0:
			bu.hp -= d
			bu.tick_notes.append("%s -%d" % [r.name, d])
	if int(r.get("heal_pct", 0)) > 0 and bu.hp < bu.max_hp():
		var g := mini(maxi(1, bu.max_hp() * int(r.heal_pct) / 100), bu.max_hp() - bu.hp)
		bu.hp += g
		bu.tick_notes.append("%s +%d" % [r.name, g])


## A short line for a tile's ground, for the HUD and the forecast ("Snow: -1 Move next turn; ice +25%"), or "" for plain ground.
static func describe(grid: TacticalGrid, c: Vector2i) -> String:
	var r := rule(grid, c)
	if r.is_empty():
		return ""
	var parts: Array[String] = []
	if int(r.get("slow", 0)) > 0:
		parts.append("-%d Move next turn" % int(r.slow))
	if int(r.get("burn_pct", 0)) > 0:
		parts.append("burns %d%% HP a turn" % int(r.burn_pct))
	if int(r.get("heal_pct", 0)) > 0:
		parts.append("heals %d%% HP a turn" % int(r.heal_pct))
	var looks: Dictionary = r.get("look", {})
	for l in looks:
		var pct := roundi((float(looks[l]) - 1.0) * 100.0)
		parts.append("%s %s%d%%" % [l, "+" if pct > 0 else "", pct])
	return "%s: %s" % [r.name, ", ".join(parts)]
