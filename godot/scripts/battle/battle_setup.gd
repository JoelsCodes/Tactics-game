class_name BattleSetup
extends RefCounted
## What a battle starts with when it is not the sample fight: its map, where the King (and the Co-Captain, if
## any) stand, the enemies and their cells, the relics to summon onto, and how many summons are allowed. A
## story scene sets BattleStage.pending_setup (and pending_game) and changes to scenes/battle.tscn. The game after
## the battle (its XP and levels) is handed on to the next scene in Cutscene3D.carried_game.

var map_path := "res://samples/demo_battlefield.json"
var king_cell := Vector2i(0, 0)
var captain_cell := TacticalGrid.NO_CELL  ## NO_CELL: no Co-Captain on this battle
var enemies: Array = []  ## [EnemyData, Vector2i] pairs
var relics: Array = []  ## [RelicItem, Vector2i] pairs: the summon stones on the field
var max_summons := DeploymentManager.DEFAULT_SUMMON_LIMIT
## The scene a win leads to (a story scene); "" goes back to the barracks. A story battle that is lost is
## fought again from the start.
var on_win := ""


func populate(stage: BattleStage) -> void:
	var dm := stage.battle.deployment
	dm.deploy_king(stage.game.roster.king, king_cell)
	var captain := stage.game.roster.deployed_co_captain()
	if captain != null and captain_cell != TacticalGrid.NO_CELL:
		dm.deploy_co_captain(captain, captain_cell)
	for r in relics:
		dm.place_relic(r[0], r[1])
	for e in enemies:
		stage.add_enemy(e[0], e[1])
