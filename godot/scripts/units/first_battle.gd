class_name FirstBattle
extends RefCounted
## The opening battles in the abandoned castle's hallway. Summoning is not available yet (no relics on the field,
## no summons, no vessels), and the squires can only move and use the basic attack. Placeholder numbers.
##   first:  straight out of the hallway scene (HallwayCutscene), the King alone at level 1 against one squire;
##           a win leads to the King's return to the hallway (HallwayReturnCutscene)
##   second: straight out of that scene, the King (as the first battle left him) against two squires

const MAP := "res://samples/intro_ruins.json"
const AFTER_FIRST := "res://scenes/hallway_return.tscn"


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
	s.enemies = [[squire(1), squire_cell]]
	s.on_win = AFTER_FIRST
	return s


## The second battle: the King and two squires on the cells where the return scene left them.
static func second_setup(king_cell: Vector2i, squire_cells: Array[Vector2i]) -> BattleSetup:
	var s := BattleSetup.new()
	s.map_path = MAP
	s.king_cell = king_cell
	s.max_summons = 0
	for i in squire_cells.size():
		s.enemies.append([squire(2 + i), squire_cells[i]])
	return s


## An Ashen Squire that only moves and uses the basic attack.
static func squire(n: int) -> EnemyData:
	var e := EnemyData.new()
	e.display_name = "Ashen Squire"
	e.id = StringName("ashen_squire_%d" % n)
	e.basic_attack_only = true
	e.stats = CharacterStats.new()
	e.stats.display_name = e.display_name
	e.stats.level = 1
	e.stats.base_max_hp = 40
	e.stats.speed = 4
	e.exp_reward = 30
	e.loadout = EquipmentLoadout.make(WeaponItem.new(), WeaponStyle.new())
	return e
