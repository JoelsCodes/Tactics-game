class_name SummonStone
extends RefCounted
## A summoning node: the glowing stone on the field that a vessel is summoned onto (the relic that gets tethered to it). Every stone
## carries one rank E physical skill, picked at random from the ones the game has so far (SkillLibrary: Quick Jab, Shield Prod,
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


## A new stone with a random rank E physical skill (`rng` for repeatable picks, e.g. in the checks).
static func make(rng: RandomNumberGenerator = null) -> RelicItem:
	var skills := e_skills()
	var r := RelicItem.new()
	r.display_name = NAME
	r.skill = skills[(rng.randi() if rng != null else randi()) % skills.size()]
	return r
