class_name KingData
extends UnitData
## The King: the Commander. Exactly one leads every battle. He summons vessels from his roster onto
## relic props on the field (within 30% of the map's longer side of where he stands), and every vessel
## is anchored to him. While he is down he cannot summon.

## The vessels he can summon; up to DeploymentManager.MAX_VESSELS on the field at once.
@export var vessel_roster: Array[VesselData] = []


func role() -> Role:
	return Role.KING
