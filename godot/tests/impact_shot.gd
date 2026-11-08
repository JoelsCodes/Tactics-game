extends Node
## Screenshots of one blow landing, frame by frame, for comparing the combat feedback before and after:
## xvfb-run -a godot --path godot res://tests/impact_shot.tscn -- out=/tmp/dir [kind=sword|heavy|crit|magic]
## It works on the code before HitFeedback too (it only calls the stage's _show_hits), so the same script makes the "before" frames.
var out_dir := "/tmp"
var kind := "sword"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			out_dir = kv[1]
		if kv.size() == 2 and kv[0] == "kind":
			kind = kv[1]
	SaveSystem.dir = "user://test_saves_impact_shot"
	var rg := FirstBattle.chamber_game(FirstBattle.game())
	BattleStage.pending_game = rg
	BattleStage.pending_setup = Riverford.setup(1)
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 0.0
	add_child(s)
	s.battle.miss_chance = 0.0
	s.battle.crit_scale = 0.0  # exact damage: no random critical hits
	await get_tree().create_timer(1.5).timeout
	var att: BattleUnit = s.battle.current
	var foe: BattleUnit = null
	for u in s.views:
		if u.team != 0 and foe == null:
			foe = u
	foe.cell = att.cell + Vector2i(0, 1)
	s._place(foe)
	s.views[foe].face(Vector2(-1, 0))
	s.views[att].face(Vector2(1, 0))
	await get_tree().create_timer(0.8).timeout
	var h := ActionResult.Hit.new()
	h.target = foe
	h.tile = foe.cell
	h.amount = 34 if kind == "crit" else 12
	if "crit" in ActionResult.Hit.new():
		h.set("crit", kind == "crit")
	var r := ActionResult.new()
	r.ok = true
	r.action = BattleAction.attack()
	r.hits.append(h)
	var anim := "heavy" if kind in ["heavy", "crit"] else ("cast" if kind == "magic" else "attack")
	s.views[att].act(anim)
	s._show_hits(att, r, anim, foe.cell)
	for i in 9:
		await RenderingServer.frame_post_draw
		var path := "%s/%s_%02d.png" % [out_dir, kind, i]
		get_viewport().get_texture().get_image().save_png(path)
		await get_tree().create_timer(0.03).timeout
	get_tree().quit()
