class_name ResultScreen
extends Control
## The end of a battle, played as a short show instead of a text box:
##
##   Victory   the screen dims, light rays turn behind the panel, the title slams in, the grade (S to D, BattleRating) is stamped,
##             the feats that earned it tick in one by one with their points, then every unit that fought gets a row: portrait,
##             name, level, an XP bar that fills from where it was (rolling over on a level up, with a LEVEL UP flash and what the
##             level gave), what it did in the fight, and an MVP badge for the one that did the most. Rewards (bonus XP, relics
##             brought home, skills learned, sword styles found, a new best grade) come last, then the Continue button.
##   Defeat    the screen darkens, the title fades in, one line says nothing was lost, and the button.
##
## A click or a key skips to the finished screen. With `animate` off (tests) everything is in its final state at once. It only
## shows a BattleSummary: nothing here changes the game.

signal continue_pressed
signal finished  ## the show is over (or was skipped): the button is on screen

const PANEL_WIDTH := 1120
const MAX_SKILL_BARS := 4  ## skills listed under one unit's row
const GRADE_COLORS := {"S": Color("#ffe27a"), "A": Color("#ff9a52"), "B": Color("#7fc4ff"), "C": Color("#8fdc9a"), "D": Color("#b7b7c2")}

var animate := true
var panel: PanelContainer
var title: Label
var subtitle: Label
var plain: Label  ## the summary as plain text (hidden; kept for tools and tests that read it)
var button: Button
var emblem: Control
var feat_box: VBoxContainer
var score_label: Label
var rows_box: VBoxContainer
var rewards_box: HFlowContainer
var top_row: HBoxContainer
var done := false
var _dim: ColorRect
var _rays: Control
var _disc: Control
var _grade := ""
var _skip := false
var _t := 0.0
var _rows: Array[Dictionary] = []
var _last_tick := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.01, 0.01, 0.03, 0.0)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_rays = Control.new()
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.modulate.a = 0.0
	_rays.draw.connect(_draw_rays)
	add_child(_rays)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HudStyle.slim_panel(44, 30))
	panel.custom_minimum_size = Vector2(720, 0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	title = Label.new()
	title.theme_type_variation = &"HeadingLabel"
	title.add_theme_color_override("font_color", HudStyle.CAPTION)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0, 0.9))
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	subtitle = Label.new()
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", HudStyle.MUTED)
	subtitle.add_theme_font_size_override("font_size", 20)
	col.add_child(subtitle)
	top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 36)
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(top_row)
	emblem = Control.new()
	emblem.custom_minimum_size = Vector2(190, 190)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(emblem)
	_disc = Control.new()
	_disc.size = Vector2(190, 190)
	_disc.pivot_offset = Vector2(95, 95)
	_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disc.draw.connect(_draw_emblem)
	_disc.visible = false
	emblem.add_child(_disc)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 5)
	right.custom_minimum_size.x = 560
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(right)
	feat_box = VBoxContainer.new()
	feat_box.add_theme_constant_override("separation", 4)
	right.add_child(feat_box)
	score_label = Label.new()
	score_label.add_theme_font_override("font", HudStyle.font(true))
	score_label.add_theme_font_size_override("font_size", 22)
	score_label.add_theme_color_override("font_color", Color("#f0f6ff"))
	score_label.modulate.a = 0.0
	right.add_child(score_label)
	rows_box = VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 6)
	col.add_child(rows_box)
	rewards_box = HFlowContainer.new()
	rewards_box.add_theme_constant_override("h_separation", 10)
	rewards_box.add_theme_constant_override("v_separation", 8)
	rewards_box.alignment = FlowContainer.ALIGNMENT_CENTER
	col.add_child(rewards_box)
	plain = Label.new()
	plain.visible = false
	col.add_child(plain)
	button = Button.new()
	button.text = "Return to the barracks"
	button.custom_minimum_size = Vector2(320, 58)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func():
		CombatAudio.play(self, "ui_confirm")
		continue_pressed.emit())
	col.add_child(button)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _rays.modulate.a > 0.0:
		_rays.queue_redraw()
	if _disc.visible and _grade == "S":
		_disc.queue_redraw()


