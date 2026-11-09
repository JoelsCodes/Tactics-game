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
	"Riverband Brute": "riverband_brute", "Hooded Cutthroat": "hooded_cutthroat", "Soul Warden": "soul_warden",
	# chapter eight (the capital)
	"Royal Infantry": "squire", "Royal Archer": "hooded_cutthroat", "Mounted Royal Guard": "riverband_brute", "Elite Patrol Commander": "riverband_brute",
	"Royal Shield Infantry": "ironhollow_sentinel", "Royal Crossbowman": "hooded_cutthroat", "Armored Halberdier": "ironhollow_sentinel", "Defensive Battle Mage": "sunward_priest",
	"Elite Gate Officer": "spectral_duelist", "Captain Aldren": "aldren", "Veteran Royal Swordsman": "spectral_duelist", "Royal Support Mage": "sunward_priest",
	"Elite Royal Infantry": "squire", "Royal Battle Mage": "sunward_priest", "Heavy Armored Guard": "ironhollow_sentinel", "Veteran Crossbowman": "hooded_cutthroat",
	"Royal Knight": "riverband_brute", "Elite Royal Knight": "spectral_duelist", "Palace Halberdier": "ironhollow_sentinel", "Royal Spellcaster": "sunward_priest",
	"Veteran Royal Archer": "hooded_cutthroat", "Palace Guard Commander": "riverband_brute",
	# chapter six (the Ashen Expanse)
	"Living Armor": "ironhollow_sentinel", "Animated Blade": "hollowmark_assassin", "Rust Construct": "stone_golem", "Armored Sentinel": "stone_colossus", "Spectral Cadet": "squire",
	"Armored Training Construct": "ironhollow_sentinel", "Phantom Archer": "hooded_cutthroat", "Academy Instructor": "riverband_brute", "Spectral Shield Infantry": "ironhollow_sentinel",
	"Elite Spectral Swordsman": "spectral_duelist", "Tactical Instructor": "riverband_brute", "Corrupted Soldier": "squire", "Corrupted Guardian": "stone_golem", "Cassian Vale": "spectral_duelist",
	"Elite Honor Swordsman": "spectral_duelist", "Royal Academy Guardian": "ironhollow_sentinel", "Veteran Phantom Archer": "hooded_cutthroat",
	# chapter seven (Vespera)
	"Wandering Spirit": "hollowmark_assassin", "Hollow Lantern": "soul_warden", "Possessed Ceremonial Armor": "ironhollow_sentinel", "Gravebound Sentinel": "stone_golem",
	"Gravebound Knight": "riverband_brute", "Stone Gargoyle": "ashen_wyvern", "Spectral Mourner": "hollowmark_assassin", "Cemetery Guardian": "stone_colossus",
	"Crystal-Infused Undead": "crystalbound_warrior", "Spectral Guardian": "hooded_cutthroat", "Resonance Construct": "crystal_crawler", "Catacomb Sentinel": "stone_golem",
	"Captured Spectral Warrior": "squire", "Crystal Guardian": "stone_golem", "Choir Sentinel": "ironhollow_sentinel", "Malrec": "malrec",
	"Bell Construct": "bell_construct", "Crystal-Infused Spirit": "hollowmark_assassin", "Bell Sentinel": "ironhollow_sentinel", "Gravel Wolf": "forest_wolf", "Alpha Gravel Wolf": "forest_wolf", "Bog Slime": "moss_slime", "Road Raider": "hooded_cutthroat",
	"Raider Brute": "riverband_brute", "Quarry Scavenger": "goblin_scavenger", "Quarry Crawler": "crystal_crawler", "Cave Eater": "eater", "Cave Boar": "boar",
	"Stone-Fused Miner": "crystalbound_warrior", "Stone Guardian": "stone_golem", "The Deepdweller": "stone_colossus", "Spectral Duelist": "spectral_duelist", "Crystalbound Warrior": "crystalbound_warrior", "Stone Golem": "stone_golem", "Crystal Crawler": "crystal_crawler",
	"Spectral Infantry": "squire", "Spectral Archer": "hooded_cutthroat", "Spectral Captain": "riverband_brute", "Spectral Shield Bearer": "ironhollow_sentinel",
	"Spectral Elite Guard": "ironhollow_sentinel", "Spectral Knight": "crystalbound_warrior", "Spectral Scout": "hooded_cutthroat", "Swift Swordsman": "spectral_duelist",
	"Kaelen": "kaelen", "Gideon": "gideon", "War Standard": "stone_colossus", "The Memorial": "stone_colossus", "Corrupted Echo": "squire",
	"Manifestation of Grief": "crystal_crawler", "Hollow Heart": "stone_golem", "Lantern Bearer": "riverband_brute", "Soul Binder": "stone_colossus", "Ritual Apparatus": "stone_colossus",
	# chapter two (Riverford): the owner's beginner sprites under the names the story uses
	"Rot-Hound": "forest_wolf", "Rot-Hound Alpha": "forest_wolf", "Sewer Slime": "moss_slime", "Town Watchman": "riverband_brute",
	"Royal Phalanx": "ironhollow_sentinel", "Royal Legionnaire": "riverband_brute", "Royal Executioner": "stone_colossus", "Rune Mage": "hollowmark_assassin",
	"Rune Hexer": "hollowmark_assassin", "Arena Wyvern": "ashen_wyvern",
	"Watch Scout": "hooded_cutthroat", "Watch Sergeant": "riverband_brute", "Royal Guard": "ironhollow_sentinel", "Battle-Mage": "sunward_priest",
	# chapter nine (the palace). "The Last King", Reave and Elowen have the owner's own sheets (Nov 2026).
	"The Last King": "last_king", "Elite Palace Infantry": "squire", "Palace Hall Halberdier": "ironhollow_sentinel", "Hall Spellcaster": "sunward_priest",
	"Veteran Hall Archer": "hooded_cutthroat", "Royal Hall Officer": "spectral_duelist", "Royal Shield Knight": "ironhollow_sentinel", "Elite Palace Guard": "riverband_brute",
	"Veteran Halberdier": "ironhollow_sentinel", "Commander of the King's Shield": "riverband_brute",
	"Animated Royal Statue": "stone_colossus", "Enchanted Ancestral Armor": "ironhollow_sentinel", "Arcane Palace Sentinel": "hollowmark_assassin", "Great Royal Guardian": "stone_golem",
	"Royal Champion Knight": "riverband_brute", "Elite Palace Spellcaster": "sunward_priest", "Royal Honor Guard": "ironhollow_sentinel",
	"Commander of the Crown's Guard": "riverband_brute",
	# chapter ten (the Falcon Guard trail): stand-ins on existing sheets, no art of their own yet
	"Deserter Swordsman": "spectral_duelist", "Deserter Crossbowman": "hooded_cutthroat", "Armored Scavenger": "ironhollow_sentinel", "Starved Wolf": "forest_wolf",
	"Deserter Captain": "riverband_brute", "Rusted Military Construct": "stone_golem", "Stone-Armored Beast": "boar", "Animated Weapon": "hollowmark_assassin",
	"Memorial Guardian": "stone_colossus", "Ancient Armored Sentinel": "ironhollow_sentinel", "Enchanted Royal Statue": "stone_colossus", "Spectral Training Construct": "squire",
	"Falcon Guard Swordsman": "spectral_duelist", "Falcon Guard Archer": "hooded_cutthroat", "Falcon Guard Shield Soldier": "ironhollow_sentinel", "Falcon Guard Officer": "riverband_brute",
	"The Last Sentinel": "stone_colossus", "Ancient Royal Construct": "stone_golem", "Enchanted Armored Guardian": "ironhollow_sentinel", "Arcane Memorial Sentinel": "hollowmark_assassin",
	# chapter eleven: more Falcon Guard on stand-in sheets (see Falcon); "Commander Vaelor" has the owner's sheet (Nov 2026)
	"Falcon Guard Spearman": "squire", "Falcon Guard Heavy Infantry": "ironhollow_sentinel", "Falcon Guard Cavalry": "riverband_brute", "Falcon Guard Battle Mage": "hollowmark_assassin",
	"Falcon Guard Honor Guard": "ironhollow_sentinel", "Falcon Guard Standard Bearer": "spectral_duelist", "Falcon Guard Captain": "riverband_brute", "Commander Vaelor": "vaelor",
	"Armored Field Construct": "stone_golem", "Territorial Boar": "boar", "Disturbed Wolf": "forest_wolf",
	# the final arc (stand-ins on existing sheets; Reave, Elowen and the revolutionaries have no art of their own yet)
	"Reave": "reave", "Elowen": "elowen", "Sunward Priest": "sunward_priest", "Ember Zealot": "ember_zealot",
	"Ember Moth": "ember_moth", "Rustshell Crab": "rust_crab", "Frostborn Warrior": "frost_warrior", "Spore Cap": "spore_cap",
	"Prism Mantis": "prism_mantis", "Gorge Maw": "gorge_maw", "Magma Ram": "magma_ram", "Skull Spider": "skull_spider", "Revolutionary Swordsman": "spectral_duelist", "Revolutionary Archer": "hooded_cutthroat",
	"Revolutionary Duelist": "spectral_duelist", "Revolutionary Battle Mage": "ember_zealot", "Revolutionary Spellcaster": "ember_zealot",
	"Revolutionary Heavy Infantry": "ironhollow_sentinel", "Revolutionary Champion": "riverband_brute", "Revolutionary Extremist": "ember_zealot",
	"Revolutionary Armored Raider": "riverband_brute", "Revolutionary Captain": "riverband_brute", "Revolutionary Vanguard Commander": "spectral_duelist",
	"Revolutionary Saboteur Commander": "ember_zealot", "Revolutionary Commander": "riverband_brute", "Revolutionary Fortress Commander": "riverband_brute",
	"Falcon Guard Elite Honor Guard": "ironhollow_sentinel", "Falcon Guard Commander": "riverband_brute", "Enchanted Garden Sentinel": "stone_colossus",
	"Elite Guardian Construct": "stone_golem", "Ancient Royal Guardian": "stone_golem"}
