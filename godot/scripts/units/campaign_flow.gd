class_name CampaignFlow
extends RefCounted
## The hooks between a battle and the saved game. No UI.
##
##   before a battle:  nothing: BattleSetup.populate places the King and the chosen party
##   after a battle:   finish_battle(game, battle, mission)  -> relics into the inventory, campaign
##                                                              stats updated, autosaved
##
## Skill levels change during the battle itself, on the same roster resources that get saved, so the autosave already holds them.


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
