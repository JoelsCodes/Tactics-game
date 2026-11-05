class_name UnitLook
extends RefCounted
## Which character sheet and tint each unit is drawn with (the sheets in assets/characters).
## Units with one of the owner's full sheets use it (CharacterLook: the King, Lyra, Ashen
## Squire, Hollow Choir, Lunar and the placeholder vessels); any other unit, and every enemy, is drawn with the
## Ashen Squire sheet (ENEMY_SHEETS), except the enemy characters in ENEMY_CHARACTERS (Robin, the Red Wolf, Vesper, the Eater, the Boar). Vessels get a faint spectral blue, enemies a faint red.

const ENEMY_SHEETS: Array[String] = ["squire"]  ## an enemy without a character of its own is an Ashen Squire
## The enemy characters with their own sheet, by name (the owner's: Robin, the Red Wolf, Vesper, the Eater and the Boar are enemies).
const ENEMY_CHARACTERS := {"Robin": "robin", "Red Wolf": "redwolf", "Vesper": "vesper", "Eater": "eater", "Boar": "boar",
	"Stone Colossus": "stone_colossus", "Forest Wolf": "forest_wolf", "Moss Slime": "moss_slime", "Goblin Scavenger": "goblin_scavenger",
	"Ironhollow Sentinel": "ironhollow_sentinel", "Ashen Wyvern": "ashen_wyvern", "Hollowmark Assassin": "hollowmark_assassin",
	"Riverband Brute": "riverband_brute", "Hooded Cutthroat": "hooded_cutthroat",
	# chapter two (Riverford): the owner's beginner sprites under the names the story uses
	"Rot-Hound": "forest_wolf", "Rot-Hound Alpha": "forest_wolf", "Sewer Slime": "moss_slime", "Town Watchman": "riverband_brute",
	"Royal Phalanx": "ironhollow_sentinel", "Royal Legionnaire": "riverband_brute", "Royal Executioner": "stone_colossus", "Rune Mage": "hollowmark_assassin",
	"Rune Hexer": "hollowmark_assassin", "Arena Wyvern": "ashen_wyvern",
	"Watch Scout": "hooded_cutthroat", "Watch Sergeant": "riverband_brute", "Royal Guard": "ironhollow_sentinel", "Battle-Mage": "hollowmark_assassin"}
const VESSEL_TINT := Color(0.55, 0.85, 1.0, 0.28)
const ENEMY_TINT := Color(1.0, 0.55, 0.5, 0.22)


static func sheet_for(unit: UnitData) -> String:
	var full := CharacterLook.base_of(unit)  # the owner's full sheets
	if unit.role() == UnitData.Role.ENEMY:
		full = ENEMY_CHARACTERS.get(unit.display_name, "")
	if full != "":
		return full
	return ENEMY_SHEETS[_pick(unit, ENEMY_SHEETS.size())]  # a unit without its own sheet, or an enemy


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
	var painted: String = Character.meta(sheet).get("portrait", "")
	if painted != "":  # the sheet came with a painted portrait
		return load("res://assets/characters/%s/%s" % [sheet, painted])
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
