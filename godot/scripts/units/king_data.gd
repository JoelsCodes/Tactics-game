class_name KingData
extends UnitData
## The King: the Commander. Exactly one leads every battle. Every vessel on the field is anchored to
## him: he summons them (within 30% of the map's longer side of where he stands) and untethers them,
## and if he falls every vessel is cut loose.

## The vessels he can summon (his roster); up to DeploymentManager.MAX_VESSELS on the field at once.
@export var vessel_roster: Array[VesselData] = []


func role() -> Role:
	return Role.KING
