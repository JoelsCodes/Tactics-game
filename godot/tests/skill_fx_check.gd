extends Node
## Ailment marks, afterimages and skill timelines (Claude, Nov 2026, owner "do 1-3"): what a status looks like on a unit, the fading
## copies behind a dash, and the timed events a skill's feedback profile can list. All of it only shows things: no rule changes.
## godot --headless --path godot res://tests/skill_fx_check.tscn
var fails := 0
var count := 0
var s: BattleStage
var fb: HitFeedback


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s: got %s, want %s" % [what, a, b])


func _ready() -> void:
	SaveSystem.dir = "user://test_saves_skillfx"
	data()
	await stage_setup()
	await marks()
	await afterimages()
	await timeline()
	print("skill fx checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


## Every status has a drawing (or is deliberately plain), every glyph exists, and the profile data's timelines only use known events.
func data() -> void:
	for st in BattleUnit.NEGATIVE + [BattleUnit.HASTE, BattleUnit.REGEN, BattleUnit.WARD]:
		ok(StatusFx.LOOKS.has(st), "'%s' has a drawing" % st)
	for st in StatusFx.LOOKS:
		var l: Dictionary = StatusFx.LOOKS[st]
		ok(StatusFx.GLYPHS.has(l.glyph), "'%s' uses a known glyph (%s)" % [st, l.glyph])
		ok(["float", "orbit", "pulse", "fall", "rise_fast"].has(l.motion), "'%s' has a known motion" % st)
		ok(int(l.n) >= 1 and int(l.n) <= 4, "'%s' has a sane number of marks" % st)
		var tex := StatusFx.glyph(l.glyph)
		ok(tex != null and tex.get_width() >= 7, "glyph %s has a texture" % l.glyph)
	var d := HitFeedback.data()
	var lists := []
	for k in d.profiles:
		lists.append([k, d.profiles[k].get("timeline", [])])
	for k in d.overrides:
		lists.append([k, d.overrides[k].get("timeline", [])])
	for k in d.get("rank_timelines", {}):
		lists.append(["rank " + k, d.rank_timelines[k]])
	var total := 0
	for pair in lists:
		for e in pair[1]:
			total += 1
			ok(HitFeedback.EVENTS.has(String(e.get("do", ""))), "%s: event '%s' is known" % [pair[0], e.get("do", "")])
			ok(["start", "impact"].has(String(e.get("on", "start"))), "%s: anchor '%s' is start or impact" % [pair[0], e.get("on", "start")])
			ok(float(e.get("at", 0.0)) >= 0.0 and float(e.get("at", 0.0)) <= 2.0, "%s: time is within two seconds" % pair[0])
	ok(total >= 40, "the data has many timelines (%d)" % total)
	# every skill that has a timeline override exists, and it is a physical one (spells get theirs by rank)
	var names := {}
	for sk in SkillLibrary.all():
		names[sk.display_name] = sk
	for k in d.overrides:
		if d.overrides[k].has("timeline"):
			ok(names.has(k), "the skill '%s' with a timeline exists" % k)
	# a rank-S dressed spell gets the big treatment, a rank-E one none
	var big: SkillData = null
	var small: SkillData = null
	for sk in SkillLibrary.all():
		if sk.category != Proficiency.Category.PHYSICAL and SkillLook.of(sk) != "":
			if sk.rank == SkillData.Rank.S and big == null:
				big = sk
			if sk.rank == SkillData.Rank.E and small == null:
				small = sk
	ok(big != null and small != null, "there are a rank S and a rank E spell to compare")
	if big != null and small != null:
		var pb := HitFeedback.profile_for(BattleAction.use(big), "cast", false, 3)
		var ps := HitFeedback.profile_for(BattleAction.use(small), "cast", false, 3)
		var kinds := []
		for e in pb.get("timeline", []):
			kinds.append(e.do)
		ok(kinds.has("aura") and kinds.has("ring") and kinds.has("shake") and kinds.has("burst"), "a rank S spell gathers, rings, shakes and bursts (%s)" % [kinds])
		ok(not ps.has("timeline"), "a rank E spell has no timeline: it looks as before")


func stage_setup() -> void:
	s = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 100000.0
	s.animate = true
	add_child(s)
	await get_tree().create_timer(0.3).timeout
	fb = s.feedback


func marks() -> void:
	var bu: BattleUnit = s.battle.deployment.king
	var v: UnitView3D = s.views[bu]
	var fx := v.status_fx
	ok(fx != null and fx.get_parent() == v, "every unit view has its marks node")
	fx.set_statuses({})
	eq(fx.shown(), [], "no status, no marks")
	fx.set_statuses({"sleep": 2, "haste": 3})
	eq(fx.shown().size(), 2, "two statuses show two sets of marks")
	eq(fx.get_child_count(), 3 + 2, "sleep has 3 marks and haste 2")
	ok(v.trail_color.a > 0.0, "a hasted unit leaves a trail while it walks")
	fx.set_statuses({"sleep": 1})
	await get_tree().process_frame
	await get_tree().process_frame
	eq(fx.shown(), ["sleep"], "a status that ended loses its marks")
	ok(v.trail_color.a == 0.0, "...and haste stops the trail")
	eq(fx.get_child_count(), 3, "the removed marks are gone")
	fx.set_statuses({"nonsense": 4, "sleep": 0})
	eq(fx.shown(), [], "an unknown status and a zero-turn one show nothing")
	fx.set_statuses({"doom": 3})
	var lb: Label3D = null
	for c in fx.get_children():
		if c is Label3D:
			lb = c
	ok(lb != null and lb.text == "3", "doom shows the turns left")
	fx.set_statuses({"doom": 1})
	eq(lb.text, "1", "...and counts down")
	# a unit that is fading or fallen shows none
	fx.set_statuses({"stun": 2})
	v.set_alpha(0.4)
	await get_tree().process_frame
	ok(not fx.visible, "a fading unit shows no marks")
	v.set_alpha(1.0)
	await get_tree().process_frame
	ok(fx.visible, "...they return when it is solid")
	# the marks sit above the unit's head and ride its knock-back
	await get_tree().process_frame
	var any := false
	for c in fx.get_children():
		if c is Sprite3D and c.visible:
			any = true
			ok(c.position.y > v.figure_height(), "a mark is above the head (%.2f over %.2f)" % [c.position.y, v.figure_height()])
	ok(any, "some mark is on show")
	# the stage feeds the marks from the unit's own statuses
	bu.add_status(BattleUnit.BURN, 2)
	await get_tree().create_timer(0.3).timeout
	ok(fx.shown().has("burn"), "the stage shows a status the unit just got")
	bu.statuses.clear()
	await get_tree().create_timer(0.3).timeout
	eq(fx.shown(), [], "...and clears it when the status is gone")
	var heavy := {}
	for k in StatusFx.LOOKS:
		heavy[k] = 2
	fx.set_statuses(heavy)
	var marks_n := 0
	for c in fx.get_children():
		if c is Sprite3D:
			marks_n += 1
	ok(marks_n <= StatusFx.MAX_MARKS, "a unit with every status shows at most %d marks (%d)" % [StatusFx.MAX_MARKS, marks_n])
	fx.clear()
	eq(fx.shown(), [], "clear removes everything")


func _afterimages_of(v: UnitView3D) -> Array:
	var out := []
	for c in v.get_parent().get_children():
		if c.has_meta("afterimage_of") and c.get_meta("afterimage_of") == v:
			out.append(c)
	return out


func afterimages() -> void:
	var bu: BattleUnit = s.battle.deployment.king
	var v: UnitView3D = s.views[bu]
	eq(_afterimages_of(v).size(), 0, "no afterimages to begin with")
	v.afterimages(0.3, Color(1, 0.5, 0.2, 0.5))
	await get_tree().create_timer(0.25).timeout
	var live := _afterimages_of(v)
	ok(live.size() >= 3 and live.size() <= UnitView3D.TRAIL_MAX, "a short burst leaves a few afterimages (%d)" % live.size())
	for a in live:
		var tint: Color = (a.material_override as ShaderMaterial).get_shader_parameter("tint")
		ok(tint.a <= 0.5 + 0.001, "an afterimage is no stronger than asked")
		ok(a.get_parent() == v.get_parent(), "afterimages belong to the board, not the unit")
	await get_tree().create_timer(UnitView3D.TRAIL_LIFE + 0.4).timeout
	eq(_afterimages_of(v).size(), 0, "they all fade away and are freed")
	# the unit itself is untouched
	eq(v.global_position.distance_to(s.board.to_global(s.board.top_point(bu.cell.x, bu.cell.y))) < 0.05, true, "the unit is where it was")
	# a dash moves the picture, trails, and the blow keeps it forward; reset puts it back
	v.dash(Vector3(1, 0, 0), 0.5, 0.1)
	await get_tree().create_timer(0.2).timeout
	ok(absf(v.visual_shift().x - 0.5) < 0.02, "a dash carries the picture 0.5 forward (%.2f)" % v.visual_shift().x)
	ok(_afterimages_of(v).size() >= 2, "a dash leaves a trail")
	v.lunge(Vector3(1, 0, 0), 0.14, 0.0, 0.05, 0.2)
	await get_tree().create_timer(0.08).timeout
	ok(v.visual_shift().x >= 0.45, "a blow after a dash does not pull the unit back (%.2f)" % v.visual_shift().x)
	await get_tree().create_timer(0.35).timeout
	ok(v.visual_shift().length() < 0.001, "everything returns exactly to the tile")
	v.reset_motion()
	await get_tree().create_timer(0.5).timeout
	# many in a row never pile up
	for i in 6:
		v.afterimages(1.0)
	await get_tree().create_timer(0.7).timeout
	ok(_afterimages_of(v).size() <= UnitView3D.TRAIL_MAX, "afterimages are capped at %d" % UnitView3D.TRAIL_MAX)
	v.reset_motion()
	await get_tree().create_timer(1.0).timeout


func timeline() -> void:
	var bu: BattleUnit = s.battle.deployment.king
	var v: UnitView3D = s.views[bu]
	var foe: BattleUnit = null
	for u in s.views:
		if u.team != bu.team and u.on_field:
			foe = u
	ok(foe != null, "a foe to aim at")
	var far := foe.cell
	# a dash at time 0 starts at once, one at 0.25 s waits
	fb.run_timeline({"timeline": [{"on": "start", "do": "dash", "dist": 0.4, "secs": 0.05}]}, "start", bu, far)
	await get_tree().create_timer(0.15).timeout
	ok(v.visual_shift().length() > 0.05, "an event with no delay runs at once (%.2f)" % v.visual_shift().length())
	v.reset_motion()
	await get_tree().create_timer(0.1).timeout
	fb.run_timeline({"timeline": [{"on": "start", "at": 0.3, "do": "dash", "dist": 0.4, "secs": 0.05}]}, "start", bu, far)
	await get_tree().create_timer(0.15).timeout
	ok(v.visual_shift().length() < 0.001, "an event with a delay waits")
	await get_tree().create_timer(0.4).timeout
	ok(v.visual_shift().length() > 0.05, "...and then runs")
	v.reset_motion()
	await get_tree().create_timer(0.1).timeout
	# the other anchor is not run
	fb.run_timeline({"timeline": [{"on": "impact", "do": "dash", "dist": 0.4, "secs": 0.05}]}, "start", bu, far)
	await get_tree().create_timer(0.15).timeout
	ok(v.visual_shift().length() < 0.001, "an impact event does not run at the start")
	fb.run_timeline({"timeline": [{"on": "impact", "do": "dash", "dist": 0.4, "secs": 0.05}]}, "impact", bu, far)
	await get_tree().create_timer(0.15).timeout
	ok(v.visual_shift().length() > 0.05, "...it runs at the impact")
	v.reset_motion()
	await get_tree().create_timer(0.1).timeout
	# a dash never goes into the target: next to it there is no room
	var next := bu.cell + Vector2i(1, 0)
	fb.run_timeline({"timeline": [{"on": "start", "do": "dash", "dist": 0.9, "secs": 0.05}]}, "start", bu, next)
	await get_tree().create_timer(0.15).timeout
	ok(v.visual_shift().length() <= 1.0 - HitFeedback.DASH_STOP + 0.02, "a dash at an adjacent target barely moves (%.2f)" % v.visual_shift().length())
	var three := bu.cell + Vector2i(3, 0)
	fb.run_timeline({"timeline": [{"on": "start", "do": "dash", "dist": 5.0, "secs": 0.05}]}, "start", bu, three)
	await get_tree().create_timer(0.15).timeout
	ok(v.visual_shift().length() <= 3.0 - HitFeedback.DASH_STOP + 0.05, "a long dash stops %.1f short of its target (%.2f)" % [HitFeedback.DASH_STOP, v.visual_shift().length()])
	v.reset_motion()
	await get_tree().create_timer(0.1).timeout
	# cleanup drops events still waiting; unknown events do nothing
	fb.run_timeline({"timeline": [{"on": "start", "at": 0.2, "do": "dash", "dist": 0.4, "secs": 0.05}]}, "start", bu, far)
	fb.cleanup()
	await get_tree().create_timer(0.4).timeout
	ok(v.visual_shift().length() < 0.001, "cleanup cancels events that were waiting")
	fb.run_timeline({"timeline": [{"on": "start", "do": "teleport"}, {"on": "start", "do": "sfx", "name": "nothing"}, {"on": "start", "do": "ring"}]}, "start", bu, far)
	await get_tree().process_frame
	ok(true, "unknown events, missing sounds and a ring with no look are ignored")
	# the profile of a dagger skill carries the dash, an ordinary sword skill none
	var dag := {}
	for e in HitFeedback.data().profiles.dagger.get("timeline", []):
		dag = e
	eq(dag.get("do", ""), "dash", "the dagger profile dashes")
	ok(not HitFeedback.data().profiles.sword.has("timeline"), "the sword profile has no timeline: it looks as before")
