class_name SummonStone
extends RefCounted
## A summoning node: the glowing stone on the field that a vessel is summoned onto (the relic that gets tethered to it). Every stone
## carries one skill (rank E physical; ranked D to S from any of the six proficiencies; rank D now and then, rank C commonly from chapter five, rank B from seven, A from nine, S rare from ten, all in rotation from eleven), picked at random from the ones the game has so far (SkillLibrary: Quick Jab, Shield Prod,
## Hamstring Cut, Step-Aside Strike, Feinting Lunge, Dirty Sand Kick, Grip Loosen, Crescent Strike, Pity Pity, Hop). The vessel
## summoned onto it can use that skill (it is the vessel's Temp-Relic) and so starts learning it.

const NAME := "Altar Shard"


## Every rank E physical skill (the shared SkillLibrary objects, never copies).
static func e_skills() -> Array[SkillData]:
	var out: Array[SkillData] = []
	for s in SkillLibrary.physical():
		if s.rank == SkillData.Rank.E:
			out.append(s)
	return out


## A new stone with a random physical skill (`rng` for repeatable picks, e.g. in the checks): rank E, except that `c_chance` of the stones carry a rank C skill and
## `d_chance` a rank D one (chapter three: now and then D; chapter five: C is common, owner Nov 2026). One roll decides, so the chances add up.
## Higher ranks come in with the story (owner, Nov 2026): rank B from chapter seven (`b_chance`), rank A from chapter nine (`a_chance`), rank S a rare variety from chapter ten
## (`s_chance`), and from chapter eleven every rank E to S is in rotation. One roll decides, from the top rank down, so all the chances add up (the rest is rank E).
static func make(rng: RandomNumberGenerator = null, d_chance := 0.0, c_chance := 0.0, b_chance := 0.0, a_chance := 0.0, s_chance := 0.0) -> RelicItem:
	var skills := e_skills()
	var roll := rng.randf() if rng != null else randf()
	var edge := 0.0
	for pair in [[SkillData.Rank.S, s_chance], [SkillData.Rank.A, a_chance], [SkillData.Rank.B, b_chance], [SkillData.Rank.C, c_chance], [SkillData.Rank.D, d_chance]]:
		edge += float(pair[1])
		if roll < edge:
			var rank: int = pair[0]
			skills = SkillLibrary.of_rank(rank)  # ranked stones draw from every proficiency (owner, Nov 2026); rank E stays physical
			break
	var r := RelicItem.new()
	r.display_name = NAME
	r.skill = skills[(rng.randi() if rng != null else randi()) % skills.size()]
	return r
