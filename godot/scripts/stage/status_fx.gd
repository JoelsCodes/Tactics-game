class_name StatusFx
extends Node3D
## What a status looks like on the unit while it lasts (Claude, Nov 2026, owner: "do 1-3"): small pixel marks drawn in code (no art
## needed) that float, orbit or pulse round the head, so a glance at the board tells who sleeps, who is stunned, who is hasted.
## A status that has no drawing here shows nothing (the unit card still lists it). It only shows things: `set_statuses` is fed the
## unit's `statuses` and decides nothing, and a unit that is fading or knocked out shows none.
##
## Each status is one row of `LOOKS`: a glyph (a tiny bitmap in `GLYPHS`), a colour, a motion (float up, fall, orbit the head, pulse in
## place, rise fast) and how many marks. Doom also shows the turns it has left.

const GLYPHS := {
	"z": ["#######", "......#", ".....#.", "....#..", "...#...", "..#....", "#######"],
	"star": ["...#...", "..###..", "#######", ".#####.", "..###..", ".##.##.", ".#...#."],
	"question": [".#####.", "#.....#", "......#", "....##.", "...#...", ".......", "...#..."],
	"anger": ["##...##", "#.....#", "...#...", "...#...", "#.....#", "##...##"],
	"skull": [".#####.", "#######", "#.###.#", "#######", ".#####.", ".#.#.#.", ".#####."],
	"cross": ["#.....#", ".#...#.", "..#.#..", "...#...", "..#.#..", ".#...#.", "#.....#"],
	"eye": ["..###.#", ".#...#.", "#..#.#.", ".#.#.#.", "..###.."],
	"down": ["#.....#", ".#...#.", "..#.#..", "...#...", "#.....#", ".#...#.", "..#.#..", "...#..."],
	"up": ["...#...", "..#.#..", ".#...#.", "#.....#", "...#...", "..#.#..", ".#...#.", "#.....#"],
	"bubble": [".###.", "#..##", "#...#", "#...#", ".###."],
	"flame": ["..#..", ".##.#", ".###.", "#####", "#####", ".###."],
	"plus": ["..#..", "..#..", "#####", "..#..", "..#.."],
	"shield": ["#####", "#####", "#####", ".###.", "..#.."],
	"crack": ["..#..", ".#...", "..#..", "...#.", "..#.."],
	"reticle": ["..#..", ".###.", "##.##", ".###.", "..#.."],
}

