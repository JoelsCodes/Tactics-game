class_name KingLook
extends RefCounted
## The King's colour variations. The sheet came with nine looks (assets/characters/king/palettes/<name>.json:
## swatches, preview, matching portrait). Each is a complete recolored animation set built by
## tools/art/king_extras.py (`king` for the original, `king_<name>` for the others), so changing the
## look changes the in-game sprite, and the portraits that show him follow it. The artwork of the other
## sections (the large illustration, the sword) is shown by the Appearance screen.

const PALETTES: Array[String] = ["original", "red", "blue", "white", "purple", "green", "brown", "gold", "crimson"]
const DIR := "res://assets/characters/king/"


## The character sheet name for a King's look: "king" or "king_red".
static func sheet_of(unit: UnitData) -> String:
	var p: String = String((unit as KingData).palette) if unit is KingData else "original"
	return "king" if p == "original" or not PALETTES.has(p) else "king_" + p


static func info(palette: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DIR + "palettes/%s.json" % palette))


## The four swatch colours of a look, as in the sheet's small palette strip.
static func swatches(palette: String) -> Array[Color]:
	var out: Array[Color] = []
	for h in info(palette).swatches:
		out.append(Color(h))
	return out


## The portrait matching a look (the sheet's small variation portraits; the original also has five large ones).
static func portrait(palette: String) -> Texture2D:
	return load(DIR + info(palette).portrait)


## The large illustration (only the original look has one) and the sword.
static func illustration() -> Texture2D:
	return load(DIR + "artwork/full_portrait.png")


static func sword() -> Texture2D:
	return load(DIR + "equipment/sword.png")
