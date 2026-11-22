class_name CoCaptainData
extends UnitData
## A companion of the King: every party member other than Alaric himself (Bram, Lyra, Merc, Gideon, Kaelen...). The type keeps the name it had when Co-Captains
## were the only humans besides the King; the vessels were merged into it (overhaul stage 3, Nov 2026). The save still writes it as "co_captain".

## Skills only this companion has, always available (not learned through relics).
@export var signature_skills: Array[SkillData] = []


func role() -> Role:
	return Role.CO_CAPTAIN
