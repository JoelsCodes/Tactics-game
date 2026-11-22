class_name CampaignFlow
extends RefCounted
## The hooks between a battle and the saved game. No UI.
##
##   before a battle:  deploy_leaders(game, deployment, ...)        -> the King and the active Co-Captain (a battle's party is placed by BattleSetup.populate)
##   after a battle:   finish_battle(game, battle, mission)  -> relics into the inventory, campaign
##                                                              stats updated, autosaved
##
## Skill levels and each vessel's tether_count / sever_count change during the battle itself, on the
## same roster resources that get saved, so the autosave already holds them.


## Puts the leaders on the map: the King (on every mission) and the Co-Captain chosen in the barracks.
## Returns [king unit, co-captain unit or null].
static func deploy_leaders(game: SaveGame, deployment: DeploymentManager, king_cell: Vector2i, captain_cell: Vector2i) -> Array:
	var captain := game.roster.deployed_co_captain()
	return [deployment.deploy_king(game.roster.king, king_cell),
		deployment.deploy_co_captain(captain, captain_cell) if captain != null else null]


## Adds a finished battle's summary to the campaign. A mission is completed only by a win.
static func record_battle(game: SaveGame, summary: BattleSummary, mission_id: StringName = &"") -> void:
	game.campaign.record_battle(summary, mission_id)


## Ends the battle (BattleController.finish: relics home go into the roster's inventory), records it
## and autosaves. Returns the summary for the results screen.
static func finish_battle(game: SaveGame, battle: BattleController, mission_id: StringName = &"") -> BattleSummary:
	var summary := battle.finish(game.roster)
	record_battle(game, summary, mission_id)
	SaveSystem.save_slot(SaveSystem.AUTOSAVE, game)
	return summary
