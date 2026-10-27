class_name Looks
## Which character sheet and palette each unit uses. Three sheets cover everyone:
## melee jobs use the swordswoman, ranged and magic jobs the card mage, and every
## enemy (clan or monster) the demon. The unit shader then swaps one hue band to the
## job's or monster's color from the data, FFT-style, so each class reads differently.

const MELEE := ["sword", "greatsword", "knife", "rapier", "katana", "fist", "mace", "spear", "claw"]
## Band that gets recolored per sheet: hue center, half-width, and its typical S and V.
const BAND := {
	"hero": {"hue": .56, "w": .075, "s": .69, "v": .66},
	"cardmage": {"hue": .585, "w": .055, "s": .46, "v": .52},
	"demon": {"hue": .94, "w": .075, "s": .64, "v": .36},
}
const MON_SCALE := {"grimkin": .86, "wolfhound": .92, "ooze": .9, "sandmaw": 1.08, "mirehag": 1.22}

static var _meta := {}


static func meta(ch: String) -> Dictionary:
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/meta.json"))
	return _meta[ch]


## {char, recolor, src_hue, band, dst: Vector3(hue, sat mult, val mult), scale}
static func of(bu: Dictionary) -> Dictionary:
	var ch: String
	var col: Color
	var sc := 1.0
	if bu.get("team", 0) == 1 or bu.mon:
		ch = "demon"
		col = Color(Data.MONSTERS[bu.mon].col) if bu.mon else Color(Data.JOBS[bu.job].col)
		sc = MON_SCALE.get(bu.mon, 1.0)
		if bu.u.get("leader"):
			sc = 1.08
	else:
		var wt: String = bu.s.wt if bu.has("s") else Rules.calc_stats(bu.u).wt
		ch = "hero" if wt in MELEE else "cardmage"
		col = Color(Data.JOBS[bu.job].col)
	var b: Dictionary = BAND[ch]
	var dh := absf(col.h - b.hue)
	dh = min(dh, 1.0 - dh)
	return {
		"char": ch,
		# Colors close to the original band keep the art untouched.
		"recolor": not (dh < .04 and col.s > .3),
		"src_hue": b.hue,
		"band": b.w,
		"dst": Vector3(col.h, clampf(col.s / b.s, .08, 1.5), clampf(col.v / b.v, .55, 1.7)),
		"scale": sc,
	}


## Applies a look's palette to a ShaderMaterial using shaders/unit.gdshader.
static func apply(mat: ShaderMaterial, look: Dictionary) -> void:
	mat.set_shader_parameter("recolor", look.recolor)
	mat.set_shader_parameter("src_hue", look.src_hue)
	mat.set_shader_parameter("band", look.band)
	mat.set_shader_parameter("dst", look.dst)
