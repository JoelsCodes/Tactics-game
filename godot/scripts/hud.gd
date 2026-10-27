class_name Hud
extends CanvasLayer
## Battle HUD (scenes/hud.tscn): turn order, law, unit status, command menu, ability
## list, target forecast, action banner, toasts and the end screen. battle.gd drives it.

signal rotate_pressed(dir: int)
signal zoom_pressed(factor: float)
signal menu_pressed

const TEAMCOL := [Color("#8cc8ff"), Color("#ff8a7a")]

var _log_tween: Tween
var _banner_tween: Tween
var _list_cancel: Callable


func _ready() -> void:
	%MenuButton.pressed.connect(func(): menu_pressed.emit())
	for spec in [["rotl", func(): rotate_pressed.emit(-1)], ["rotr", func(): rotate_pressed.emit(1)], ["plus", func(): zoom_pressed.emit(1.2)], ["minus", func(): zoom_pressed.emit(.83)]]:
		%MapControls.add_child(IconButton.make(spec[0], spec[1]))
	%Scrim.gui_input.connect(func(e):
		if e is InputEventMouseButton and not e.pressed and _list_cancel.is_valid():
			_list_cancel.call())


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func label(text: String, variation := "", size := 0, col = null) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if size:
		l.add_theme_font_size_override("font_size", size)
	if col != null:
		l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ---------- top ----------
func set_law(ban, fav) -> void:
	var b: String = Data.LAWS[ban].name if ban else "None"
	var f: String = Data.LAWS[fav].name if fav else "None"
	%Law.text = "[color=#e7c46a]LAW[/color]   [color=#ff9a8a]Ban[/color] %s   [color=#8fe39a]Favor[/color] %s" % [b, f]


func set_order(list: Array) -> void:
	clear(%Order)
	for i in min(8, list.size()):
		var p := Portrait.make(list[i], 44 if i == 0 else 38)
		%Order.add_child(p)


func log_msg(text: String) -> void:
	%Log.text = text
	%Log.modulate.a = 1
	if _log_tween:
		_log_tween.kill()
	_log_tween = create_tween()
	_log_tween.tween_interval(1.8)
	_log_tween.tween_property(%Log, "modulate:a", 0.0, .5)


## Ability name window that slides in when anyone acts (FFT style).
func banner(text: String) -> void:
	%BannerLabel.text = text
	var bp: Control = %BannerLabel.get_parent()
	%Banner.visible = true
	bp.modulate.a = 0
	bp.scale = Vector2(1, .2)
	await get_tree().process_frame
	bp.pivot_offset = bp.size / 2
	bp.position = (%Banner.size - bp.size) / 2
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(bp, "modulate:a", 1.0, .12)
	_banner_tween.parallel().tween_property(bp, "scale", Vector2.ONE, .15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(.8)
	_banner_tween.tween_property(bp, "modulate:a", 0.0, .25)
	_banner_tween.tween_callback(func(): %Banner.visible = false)


func toast(text: String) -> void:
	%ToastLabel.text = text
	%ToastPanel.visible = true
	%ToastPanel.modulate.a = 1
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(%ToastPanel, "modulate:a", 0.0, .3)
	tw.tween_callback(func(): %ToastPanel.visible = false)


# ---------- bottom ----------
func show_status(u: Dictionary, extra := "") -> void:
	clear(%StatusBox)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Portrait.make(u, 60))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nm := label(u.name, "HeaderLabel", 17, TEAMCOL[u.team])
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	head.add_child(nm)
	head.add_child(label("Lv%d" % u.lv, "", 14, Color("#fff1c8")))
	v.add_child(head)
	var sub := "%s%s" % ["Monster" if u.mon else Data.JOBS[u.job].name, ("  ·  %d JP" % u.jp) if u.jp else ""]
	if u.cards:
		sub += "  ·  Yellow card"
	if u.get("title"):
		sub += "  ·  " + Data.TITLES[u.title].name
	if u.get("remove", -1) > 0:
		sub += "  ·  Remove %d" % u.remove
	v.add_child(label(sub, "SmallLabel"))
	v.add_child(StatBar.make("HP", u.hp, u.s.mhp, Color("#5fd36a") if u.hp > u.s.mhp * .5 else Color("#e8c050") if u.hp > u.s.mhp * .25 else Color("#e8574a")))
	if u.s.mmp:
		v.add_child(StatBar.make("MP", Rules.mp_total(u), Rules.mp_max_total(u), Color("#5aa8ff")))
	var line := "CT %d" % max(0, roundi(u.ct))
	for k in u.st:
		line += "  " + Data.STATUS[k].name
	v.add_child(label(line, "SmallLabel"))
	row.add_child(v)
	%StatusBox.add_child(row)
	if extra != "":
		var e := label(extra, "SmallLabel")
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		%StatusBox.add_child(e)
	%StatusPanel.visible = true


