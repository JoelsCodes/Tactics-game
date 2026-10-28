class_name Looks
## Which character sheet, tint and size each unit uses. Seven characters cover the cast:
##   hero (blond swordswoman)  knight (silver-haired cape)  cardmage (white-haired card caster)
##   gunman (red-haired suit)  dino (green saurian)  brute (red horned beast)  wolf (grey wolfman)
## Jobs pick a character; monsters pick one and a tint. Enemy clan units get a faint red tint
## so they read as hostile even when they share a sheet with your party.

const JOB_CHAR := {
	"squire": "hero", "spellblade": "hero", "fencer": "hero",
	"knight": "knight", "mender": "knight",
	"rogue": "gunman", "shadow": "gunman", "archer": "gunman", "deadeye": "gunman", "gunner": "gunman", "tinker": "gunman",
	"warrior": "dino", "brawler": "dino", "wyrmlancer": "dino", "cleric": "dino",
	"animist": "wolf", "mossknight": "wolf",
	"summoner": "cardmage", "arcanist": "cardmage", "sage": "cardmage", "chronomancer": "cardmage", "illusionist": "cardmage", "alchemist": "cardmage",
}
## monster: [character, tint color, tint amount, hue shift, scale]. Every fighter is drawn at one standard
## size (scale 1.0): monsters and leaders differ by color, not by size.
const MONSTER := {
	"grimkin": ["brute", Color(1, 1, 1), 0.0, 0.0, 1.0],
	"wolfhound": ["wolf", Color(1, 1, 1), 0.0, 0.0, 1.0],
	"ooze": ["dino", Color(.45, .95, .85), .55, .08, 1.0],
	"sandmaw": ["brute", Color(.95, .8, .45), .6, .04, 1.0],
	"mirehag": ["cardmage", Color(.55, .85, .5), .5, .3, 1.0],
}
const ENEMY_TINT := Color(1.0, .62, .55)

static var _meta := {}


static func meta(ch: String) -> Dictionary:
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/meta.json"))
	return _meta[ch]


## {char, tint: Color (a = amount), hue, scale}
static func of(bu: Dictionary) -> Dictionary:
	if bu.mon:
		var m: Array = MONSTER.get(bu.mon, MONSTER.grimkin)
		return {"char": m[0], "tint": Color(m[1], m[2]), "hue": m[3], "scale": m[4]}
	var ch: String = JOB_CHAR.get(bu.job, "hero")
	var enemy: bool = bu.get("team", 0) == 1
	return {"char": ch, "tint": Color(ENEMY_TINT, .22) if enemy else Color(1, 1, 1, 0), "hue": 0.0, "scale": 1.0}


## Applies a look's colors to a ShaderMaterial using shaders/unit.gdshader.
static func apply(mat: ShaderMaterial, look: Dictionary) -> void:
	mat.set_shader_parameter("tint", look.tint)
	mat.set_shader_parameter("hue_shift", look.hue)
