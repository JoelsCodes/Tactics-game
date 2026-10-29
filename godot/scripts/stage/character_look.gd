class_name CharacterLook
extends RefCounted
## The characters that came as full sheets (the King, Vesper, Lyra, Ashen Squire, Hollow Choir, Lantern
## Wraith, and the placeholder vessels): which sheet a unit is drawn from, and the sheet's other artwork
## (large illustration, weapon), cut by tools/art/king_extras.py and char_extras.py. The sheets' colour
## variations are not used (the owner removed them).

## Which full sheet a unit is drawn from, by role and id (others use UnitLook's older sheets).
const BY_ID := {&"lyra": "mira", &"mira": "mira",  # Lyra (renamed from Mira; older saves keep the id "mira"), drawn from the `mira` sheet files
	&"vesper": "vesper", &"ashen_squire": "squire", &"hollow_choir": "choir", &"lantern_wraith": "wraith",
	# placeholder vessels (no looks yet)
	&"bram": "warden", &"warden": "warden",  # Bram (renamed from Warden; older saves keep the id "warden")
	&"sorceress": "sorc", &"shade": "shade", &"lancer": "lancer", &"blade": "blade"}


static func dir(base: String) -> String:
	return "res://assets/characters/%s/" % base


## The full sheet of a unit ("" when it has none).
static func base_of(unit: UnitData) -> String:
	if unit == null:
		return ""
	if unit.role() == UnitData.Role.KING:
		return "king"
	if unit.role() == UnitData.Role.ENEMY:
		return ""
	return BY_ID.get(unit.id, "")


## The large illustration.
static func illustration(base: String) -> Texture2D:
	return load(dir(base) + "artwork/full_portrait.png")


## The weapon artwork (a sword or a staff) and its name.
static func weapon(base: String) -> Texture2D:
	for w in ["sword", "staff"]:
		if ResourceLoader.exists(dir(base) + "equipment/%s.png" % w):
			return load(dir(base) + "equipment/%s.png" % w)
	return null


static func weapon_name(base: String) -> String:
	return "Staff" if ResourceLoader.exists(dir(base) + "equipment/staff.png") else "Sword"
