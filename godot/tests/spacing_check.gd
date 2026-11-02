extends Node
## Headless: in every battle map nobody can reach anybody on the first turn. For each opposing pair, the Manhattan distance
## between their starting cells is greater than the most either could cover in one turn: its Move stat plus the farthest
## reach of its weapon style (the footprints come from the style). Summon stones count as player positions (a vessel appears
## there). A walking distance is never shorter than the Manhattan one, so this is the safe bound.
## godot --headless --path godot res://tests/spacing_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


## Most a unit can cover in one turn, as a Manhattan distance: its Move plus its weapon style's farthest reach.
func threat(data: UnitData) -> int:
	var mv := data.stats.final_stat(StatModifier.Stat.MOVE, data.loadout)
	var far := 0
	var style: WeaponStyle = data.loadout.weapon_style if data.loadout != null and data.loadout.weapon_style != null else WeaponStyle.new()
	for o in style.offsets():
		far = maxi(far, absi(o.x) + absi(o.y))
	return mv + far


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
	await check_battle("sample fight", SaveGame.new_game(), null)
	print("spacing checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)
