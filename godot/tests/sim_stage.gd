extends Node
## A stand-in for BattleStage so the playtest simulator (campaign_sim) runs the story battles' real ScenarioRules with no board or animation:
## the same calls, done at once (walking moves the unit, reinforcements are added next to their caller, banners are kept as text).

class Talk:
	var said: Array[String] = []
	func say(a = null, _b = null, _c = null, _d = null) -> void:
		said.append(str(a))
	func set_objective(_t) -> void:
		pass

var battle: BattleController
var setup: BattleSetup
var animate := false
var views := {}
var hud := Talk.new()
var bark := Talk.new()
var board := Node.new()


func walk(bu: BattleUnit, c: Vector2i) -> void:
	battle.move(bu, c)


func end_turn() -> void:
	if battle.current != null:
		battle.end_turn()


func _float(_bu, _text, _color = null, _big = false) -> void:
	pass


func _play_flees() -> void:
	pass


func spawn_enemy_near(data: EnemyData, c: Vector2i) -> BattleUnit:
	for r in 4:
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if absi(dx) + absi(dy) != r:
					continue
				var cell := c + Vector2i(dx, dy)
				if battle.grid.in_bounds(cell) and battle.grid.can_stand(cell) and not battle.grid.is_occupied(cell):
					var rng := RandomNumberGenerator.new()
					rng.randomize()
					EnemyStyles.assign(data, rng)
					return battle.add_enemy(data, cell)
	return null
