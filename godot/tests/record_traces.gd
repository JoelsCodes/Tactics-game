extends Node
## Re-records the regression battles in tests/fixtures/ from the Godot rules (AI vs AI, seeded).
## Run this only after a deliberate rules change that alters the battles:
##   godot --headless --path godot res://tests/record_traces.tscn
## Two finished battles per story mission, as trace_<stage>_<seed>.json.

const T = preload("res://tests/run_tests.gd")


func _ready() -> void:
	var dir := "res://tests/fixtures/"
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("trace_"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + f))
	for stage in 3:
		var kept := 0
		var seed := 1
		while kept < 2 and seed < 60:
			var t := record(stage, seed)
			if t.over != 0:
				kept += 1
				var file := FileAccess.open(dir + "trace_%d_%d.json" % [stage, seed], FileAccess.WRITE)
				file.store_string(JSON.stringify(t) + "\n")
				print("mission %d seed %d: %d turns, %s" % [stage + 1, seed, t.turns.size(), "win" if t.over == 1 else "loss"])
			seed += 1
	get_tree().quit()


func record(stage: int, seed: int) -> Dictionary:
	Rules.seed_lcg(seed)
	var party := Rules.new_party()
	for u in party:
		while u.lv < 1 + stage * 2:
			u.lv += 1
			Rules.grow(u, Data.JOBS[u.job].g)
	var B := Rules.mission_battle(stage, party, {"potion": 6, "phoenix": 2, "antidote": 2})
	var start := []
	for u in B.units:
		start.append([u.id, u.name, u.team, u.x, u.y, u.f, u.s.mhp, u.s.atk, u.s.spd, u.ct])
	var turns := []
	T.play(B, 400, func(rec):
		var p = rec.plan
		turns.append({"actor": rec.actor, "skip": rec.skip, "plan": null if p == null else {"x": p.x, "y": p.y, "id": p.id, "cx": p.cx, "cy": p.cy}, "units": rec.units})
		return true)
	Rules.unseed()
	return {"stage": stage, "seed": seed, "over": B.over, "start": start, "turns": turns}