## status -> {glyph, color, motion, n (marks), size (1 = a glyph about a third of a tile)}
const LOOKS := {
	"sleep": {"glyph": "z", "color": Color(0.7, 0.82, 1.0), "motion": "float", "n": 3},
	"stun": {"glyph": "star", "color": Color(1.0, 0.9, 0.35), "motion": "orbit", "n": 3},
	"confuse": {"glyph": "question", "color": Color(0.95, 0.5, 1.0), "motion": "orbit", "n": 2},
	"berserk": {"glyph": "anger", "color": Color(1.0, 0.3, 0.25), "motion": "pulse", "n": 1, "size": 1.2},
	"doom": {"glyph": "skull", "color": Color(0.8, 0.55, 1.0), "motion": "pulse", "n": 1, "size": 1.1},
	"curse": {"glyph": "cross", "color": Color(0.7, 0.35, 0.95), "motion": "float", "n": 2},
	"blind": {"glyph": "eye", "color": Color(0.85, 0.85, 0.9), "motion": "pulse", "n": 1},
	"mild_blind": {"glyph": "eye", "color": Color(0.7, 0.7, 0.75), "motion": "pulse", "n": 1, "size": 0.8},
	"slowed": {"glyph": "down", "color": Color(0.55, 0.75, 1.0), "motion": "fall", "n": 2},
	"haste": {"glyph": "up", "color": Color(1.0, 0.92, 0.4), "motion": "rise_fast", "n": 2},
	"poison": {"glyph": "bubble", "color": Color(0.5, 0.95, 0.35), "motion": "float", "n": 3},
	"burn": {"glyph": "flame", "color": Color(1.0, 0.55, 0.2), "motion": "float", "n": 3},
	"regen": {"glyph": "plus", "color": Color(0.5, 1.0, 0.65), "motion": "float", "n": 2},
	"ward": {"glyph": "shield", "color": Color(0.55, 0.8, 1.0), "motion": "pulse", "n": 1, "size": 0.9},
	"exposed": {"glyph": "crack", "color": Color(1.0, 0.4, 0.35), "motion": "pulse", "n": 1},
	"silence": {"glyph": "cross", "color": Color(0.8, 0.8, 0.85), "motion": "pulse", "n": 1, "size": 0.8},
	"root": {"glyph": "down", "color": Color(0.6, 0.78, 0.4), "motion": "pulse", "n": 1, "size": 0.8},
	"marked": {"glyph": "reticle", "color": Color(1.0, 0.55, 0.3), "motion": "pulse", "n": 1},
	"atk_down": {"glyph": "down", "color": Color(1.0, 0.4, 0.35), "motion": "fall", "n": 1},
}
const GLYPH_PX := 0.062  ## world units per glyph pixel: a 7 px glyph is about 0.45 of a tile (about 30 px on screen at 1080p)
const LOOP := 1.6  ## seconds a floating mark takes from head to gone
const ORBIT_R := 0.5
const ORBIT_SECS := 1.5
const MAX_MARKS := 12  ## marks on one unit at once; the rest are skipped

static var _tex := {}  ## glyph name -> texture (with a dark outline so it reads on any ground)

var view: UnitView3D
var _t := randf() * 10.0
var _active := {}  ## status -> {"marks": Array[Sprite3D], "look": Dictionary, "label": Label3D or null}
var _shown := true


func _init(v: UnitView3D = null) -> void:
	view = v
	name = "StatusFx"


## The statuses on show now: names the unit has, and for doom the turns left (shown beside the skull). Marks of a status that
## ended go away, marks of a new one start; a status without a drawing is ignored.
func set_statuses(statuses: Dictionary) -> void:
	for s in _active.keys():
		if int(statuses.get(s, 0)) <= 0:
			_drop(s)
	var count := 0
	for s in _active:
		count += (_active[s].marks as Array).size()
	if view != null and is_instance_valid(view):
		view.trail_color = Color(1.0, 0.92, 0.4, 0.4) if int(statuses.get("haste", 0)) > 0 else Color(0, 0, 0, 0)  # a hasted unit leaves a trail
	for s in statuses:
		if int(statuses[s]) <= 0 or not LOOKS.has(s):
			continue
		if not _active.has(s):
			var l: Dictionary = LOOKS[s]
			if count + int(l.n) > MAX_MARKS:
				continue
			_active[s] = {"marks": _make(l), "look": l, "label": null}
			count += int(l.n)
		if s == "doom":
			_doom_label(int(statuses[s]))


## Names of the statuses showing a drawing now (tests read it).
func shown() -> Array:
	return _active.keys()


func clear() -> void:
	for s in _active.keys():
		_drop(s)


func _drop(s: String) -> void:
	var e: Dictionary = _active[s]
	for m in e.marks:
		if is_instance_valid(m):
			m.queue_free()
	if e.label != null and is_instance_valid(e.label):
		e.label.queue_free()
	_active.erase(s)


func _make(l: Dictionary) -> Array:
	var out := []
	for i in int(l.n):
		var sp := Sprite3D.new()
		sp.texture = glyph(String(l.glyph))
		sp.pixel_size = GLYPH_PX * float(l.get("size", 1.0))
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.shaded = false
		sp.double_sided = true
		sp.transparent = true
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		sp.modulate = l.color
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sp.render_priority = 4
		sp.visible = false  # placed on the first frame
		add_child(sp)
		out.append(sp)
	return out


