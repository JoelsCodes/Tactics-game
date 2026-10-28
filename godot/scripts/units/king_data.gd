class_name KingData
extends UnitData
## The King: the Commander. Exactly one leads every battle. He summons vessels from the relic props
## on the field (within 30% of the map's longer side of where he stands), and every vessel is anchored
## to him. While he is down he cannot summon.


func role() -> Role:
	return Role.KING
