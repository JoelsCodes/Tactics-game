class_name SkillTree
extends Resource
## A unit's personal skill tree: the skills it has trained and their levels.
## A skill a unit uses through an equipped relic is trained here (`practice_skill`): the first use starts it at level 0 and every use fills
## its level bar. At level 1 it is learned and kept for good (usable without the relic); more use levels it to 99.

signal skill_mastered(skill: SkillData)

@export var masteries: Array[SkillMastery] = []


## A unit's skill tree, made on the spot when it has none yet.
static func of(u: UnitData) -> SkillTree:
	if u.skill_tree == null:
		u.skill_tree = SkillTree.new()
	return u.skill_tree


func mastery_of(skill: SkillData) -> SkillMastery:
	for m in masteries:
		if m.skill == skill:
			return m
	return null


func is_learned(skill: SkillData) -> bool:
	var m := mastery_of(skill)
	return m != null and m.is_mastered()


## Every skill permanently inherited (mastery level 1).
func learned_skills() -> Array[SkillData]:
	var out: Array[SkillData] = []
	for m in masteries:
		if m.is_mastered():
			out.append(m.skill)
	return out


## Level of a skill in this tree (0 if never studied).
func skill_level(skill: SkillData) -> int:
	var m := mastery_of(skill)
	return m.level if m != null else 0


## Whether the unit can use `skill` without a relic: it is learned (level 1+).
func can_use(skill: SkillData) -> bool:
	var m := mastery_of(skill)
	return m != null and m.is_mastered()


## Every skill the unit can use without a relic: the learned ones.
func usable_skills() -> Array[SkillData]:
	return learned_skills()


## Makes `skill` learned at once (level 1): for gifts and for the checks that need a unit with a skill.
func learn(skill: SkillData) -> SkillMastery:
	var m := mastery_of(skill)
	if m == null:
		m = SkillMastery.make(skill)
		masteries.append(m)
	if not m.is_mastered():
		m.level = 1
		m.progress = 0
		emit_changed()
	return m


## Practice (owner, Nov 2026): using a skill an equipped relic carries fills its bar. The first use starts the skill at level 0;
## at level 1 it is learned for good and stays usable in every later battle (`usable_skills`), even without the relic that carried it. Returns the levels gained.
## `learned` is set to true when this use took the skill from level 0 to 1.
func practice_skill(skill: SkillData, stats: CharacterStats, loadout: EquipmentLoadout = null, rng: RandomNumberGenerator = null) -> Dictionary:
	if skill == null or stats == null:
		return {"levels": 0, "learned": false}
	var m := mastery_of(skill)
	if m == null:
		m = SkillMastery.make(skill)
		masteries.append(m)
	var was_learned := m.is_mastered()
	var gained := m.add_progress(stats.roll_skill_gain(skill.category, loadout, rng))
	var learned := not was_learned and m.is_mastered()
	if learned:
		skill_mastered.emit(skill)
	if gained > 0 or learned:
		emit_changed()
	return {"levels": gained, "learned": learned}
