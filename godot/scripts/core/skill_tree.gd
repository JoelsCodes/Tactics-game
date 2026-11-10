class_name SkillTree
extends Resource
## A human's personal skill tree: skills inherited from vessels through mentorship and their levels.
## Starting a study puts a skill at level 0 and makes it usable at once; using it fills its level bar.
## At level 1 it is learned and kept for good; more use levels it to 99. One skill is the active study
## at a time; switching keeps the progress of the others, but a paused study cannot be used.

signal skill_mastered(skill: SkillData)

@export var masteries: Array[SkillMastery] = []
@export var active_index := -1  ## index into masteries of the active study, -1 = none
## Mentor Bonds (humans): the vessel's name -> bond points. Studying a skill from a vessel grows the bond with it: every point the study
## bar gains is a bond point, and learning the skill for good adds BOND_LEARN. Every BOND_PER_LEVEL points is a bond level (up to
## BOND_MAX), and each level makes skills studied from that vessel fill BOND_BONUS faster. Small on purpose: the bond is about who
## taught whom. Saved with the tree.
@export var mentor_bonds := {}

const BOND_PER_LEVEL := 100
const BOND_MAX := 5
const BOND_BONUS := 0.03
const BOND_LEARN := 40


func bond_points(mentor: String) -> int:
	return int(mentor_bonds.get(mentor, 0))


func bond_level(mentor: String) -> int:
	return clampi(bond_points(mentor) / BOND_PER_LEVEL, 0, BOND_MAX)


## How much faster a skill studied from `mentor` fills (0.03 per bond level).
func bond_bonus(mentor: String) -> float:
	return BOND_BONUS * bond_level(mentor)


## Points into the bond's current level and what the level needs ([points, needed]); needed is 0 at the top level.
func bond_bar(mentor: String) -> Array:
	if bond_level(mentor) >= BOND_MAX:
		return [0, 0]
	return [bond_points(mentor) % BOND_PER_LEVEL, BOND_PER_LEVEL]


## Adds bond points with `mentor`. Returns the bond levels gained.
func add_bond(mentor: String, points: int) -> int:
	if mentor == "" or points <= 0:
		return 0
	var before := bond_level(mentor)
	mentor_bonds[mentor] = mini(bond_points(mentor) + points, BOND_PER_LEVEL * BOND_MAX)
	return bond_level(mentor) - before


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


func active_study() -> SkillMastery:
	return masteries[active_index] if active_index >= 0 and active_index < masteries.size() else null


## Makes `skill` the active study (resuming earlier progress if it was studied before).
## Returns its mastery, or null if it is already learned.
func start_study(skill: SkillData, mentor := "") -> SkillMastery:
	var m := mastery_of(skill)
	if m != null and m.is_mastered():
		return null
	if m == null:
		m = SkillMastery.make(skill, mentor)
		masteries.append(m)
	elif mentor != "":
		m.mentor_name = mentor
	active_index = masteries.find(m)
	emit_changed()
	return m


func stop_study() -> void:
	active_index = -1
	emit_changed()


## Level of a skill in this tree (0 if never studied).
func skill_level(skill: SkillData) -> int:
	var m := mastery_of(skill)
	return m.level if m != null else 0


## Whether the human can use `skill` right now: learned (level 1+) or the active study at level 0.
## A paused study cannot be used until it is the active study again.
func can_use(skill: SkillData) -> bool:
	var m := mastery_of(skill)
	return m != null and (m.is_mastered() or m == active_study())


## Every skill the human can use right now: the learned ones plus the active study.
func usable_skills() -> Array[SkillData]:
	var out := learned_skills()
	var a := active_study()
	if a != null:
		out.append(a.skill)
	return out


## Practice (vessels, Nov 2026): using ANY skill in battle fills its bar, with no study needed (a vessel has no mentor). The first use starts the skill at level 0;
## at level 1 it is learned for good and stays usable in every later battle (`usable_skills`), even without the relic that carried it. Returns the levels gained.
## `learned` is set to true when this use took the skill from level 0 to 1.
func practice_skill(skill: SkillData, stats: CharacterStats, loadout: EquipmentLoadout = null, rng: RandomNumberGenerator = null) -> Dictionary:
	if skill == null or stats == null:
		return {"levels": 0, "learned": false}
	var m := mastery_of(skill)
	if m == null:
		m = SkillMastery.make(skill, "")
		masteries.append(m)
	var was_learned := m.is_mastered()
	var gained := m.add_progress(stats.roll_skill_gain(skill.category, loadout, rng))
	var learned := not was_learned and m.is_mastered()
	if learned:
		skill_mastered.emit(skill)
	if gained > 0 or learned:
		emit_changed()
	return {"levels": gained, "learned": learned}


## Humans (the King, the Co-Captains) fill a skill's bar this much faster while they are still studying it (level 0); once it is learned
## (level 1 and up) its uses count at the normal rate (owner, Nov 2026). Vessels learn by practice_skill and are not affected.
const STUDY_RATE := 1.5


## Records `uses` uses of a usable skill (the King's and Co-Captains' path): each adds a roll of the character's rank gain for the
## skill's proficiency (gain minus 0..3) to its level bar, x STUDY_RATE while the skill is still being studied (level 0). Taking the
## active study from level 0 to 1 learns it for good and frees the study slot. Returns the levels gained (0 if it cannot be used now).
func use_skill(skill: SkillData, stats: CharacterStats, uses := 1, loadout: EquipmentLoadout = null, rng: RandomNumberGenerator = null) -> int:
	if not can_use(skill) or stats == null:
		return 0
	var m := mastery_of(skill)
	var was_learned := m.is_mastered()
	var gained := 0
	for i in maxi(uses, 0):  # use by use, so the rate drops back to 1.0 on the use after it is learned
		var p := stats.roll_skill_gain(skill.category, loadout, rng)
		if not m.is_mastered():
			p = roundi(p * STUDY_RATE * (1.0 + bond_bonus(m.mentor_name)))
			add_bond(m.mentor_name, p)  # studying with a vessel grows the bond with it
		gained += m.add_progress(p)
	if not was_learned and m.is_mastered():
		active_index = -1
		add_bond(m.mentor_name, BOND_LEARN)
		skill_mastered.emit(skill)
	if gained > 0:
		emit_changed()
	return gained