func _input(e: InputEvent) -> void:
	if not visible or done or not animate:
		return
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventKey and e.pressed and not e.echo) or (e is InputEventScreenTouch and e.pressed):
		_skip = true


## Shows the summary. Returns at once; the show runs on its own (`finished` when it is over).
func show_summary(summary: BattleSummary) -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP  # the board under it is done with
	done = false
	_skip = false
	var won := summary.outcome == BattleController.Outcome.WON
	title.text = {BattleController.Outcome.WON: "Victory", BattleController.Outcome.LOST: "Defeat"}.get(summary.outcome, "Battle over")
	title.add_theme_color_override("font_color", HudStyle.CAPTION if won else Color("#e0604f"))
	plain.text = _plain_text(summary)
	var rating := summary.rating if won else null
	_grade = rating.grade if rating != null else ""
	top_row.visible = rating != null
	rows_box.visible = won
	panel.custom_minimum_size.x = PANEL_WIDTH if won else 720
	for c in feat_box.get_children() + rows_box.get_children() + rewards_box.get_children():
		c.queue_free()
	_rows.clear()
	if won:
		subtitle.text = "%d %s defeated  ·  Round %d" % [summary.enemies_defeated, "enemy" if summary.enemies_defeated == 1 else "enemies", rating.rounds if rating != null else maxi(1, summary.turns)]
		_build_rows(summary)
	else:
		subtitle.text = "The party has fallen. Nothing was lost: everything is as it was before the battle." if summary.outcome == BattleController.Outcome.LOST else ""
	_play(summary, rating, won)


# ---------- the show ----------

func _wait(secs: float) -> void:
	if not animate or _skip or secs <= 0.0 or not is_inside_tree():
		return
	var left := secs
	while left > 0.0 and not _skip and is_inside_tree():
		await get_tree().process_frame
		left -= get_process_delta_time()


func _sfx(event: String, pitch := 1.0, gain := 0.0) -> void:
	if animate and not _skip:
		CombatAudio.play(self, event, pitch, gain)


func _play(summary: BattleSummary, rating: BattleRating, won: bool) -> void:
	button.modulate.a = 0.0
	button.disabled = true
	_dim.color.a = 0.0
	_rays.modulate.a = 0.0
	if animate:
		create_tween().tween_property(_dim, "color:a", 0.5 if won else 0.72, 0.5 if won else 1.2)
		panel.modulate.a = 0.0
		panel.pivot_offset = panel.size / 2.0
		create_tween().tween_property(panel, "modulate:a", 1.0, 0.25)
		title.pivot_offset = title.size / 2.0
		title.scale = Vector2(2.4, 2.4) if won else Vector2.ONE
		if won:
			var tw := create_tween()
			tw.tween_property(title, "scale", Vector2.ONE, 0.26).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			create_tween().tween_property(_rays, "modulate:a", 1.0, 1.2)
		await _wait(0.7 if won else 1.4)
	if rating != null:
		for f in rating.feats:
			_add_feat(f)
			_sfx("feat_pop", 1.0 + 0.05 * feat_box.get_child_count())
			await _wait(0.22)
		await _wait(0.15)
		_stamp(rating)
		await _wait(0.75)
	if won:
		for i in _rows.size():
			_fill_row(_rows[i], i)
		var longest := 0.0
		for r in _rows:
			longest = maxf(longest, float(r.secs))
		await _wait(longest + 0.12 * _rows.size() + 0.2)
		for chip in _reward_chips(summary, rating):
			rewards_box.add_child(chip)
			_pop(chip)
			_sfx("reward", 1.0, -4.0)
			await _wait(0.2)
	_finish(summary, rating, won)