func _doom_label(turns: int) -> void:
	var e: Dictionary = _active["doom"]
	if e.label == null:
		var lb := Label3D.new()
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.shaded = false
		lb.double_sided = true
		lb.no_depth_test = false
		lb.pixel_size = 0.006
		lb.font_size = 56
		lb.outline_size = 14
		lb.modulate = LOOKS.doom.color
		lb.outline_modulate = Color(0.1, 0.0, 0.15, 0.95)
		lb.render_priority = 5
		add_child(lb)
		e.label = lb
	(e.label as Label3D).text = str(turns)


func _process(delta: float) -> void:
	_t += delta
	if view == null or not is_instance_valid(view):
		return
	# a unit that is fading (a summon appearing, a knockout) or fallen shows no marks
	var show: bool = view.get_alpha() > 0.95 and view.animator != null and view.animator.state != SpriteAnimator.State.DEAD
	if show != _shown:
		_shown = show
		visible = show
	if not show or _active.is_empty():
		return
	var top := view.figure_height() + 0.12
	var base := view.visual_shift() + Vector3(0, top, 0)
	for s in _active:
		var e: Dictionary = _active[s]
		var l: Dictionary = e.look
		var marks: Array = e.marks
		var n := marks.size()
		for i in n:
			var sp: Sprite3D = marks[i]
			var ph := float(i) / float(n)
			var pos := base
			var a := 1.0
			var sc := 1.0
			match String(l.motion):
				"float":  # drifts up from the head, fades in and out, the marks staggered
					var u := fposmod(_t / LOOP + ph, 1.0)
					pos += Vector3(sin((u + ph) * TAU) * 0.12, u * 0.75, 0)
					a = sin(u * PI)
				"rise_fast":
					var u2 := fposmod(_t / (LOOP * 0.55) + ph, 1.0)
					pos += Vector3((ph - 0.25) * 0.4, u2 * 0.8 - 0.05, 0)
					a = sin(u2 * PI)
				"fall":  # sinks slowly from above the head toward it
					var u3 := fposmod(_t / (LOOP * 1.2) + ph, 1.0)
					pos += Vector3((ph - 0.25) * 0.4, 0.7 - u3 * 0.7, 0)
					a = sin(u3 * PI)
				"orbit":
					var ang := _t / ORBIT_SECS * TAU + ph * TAU
					pos += Vector3(cos(ang) * ORBIT_R, 0.06, sin(ang) * ORBIT_R * 0.7)
				_:  # pulse: in place above the head, swelling and settling
					pos += Vector3(0, 0.3, 0)
					var w := 0.5 + 0.5 * sin(_t * 4.0 + ph * TAU)
					sc = 1.0 + 0.18 * w
					a = 0.75 + 0.25 * w
			sp.position = pos
			sp.scale = Vector3.ONE * sc
			var c: Color = l.color
			sp.modulate = Color(c.r, c.g, c.b, a)
			sp.visible = a > 0.02
		if e.label != null:
			(e.label as Label3D).position = base + Vector3(0.34, 0.3, 0)


# ---------- the glyphs ----------

## The texture of a glyph: its pixels in white (the sprite's modulate colours it) with a one-pixel dark outline around them.
static func glyph(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var rows: Array = GLYPHS[name]
	var w := 0
	for r in rows:
		w = maxi(w, String(r).length())
	var h := rows.size()
	var img := Image.create(w + 2, h + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in String(rows[y]).length():
			if String(rows[y])[x] != "#":
				continue
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if img.get_pixel(x + 1 + dx, y + 1 + dy).a < 0.5:
						img.set_pixel(x + 1 + dx, y + 1 + dy, Color(0.06, 0.04, 0.1, 0.9))
	for y in h:
		for x in String(rows[y]).length():
			if String(rows[y])[x] == "#":
				img.set_pixel(x + 1, y + 1, Color.WHITE)
	var t := ImageTexture.create_from_image(img)
	_tex[name] = t
	return t
