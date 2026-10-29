class_name CharacterLook
extends RefCounted
## Colour looks of the characters that came as full sheets (the King, Vesper, Mira, Ashen Squire,
## Hollow Choir, Lantern Wraith). Each sheet has its looks in assets/characters/<base>/palettes/<look>.json
## (swatches, preview, matching portrait) and a complete recolored animation set per look
## (`<base>_<look>`, built by tools/art/king_extras.py and char_extras.py), so changing a unit's look
## (UnitData.palette) changes its in-game sprite, and the portraits that show it follow. The sheet's
## other artwork (large illustration, weapon) is shown by the Appearance screen.

## Which full sheet a unit is drawn from, by role and id (others use UnitLook's older sheets).
const BY_ID := {&"mira": "mira", &"vesper": "vesper", &"ashen_squire": "squire", &"hollow_choir": "choir", &"lantern_wraith": "wraith",
	# placeholder vessels (no looks yet)
	&"sorceress": "sorc", &"warden": "warden", &"shade": "shade", &"lancer": "lancer", &"blade": "blade"}


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


## The looks of a sheet, the original first ([] for a sheet without looks).
static func looks(base: String) -> Array:
	if base == "":
		return []
	return Character.meta(base).get("palettes", [])


## The sheet a unit is drawn with in its look: "king" or "king_red"; "" when it has no full sheet.
static func sheet_of(unit: UnitData) -> String:
	var base := base_of(unit)
	if base == "":
		return ""
	var p := String(unit.palette)
	return base if p == "original" or not looks(base).has(p) else "%s_%s" % [base, p]


static func info(base: String, look: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(dir(base) + "palettes/%s.json" % look))


## The four swatch colours of a look, as in the sheet's small palette strip.
static func swatches(base: String, look: String) -> Array[Color]:
	var out: Array[Color] = []
	for h in info(base, look).swatches:
		out.append(Color(h))
	return out


## The portrait matching a look (the original also has five large ones: meta.portraits).
static func portrait(base: String, look: String) -> Texture2D:
	return load(dir(base) + info(base, look).portrait)


## The large illustration (drawn for the original look only).
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
