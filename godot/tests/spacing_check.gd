extends Node
## Headless: in every battle map nobody can reach anybody on the first turn. For each opposing pair, the Manhattan distance
## between their starting cells is greater than the most either could cover in one turn: its Move stat plus 1 tile (weapon reach
## does not count). Summon stones count as player positions (a vessel appears
## there). A walking distance is never shorter than the Manhattan one, so this is the safe bound.
## godot --headless --path godot res://tests/spacing_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


## Most a unit can cover in one turn for this check (owner, Nov 2026): its Move plus 1 tile. Weapon reach no longer counts: the Rook,
## Bishop and Queen reach the whole map along a line, so only walking-and-one-step is kept apart.
func threat(data: UnitData) -> int:
	return data.stats.final_stat(StatModifier.Stat.MOVE, data.loadout) + 1


func check_battle(label: String, game: SaveGame, setup: BattleSetup) -> void:
	BattleStage.pending_game = game
	BattleStage.pending_setup = setup
	var b: BattleStage = load("res://scenes/battle.tscn").instantiate()
	b.enemy_delay = 1000.0  # an enemy that acts first waits, so the cells are the starting ones
	add_child(b)
	await get_tree().process_frame
	var dm := b.battle.deployment
	var mine: Array = []  # [cell, threat, name]
	for u in [dm.king, dm.co_captain]:
		if u != null:
			mine.append([u.cell, threat(u.data), u.data.display_name])
	var vessel_threat := 0
	for v in game.roster.vessels():
		vessel_threat = maxi(vessel_threat, threat(v))
	for cell in dm.props.keys():
		mine.append([cell, vessel_threat, "a vessel on the stone at %s" % cell])
	ok(not mine.is_empty() and not b.battle.enemies.is_empty(), "%s: there are two sides" % label)
	var worst := 999
	for m in mine:
		for e in b.battle.enemies:
			var dist := absi(m[0].x - e.cell.x) + absi(m[0].y - e.cell.y)
			var reach := maxi(int(m[1]), threat(e.data))
			worst = mini(worst, dist - reach)
			ok(dist > reach, "%s: %s %s and %s %s start %d apart, more than the %d one turn can cover" % [label, m[2], m[0], e.data.display_name, e.cell, dist, reach])
	print("%s: the closest pair is %d tile(s) beyond reach" % [label, worst])
	b.queue_free()
	await get_tree().process_frame


func _ready() -> void:
	SaveSystem.dir = "user://test_saves_spacing"
	await check_battle("hallway", FirstBattle.game(), FirstBattle.setup(HallwayCutscene.HALFWAY, HallwayCutscene.ENTRANCE))
	await check_battle("chamber", FirstBattle.chamber_game(FirstBattle.game()), FirstBattle.chamber_setup(ChamberCutscene.WALL_SPOT, ChamberCutscene.SQUIRES_TO))
	await check_battle("hallway replay", FirstBattle.chamber_game(FirstBattle.game()), WorldData.setup_for("hallway", 1))
	await check_battle("chamber replay", FirstBattle.chamber_game(FirstBattle.game()), WorldData.setup_for("chamber", 1))
	var with_captain := FirstBattle.chamber_game(FirstBattle.game())
	with_captain.roster.co_captains.append(SampleParty.make().co_captains[0])
	with_captain.roster.active_co_captain = with_captain.roster.co_captains[0]
	await check_battle("hallway replay with a Co-Captain", with_captain, WorldData.setup_for("hallway", 1))
	await check_battle("chamber replay with a Co-Captain", with_captain, WorldData.setup_for("chamber", 1))
	for n in range(1, 6):
		await check_battle("Riverford %d" % n, FirstBattle.chamber_game(FirstBattle.game()), Riverford.setup(n))
		await check_battle("Riverford %d with a Co-Captain" % n, with_captain, Riverford.setup(n))
	var ch3 := Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())))
	for n in range(1, 4):
		await check_battle("Crucible %d" % n, ch3, Crucible.setup(n))
	await check_battle("sample fight", SaveGame.new_game(), null)
	print("spacing checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)
