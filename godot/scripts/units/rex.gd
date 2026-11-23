class_name Rex
extends RefCounted
## Rex (owner, Nov 2026: "He's a playable member"): a bare-fisted brawler in a long coat and red scarf, drawn from the `rex` sheet (the owner's
## 5-view prototype, cut by tools/art/cut_anim_v3.gd with its stray specks cleaned). Fast and hard-hitting, light on defence and magic.
## DRAFT (Claude's): his numbers, relics and skills, and when he joins. The story does not bring him in yet, so he joins the company as soon as Bram and
## Lyra have (`join`, called by GameSession.current()); a story scene can bring him in instead with ["give_rex"].


static func make() -> CoCaptainData:
	return Crucible._companion("Rex", &"rex", {"hp": 68, "atk": 11, "def": 6, "mag": 2, "res": 5, "spd": 8, "will": 8, "move": 4, "jump": 2}, "Bare Fists",
		[["Taped Knuckles", "Quick Jab"], ["Red Scarf", "Stunning Blow"]])


## He joins for good, one level below Alaric (Crucible.join_at_level). Safe to call twice.
static func recruit(g: SaveGame) -> SaveGame:
	var owned: Array[CoCaptainData] = g.roster.co_captains
	if not owned.any(func(o): return o.display_name == "Rex"):
		owned.append(Crucible.join_at_level(make(), g))
	return g


## The stand-in joining point until the story has one: a game whose company already has Bram (past the chamber battle) gets Rex. Returns `g`.
static func join(g: SaveGame) -> SaveGame:
	if g != null and g.roster != null and g.roster.co_captains.any(func(o): return o.display_name == "Bram"):
		recruit(g)
	return g
