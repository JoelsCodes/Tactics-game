class_name UnitLook
extends RefCounted
## Which character sheet and tint each unit is drawn with (the seven sheets in assets/characters).
## The King is the hero, Co-Captains the knight; vessels and enemies pick a sheet from their name so
## the same unit always looks the same. Vessels get a faint spectral blue, enemies a faint red.

const VESSEL_SHEETS: Array[String] = ["cardmage", "gunman", "dino", "wolf"]
const ENEMY_SHEETS: Array[String] = ["brute", "wolf", "dino", "gunman"]
const VESSEL_TINT := Color(0.55, 0.85, 1.0, 0.28)
const ENEMY_TINT := Color(1.0, 0.55, 0.5, 0.22)


static func sheet_for(unit: UnitData) -> String:
	match unit.role():
		UnitData.Role.KING:
			return "hero"
		UnitData.Role.CO_CAPTAIN:
			return "knight"
		UnitData.Role.VESSEL:
			return VESSEL_SHEETS[_pick(unit, VESSEL_SHEETS.size())]
	return ENEMY_SHEETS[_pick(unit, ENEMY_SHEETS.size())]


static func tint_for(unit: UnitData) -> Color:
	match unit.role():
		UnitData.Role.VESSEL:
			return VESSEL_TINT
		UnitData.Role.ENEMY:
			return ENEMY_TINT
	return Color(1, 1, 1, 0)


## The head-and-shoulders crop of the sheet's first idle frame, for portraits. Every sheet is cut to
## the same body height with the feet at meta.anchor, so the same box works for all of them.
static func portrait(sheet: String) -> Texture2D:
	var frames: SpriteFrames = load("res://assets/characters/%s.tres" % sheet)
	var tex := frames.get_frame_texture("idle_f", 0)
	var anchor: Array = Character.meta(sheet).anchor
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(anchor[0] - 36, anchor[1] - 144, 72, 72)
	return a


static func _pick(unit: UnitData, n: int) -> int:
	var key := String(unit.id) if unit.id != &"" else unit.display_name
	return posmod(key.hash(), n)
