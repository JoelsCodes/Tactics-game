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
## "" (a smoke bomb and gone) or "yield" (the unit stays in view, says its line and sinks away without smoke: the King kneels).
var flee_style := ""
## What the story says when the fight begins: [sheet, name, text] (a bark under the turn bar).
var opening_line: Array = []
## Scenario rules (ScenarioRules): "carriers" {exit: [cells], allowed}, "clock" {every, spirits}, "king_drain" {pct, source, stop_below}, "king_must_live",
## "win_when_down" ("carrier", "device" or a unit's name), "event" {unit, below, banner, line}. Empty: the plain "defeat all enemies".
var rules := {}
## Vessels that fight for this battle only (chapter four's Gideon and Kaelen, before they join): summonable like any vessel, never added to the roster.
var temp_vessels: Array[VesselData] = []
## A Co-Captain's name that fights in this battle even if the player has stood her down (chapter five, Battle 4: Lyra is the only one who can stay). It changes nothing
## in the save: `stand_down` is left as the player set it.
var force_co_captain := ""
## The chosen party fights (owner, Nov 2026): a world-map battle puts the party picked in the Formation pop-up on the map beside the King (`party_cells`);
## nobody is summoned and no stones lie on the field. False for the first two story fights (hallway and chamber), which still teach the old summoning.
var party_mode := false


## Who fights beside the King in a party-mode battle: the remembered party, or only the named Co-Captain when the battle forces one (`force_co_captain`),
## then the battle's own temporary allies.
func party_for(game: SaveGame) -> Array[UnitData]:
	var out: Array[UnitData] = []
	if force_co_captain != "":
		for c in game.roster.co_captains:
			if c.display_name == force_co_captain:
				out.append(c)
	else:
		out.append_array(game.roster.party())
	for v in temp_vessels:
		if not out.any(func(u): return u.display_name == v.display_name):
			out.append(v)
	return out


static func threat_of(data: UnitData) -> int:
	return data.stats.final_stat(StatModifier.Stat.MOVE, data.loadout) + 1 if data.stats != null else 5


## Cells for `members` beside the King, nearest first: the map's Co-Captain cell for the first, then the free tiles around him. A tile that keeps
## every foe farther than one turn can cover (the first-turn spacing rule, `tests/spacing_check`) is taken before one that does not.
func party_cells(grid: TacticalGrid, members: Array) -> Array[Vector2i]:
	var taken := {king_cell: true}
	for e in enemies:
		taken[e[1]] = true
	var out: Array[Vector2i] = []
	for m in members:
		var need := threat_of(m)
		var best := TacticalGrid.NO_CELL
		var best_key := Vector3(9999, 9999, 9999)
		var candidates: Array[Vector2i] = []
		if captain_cell != TacticalGrid.NO_CELL and out.is_empty():
			candidates.append(captain_cell)
		for dx in range(-6, 7):
			for dy in range(-6, 7):
				candidates.append(king_cell + Vector2i(dx, dy))
		for c in candidates:
			if taken.has(c) or not grid.in_bounds(c) or not grid.can_stand(c):
				continue
			var bad := 0
			var gap := 999
			for e in enemies:
				var d := absi(c.x - e[1].x) + absi(c.y - e[1].y)
				gap = mini(gap, d)
				if d <= maxi(need, threat_of(e[0])):
					bad += 1
			var from_king := absi(c.x - king_cell.x) + absi(c.y - king_cell.y)
			var key := Vector3(bad, 0 if c == captain_cell and out.is_empty() else from_king, -gap)
			if key < best_key:
				best_key = key
				best = c
		if best == TacticalGrid.NO_CELL:
			break
		taken[best] = true
		out.append(best)
	return out


func populate(stage: BattleStage) -> void:
	var dm := stage.battle.deployment
	dm.deploy_king(stage.game.roster.king, king_cell)
	if party_mode:
		var members := party_for(stage.game)
		var cells := party_cells(stage.battle.grid, members)
		for i in cells.size():
			dm.deploy_party_member(members[i], cells[i])
	else:
		var captain := stage.game.roster.deployed_co_captain()
		if captain == null and force_co_captain != "":
			for c in stage.game.roster.co_captains:
				if c.display_name == force_co_captain:
					captain = c
		if captain != null and captain_cell != TacticalGrid.NO_CELL:
			dm.deploy_co_captain(captain, captain_cell)
	if not tutorial and not fixed_styles:  # the tutorial fights keep the stones they were given
		SkillCollection.freshen(relics, stage.game)  # some stones whose skill the party already has carry a new one instead
	for r in relics:
		dm.place_relic(r[0], r[1])
	if not party_mode:
		for v in temp_vessels:
			if not dm.owned_vessels.any(func(o): return o.display_name == v.display_name):
				dm.owned_vessels.append(v)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for e in enemies:
		if not fixed_styles:
			EnemyStyles.assign(e[0], rng)  # a new random style and stance for every enemy, every battle
		var bu := stage.add_enemy(e[0], e[1])
		if bu != null and flee.has(e[0].display_name):
			stage.battle.fleeing[bu] = int(flee[e[0].display_name])