func hide_status() -> void:
	%StatusPanel.visible = false


## items: [{text, cb, disabled}]. Empty hides the menu.
func set_commands(items: Array) -> void:
	clear(%Commands)
	for it in items:
		var b := Button.new()
		b.text = it.text
		b.theme_type_variation = "CommandButton"
		b.disabled = it.get("disabled", false)
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = load("res://assets/ui/pointer.png") if it.get("primary") else null
		b.custom_minimum_size = Vector2(0, 38)
		b.pressed.connect(it.cb)
		%Commands.add_child(b)
	%CommandPanel.visible = not items.is_empty()


func hint(text: String) -> void:
	%Hint.text = text
	%Hint.visible = text != ""


## Damage/heal forecast: rows [{name, team, text}].
func show_target(title: String, warn: String, rows: Array) -> void:
	clear(%TargetBox)
	var head := HBoxContainer.new()
	head.add_child(label(title, "HeaderLabel"))
	if warn != "":
		var w := label(warn, "SmallLabel", 0, Color("#ff9a8a"))
		w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		head.add_child(w)
	%TargetBox.add_child(head)
	for r in rows:
		var h := HBoxContainer.new()
		var n := label(r.name, "", 15, TEAMCOL[r.team])
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		h.add_child(label(r.text, "", 15, Color("#fff1c8")))
		%TargetBox.add_child(h)
	if rows.is_empty():
		%TargetBox.add_child(label("No targets there.", "SmallLabel"))
	%TargetPanel.visible = true


func hide_target() -> void:
	%TargetPanel.visible = false


func clear_bottom() -> void:
	hide_status()
	hide_target()
	set_commands([])
	hint("")


# ---------- ability list ----------
## groups: [{name, rows: [{name, desc, cost, tag, tag_col, disabled, cb}]}]
func open_list(title: String, groups: Array, on_cancel: Callable) -> void:
	%ListTitle.text = title
	clear(%ListBox)
	clear(%ListButtons)
	_list_cancel = on_cancel
	for g in groups:
		%ListBox.add_child(label(g.name, "SectionLabel"))
		for r in g.rows:
			%ListBox.add_child(ListRow.make(r, func(t): %Help.text = t))
	%Help.text = "Tap an ability to choose its target."
	var c := Button.new()
	c.text = "Cancel"
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.custom_minimum_size = Vector2(0, 42)
	c.pressed.connect(on_cancel)
	%ListButtons.add_child(c)
	%Sheet.visible = true


func close_list() -> void:
	%Sheet.visible = false
	_list_cancel = Callable()


func list_open() -> bool:
	return %Sheet.visible