## Everything in its final state (the end of the show, a skip, or no animation at all).
func _finish(summary: BattleSummary, rating: BattleRating, won: bool) -> void:
	_dim.color.a = 0.5 if won else 0.72
	_rays.modulate.a = 1.0 if won else 0.0
	panel.modulate.a = 1.0
	title.scale = Vector2.ONE
	if rating != null:
		if feat_box.get_child_count() < rating.feats.size():
			for i in range(feat_box.get_child_count(), rating.feats.size()):
				_add_feat(rating.feats[i])
		for c in feat_box.get_children():
			c.modulate.a = 1.0
		_disc.visible = true
		_disc.scale = Vector2.ONE
		_disc.rotation = 0.0
		_disc.queue_redraw()
		score_label.text = _score_text(rating)
		score_label.modulate.a = 1.0
	for r in _rows:
		_settle_row(r)
	if won and rewards_box.get_child_count() == 0:
		for chip in _reward_chips(summary, rating):
			rewards_box.add_child(chip)
	for c in rewards_box.get_children():
		(c as Control).scale = Vector2.ONE
		c.modulate.a = 1.0
	button.disabled = false
	if animate:
		create_tween().tween_property(button, "modulate:a", 1.0, 0.25)
	else:
		button.modulate.a = 1.0
	done = true
	finished.emit()


func _pop(c: Control) -> void:
	if not animate or _skip:
		return
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.12)
	await get_tree().process_frame
	if is_instance_valid(c):
		c.pivot_offset = c.size / 2.0
		c.scale = Vector2(1.3, 1.3)
		c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


# ---------- grade and feats ----------

