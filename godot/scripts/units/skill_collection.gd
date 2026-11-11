class_name SkillCollection
extends RefCounted
## The collecting side of skills: what the party has mastered, what is still new to it, and small helpers the screens share
## (a unit's bar for a skill, the colours and letters of ranks and proficiencies).
##
##   mastered    a skill at level 1 or more in someone's tree: a vessel's (learned by use) or a human's (learned by study)
##   new         nobody in the party has mastered it yet. Summon stones show NEW on such a skill, and `freshen` turns some of a
##               battle's stones that carry an already mastered skill into ones that are new, so replays keep feeding the collection.
##   collected   how many of the game's skills (SkillLibrary.all) someone in the party has mastered
##
## Nothing here changes a rule: a stone's skill is only ever swapped for another of the SAME rank.

const FRESH_CHANCE := 0.6  ## a stone whose skill is already mastered becomes a new one this often (when the rank has one left)
const CATEGORY_COLORS := [Color("#ff9a52"), Color("#6fc3ff"), Color("#6be08a"), Color("#e9c777"), Color("#c58bff"), Color("#9aa0c8")]


## Every skill someone in the party has mastered: SkillData -> the names of who has it.
static func mastered(game: SaveGame) -> Dictionary:
	var out := {}
	if game == null or game.roster == null:
		return out
	for u in game.roster.all_units():
		if u == null or u.skill_tree == null:
			continue
		for m in u.skill_tree.masteries:
			if m.is_mastered():
				if not out.has(m.skill):
					out[m.skill] = []
				out[m.skill].append(u.display_name)
	return out


static func is_new(game: SaveGame, skill: SkillData) -> bool:
	return skill != null and not mastered(game).has(skill)


static func total() -> int:
	return SkillLibrary.all().size()


static func collected(game: SaveGame) -> int:
	var have := mastered(game)
	var n := 0
	for s in SkillLibrary.all():
		if have.has(s):
			n += 1
	return n


## Turns some stones that carry a skill the party has already mastered into stones with a new skill of the same rank.
## `relics` is BattleSetup.relics ([RelicItem, cell] pairs). Returns how many were changed.
static func freshen(relics: Array, game: SaveGame, rng: RandomNumberGenerator = null) -> int:
	var have := mastered(game)
	if have.is_empty():
		return 0
	var on_map := {}
	for p in relics:
		if p[0].skill != null:
			on_map[p[0].skill] = true
	var changed := 0
	for p in relics:
		var relic: RelicItem = p[0]
		if relic.skill == null or not have.has(relic.skill):
			continue
		if (rng.randf() if rng != null else randf()) >= FRESH_CHANCE:
			continue
		var pool := SkillLibrary.of_rank(relic.skill.rank).filter(func(k): return not have.has(k) and not on_map.has(k))
		if pool.is_empty():
			continue
		on_map.erase(relic.skill)
		relic.skill = pool[(rng.randi() if rng != null else randi()) % pool.size()]
		on_map[relic.skill] = true
		changed += 1
	return changed


## Whether `skill` is being learned right now by `u`: it has been started (a vessel used it, a human studies it) and is not learned yet (level 0).
## A human's paused study cannot be used, so it never shows up in a battle menu.
static func is_learning(u: UnitData, skill: SkillData) -> bool:
	var m := mastery(u, skill)
	return m != null and not m.is_mastered()


static func is_favorite(u: UnitData, skill: SkillData) -> bool:
	return u != null and skill != null and u.favorite_skills.has(skill.display_name)


## Stars or un-stars a skill. Returns whether it is a favorite now.
static func toggle_favorite(u: UnitData, skill: SkillData) -> bool:
	if u == null or skill == null:
		return false
	if u.favorite_skills.has(skill.display_name):
		u.favorite_skills.erase(skill.display_name)
		return false
	u.favorite_skills.append(skill.display_name)
	return true


## A unit's mastery of a skill (its level and bar), or null when it has never used or studied it.
static func mastery(u: UnitData, skill: SkillData) -> SkillMastery:
	return u.skill_tree.mastery_of(skill) if u != null and u.skill_tree != null and skill != null else null


## What a unit's bar for a skill stands for, in a few words.
static func state_text(u: UnitData, skill: SkillData) -> String:
	var m := mastery(u, skill)
	if m == null:
		return "New: use it to start learning it" if u is VesselData else "On a relic: not learned"
	if m.is_maxed():
		return "Level 99: mastered completely"
	if m.is_mastered():
		return "Learned for good"
	if u is VesselData:
		return "Practising: learned for good at level 1"
	return "Studying: learned for good at level 1" if u.skill_tree.active_study() == m else "Study paused"


static func rank_letter(skill: SkillData) -> String:
	return SkillData.Rank.keys()[skill.rank] if skill != null else ""


static func rank_color(skill: SkillData) -> Color:
	return MenuKit.rank_color(skill.rank) if skill != null else Color.WHITE


static func category_color(cat: Proficiency.Category) -> Color:
	return CATEGORY_COLORS[clampi(int(cat), 0, CATEGORY_COLORS.size() - 1)]


## "Physical · Rank C"
static func kind_line(skill: SkillData) -> String:
	return "%s  ·  Rank %s" % [Proficiency.display_name(skill.category), rank_letter(skill)]


## A skill's description, never empty: its own text, or a plain line made from what the skill is (a few early relic skills have no text).
static func describe(skill: SkillData) -> String:
	if skill == null:
		return ""
	if skill.description != "":
		return skill.description
	if skill.is_physical():
		var b := skill.band()
		return "A physical strike in the shape of the user's weapon style and stance. Rank %s: %.2f to %.2f times Attack." % [rank_letter(skill), float(b[0]), float(b[1])]
	if skill.base_power > 0:
		return "A %s skill with power %d, stronger as its level rises." % [Proficiency.display_name(skill.category).to_lower(), skill.base_power]
	return "A %s skill." % Proficiency.display_name(skill.category).to_lower()
