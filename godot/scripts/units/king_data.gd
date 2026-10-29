class_name KingData
extends UnitData
## The King: the Commander. Exactly one leads every battle. He summons vessels from his roster onto
## relic props on the field (within 30% of the map's longer side of where he stands), and every vessel
## is anchored to him. While he is down he cannot summon.

## Which colour variation of the King's sheet he is drawn in (see KingLook): "original", "red", ...
@export var palette: StringName = &"original"

## The vessels he owns; in battle he can summon any of them, up to the map's summon limit in all.
@export var vessel_roster: Array[VesselData] = []


func role() -> Role:
	return Role.KING
