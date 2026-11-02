class_name Riverbank
extends RefCounted
## The four Riverbank battles (samples/riverbank_1..4.json, made by tools/make_riverbank_maps.py): one tileset, four shapes. Each
## map file carries its own "spawns" (Alaric, the Co-Captain's place, the summon stones, the enemies). Placeholder enemies and
## numbers: the owner will write the story and the foes.
##   1 The Ford           16x18  a river with a bridge in the north, a wading ford in the south and a ridge in the way
##   2 The Mill Race      16x18  a mill island in a deep moat with offset bridges; a bluff on each flank, climbed only from the far side
##   3 The Broken Bridge  16x18  the bridge's middle is gone: a wading ford west, a ridge path east, archers on the bluff
##   4 The Warden's Hold  15x15  the enemy's fortress terrace behind a moat, the boss on the dais in its hall
## Standing rules for these maps (the owner's): the standard size is 16x16, grown by up to 3 on each side, kept even, never past 19 (the depth,
## up the screen, stays 16 because a deeper board runs under the battle HUD, so the growth is in the width); level 4 is 15x15.
## Everyone starts out of reach of everyone on the first turn (tests/spacing_check.gd), and the ways across are blocked by water,
## cliffs and trees, so the road to the enemy is a detour (tests/riverbank_check.gd). Ending a turn in shallow water costs 1 Move on
## the next turn (BattleController.WADING_SLOW).

const MAPS := ["", "res://samples/riverbank_1.json", "res://samples/riverbank_2.json", "res://samples/riverbank_3.json", "res://samples/riverbank_4.json"]
const NAMES := ["", "The Ford", "The Mill Race", "The Broken Bridge", "The Warden's Hold"]
const ENEMY_LEVEL := [0, 3, 4, 5, 6]


## The battle for level `n` (1-4) as a BattleSetup (no map id or flags: WorldData sets those).
static func setup(n: int) -> BattleSetup:
	var path: String = MAPS[n]
	var sp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))["spawns"]
	var s := BattleSetup.new()
	s.map_path = path
	s.king_cell = cell(sp["king"])
	s.captain_cell = cell(sp["captain"])
	for c in sp["stones"]:
		s.relics.append([FirstBattle._stone(), cell(c)])
	var i := 0
	for e in sp["enemies"]:
		i += 1
		s.enemies.append([enemy(String(e["kind"]), n, i), cell(e["at"])])
	if n == 4:
		s.objective = "Defeat the boss in the Hold"
	return s


static func cell(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


## An enemy of a kind: "squire" (rook), "archer" (bishop), "wolf" (knight, the Red Wolf) or "boss" (knight, Robin, tougher).
static func enemy(kind: String, n: int, i: int) -> EnemyData:
	var e := EnemyData.new()
	e.id = StringName("riverbank_%d_%s_%d" % [n, kind, i])
	e.basic_attack_only = true
	e.stats = CharacterStats.new()
	var style := WeaponStyle.new()
	var lv: int = ENEMY_LEVEL[n]
	match kind:
		"archer":
			e.display_name = "Ashen Archer"
			style.geometry = TacticalMath.Geometry.BISHOP
			e.stats.base_max_hp = 32
			e.stats.speed = 5
			e.exp_reward = 35
		"wolf":
			e.display_name = "Red Wolf"
			style.geometry = TacticalMath.Geometry.KNIGHT
			e.stats.base_max_hp = 45
			e.stats.speed = 6
			e.exp_reward = 45
		"boss":
			e.display_name = "Robin"  # the owner's enemy character, standing in as the Warden
			style.geometry = TacticalMath.Geometry.KNIGHT
			e.stats.base_max_hp = 100
			e.stats.attack = 10
			e.stats.defense = 8
			e.stats.speed = 6
			e.exp_reward = 150
			lv += 2
		_:
			e.display_name = "Ashen Squire"
			style.geometry = TacticalMath.Geometry.ROOK
			e.stats.base_max_hp = 40
			e.stats.speed = 4
			e.exp_reward = 30
	style.reach = 2
	e.stats.display_name = e.display_name
	e.stats.level = lv
	e.loadout = EquipmentLoadout.make(WeaponItem.new(), style)
	return e
