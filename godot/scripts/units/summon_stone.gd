class_name SummonStone
extends RefCounted
## A summoning node: the glowing stone on the field that a vessel is summoned onto (the relic that gets tethered to it). Every stone
## carries one physical skill (rank E; rank D now and then, rank C commonly from chapter five), picked at random from the ones the game has so far (SkillLibrary: Quick Jab, Shield Prod,
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
static func make(rng: RandomNumberGenerator = null, d_chance := 0.0, c_chance := 0.0) -> RelicItem:
	var skills := e_skills()
	var roll := rng.randf() if rng != null else randf()
	if roll < c_chance:
		skills = SkillLibrary.physical().filter(func(s): return s.rank == SkillData.Rank.C)
	elif roll < c_chance + d_chance:
		skills = SkillLibrary.physical().filter(func(s): return s.rank == SkillData.Rank.D)
	var r := RelicItem.new()
	r.display_name = NAME
	r.skill = skills[(rng.randi() if rng != null else randi()) % skills.size()]
	return r
