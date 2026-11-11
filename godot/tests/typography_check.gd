extends Node
## Headless checks for the typography system (owner, Nov 2026): Cinzel Bold for headings, Inter for everything played, one place for sizes, nothing under 16 px
## (except the HP tag on a turn-order card), the old font calls answered by the new fonts, the themes carrying them, and the menus' rows tall enough.
## godot --headless --path godot res://tests/typography_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func _ready() -> void:
	fonts()
	sizes()
	themes()
	await menus()
	print("typography checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func family(f: Font) -> String:
	var b: Font = (f as FontVariation).base_font if f is FontVariation else f
	return String((b as FontFile).get_font_name()).split(" ")[0] if b is FontFile else ""  # a weight's own name is "Inter SemiBold": the family is the first word


func fonts() -> void:
	ok(family(Typography.display()) == "Cinzel" and Typography.display().get_font_style_name() != "", "headings use Cinzel (%s)" % family(Typography.display()))
	ok(Typography.display().get_font_style_name().to_lower().contains("bold") or (Typography.display() as FontFile).font_weight >= 700, "and it is the Bold cut")
	for w in ["regular", "medium", "semibold", "bold"]:
		ok(family(Typography.ui(w)) == "Inter", "Inter %s loads" % w)
	ok((Typography.ui("regular") as FontFile).font_weight < (Typography.ui("semibold") as FontFile).font_weight, "and the weights differ")
	ok(Typography.numbers() is FontVariation and (Typography.numbers() as FontVariation).opentype_features.has("tnum"), "numbers use Inter's tabular figures")
	ok(family(HudStyle.font(false, false)) == "Inter" and family(HudStyle.font(true, false)) == "Inter", "HudStyle.font answers with Inter for play")
	ok(family(HudStyle.font(true, true)) == "Cinzel" and family(MenuKit.font(false, true)) == "Cinzel", "and with Cinzel for display; MenuKit.font follows")
	for f in ["Cinzel-Bold.ttf", "Inter-Regular.ttf", "Inter-Medium.ttf", "Inter-SemiBold.ttf", "Inter-Bold.ttf", "LICENSE.txt", "OFL.txt"]:
		ok(FileAccess.file_exists("res://assets/fonts/" + f), "%s is in assets/fonts" % f)
	ok(not FileAccess.file_exists("res://assets/fonts/Lato-Regular.ttf"), "the old body font is gone")


func sizes() -> void:
	for role in Typography.SIZES:
		var sz := Typography.size(role)
		ok(sz >= 16 or role == Typography.Role.TINY, "role %s is %d px (nothing under 16 but TINY)" % [Typography.Role.keys()[role], sz])
	ok(Typography.size(Typography.Role.BODY) >= 18 and Typography.size(Typography.Role.BODY) <= 20, "body text is 18 to 20 px (%d)" % Typography.size(Typography.Role.BODY))
	ok(Typography.size(Typography.Role.BODY_STRONG) >= 18 and Typography.size(Typography.Role.BODY_STRONG) <= 20, "and skill names too (%d)" % Typography.size(Typography.Role.BODY_STRONG))
	ok(Typography.size(Typography.Role.SECTION) > Typography.size(Typography.Role.BODY), "section titles are larger than body text")
	ok(Typography.size(Typography.Role.HEADING) > Typography.size(Typography.Role.SECTION) and Typography.size(Typography.Role.TITLE) > Typography.size(Typography.Role.HEADING), "headings step up: section, heading, title")
	Typography.scale = 1.25
	ok(Typography.size(Typography.Role.BODY) == roundi(19 * 1.25), "the text size multiplier scales every role")
	Typography.scale = 1.0


func themes() -> void:
	for t in [HudStyle.hud_theme(), MenuKit.theme(), HudStyle.theme()]:
		ok(family(t.default_font) == "Inter" and t.default_font_size == Typography.size(Typography.Role.BODY), "a theme's default is Inter at body size")
		ok(family(t.get_font("font", "Button")) == "Inter", "its buttons use Inter")
		ok(family(t.get_font("font", "SectionLabel")) == "Cinzel" and family(t.get_font("font", "HeadingLabel")) == "Cinzel", "its section and heading labels use Cinzel")
		ok(family(t.get_font("font", "TooltipLabel")) == "Inter" and t.get_font_size("font_size", "TooltipLabel") >= 16, "tooltips use Inter")
		ok(family(t.get_font("font", "ItemList")) == "Inter", "lists use Inter")


func menus() -> void:
	SaveSystem.dir = "user://test_saves_typography"
	var b: BarracksScreen = load("res://scenes/barracks.tscn").instantiate()
	b.roster = SampleParty.make()
	add_child(b)
	await get_tree().process_frame
	b.mentor_buttons[1].pressed.emit()
	await get_tree().process_frame
	var mm := b.mentorship
	ok(family(mm.skill_title.get_theme_font("font")) == "Cinzel", "the Mentorship skill title is Cinzel")
	ok(family(mm.study_button.get_theme_font("font")) == "Inter" and mm.study_button.text != mm.study_button.text.to_upper(), "the Study button is Inter in sentence case (%s)" % mm.study_button.text)
	for lbl in [mm.compare_label, mm.skill_label, mm.study_label, mm.learned_label]:
		ok(family(lbl.get_theme_font("font")) == "Inter" and lbl.get_theme_font_size("font_size") >= 18, "a Mentorship text label is Inter at 18 px or more")
	# nothing in the menus is set under 16 px
	var small: Array[String] = []
	for n in b.find_children("*", "Label", true, false):
		if (n as Label).visible and (n as Label).text != "" and (n as Label).get_theme_font_size("font_size") < 16:
			small.append((n as Label).text)
	ok(small.is_empty(), "no visible label in the barracks and Mentorship is under 16 px (%s)" % [small])
	b.queue_free()
	await get_tree().process_frame
	# the battle menu
	BattleStage.show_intro = false
	BattleStage.pending_game = FirstBattle.chamber_game(FirstBattle.game())
	BattleStage.pending_setup = WorldData.setup_for("alley", 1)
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 0.0
	s.animate = false
	add_child(s)
	await get_tree().process_frame
	var pal := s.hud.palette
	pal.open_list("abilities")
	ok(CommandPalette.SKILL_ROW >= 64, "a skill row is %d px tall (was 50)" % CommandPalette.SKILL_ROW)
	for btn in pal.list_buttons:
		ok(btn.custom_minimum_size.y >= CommandPalette.SKILL_ROW, "every skill row has the full height")
	ok(family(pal.detail_name.get_theme_font("font")) == "Cinzel" and family(pal.detail_text.get_theme_font("font")) == "Inter", "the detail pane: Cinzel name, Inter description")
	ok(pal.detail_text.get_theme_font_size("font_size") >= 18, "the description is 18 px or more")
	ok(pal.end_button.text == "Wait" and pal.attack_button.text == "Attack", "the command bar is in sentence case (%s, %s)" % [pal.end_button.text, pal.attack_button.text])
	ok(family(s.hud.card.name_label.get_theme_font("font")) == "Cinzel" and family(s.hud.card.class_label.get_theme_font("font")) == "Inter", "the character card: Cinzel name, Inter details")
	ok(not s.hud.card.name_label.text == s.hud.card.name_label.text.to_upper() or s.hud.card.name_label.text.length() <= 1, "and the name is not forced to capitals")
	s.queue_free()
	await get_tree().process_frame
