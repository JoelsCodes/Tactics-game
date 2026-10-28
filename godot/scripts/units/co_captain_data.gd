class_name CoCaptainData
extends UnitData
## A Co-Captain: a permanent human officer with signature skills. At most one per battle. Immune to
## vessel decay: no Fade Clock, and not cut loose when the King falls.

## Skills only this officer has, always available (not learned through relics).
@export var signature_skills: Array[SkillData] = []


func role() -> Role:
	return Role.CO_CAPTAIN
