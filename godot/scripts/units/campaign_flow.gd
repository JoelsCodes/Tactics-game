class_name CampaignFlow
extends RefCounted
## The hooks between a battle and the saved game. No UI.
##
##   before a battle:  prepare_deployment(game, deployment)  -> only the active squad can be summoned
##   after a battle:   finish_battle(game, battle, mission)  -> relics into the inventory, campaign
##                                                              stats updated, autosaved
##
## Skill levels and each vessel's tether_count / sever_count change during the battle itself, on the
## same roster resources that get saved, so the autosave already holds them.


## Limits summoning to the party's active squad.
static func prepare_deployment(game: SaveGame, deployment: DeploymentManager) -> void:
	deployment.restrict_to(game.roster.active_vessels)


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
