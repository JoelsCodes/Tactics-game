class_name SampleBattle
extends RefCounted
## Fills a BattleStage with a small test fight until there are real missions: the King and the Co-Captain
## chosen in the Formation pop-up, and four placeholder enemies on the far bank.
## Placeholder names, positions and numbers.

## Everyone starts far enough apart that nobody can reach anyone on the first turn (tests/spacing_check.gd): the party on
## the west bank, the enemies on the far bank.
const KING_CELL := Vector2i(1, 4)
const CAPTAIN_CELL := Vector2i(1, 7)
const ENEMY_CELLS: Array[Vector2i] = [Vector2i(10, 5), Vector2i(11, 8), Vector2i(10, 10), Vector2i(11, 3)]


## The fight as a BattleSetup. `level` 1-3 raises the enemies' level (3, 5, 7).
static func setup(level := 1) -> BattleSetup:
	var s := BattleSetup.new()
	s.map_path = "res://samples/demo_battlefield.json"
	s.king_cell = KING_CELL
	s.captain_cell = CAPTAIN_CELL
	for i in ENEMY_CELLS.size():
		var e := EnemyData.new()
		e.display_name = ["Grimkin", "Red Wolf", "Robin", "Ashen Archer"][i]
		e.id = StringName("foe_%d" % i)
		e.stats = CharacterStats.new()
		e.stats.base_max_hp = 40
		e.stats.speed = 4 + i
		e.stats.level = 3 + (level - 1) * 2
		e.exp_reward = 30
		var style := WeaponStyle.new()
		style.geometry = [TacticalMath.Geometry.KING, TacticalMath.Geometry.KNIGHT, TacticalMath.Geometry.KING, TacticalMath.Geometry.BISHOP][i]
		e.loadout = EquipmentLoadout.make(WeaponItem.new(), style)
		s.enemies.append([e, ENEMY_CELLS[i]])
	return s


static func populate(stage: BattleStage) -> void:
	setup().populate(stage)