func _add_feat(f: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var mark := Label.new()
	mark.text = "◆"
	mark.add_theme_color_override("font_color", HudStyle.ICE)
	mark.add_theme_font_size_override("font_size", 16)
	row.add_child(mark)
	var name := Label.new()
	name.text = String(f.name)
	name.add_theme_font_override("font", HudStyle.font(true, true))
	name.add_theme_font_size_override("font_size", 21)
	name.add_theme_color_override("font_color", Color("#f0f6ff"))
	name.custom_minimum_size.x = 190
	row.add_child(name)
	var detail := Label.new()
	detail.text = String(f.detail)
	detail.add_theme_font_size_override("font_size", 17)
	detail.add_theme_color_override("font_color", HudStyle.MUTED)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.clip_text = true
	row.add_child(detail)
	var pts := Label.new()
	pts.text = "+%d" % int(f.points)
	pts.add_theme_font_override("font", HudStyle.font(true))
	pts.add_theme_font_size_override("font_size", 21)
	pts.add_theme_color_override("font_color", HudStyle.GOLD)
	row.add_child(pts)
	feat_box.add_child(row)
	if animate and not _skip:
		row.modulate.a = 0.0
		row.create_tween().tween_property(row, "modulate:a", 1.0, 0.15)


func _score_text(rating: BattleRating) -> String:
	return "Score %d" % rating.score + ("   ·   Bonus XP +%d%%" % rating.bonus_percent if rating.bonus_percent > 0 else "")


func _stamp(rating: BattleRating) -> void:
	score_label.text = _score_text(rating)
	_disc.visible = true
	_disc.queue_redraw()
	if not animate or _skip:
		score_label.modulate.a = 1.0
		return
	_disc.scale = Vector2(3.2, 3.2)
	_disc.rotation = -0.5
	_disc.modulate.a = 0.0
	var tw := _disc.create_tween().set_parallel(true)
	tw.tween_property(_disc, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_disc, "rotation", 0.0, 0.2)
	tw.tween_property(_disc, "modulate:a", 1.0, 0.1)
	await tw.finished
	if not is_inside_tree():
		return
	_sfx("grade_stamp", 1.0 if rating.grade in ["S", "A"] else 0.85)
	var shake := panel.create_tween()  # the panel takes the stamp
	var home := panel.position
	for i in 5:
		shake.tween_property(panel, "position", home + Vector2(randf_range(-7, 7), randf_range(-7, 7)) * (1.0 - i / 5.0), 0.03)
	shake.tween_property(panel, "position", home, 0.03)
	var bump := _disc.create_tween()
	bump.tween_property(_disc, "scale", Vector2(1.14, 1.14), 0.06)
	bump.tween_property(_disc, "scale", Vector2.ONE, 0.14).set_ease(Tween.EASE_OUT)
	create_tween().tween_property(score_label, "modulate:a", 1.0, 0.25)


func _draw_emblem() -> void:
	var c := Vector2(95, 95)
	var col: Color = GRADE_COLORS.get(_grade, Color.WHITE)
	_disc.draw_circle(c, 92, Color(0, 0, 0, 0.55))
	_disc.draw_circle(c, 84, Color(0.07, 0.06, 0.1, 0.96))
	_disc.draw_arc(c, 88, 0, TAU, 72, HudStyle.ICE, 5.0, true)
	_disc.draw_arc(c, 76, 0, TAU, 72, Color(col, 0.7), 2.0, true)
	for i in 12:  # notches round the rim
		var a := TAU * i / 12.0
		_disc.draw_line(c + Vector2.from_angle(a) * 79, c + Vector2.from_angle(a) * 84, Color(HudStyle.ICE, 0.8), 2.0, true)
	if _grade == "S":  # a slow shine sweeping round the ring
		var a0 := fmod(_t * 1.6, TAU)
		_disc.draw_arc(c, 88, a0, a0 + 0.9, 16, Color(1, 1, 1, 0.9), 5.0, true)
	var f := HudStyle.font(true, true)
	var fs := 118
	var w := f.get_string_size(_grade, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(c.x - w / 2.0, c.y + fs * 0.36)
	_disc.draw_string_outline(f, at, _grade, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0.12, 0.05, 0.0, 0.95))
	_disc.draw_string(f, at, _grade, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	var gf := HudStyle.font(false, true)
	var gw := gf.get_string_size("GRADE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_disc.draw_string(gf, Vector2(c.x - gw / 2.0, c.y + 66), "GRADE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#cfe6ff"))


func _draw_rays() -> void:
	var view := get_viewport_rect().size
	var c := view / 2.0
	var n := 14
	var reach := view.length()
	for i in n:
		var a := TAU * i / n + _t * 0.12
		var wide := TAU / n * 0.42
		var pts := PackedVector2Array([c, c + Vector2.from_angle(a - wide / 2.0) * reach, c + Vector2.from_angle(a + wide / 2.0) * reach])
		_rays.draw_colored_polygon(pts, Color(1.0, 0.86, 0.5, 0.055))


# ---------- the party's rows ----------

func _build_rows(summary: BattleSummary) -> void:
	var units: Array[BattleUnit] = []
	for bu in summary.lines:
		if bu.data.role() != UnitData.Role.ENEMY and bu.team == 0 and (summary.lines[bu].turns > 0 or summary.participants.has(bu)):
			units.append(bu)
	var small := units.size() > 4
	var mvp: BattleUnit = summary.rating.mvp if summary.rating != null else null
	for bu in units:
		var l: BattleSummary.UnitLine = summary.lines[bu]
		var before: Array = summary.exp_before.get(bu, [bu.data.stats.level if bu.data.stats != null else 1, bu.data.stats.exp if bu.data.stats != null else 0])
		var h := 48 if small else 60
		var holder := PanelContainer.new()
		holder.add_theme_stylebox_override("panel", HudStyle.box(Color("#0b1118", 0.7), Color("#3a4a5e"), 4, 1, 12, 5))
		rows_box.add_child(holder)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 4)
		holder.add_child(stack)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		stack.add_child(row)
		var skill_bars: Array = _skill_line(stack, summary, bu)
		var frame := PanelContainer.new()
		frame.custom_minimum_size = Vector2(h, h)
		frame.add_theme_stylebox_override("panel", HudStyle.portrait_box(HudStyle.team_color(bu), 4))
		row.add_child(frame)
		var pic := TextureRect.new()
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.texture = UnitLook.portrait(UnitLook.sheet_for(bu.data))
		pic.modulate = Color(0.55, 0.55, 0.55) if l.knocked_out else Color.WHITE
		frame.add_child(pic)
		var who := VBoxContainer.new()
		who.custom_minimum_size.x = 210
		who.add_theme_constant_override("separation", 0)
		who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(who)
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 8)
		who.add_child(name_row)
		var name := Label.new()
		name.text = bu.data.display_name
		name.add_theme_font_override("font", HudStyle.font(true, true))
		name.add_theme_font_size_override("font_size", 21)
		name.add_theme_color_override("font_color", Color("#f0f6ff"))
		name_row.add_child(name)
		if bu == mvp and units.size() > 1:
			var badge := Label.new()
			badge.text = " MVP "
			badge.add_theme_font_override("font", HudStyle.font(true))
			badge.add_theme_font_size_override("font_size", 14)
			badge.add_theme_color_override("font_color", HudStyle.INK)
			badge.add_theme_stylebox_override("normal", HudStyle.box(HudStyle.GOLD, Color("#fff3d0"), 4, 1, 4, 0))
			badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			name_row.add_child(badge)
		var lv := Label.new()
		lv.add_theme_font_size_override("font_size", 16)
		lv.add_theme_color_override("font_color", HudStyle.MUTED)
		who.add_child(lv)
		var xp := VBoxContainer.new()
		xp.custom_minimum_size.x = 330
		xp.add_theme_constant_override("separation", 2)
		xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(xp)
		var xp_head := HBoxContainer.new()
		xp.add_child(xp_head)
		var gained := Label.new()
		gained.add_theme_font_override("font", HudStyle.font(true))
		gained.add_theme_font_size_override("font_size", 17)
		gained.add_theme_color_override("font_color", HudStyle.XP)
		gained.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		xp_head.add_child(gained)
		var count := Label.new()
		count.add_theme_font_size_override("font_size", 15)
		count.add_theme_color_override("font_color", HudStyle.MUTED)
		xp_head.add_child(count)
		var bar := HudStyle.bar(HudStyle.XP, 12)
		bar.max_value = 1.0
		xp.add_child(bar)
		var did := Label.new()
		did.add_theme_font_size_override("font_size", 16)
		did.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		did.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		did.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var parts: Array[String] = ["Dealt %d" % l.damage_dealt, "Taken %d" % l.damage_taken]
		if l.healing_done > 0:
			parts.append("Healed %d" % l.healing_done)
		if l.knockouts > 0:
			parts.append("KO %d" % l.knockouts)
		if l.knocked_out:
			parts.append("fell")
		did.text = "  ·  ".join(parts)
		row.add_child(did)
		var r := {"unit": bu, "line": l, "lv": lv, "gained": gained, "count": count, "bar": bar, "did": did, "holder": holder, "name": name,
			"level": int(before[0]), "exp": int(before[1]), "gain": l.exp_gained, "base": did.text, "skills": skill_bars,
			"secs": clampf(0.5 + l.exp_gained / 160.0, 0.5, 2.2) if l.exp_gained > 0 else 0.0}
		_show_xp(r, r.level, r.exp, 0)
		if animate:
			holder.modulate.a = 0.0
		_rows.append(r)


func _show_xp(r: Dictionary, level: int, e: int, counted: int) -> void:
	var need := ExperienceCurve.to_next(level)
	(r.lv as Label).text = "Lv %d" % level
	(r.bar as ProgressBar).value = float(e) / need if need > 0 else 1.0
	(r.count as Label).text = "%d / %d" % [e, need] if need > 0 else "MAX"
	(r.gained as Label).text = "+%d XP" % counted if int(r.gain) > 0 else "XP"


## Fills one row's XP bar from where it was to where it is now, level by level.
func _fill_row(r: Dictionary, index: int) -> void:
	await _wait(0.12 * index)
	var holder: Control = r.holder
	if animate and not _skip and is_instance_valid(holder):
		holder.create_tween().tween_property(holder, "modulate:a", 1.0, 0.15)
	for sb in r.skills:  # the skill bars fill alongside the XP bar
		if animate and not _skip and is_instance_valid(sb.bar):
			(sb.bar as ProgressBar).value = float(sb.from)
			(sb.bar as ProgressBar).create_tween().tween_property(sb.bar, "value", float(sb.to), 0.7).set_ease(Tween.EASE_OUT).set_delay(0.15)
	var gain := int(r.gain)
	if gain <= 0 or not animate:
		return
	var level := int(r.level)
	var e := int(r.exp)
	var counted := 0
	var per_sec := float(gain) / maxf(0.01, float(r.secs))
	var carry := 0.0
	while counted < gain and not _skip and is_inside_tree():
		await get_tree().process_frame
		carry += per_sec * get_process_delta_time()
		var step := mini(int(carry), gain - counted)
		if step <= 0:
			continue
		carry -= step
		var need := ExperienceCurve.to_next(level)
		if need <= 0:
			counted = gain
			break
		step = mini(step, need - e)
		e += step
		counted += step
		if e >= need:
			e = 0
			level += 1
			_level_flash(r, level)
		_show_xp(r, level, e, counted)
		if _t - _last_tick > 0.05:
			_last_tick = _t
			_sfx("xp_tick", 0.9 + 0.5 * float(counted) / gain, -6.0)


func _level_flash(r: Dictionary, level: int) -> void:
	_sfx("level_up")
	var holder: PanelContainer = r.holder
	if not is_instance_valid(holder):
		return
	holder.add_theme_stylebox_override("panel", HudStyle.box(Color(0.2, 0.15, 0.03, 0.75), HudStyle.GOLD, 6, 2, 12, 5))
	holder.modulate = Color(2.2, 2.0, 1.5)
	holder.create_tween().tween_property(holder, "modulate", Color.WHITE, 0.45)
	(r.did as Label).text = _level_text(r)
	(r.did as Label).add_theme_color_override("font_color", HudStyle.GOLD)


func _level_text(r: Dictionary) -> String:
	var l: BattleSummary.UnitLine = r.line
	if l.level_ups.is_empty():
		return String(r.base)
	var first: LevelUp = l.level_ups[0]
	var last: LevelUp = l.level_ups[-1]
	var parts: Array[String] = ["LEVEL UP!  Lv %d → %d" % [first.from_level, last.to_level]]
	if last.hp_after > first.hp_before:
		parts.append("HP +%d" % (last.hp_after - first.hp_before))
	if last.sp_after > first.sp_before:
		parts.append("SP +%d" % (last.sp_after - first.sp_before))
	var gains := {}
	for up in l.level_ups:
		for st in up.gains:
			if st != StatModifier.Stat.MAX_HP:
				gains[st] = int(gains.get(st, 0)) + int(up.gains[st])
	for st in gains:
		parts.append("%s +%d" % [StatModifier.stat_name(st), gains[st]])
	return "  ".join(parts)


## A row as it stands when the show is over.
func _settle_row(r: Dictionary) -> void:
	var holder: PanelContainer = r.holder
	if not is_instance_valid(holder):
		return
	holder.modulate = Color.WHITE
	for sb in r.skills:
		if is_instance_valid(sb.bar):
			(sb.bar as ProgressBar).value = float(sb.to)
	var l: BattleSummary.UnitLine = r.line
	var stats: CharacterStats = (r.unit as BattleUnit).data.stats
	var level := l.level_after if l.level_after > 0 else int(r.level)
	_show_xp(r, level, stats.exp if stats != null and int(r.gain) > 0 else int(r.exp), int(r.gain))
	if not l.level_ups.is_empty():
		holder.add_theme_stylebox_override("panel", HudStyle.box(Color(0.2, 0.15, 0.03, 0.75), HudStyle.GOLD, 6, 2, 12, 5))
		(r.did as Label).text = _level_text(r)
		(r.did as Label).add_theme_color_override("font_color", HudStyle.GOLD)


## Under a unit's row: the skills it trained this battle, each with its level and a small bar (BattleSummary.skill_progress).
## A skill that reached level 1 says LEARNED; one that gained levels shows from which to which. Returns [{bar, from, to}] for the show.
func _skill_line(stack: VBoxContainer, summary: BattleSummary, bu: BattleUnit) -> Array:
	var out := []
	var trained: Dictionary = summary.skill_progress.get(bu, {})
	if trained.is_empty():
		return out
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 18)
	flow.add_theme_constant_override("v_separation", 2)
	stack.add_child(flow)
	var head := Label.new()
	head.text = "SKILLS"
	head.add_theme_font_override("font", HudStyle.font(true, true))
	head.add_theme_font_size_override("font_size", 12)
	head.add_theme_color_override("font_color", HudStyle.MUTED)
	flow.add_child(head)
	var shown := 0
	for skill in trained:
		if shown >= MAX_SKILL_BARS:
			var more := Label.new()
			more.text = "+%d more" % (trained.size() - shown)
			more.add_theme_font_size_override("font_size", 13)
			more.add_theme_color_override("font_color", HudStyle.MUTED)
			flow.add_child(more)
			break
		shown += 1
		var p: Array = trained[skill]
		var learned := int(p[0]) == 0 and int(p[2]) >= 1
		var levels := int(p[2]) - int(p[0])
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 6)
		flow.add_child(item)
		var name := Label.new()
		name.text = (skill as SkillData).display_name
		name.add_theme_font_override("font", HudStyle.font(true))
		name.add_theme_font_size_override("font_size", 14)
		name.add_theme_color_override("font_color", SkillCollection.rank_color(skill).lightened(0.3))
		item.add_child(name)
		var bar := HudStyle.slim_bar(HudStyle.XP if int(p[2]) >= 1 else Color("#7fe6ff"), 6)
		bar.max_value = 1.0
		bar.custom_minimum_size.x = 90
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var to := float(p[3]) / TacticalMath.PROGRESS_PER_LEVEL
		bar.value = to
		item.add_child(bar)
		var lv := Label.new()
		lv.text = "LEARNED  Lv %d" % int(p[2]) if learned else ("Lv %d → %d" % [int(p[0]), int(p[2])] if levels > 0 else "Lv %d  +%d" % [int(p[2]), int(p[3]) - int(p[1])])
		lv.add_theme_font_override("font", HudStyle.font(learned or levels > 0))
		lv.add_theme_font_size_override("font_size", 13)
		lv.add_theme_color_override("font_color", HudStyle.GOLD if learned or levels > 0 else HudStyle.MUTED)
		item.add_child(lv)
		out.append({"bar": bar, "from": 0.0 if levels > 0 else float(p[1]) / TacticalMath.PROGRESS_PER_LEVEL, "to": to})
	return out