# ---------- end ----------
func show_end(won: bool, info: String, buttons: Array) -> void:
	clear_bottom()
	%End.visible = true
	%EndTitle.text = "VICTORY!" if won else "DEFEAT"
	%EndTitle.add_theme_color_override("font_color", Color("#ffd86a") if won else Color("#ff7a68"))
	%EndInfo.text = info
	clear(%EndButtons)
	for b in buttons:
		var btn := Button.new()
		btn.text = b.text
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 48)
		if b.get("primary"):
			btn.theme_type_variation = "PrimaryButton"
		btn.pressed.connect(b.cb)
		%EndButtons.add_child(btn)
	var t: Label = %EndTitle
	t.pivot_offset = t.size / 2
	t.scale = Vector2(2.2, 2.2)
	t.modulate.a = 0
	var tw := create_tween().set_parallel()
	tw.tween_property(t, "scale", Vector2.ONE, .45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "modulate:a", 1.0, .25)


## One tappable ability row: name, tag (Banned/Favored), cost, small description.
## Ignores the release after a drag so scrolling the list does not pick a row.
class ListRow extends PanelContainer:
	signal pressed
	var disabled := false
	var _down = null
	var _desc := ""
	var _on_focus: Callable

	static func make(r: Dictionary, on_focus: Callable) -> ListRow:
		var row := ListRow.new()
		row.disabled = r.get("disabled", false)
		row._desc = r.get("desc", "")
		row._on_focus = on_focus
		row.theme_type_variation = "RowPanel"
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.pressed.connect(r.cb)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var n := Hud.label(r.name, "", 16)
		h.add_child(n)
		if r.get("tag", "") != "":
			h.add_child(Hud.label(r.tag, "SmallLabel", 0, r.get("tag_col", Color.WHITE)))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(sp)
		if r.get("cost", "") != "":
			h.add_child(Hud.label(r.cost, "", 15, Color("#9cc8ff")))
		v.add_child(h)
		if row._desc != "":
			var d := Hud.label(row._desc, "SmallLabel")
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(d)
		row.add_child(v)
		if row.disabled:
			row.modulate = Color(1, 1, 1, .45)
		row.mouse_entered.connect(func(): row._on_focus.call(row._desc))
		return row

	func _gui_input(e: InputEvent) -> void:
		if disabled or not (e is InputEventMouseButton) or e.button_index != MOUSE_BUTTON_LEFT:
			return
		if e.pressed:
			_down = e.global_position
			theme_type_variation = "RowPanelPressed"
		else:
			theme_type_variation = "RowPanel"
			if _down != null and e.global_position.distance_to(_down) < 12:
				pressed.emit()
			_down = null


## Round map button with a drawn icon: rotl, rotr, plus, minus.
class IconButton extends Button:
	var kind := ""

	static func make(k: String, cb: Callable) -> IconButton:
		var b := IconButton.new()
		b.kind = k
		b.custom_minimum_size = Vector2(42, 42)
		b.focus_mode = Control.FOCUS_NONE
		b.theme_type_variation = "MapButton"
		b.pressed.connect(cb)
		return b

	func _draw() -> void:
		var c := size / 2
		var r := size.x * .22
		var col := Color("#fff4dc")
		var w := 2.5
		match kind:
			"plus":
				draw_line(c - Vector2(r, 0), c + Vector2(r, 0), col, w)
				draw_line(c - Vector2(0, r), c + Vector2(0, r), col, w)
			"minus":
				draw_line(c - Vector2(r, 0), c + Vector2(r, 0), col, w)
			"rotl", "rotr":
				var a0 := -PI * .9 if kind == "rotl" else -PI * .1
				var a1 := PI * .4 if kind == "rotl" else PI * 1.4
				draw_arc(c, r, a0, a1, 20, col, w, true)
				var tip := c + Vector2(cos(a0), sin(a0)) * r
				var dirv := Vector2(-sin(a0), cos(a0)) * (-1 if kind == "rotl" else 1)
				var side := dirv.orthogonal()
				draw_colored_polygon(PackedVector2Array([tip + dirv * 6, tip - side * 5, tip + side * 5]), col)
