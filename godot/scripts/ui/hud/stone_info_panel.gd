class_name StoneInfoPanel
extends VBoxContainer
## The summon stone's window: while a vessel is being summoned and a glowing stone is pointed at, a panel slides out from the left edge of the
## battle HUD (where the damage prediction sits; it is never shown at the same time) with everything about the stone: its skill's name, rank and
## proficiency, the kind of stone (reach, field or prize), whether the skill is new to the party, what the skill does, its SP cost and power, and
## what summoning this vessel onto it means (it uses the skill from the stone and starts learning it: its bar if it already has one, the Fade Clock).
## The battlefield itself only shows the skill's name over a stone. This only shows things; BattleStage feeds it and hides it.

const WIDTH := 440
const SLIDE := 0.2
const KINDS := {"reach": "Reach stone", "field": "Field stone", "prize": "Prize stone"}
const KIND_NOTES := {
	"reach": "Close to the King: it can be used on the first turn.",
	"field": "Out in the middle of the map: the King has to advance to use it.",
	"prize": "Deep in the enemy's ground, with the best skill on the map. The reward for pushing forward.",
}
const MUTED := Color("#9eacbd")

var plaque_label: Label
var name_label: Label
var chips: HBoxContainer
var desc: Label
var stats: Label
var note: Label
var vessel_label: Label
var bar: ColorRect
var bar_fill: ColorRect
var shown := false
var shown_skill: SkillData
var _tween: Tween
var _home_x := 0.0


func _ready() -> void:
	custom_minimum_size.x = WIDTH
	add_theme_constant_override("separation", -6)
	var plaque := HudStyle.plaque("SUMMON STONE", 18)
	plaque_label = plaque.get_node("Text")
	add_child(plaque)
	var body := PanelContainer.new()
	body.add_theme_stylebox_override("panel", HudStyle.slim_panel(20, 14))
	add_child(body)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	body.add_child(col)
	name_label = Label.new()
	Typography.apply(name_label, Typography.Role.SUBHEADING, Color("#f0f6ff"))
	name_label.clip_text = true
	col.add_child(name_label)
	chips = HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	col.add_child(chips)
	col.add_child(HudStyle.divider())
	desc = Label.new()
	Typography.apply(desc, Typography.Role.BODY, Color("#c4d0de"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = WIDTH - 44
	col.add_child(desc)
	stats = Label.new()
	Typography.apply(stats, Typography.Role.NUMBER, HudStyle.GOLD)
	col.add_child(stats)
	note = Label.new()
	Typography.apply(note, Typography.Role.LABEL, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = WIDTH - 44
	col.add_child(note)
	col.add_child(HudStyle.divider())
	vessel_label = Label.new()
	Typography.apply(vessel_label, Typography.Role.BODY, Color("#cfe6ff"))
	vessel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vessel_label.custom_minimum_size.x = WIDTH - 44
	col.add_child(vessel_label)
	bar = ColorRect.new()
	bar.color = Color(0, 0, 0, 0.6)
	bar.custom_minimum_size = Vector2(0, 10)
	col.add_child(bar)
	bar_fill = ColorRect.new()
	bar_fill.color = HudStyle.GOLD
	bar_fill.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	bar.add_child(bar_fill)
	modulate.a = 0.0
	hide()


## Shows the window for the stone `relic` (a RelicItem on the field) as it would be used by `vessel` (VesselData). `game` is the SaveGame (what the
## party has mastered). A stone with no skill hides the window.
func show_stone(relic: RelicItem, vessel: VesselData, game: SaveGame) -> void:
	if relic == null or relic.skill == null:
		hide_stone()
		return
	var sk := relic.skill
	if shown and shown_skill == sk:
		_slide(true)
		return
	shown_skill = sk
	var kind := StonePlacement.kind_of(relic)
	plaque_label.text = String(KINDS.get(kind, "Summon stone")).to_upper()
	name_label.text = sk.display_name
	name_label.add_theme_color_override("font_color", Color("#ffdc8a") if kind == "prize" else Color("#f0f6ff"))
	for c in chips.get_children():
		chips.remove_child(c)
		c.queue_free()
	_chip("Rank %s" % SkillCollection.rank_letter(sk), SkillCollection.rank_color(sk))
	_chip(Proficiency.display_name(sk.category), SkillCollection.category_color(sk.category))
	if SkillCollection.is_new(game, sk):
		_chip("New to the party", HudStyle.ICE)
	else:
		var who: Array = SkillCollection.mastered(game).get(sk, [])
		_chip("Known by %s" % ", ".join(who.slice(0, 2)) if not who.is_empty() else "Known", Color("#9aa6c4"))
	desc.text = SkillCollection.describe(sk)
	var parts: Array[String] = ["%d SP" % sk.sp_cost]
	if sk.is_physical():
		var b := sk.band()
		parts.append("%.2f to %.2f x Attack" % [float(b[0]), float(b[1])])
	elif sk.base_power > 0:
		parts.append("Power %d" % sk.base_power)
	stats.text = "   ·   ".join(parts)
	note.text = String(KIND_NOTES.get(kind, ""))
	note.visible = note.text != ""
	_vessel_text(sk, vessel)
	_slide(true)


func hide_stone() -> void:
	shown_skill = null
	_slide(false)


func _vessel_text(sk: SkillData, vessel: VesselData) -> void:
	if vessel == null:
		vessel_label.text = ""
		bar.visible = false
		return
	var m := SkillCollection.mastery(vessel, sk)
	var lines := ["%s uses %s from the stone and starts learning it." % [vessel.display_name, sk.display_name]]
	if m == null:
		lines.append("Not started yet: learned for good at level 1.")
		bar.visible = false
	else:
		lines.append(SkillCollection.state_text(vessel, sk) + ("  ·  Level %d" % m.level if m.is_mastered() else ""))
		bar.visible = true
		bar_fill.anchor_right = clampf(m.fill(), 0.0, 1.0)
		bar_fill.offset_right = 0
	lines.append("Fade Clock: %d turns, then the stone is spent." % vessel.fade_turns)
	vessel_label.text = "\n".join(lines)


func _chip(text: String, col: Color) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", HudStyle.box(Color(col, 0.14), Color(col, 0.7), 5, 1, 8, 1))
	var l := Label.new()
	l.text = text
	Typography.apply(l, Typography.Role.LABEL, col.lightened(0.25))
	p.add_child(l)
	chips.add_child(p)


func _slide(on: bool) -> void:
	if _tween != null:
		_tween.kill()
	if on == shown and on:
		return
	shown = on
	_tween = create_tween()
	_tween.set_parallel(true)
	if on:
		show()
		position.x = _home_x - WIDTH - 40.0
		modulate.a = 0.0
		_tween.tween_property(self, "position:x", _home_x, SLIDE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "modulate:a", 1.0, SLIDE * 0.8)
	else:
		_tween.tween_property(self, "position:x", _home_x - WIDTH - 40.0, SLIDE * 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_tween.tween_property(self, "modulate:a", 0.0, SLIDE * 0.8)
		_tween.chain().tween_callback(hide)


func set_home(x: float) -> void:
	_home_x = x
	if shown:
		position.x = x
