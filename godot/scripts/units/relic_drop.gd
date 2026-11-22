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
