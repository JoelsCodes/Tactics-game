class_name Mentorship
extends RefCounted
## Rules for humans (King, Co-Captains) studying skills from vessels and inheriting them for good.
## No UI here: the barracks screens call these.
##
##   1. A human picks a vessel from the party roster and one of the skills on that vessel's relics.
##   2. That skill becomes the human's active study (SkillTree.start_study), at level 0. The human can
##      use it right away.
##   3. Each use (SkillTree.use_skill, called by combat) adds the human's rank gain in the skill's
##      proficiency minus a roll of 0-3 (S 25-28 ... C 10-13 ... F 5-8, x efficiency) to a 100-point bar.
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


## What a vessel can teach: the skills its equipped relics carry (Relic Slots 1-2, and the Temp-Relic during battle), then the skills it has mastered itself.
static func offers(vessel: VesselData) -> Array[Offer]:
	var out: Array[Offer] = []
	if vessel == null:
		return out
	if vessel.loadout == null:
		return mastered_offers(vessel)
	for r in vessel.loadout.relics():
		if r.skill != null:
			out.append(Offer.new(r.skill, r))
	return out + mastered_offers(vessel, out)


## Skills the vessel has mastered by using them in battle (level 1 and up in its own tree): it can teach those for good, with or
## without the relic it learned them from (owner, Nov 2026). `have` are offers already listed (no skill twice). Their `relic` is null.
static func mastered_offers(vessel: VesselData, have: Array[Offer] = []) -> Array[Offer]:
	var out: Array[Offer] = []
	if vessel == null or vessel.skill_tree == null:
		return out
	for s in vessel.skill_tree.learned_skills():
		if not have.any(func(o): return o.skill == s):
			out.append(Offer.new(s, null))
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
			var m := tree_of(human).mastery_of(skill)
			if m != null and m.mentor_name == vessel.display_name:
				return "already studying"  # (studying it with another teacher is allowed: the study just changes teacher)
	return ""


## Makes `skill` the human's active study. Returns its mastery, or null if not allowed.
static func start_study(human: UnitData, vessel: VesselData, skill: SkillData) -> SkillMastery:
	if study_error(human, vessel, skill) != "":
		return null
	return tree_of(human).start_study(skill, vessel.display_name, teacher_level(vessel, skill))


## The vessel's own level in `skill` (0 when it only carries it on a relic and has never used it).
static func teacher_level(vessel: VesselData, skill: SkillData) -> int:
	var m := vessel.skill_tree.mastery_of(skill) if vessel != null and vessel.skill_tree != null else null
	return m.level if m != null else 0


## One vessel that can teach a skill to a human, and what studying with it would be worth.
class Teacher:
	var vessel: VesselData
	var relic: RelicItem  ## the relic it carries the skill on, or null when it has mastered the skill itself
	var level := 0  ## its own level in the skill
	var bond := 0  ## the human's Mentor Bond level with it
	var bond_bonus := 0.0  ## study speed from the bond
	var teach_bonus := 0.0  ## study speed from its mastery of the skill
	var total := 0.0  ## both, as a fraction (0.07 is +7%)
	var current := false  ## the human is studying this skill from it right now


## Every vessel in `roster` that can teach `skill` to `human` (it carries the skill on a relic or has mastered it), best teacher first: the
## quickest study, then the higher bond, then the higher level.
static func teachers(human: UnitData, roster: PartyRoster, skill: SkillData) -> Array[Teacher]:
	var out: Array[Teacher] = []
	if human == null or roster == null or skill == null:
		return out
	var tree := tree_of(human)
	var m := tree.mastery_of(skill)
	for v in roster.vessels():
		for o in offers(v):
			if o.skill != skill:
				continue
			var t := Teacher.new()
			t.vessel = v
			t.relic = o.relic
			t.level = teacher_level(v, skill)
			t.bond = tree.bond_level(v.display_name)
			t.bond_bonus = tree.bond_bonus(v.display_name)
			t.teach_bonus = SkillTree.teach_bonus(t.level)
			t.total = t.bond_bonus + t.teach_bonus
			t.current = m != null and not m.is_mastered() and tree.active_study() == m and m.mentor_name == v.display_name
			out.append(t)
			break
	out.sort_custom(func(a, b): return a.total > b.total or (is_equal_approx(a.total, b.total) and (a.bond > b.bond or (a.bond == b.bond and a.level > b.level))))
	return out


## Every skill some vessel in `roster` can teach, in no particular order, each once.
static func taught_skills(roster: PartyRoster) -> Array[SkillData]:
	var out: Array[SkillData] = []
	if roster == null:
		return out
	for v in roster.vessels():
		for o in offers(v):
			if not out.has(o.skill):
				out.append(o.skill)
	return out
