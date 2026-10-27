class_name Portrait
extends PanelContainer
## A unit's face in a framed box, recolored with the unit's palette.

const FRAME := [Color(0.42, 0.72, 1.0), Color(1.0, 0.45, 0.38), Color(0.85, 0.72, 0.42)]


static func make(unit_or_bu: Dictionary, px := 40, team := -1) -> Portrait:
	var p := Portrait.new()
	var bu := unit_or_bu if unit_or_bu.has("u") else {"u": unit_or_bu, "id": unit_or_bu.id, "race": unit_or_bu.race, "job": unit_or_bu.job, "mon": unit_or_bu.mon, "team": max(team, 0)}
	var look := Looks.of(bu)
	var t: int = team if team >= 0 else bu.get("team", 2)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.18)
	sb.border_color = FRAME[t]
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(1)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(px, px)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := TextureRect.new()
	tr.texture = load("res://assets/characters/%s/portrait.png" % look.char)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.custom_minimum_size = Vector2(px - 2, px - 2)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.flip_h = bu.get("team", 0) == 1
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/unit.gdshader")
	Looks.apply(m, look)
	tr.material = m
	p.add_child(tr)
	return p
