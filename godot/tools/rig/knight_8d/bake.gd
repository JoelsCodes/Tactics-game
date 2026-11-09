extends Node
## Bakes the rigged knight (knight_8d.tscn: native Skeleton2D / Bone2D cutout rig, from the owner's Alaric rig) into two magenta-background
## sheets in the layouts the art tools cut (idle_walk_sheet.py and attack_sheet.py), so the rig plays in battle like any sheet character
## (SpriteAnimator, hit flash, hitstop, the tile rule) with no run-time bridge:
##   art_src/characters/alaric_rig_idle_walk_sheet.png   IDLE row on top, WALK below; panels DOWN, RIGHT, UP, LEFT; 4 frames a panel
##   art_src/characters/alaric_rig_attack_sheet.png      rows DOWN, UP, LEFT, RIGHT; 4 frames each (strike on the third)
## Four directions only: S, E and N are drawn; W is the rig's own mirrored view of E (the sword hangs on the other side).
## Needs a renderer:  xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot res://tools/rig/knight_8d/bake.tscn
## then:              python3 godot/tools/art/alaric_rig.py

const CELL := Vector2i(200, 300)  ## one frame's cell on the sheets
const GAP := 40  ## magenta between panels
const FEET := Vector2(100, 290)  ## where the rig's feet (local 0, 0) go in a cell
const SCALE := 0.5  ## the rig's source art is about 512 px tall
const MAGENTA := Color(1.0, 0.0, 1.0)
const FRAMES := 4
const DIRS := ["S", "E", "N", "W"]

var vp: SubViewport
var rig: Node2D


func _ready() -> void:
	vp = SubViewport.new()
	vp.size = CELL
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = MAGENTA
	bg.size = Vector2(CELL)
	vp.add_child(bg)
	rig = load("res://tools/rig/knight_8d/knight_8d.tscn").instantiate()
	rig.position = FEET
	rig.scale = Vector2(SCALE, SCALE)
	vp.add_child(rig)
	await get_tree().process_frame
	await _bake()
	get_tree().quit()


func _bake() -> void:
	var pw := CELL.x * FRAMES
	var iw := Image.create(pw * 4 + GAP * 3, CELL.y * 2 + GAP, false, Image.FORMAT_RGB8)
	iw.fill(MAGENTA)
	var atk := Image.create(pw, CELL.y * 4, false, Image.FORMAT_RGB8)
	atk.fill(MAGENTA)
	for d in 4:
		for k in FRAMES:
			iw.blit_rect(await _shot(DIRS[d], "idle", k), Rect2i(Vector2i.ZERO, CELL), Vector2i(d * (pw + GAP) + k * CELL.x, 0))
			iw.blit_rect(await _shot(DIRS[d], "walk", k), Rect2i(Vector2i.ZERO, CELL), Vector2i(d * (pw + GAP) + k * CELL.x, CELL.y + GAP))
	var rows := {"S": 0, "N": 1, "W": 2, "E": 3}  # the attack sheet's row order: DOWN, UP, LEFT, RIGHT
	for d in DIRS:
		for k in FRAMES:
			atk.blit_rect(await _shot(d, "attack", k), Rect2i(Vector2i.ZERO, CELL), Vector2i(k * CELL.x, rows[d] * CELL.y))
	var dir := ProjectSettings.globalize_path("res://art_src/characters/")
	print("idle/walk ", iw.save_png(dir + "alaric_rig_idle_walk_sheet.png"), "  attack ", atk.save_png(dir + "alaric_rig_attack_sheet.png"), "  ", iw.get_size(), atk.get_size())


func _shot(dir: String, kind: String, k: int) -> Image:
	for n in ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]:
		rig.get_node("Directions/" + n).visible = n == dir
	rig.position = FEET
	pose(dir, kind, k)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()


func _b(dir: String, path: String) -> Bone2D:
	return rig.get_node("Directions/%s/Skeleton2D/Hips/%s" % [dir, path]) as Bone2D


## Poses the rig at frame `k` of `kind` (idle, walk, attack): bone rotations in radians, and a small shove of the whole figure.
func pose(dir: String, kind: String, k: int) -> void:
	var bones := {
		"Chest": 0.0, "Chest/Neck/Head": 0.0, "Chest/LeftUpperArm": 0.0, "Chest/RightUpperArm": 0.0,
		"Chest/LeftUpperArm/LeftForearm": 0.0, "Chest/RightUpperArm/RightForearm": 0.0,
		"LeftThigh": 0.0, "RightThigh": 0.0, "LeftThigh/LeftShin": 0.0, "RightThigh/RightShin": 0.0, "Weapon": 0.0}
	var shove := Vector2.ZERO  # pixels, in rig space
	var bob := 0.0
	var t := float(k) / FRAMES
	match kind:
		"idle":
			var s := sin(t * TAU)
			bones["Chest"] = s * 0.012
			bones["Chest/Neck/Head"] = -s * 0.008
			bones["Chest/LeftUpperArm"] = s * 0.015
			bones["Chest/RightUpperArm"] = -s * 0.015
			bob = -s * 2.0
		"walk":
			var s := sin(t * TAU)
			var c := cos(t * TAU)
			bones["Chest"] = s * 0.03
			bones["Chest/Neck/Head"] = -s * 0.02
			bones["Chest/LeftUpperArm"] = s * 0.16
			bones["Chest/RightUpperArm"] = -s * 0.16
			bones["Chest/LeftUpperArm/LeftForearm"] = -s * 0.08
			bones["Chest/RightUpperArm/RightForearm"] = s * 0.08
			bones["LeftThigh"] = -s * 0.13
			bones["RightThigh"] = s * 0.13
			bones["LeftThigh/LeftShin"] = maxf(0.0, s) * 0.06
			bones["RightThigh/RightShin"] = maxf(0.0, -s) * 0.06
			bones["Weapon"] = s * 0.03
			bob = -absf(c) * 4.0
		"attack":
			# wind-up, raised, the blow, recovery (the strike is the third frame)
			var chest: float = [-0.05, -0.09, 0.10, 0.03][k]
			var arm: float = [-0.25, -0.5, 0.4, 0.1][k]
			var fore: float = [-0.1, -0.25, 0.15, 0.05][k]
			var sword: float = [-0.12, -0.35, 0.45, 0.12][k]
			bones["Chest"] = chest
			bones["Chest/Neck/Head"] = -chest * 0.6
			bones["Chest/RightUpperArm"] = arm
			bones["Chest/RightUpperArm/RightForearm"] = fore
			bones["Chest/LeftUpperArm"] = -arm * 0.3
			bones["Weapon"] = sword
			bones["LeftThigh"] = [0.03, 0.05, -0.08, -0.02][k]
			bones["RightThigh"] = [-0.03, -0.05, 0.08, 0.02][k]
			var lunge: float = [-4.0, -8.0, 16.0, 5.0][k]  # forward along the facing
			shove = _forward(dir) * lunge
	for path in bones:
		_b(dir, path).rotation = bones[path]
	rig.position = FEET + (shove + Vector2(0, bob)) * SCALE


## The screen direction a view faces.
func _forward(dir: String) -> Vector2:
	match dir:
		"S":
			return Vector2(0, 1)
		"N":
			return Vector2(0, -1)
		"E":
			return Vector2(1, 0)
	return Vector2(-1, 0)
