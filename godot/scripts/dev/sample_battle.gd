class_name SampleBattle
extends RefCounted
## Fills a BattleStage with a small test fight until there are real missions: the King and the Co-Captain
## chosen in the barracks, three relics on the field to summon onto, and four placeholder enemies on the
## far bank.
## Placeholder names, positions and numbers.

## Everyone starts far enough apart that nobody can reach anyone on the first turn (tests/spacing_check.gd): the party on
## the west bank, the enemies on the far bank.
const KING_CELL := Vector2i(1, 4)
const CAPTAIN_CELL := Vector2i(1, 7)
const RELIC_CELLS: Array[Vector2i] = [Vector2i(2, 2), Vector2i(2, 6), Vector2i(0, 1)]
const ENEMY_CELLS: Array[Vector2i] = [Vector2i(10, 5), Vector2i(11, 8), Vector2i(10, 10), Vector2i(11, 3)]


## The fight as a BattleSetup. `level` 1-3 raises the enemies' level (3, 5, 7).
static func setup(level := 1) -> BattleSetup:
	var s := BattleSetup.new()
	s.map_path = "res://samples/demo_battlefield.json"
	s.king_cell = KING_CELL
	s.captain_cell = CAPTAIN_CELL
	s.max_summons = int(JSON.parse_string(FileAccess.get_file_as_string(s.map_path)).get("max_summons", DeploymentManager.DEFAULT_SUMMON_LIMIT))
	var names := ["Ember Shard", "Hollow Bell", "Tide Glass"]
	for i in RELIC_CELLS.size():
		var r := SummonStone.make()  # every stone carries a random rank E physical skill
		r.display_name = names[i]
		s.relics.append([r, RELIC_CELLS[i]])
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
