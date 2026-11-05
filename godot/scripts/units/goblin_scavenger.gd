class_name GoblinScavenger
extends RefCounted
## Low-level enemy. Its name selects goblin_scavenger in UnitLook.ENEMY_CHARACTERS.
## Map and encounter authors can use: stage.add_enemy(GoblinScavenger.make(), cell).

static func make() -> EnemyData:
	var enemy := EnemyData.new()
	enemy.id = &"goblin_scavenger"
	enemy.display_name = "Goblin Scavenger"
	enemy.exp_reward = 12
	enemy.basic_attack_only = true

	var stats := CharacterStats.new()
	stats.display_name = enemy.display_name
	stats.level = 1
	stats.base_max_hp = 32
	stats.attack = 5
	stats.defense = 2
	stats.magic = 2
	stats.resistance = 2
	stats.speed = 7
	stats.move = 4
	stats.jump = 1
	enemy.stats = stats

	var dagger := WeaponItem.new()
	dagger.display_name = "Rusty Dagger"
	dagger.base_power = 4
	var style := WeaponStyle.new()
	style.geometry = TacticalMath.Geometry.PAWN
	style.stance = WeaponStyle.Stance.IMPACT
	enemy.loadout = EquipmentLoadout.make(dagger, style)
	return enemy
