class_name AppearanceMenu
extends Control
## A unit's appearance screen (barracks > Appearance, for every unit drawn from one of the owner's full
## sheets): the colour looks of its sheet. Shows the large illustration (the original look only), the
## in-game sprite animated in the chosen look (the recolored animation frames, not the small preview),
## the matching portrait, the four swatches of the look and the weapon (sword or staff). Picking a look
## sets UnitData.palette; the turn queue, status cards and the battle sprite follow it (UnitLook /
## CharacterLook). Plain default controls like the other barracks menus.

signal closed
signal changed

var unit: UnitData
var base := ""  ## the unit's full sheet
var title: Label
var back_button: Button
var swatch_buttons: Array[Button] = []  ## one per look of the sheet
var looks: Array = []
var illustration: TextureRect
var portrait: TextureRect
var sprite: AnimatedSprite2D
var sword: TextureRect
var no_art: Label
var name_label: Label
var swatch_strip: HBoxContainer
var _stage: Control
var _grid: GridContainer
var _weapon_title: Label


func _ready() -> void:
	_build()


func open(u: UnitData) -> void:
	unit = u
	base = CharacterLook.base_of(u)
	looks = CharacterLook.looks(base)
	title.text = "Appearance  ·  %s" % u.display_name
	for b in swatch_buttons:
		b.queue_free()
	swatch_buttons.clear()
	for p in looks:
		var b := Button.new()
		b.toggle_mode = true
		b.text = String(p).capitalize()
		b.icon = CharacterLook.portrait(base, p)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 40)
		b.custom_minimum_size = Vector2(170, 56)
		b.pressed.connect(choose.bind(p))
		_grid.add_child(b)
		swatch_buttons.append(b)
	sprite.scale = Vector2.ONE * 1.7 * float(Character.meta(base).get("scale", 1.0))
	sprite.offset = Vector2(0, Character.meta(base).size[1] / 2.0 - Character.meta(base).anchor[1])
	sword.texture = CharacterLook.weapon(base)
	_weapon_title.text = CharacterLook.weapon_name(base).to_upper()
	_show_look(String(u.palette) if looks.has(String(u.palette)) else "original")
	show()


## Sets the look and redraws.
func choose(palette: String) -> void:
	if unit == null or not looks.has(palette):
		return
	unit.palette = StringName(palette)
	_show_look(palette)
	changed.emit()


func _show_look(p: String) -> void:
	var info := CharacterLook.info(base, p)
	name_label.text = String(info.label).to_upper()
	portrait.texture = CharacterLook.portrait(base, p)
	illustration.texture = CharacterLook.illustration(base)
	illustration.modulate = Color.WHITE if p == "original" else Color(1, 1, 1, 0.0)
	no_art.visible = p != "original"
	var sheet := base if p == "original" else "%s_%s" % [base, p]
	sprite.sprite_frames = load("res://assets/characters/%s.tres" % sheet)
	sprite.play("idle_s")
	for c in swatch_strip.get_children():
		c.queue_free()
	for col in CharacterLook.swatches(base, p):
		var r := ColorRect.new()
		r.color = col
		r.custom_minimum_size = Vector2(54, 30)
		swatch_strip.add_child(r)
	for i in swatch_buttons.size():
		swatch_buttons[i].button_pressed = looks[i] == p


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(HudStyle.backdrop())
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)
	var page := VBoxContainer.new()
	page.name = "Page"
	page.add_theme_constant_override("separation", 24)
	margin.add_child(page)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(140, 52)
	back_button.pressed.connect(func():
		hide()
		closed.emit())
	head.add_child(back_button)
	title = Label.new()
	title.theme_type_variation = &"HeadingLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)
	page.add_child(head)
	var body := HBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 32)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)

	# left: the large illustration
	var left := MentorshipMenu._panel(body, 500)
	left.add_child(MentorshipMenu._section("Illustration"))
	var frame := Control.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size.y = 520
	left.add_child(frame)
	illustration = TextureRect.new()
	illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	illustration.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	illustration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(illustration)
	no_art = Label.new()
	no_art.text = "The large illustration exists for the original look only."
	no_art.theme_type_variation = &"SmallLabel"
	no_art.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	no_art.set_anchors_and_offsets_preset(Control.PRESET_HCENTER_WIDE)
	no_art.offset_top = 200
	no_art.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(no_art)

	# middle: the look
	var mid := MentorshipMenu._panel(body, 0)
	mid.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(MentorshipMenu._section("Look"))
	name_label = Label.new()
	name_label.theme_type_variation = &"TitleLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(name_label)
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(0, 330)
	mid.add_child(_stage)
	sprite = AnimatedSprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # crisp pixels
	sprite.scale = Vector2.ONE * 3.0  # set per sheet in open()
	sprite.position = Vector2(300, 300)
	_stage.add_child(sprite)
	_stage.resized.connect(func(): sprite.position = Vector2(_stage.size.x / 2.0, _stage.size.y - 24.0))
	swatch_strip = HBoxContainer.new()
	swatch_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	swatch_strip.add_theme_constant_override("separation", 6)
	mid.add_child(swatch_strip)
	mid.add_child(MentorshipMenu._section("Colour variations"))
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	mid.add_child(_grid)

	# right: the matching portrait and the sword
	var right := MentorshipMenu._panel(body, 300)
	right.add_child(MentorshipMenu._section("Portrait"))
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(0, 190)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right.add_child(portrait)
	_weapon_title = MentorshipMenu._section("Sword")
	right.add_child(_weapon_title)
	sword = TextureRect.new()
	sword.custom_minimum_size = Vector2(0, 300)
	sword.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sword.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right.add_child(sword)
