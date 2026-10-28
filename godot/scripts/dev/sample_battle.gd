class_name SampleBattle
extends RefCounted
## Fills a BattleStage with a small test fight until there are real missions: the party's King and first
## Co-Captain, three relics on the field to summon onto, and four placeholder enemies on the far bank.
## Placeholder names, positions and numbers.

const KING_CELL := Vector2i(2, 4)
const CAPTAIN_CELL := Vector2i(3, 6)
const RELIC_CELLS: Array[Vector2i] = [Vector2i(4, 2), Vector2i(4, 7), Vector2i(1, 9)]
const ENEMY_CELLS: Array[Vector2i] = [Vector2i(9, 5), Vector2i(10, 7), Vector2i(9, 10), Vector2i(11, 3)]


static func populate(stage: BattleStage) -> void:
	var roster := stage.game.roster
	stage.battle.deployment.deploy_king(roster.king, KING_CELL)
	if not roster.co_captains.is_empty():
		stage.battle.deployment.deploy_co_captain(roster.co_captains[0], CAPTAIN_CELL)
	var names := ["Ember Shard", "Hollow Bell", "Tide Glass"]
	for i in RELIC_CELLS.size():
		var r := RelicItem.new()
		r.display_name = names[i]
		var s := SkillData.new()
		s.display_name = ["Flare", "Toll", "Undertow"][i]
		s.category = [Proficiency.Category.ELEMENTAL, Proficiency.Category.STATUS, Proficiency.Category.VOID][i]
		s.sp_cost = [4, 3, 6][i]
		s.base_power = [7, 0, 6][i]
		r.skill = s
		stage.battle.deployment.place_relic(r, RELIC_CELLS[i])
	for i in ENEMY_CELLS.size():
		var e := EnemyData.new()
		e.display_name = ["Grimkin", "Marsh Hound", "Grimkin", "Ashen Archer"][i]
		e.id = StringName("foe_%d" % i)
		e.stats = CharacterStats.new()
		e.stats.base_max_hp = 40
		e.stats.speed = 4 + i
		e.stats.level = 3
		e.exp_reward = 30
		var style := WeaponStyle.new()
		style.geometry = [TacticalMath.Geometry.KING, TacticalMath.Geometry.KNIGHT, TacticalMath.Geometry.KING, TacticalMath.Geometry.BISHOP][i]
		e.loadout = EquipmentLoadout.make(WeaponItem.new(), style)
		stage.add_enemy(e, ENEMY_CELLS[i])
