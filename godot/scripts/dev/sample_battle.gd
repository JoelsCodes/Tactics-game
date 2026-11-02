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


static func populate(stage: BattleStage) -> void:
	CampaignFlow.deploy_leaders(stage.game, stage.battle.deployment, KING_CELL, CAPTAIN_CELL)
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
		e.display_name = ["Grimkin", "Red Wolf", "Robin", "Ashen Archer"][i]
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
