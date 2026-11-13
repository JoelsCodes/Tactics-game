class_name SummonRanking
extends RefCounted
## Who to summon onto a stone, best first (owner, Nov 2026): the vessels that are ALREADY learning the stone's skill come first (the furthest along
## first: the stone finishes what they started); then those who have not started it, the one that learns it fastest first (the most bar points a
## use earns: `CharacterStats.skill_gain`); then those who already know it (the stone gives them nothing new). A vessel that cannot be summoned right
## now (on the field, removed, too far, no summons left) comes last with the reason. Ties go to the vessel summoned last, then by name.
## Only orders and describes; DeploymentManager still decides whether a summon is allowed.

enum State { LEARNING, FRESH, KNOWN, BLOCKED }

static var last_used := ""  ## display name of the vessel summoned last (this session)


## One row per vessel the King owns, best first. Each: {vessel, state, available, best, fill, gain, level, tag, error}.
static func entries(dm: DeploymentManager, relic: RelicItem, cell: Vector2i) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var sk: SkillData = relic.skill if relic != null else null
	for v in dm.owned_vessels:
		var err := dm.summon_error(v, cell)
		var m := SkillCollection.mastery(v, sk)
		var gain := v.stats.skill_gain(sk.category, v.loadout) if v.stats != null and sk != null else 0
		var state: int = State.FRESH
		if err != "":
			state = State.BLOCKED
		elif m != null and m.is_mastered():
			state = State.KNOWN
		elif m != null and m.progress > 0:
			state = State.LEARNING
		rows.append({"vessel": v, "state": state, "available": err == "", "best": false, "fill": m.fill() if m != null else 0.0,
			"gain": gain, "level": m.level if m != null else 0, "error": err, "tag": ""})
	rows.sort_custom(_before)
	var first_fresh := -1
	for i in rows.size():
		var r: Dictionary = rows[i]
		match r.state:
			State.LEARNING:
				r.tag = "Learning  %d%%" % roundi(float(r.fill) * 100.0)
			State.FRESH:
				if first_fresh < 0:
					first_fresh = i
				r.tag = "Fast learner  +%d" % r.gain if i == first_fresh and _fresh_count(rows) > 1 else "Learns  +%d" % r.gain
			State.KNOWN:
				r.tag = "Knows it  Lv %d" % r.level
			State.BLOCKED:
				r.tag = short_reason(r.error)
	for r in rows:
		if r.available:
			r.best = true
			break
	return rows


static func _fresh_count(rows: Array[Dictionary]) -> int:
	return rows.filter(func(r): return r.state == State.FRESH).size()


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if a.state != b.state:
		return a.state < b.state
	if a.state == State.LEARNING and not is_equal_approx(a.fill, b.fill):
		return a.fill > b.fill
	if a.state == State.FRESH and a.gain != b.gain:
		return a.gain > b.gain
	if a.state == State.KNOWN and a.level != b.level:
		return a.level < b.level  # the one who knows it least well gains most from using it again
	var al: bool = a.vessel.display_name == last_used
	var bl: bool = b.vessel.display_name == last_used
	if al != bl:
		return al
	return String(a.vessel.display_name) < String(b.vessel.display_name)


## The reason a summon is refused, in a few words for a bar.
static func short_reason(err: String) -> String:
	if err.begins_with("already on the field"):
		return "On the field"
	if err.begins_with("removed"):
		return "Gone this battle"
	if err.begins_with("too far"):
		return "Out of reach"
	if err.begins_with("summon limit"):
		return "No summons left"
	if err.begins_with("tile is blocked"):
		return "Tile blocked"
	if err.begins_with("the King must"):
		return "King is down"
	return "Cannot"
