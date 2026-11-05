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
## A story scene (StoryScene key) played on the way to `on_win` the first time the battle is won: set by WorldData.start for a map's "post" scene.
var on_win_scene := ""
## Shows the summon tutorial (BattleTutorial) in this battle.
var tutorial := false
## The world map's map this battle is (see WorldData), its level (1-based), whether it is a replay of a cleared map (a copy of
## the game: nothing it earns is kept and it is not saved) and whether it was started from the world map (a lost one leaves
## to the world map).
var map_id := ""
var level := 1
var replay := false
var world := false
## Keeps the enemies' own weapon styles instead of rolling random ones (the tutorial fights: the first battle and the chamber).
var fixed_styles := false
## The objective line ("" keeps "Defeat all enemies").
var objective := ""
## Reinforcements: [{round, enemies: [[EnemyData, Vector2i], ...], line: [sheet, name, text], banner}]. They arrive when the battle's turn counter
## reaches `round` (BattleStage), on the given cells (or the nearest free ones).
var waves: Array = []
## Enemies that leave the fight instead of falling: display name -> percent of max HP at which they flee (BattleController.fleeing). Such a unit
## can never be knocked out; at the percent it goes (a smoke, a line) and counts as beaten.
var flee := {}
## What a fleeing enemy says: [sheet, name, text] (the stage shows it as it goes).
var flee_line: Array = []
## What the story says when the fight begins: [sheet, name, text] (a bark under the turn bar).
var opening_line: Array = []


func populate(stage: BattleStage) -> void:
	var dm := stage.battle.deployment
	dm.deploy_king(stage.game.roster.king, king_cell)
	var captain := stage.game.roster.deployed_co_captain()
	if captain != null and captain_cell != TacticalGrid.NO_CELL:
		dm.deploy_co_captain(captain, captain_cell)
	for r in relics:
		dm.place_relic(r[0], r[1])
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for e in enemies:
		if not fixed_styles:
			EnemyStyles.assign(e[0], rng)  # a new random style and stance for every enemy, every battle
		var bu := stage.add_enemy(e[0], e[1])
		if bu != null and flee.has(e[0].display_name):
			stage.battle.fleeing[bu] = int(flee[e[0].display_name])
