class_name FirstBattle
extends RefCounted
## The first battle, straight out of the hallway scene (HallwayCutscene): the King alone at level 1 against one
## Ashen Squire in the abandoned castle's hallway. Summoning is not available yet (no relics on the field, no
## summons, no vessels), and the squire can only move and use the basic attack. Placeholder numbers.

const MAP := "res://samples/intro_ruins.json"


## A new game for it: the King at level 1, with no Co-Captain, vessels or spare relics yet.
static func game() -> SaveGame:
	var roster := PartyRoster.new()
	roster.king = SampleParty.make().king
	roster.king.stats.level = 1
	roster.king.vessel_roster.clear()
	return SaveGame.new_game(roster)


## The battle with the King and the squire on the cells where the scene left them.
static func setup(king_cell: Vector2i, squire_cell: Vector2i) -> BattleSetup:
	var s := BattleSetup.new()
	s.map_path = MAP
	s.king_cell = king_cell
	s.max_summons = 0
	var e := EnemyData.new()
	e.display_name = "Ashen Squire"
	e.id = &"ashen_squire_1"
	e.basic_attack_only = true
	e.stats = CharacterStats.new()
	e.stats.display_name = e.display_name
	e.stats.level = 1
	e.stats.base_max_hp = 40
	e.stats.speed = 4
	e.exp_reward = 30
	e.loadout = EquipmentLoadout.make(WeaponItem.new(), WeaponStyle.new())
	s.enemies = [[e, squire_cell]]
	return s
