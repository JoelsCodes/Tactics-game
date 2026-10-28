class_name Mentorship
extends RefCounted
## Rules for humans (King, Co-Captains) studying skills from vessels and inheriting them for good.
## No UI here: the barracks screens call these.
##
##   1. A human picks a vessel from the party roster and one of the skills on that vessel's relics.
##   2. That skill becomes the human's active study (SkillTree.start_study), at level 0. The human can
##      use it right away.
##   3. Each use (SkillTree.use_skill, called by combat) adds the human's rank gain in the skill's
##      proficiency minus a roll of 0-3 (S 17-20 ... C 7-10 ... F 1-4, x efficiency) to a 100-point bar.
##   4. At level 1 the skill is learned and kept for good; further use levels it toward 99.

enum Status {
	AVAILABLE,  ## can be studied
	STUDYING,  ## the active study, level 0: usable, not kept yet
	PAUSED,  ## started before, not the active study: progress kept, not usable
	LEARNED,  ## mastered: in the personal tree
}


## A skill a vessel offers, with the relic it comes through.
class Offer:
	var skill: SkillData
	var relic: RelicItem

	func _init(s: SkillData, r: RelicItem) -> void:
		skill = s
		relic = r


static func is_eligible(human: UnitData) -> bool:
	return human != null and human.is_human()


## Gives a human a skill tree if it has none yet.
static func tree_of(human: UnitData) -> SkillTree:
	if human.skill_tree == null:
		human.skill_tree = SkillTree.new()
	return human.skill_tree


## Skills the vessel's equipped relics carry (Relic Slots 1-2, and the Temp-Relic during battle).
static func offers(vessel: VesselData) -> Array[Offer]:
	var out: Array[Offer] = []
	if vessel == null or vessel.loadout == null:
		return out
	for r in vessel.loadout.relics():
		if r.skill != null:
			out.append(Offer.new(r.skill, r))
	return out


static func status(human: UnitData, skill: SkillData) -> Status:
	var tree := tree_of(human)
	var m := tree.mastery_of(skill)
	if m == null:
		return Status.AVAILABLE
	if m.is_mastered():
		return Status.LEARNED
	if tree.active_study() != m:
		return Status.PAUSED
	return Status.STUDYING


static func status_name(s: Status) -> String:
	return Status.keys()[s].capitalize()


## Why `human` cannot start studying `skill` from `vessel`, or "" if they can.
static func study_error(human: UnitData, vessel: VesselData, skill: SkillData) -> String:
	if not is_eligible(human):
		return "only the King and Co-Captains can study"
	if skill == null:
		return "no skill selected"
	var offered := false
	for o in offers(vessel):
		if o.skill == skill:
			offered = true
	if not offered:
		return "this vessel does not carry that skill"
	match status(human, skill):
		Status.LEARNED:
			return "already learned"
		Status.STUDYING:
			return "already studying"
	return ""


## Makes `skill` the human's active study. Returns its mastery, or null if not allowed.
static func start_study(human: UnitData, vessel: VesselData, skill: SkillData) -> SkillMastery:
	if study_error(human, vessel, skill) != "":
		return null
	return tree_of(human).start_study(skill, vessel.display_name)
