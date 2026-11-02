class_name FirstBattle
extends RefCounted
## The opening battles of the story. Placeholder numbers.
##   first:   in the abandoned castle's hallway, straight out of the hallway scene (HallwayCutscene): Alaric alone at
##            level 1 against one Ashen Squire. No summoning (no relics on the field, no summons, no vessels yet).
##            A win leads to HallwayReturnCutscene, then the chamber.
##   chamber: in the ruins' final chamber, straight out of the altar scene (ChamberCutscene): Alaric with Bram and Lyra
##            as his vessels against two Ashen Squires, with the summon tutorial (BattleTutorial). Two summon stones lie
##            by the altar, two summons are allowed. A win leads to the base conversation (BaseCutscene), then the
##            barracks. The squires can only move and use the basic attack.
## Alaric starts with the Rook weapon style, as the owner set.

const MAP := "res://samples/intro_ruins.json"  ## the hallway
const CHAMBER := "res://samples/ruins_chamber.json"
const AFTER_FIRST := "res://scenes/hallway_return.tscn"
const AFTER_CHAMBER := "res://scenes/base.tscn"
const ALARIC := "Alaric"
const STONES: Array[Vector2i] = [Vector2i(10, 6), Vector2i(10, 3)]  ## the summon stones: where Bram and Lyra stood (ChamberCutscene)


## A new game for the story: Alaric at level 1 with the Rook weapon style, no Co-Captain, vessels or spare relics yet.
static func game() -> SaveGame:
	var roster := PartyRoster.new()
	roster.king = SampleParty.make().king
	roster.king.display_name = ALARIC
	roster.king.id = &"alaric"
	roster.king.stats.display_name = ALARIC
	roster.king.stats.level = 1
	var style := WeaponStyle.new()
	style.display_name = "Rook"
	style.geometry = TacticalMath.Geometry.ROOK
	style.stance = WeaponStyle.Stance.IMPACT
	roster.king.loadout.weapon_style = style
	roster.king.vessel_roster.clear()
	return SaveGame.new_game(roster)


## `g` with Bram and Lyra among Alaric's vessels (once: calling it again changes nothing). Returns `g`.
static func chamber_game(g: SaveGame) -> SaveGame:
	var owned: Array[VesselData] = g.roster.king.vessel_roster
	for name in ["Bram", "Lyra"]:
		if not owned.any(func(v): return v.display_name == name):
			owned.append(SampleParty.bram() if name == "Bram" else SampleParty.lyra())
	return g


## The battle in the hallway with Alaric and the squire on the cells where the scene left them.
static func setup(king_cell: Vector2i, squire_cell: Vector2i) -> BattleSetup:
	var s := BattleSetup.new()
	s.map_path = MAP
	s.king_cell = king_cell
	s.max_summons = 0
	s.enemies = [[squire(1), squire_cell]]
	s.on_win = AFTER_FIRST
	s.map_id = "hallway"
	return s


## The battle in the chamber: Alaric where he stood by the altar, two squires, two summon stones, the tutorial.
static func chamber_setup(king_cell: Vector2i, squire_cells: Array[Vector2i]) -> BattleSetup:
	var s := BattleSetup.new()
	s.map_path = CHAMBER
	s.king_cell = king_cell
	s.max_summons = 2
	s.tutorial = true
	for i in squire_cells.size():
		s.enemies.append([squire(2 + i), squire_cells[i]])
	for cell in STONES:
		s.relics.append([_stone(), cell])
	s.on_win = AFTER_CHAMBER
	s.map_id = "chamber"
	return s


## An altar shard: the field relic a vessel is tethered to (it becomes the vessel's Temp-Relic).
static func _stone() -> RelicItem:
	return SampleParty._relic("Altar Shard", SampleParty._skill("Echo", Proficiency.Category.TACTICAL, 2, 0))


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