const VESSEL_TINT := Color(0.55, 0.85, 1.0, 0.28)
const ENEMY_TINT := Color(1.0, 0.55, 0.5, 0.22)


static func sheet_for(unit: UnitData) -> String:
	var full := CharacterLook.base_of(unit)  # the owner's full sheets
	if unit.role() == UnitData.Role.ENEMY:
		full = ENEMY_CHARACTERS.get(unit.display_name, "")
	if full != "":
		return full
	return ENEMY_SHEETS[_pick(unit, ENEMY_SHEETS.size())]  # a unit without its own sheet, or an enemy


## The Falcon Guard are long-dead soldiers: a faint pale-blue spectral tint keeps them apart from the living soldiers of chapter eight.
const FALCON_TINT := Color(0.7, 0.9, 1.0, 0.34)
## Reave's revolutionaries are living: a warm green-gold cast sets them apart from both the royal soldiers and the Falcon Guard.
const REVOLT_TINT := Color(0.75, 1.0, 0.55, 0.3)


static func tint_for(unit: UnitData) -> Color:
	if unit.role() == UnitData.Role.ENEMY and unit.display_name.begins_with("Revolutionary") and sheet_for(unit) != "ember_zealot":  # the flame zealot keeps its own colours
		return REVOLT_TINT
	if unit.role() == UnitData.Role.ENEMY and unit.display_name.begins_with("Falcon Guard"):
		return FALCON_TINT
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
	sheet = Character.sheet(sheet)
	if painted != "":  # the sheet came with a painted portrait
		return load("res://assets/characters/%s/%s" % [sheet, painted])
	var frames: SpriteFrames = load("res://assets/characters/%s.tres" % sheet)
	var tex := frames.get_frame_texture("idle_f", 0)
	var anchor: Array = Character.meta(sheet).anchor
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(anchor[0] - 36, anchor[1] - 144, 72, 72)
	return a


## The portrait showing expression `face` (one of the sheet's `portrait_names`), or the plain portrait when the sheet has no such face.
static func portrait_face(sheet: String, face: String) -> Texture2D:
	var meta := Character.meta(sheet)
	var names: Array = meta.get("portrait_names", [])
	var i := names.find(face)
	var files: Array = meta.get("portraits", [])
	if i < 0 or i >= files.size():
		return portrait(sheet)
	return load("res://assets/characters/%s/%s" % [Character.sheet(sheet), files[i]])


## Whether the sheet has expression portraits (Alaric's sixteen).
static func has_faces(sheet: String) -> bool:
	return not Character.meta(sheet).get("portrait_names", []).is_empty()


static func _pick(unit: UnitData, n: int) -> int:
	var key := String(unit.id) if unit.id != &"" else unit.display_name
	return posmod(key.hash(), n)
