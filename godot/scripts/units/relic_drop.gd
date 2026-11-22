class_name RelicDrop
extends RefCounted
## The relics enemies leave behind (owner, Nov 2026): as soon as an enemy is defeated the party gets a relic carrying a random skill, which goes into the
## inventory and is equipped at the base (the Equipment tab). **Nobody learns a skill by defeating an enemy.** The skill's rank depends on the chapter
## (Crucible.player_top_rank: C up to chapter six, B from seven, A from nine, S from ten) and leans towards the lower ranks; every proficiency is in the pool.
## The weights are a placeholder for the owner to tune.

const NAME_SUFFIX := " Relic"
## Relative chance of each rank (E, D, C, B, A, S) among the ranks the chapter allows.
const WEIGHTS := [40.0, 28.0, 18.0, 8.0, 4.0, 2.0]


## A new relic with a random skill for `chapter` (1 = the opening chapters). `rng` makes the pick repeatable (the checks).
static func make(chapter: int, rng: RandomNumberGenerator = null) -> RelicItem:
	var top := Crucible.player_top_rank(maxi(chapter, 1))
	var total := 0.0
	for r in range(top + 1):
		total += WEIGHTS[r]
	var roll := (rng.randf() if rng != null else randf()) * total
	var rank := 0
	var acc := 0.0
	for r in range(top + 1):
		acc += WEIGHTS[r]
		if roll < acc:
			rank = r
			break
	var pool := SkillLibrary.of_rank(rank)
	var relic := RelicItem.new()
	relic.skill = pool[(rng.randi() if rng != null else randi()) % pool.size()]
	relic.display_name = relic.skill.display_name + NAME_SUFFIX
	return relic


## Two relics are "the same move" when they carry the same skill with the same passives, drawbacks and drains: they stack in lists as x2, x3 (owner, Nov 2026).
static func key(r: RelicItem) -> String:
	var parts: Array[String] = [r.skill.display_name if r.skill != null else "", r.display_name]
	for m in r.modifiers():
		parts.append(m.describe())
	parts.append("%d/%d" % [r.sp_drain_per_turn, r.hp_drain_per_turn])
	return "|".join(parts)


## The relics grouped into stacks, in order of first appearance: [{relic: the first of them, relics: all of them, count: n, label: "Name" or "Name  x3"}].
static func stacks(relics: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var at := {}
	for r in relics:
		var k := key(r)
		if at.has(k):
			var st: Dictionary = out[at[k]]
			st.relics.append(r)
			st.count += 1
			st.label = "%s  x%d" % [r.display_name, st.count]
		else:
			at[k] = out.size()
			out.append({"relic": r, "relics": [r], "count": 1, "label": r.display_name})
	return out