# ---------- rewards ----------

func _chip(text: String, col := HudStyle.ICE) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", HudStyle.box(Color(col, 0.14), Color(col, 0.8), 14, 1, 14, 5))
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", HudStyle.font(true))
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", col.lightened(0.35))
	p.add_child(l)
	return p


func _reward_chips(summary: BattleSummary, rating: BattleRating) -> Array[Control]:
	var out: Array[Control] = []
	if summary.exp_each > 0:
		out.append(_chip("XP %d  ·  %d each" % [summary.exp_pool, summary.exp_each]))
	if summary.exp_bonus > 0 and rating != null:
		out.append(_chip("Grade %s bonus  +%d XP" % [rating.grade, summary.exp_bonus], GRADE_COLORS.get(rating.grade, HudStyle.ICE)))
	if summary.new_best and rating != null:
		out.append(_chip("New best grade: %s" % rating.grade, GRADE_COLORS.get(rating.grade, HudStyle.ICE)))
	for r in summary.relics_secured:
		out.append(_chip("Relic home: %s" % r.display_name, HudStyle.VESSEL))
	for s in summary.skills_learned:
		out.append(_chip("Learned: %s" % s.display_name, HudStyle.HP))
	for f in summary.styles_found:
		var st = PartyRoster.style_from_key(f.key)
		if st != null:
			out.append(_chip("%s: %s · %s" % [(f.unit as BattleUnit).data.display_name, StanceRules.style_name(st.geometry), StanceRules.stance_name(st.stance)], Color("#9cc3e6")))
	if summary.collection_total > 0 and not summary.skills_learned.is_empty():
		out.append(_chip("Skills collected: %d / %d" % [summary.collection_have, summary.collection_total], HudStyle.HP))
	if rating != null and rating.biggest_hit > 0:
		out.append(_chip("Biggest hit: %d (%s)" % [rating.biggest_hit, rating.biggest_hitter], Color("#ff9a52")))
	return out


func _plain_text(summary: BattleSummary) -> String:
	var lines: Array[String] = []
	for bu in summary.lines:
		if bu.data.role() != UnitData.Role.ENEMY:
			lines.append(summary.describe(bu))
	if summary.exp_each > 0:
		lines.append("XP pool %d, %d each" % [summary.exp_pool, summary.exp_each])
	if not summary.relics_secured.is_empty():
		lines.append("Relics home: " + ", ".join(summary.relics_secured.map(func(r): return r.display_name)))
	return "\n".join(lines)
