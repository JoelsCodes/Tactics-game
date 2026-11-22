extends Node
## Headless: the Company Headquarters (BarracksScreen in the MenuKit look, the Roster layout of Nov 2026). Every tab opens, Q / E and the shoulder buttons step
## through the page tabs, Esc goes back to the Roster, a member row selects that member and Equipment / Abilities open the selected member's menu, every
## member has a row with real numbers and a centre panel (strip, attributes, equipment, skills), save and load still work, and the main menu has no party
## controls (the party is picked in the Formation pop-up before a battle).
## godot --headless --path godot res://tests/hq_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _ready() -> void:
	SaveSystem.dir = "user://test_saves_hq"
	var b: BarracksScreen = load("res://scenes/barracks.tscn").instantiate()
	b.roster = SampleParty.make()
	add_child(b)
	await get_tree().process_frame
	await get_tree().process_frame
	var members := b._members()
	ok(b.card_buttons.size() == members.size() and members.size() > 0, "a row for every member (%d)" % members.size())
	ok(b.card_buttons[0].button_pressed and b.selected_unit == b.roster.king, "the King is selected at first")
	ok(b.nav_buttons.size() == BarracksScreen.SECTIONS.size() and BarracksScreen.SECTIONS.size() == 6 and not BarracksScreen.SECTIONS.has("Formation"), "six tabs along the top, and no Formation")
	for name in ["Campaign", "Records", "System", "Roster"]:
		b.show_section(name)
		ok(b._pages[name].visible and b._pages.keys().filter(func(k): return b._pages[k].visible).size() == 1, "%s shows alone" % name)
	# keyboard and controller: Q / E and the shoulders step through sections; Esc returns to Company
	var e := InputEventKey.new()
	e.keycode = KEY_E
	e.pressed = true
	b._unhandled_input(e)
	ok(b.section == "Campaign", "E steps to the next page tab")
	var j := InputEventJoypadButton.new()
	j.button_index = JOY_BUTTON_RIGHT_SHOULDER
	j.pressed = true
	b._unhandled_input(j)
	ok(b.section == "Records", "the right shoulder button steps too")
	var q := InputEventKey.new()
	q.keycode = KEY_Q
	q.pressed = true
	b._unhandled_input(q)
	ok(b.section == "Campaign", "Q steps back")
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	b._unhandled_input(esc)
	ok(b.section == "Roster", "Esc goes back to the Roster")
	# selecting a card: Skills and Equipment open that member
	var vi := members.find(b.roster.vessels()[0])
	b.card_buttons[vi].button_pressed = true
	ok(b.selected_unit == members[vi] and not b.card_buttons[0].button_pressed, "a row selects its member, one at a time")
	b.show_section("Abilities")
	ok(b.skills_menu.visible and b.skills_menu.unit == members[vi] and not b.main.visible, "Abilities opens the selected member's skills")
	b.skills_menu.closed.emit()
	ok(b.main.visible, "closing it returns to the Headquarters")
	b.show_section("Equipment")
	ok(b.loadout_menu.visible and not b.main.visible, "Equipment opens the selected member's loadout")
	b.loadout_menu.closed.emit()
	# Esc / B closes each sub-menu and brings the Headquarters back
	for which in ["mentorship", "skills", "loadout"]:
		match which:
			"mentorship": b.open_mentorship(b.roster.king)
			"skills": b.open_skills(b.roster.king)
			"loadout": b.open_loadout(b.roster.king)
		var menu: Control = {"mentorship": b.mentorship, "skills": b.skills_menu, "loadout": b.loadout_menu}[which]
		ok(menu.visible and not b.main.visible, "%s opens over the Headquarters" % which)
		ok(menu.has_node(".") and menu.theme != null, "%s uses the kit's theme" % which)
		var c := InputEventAction.new()
		c.action = "ui_cancel"
		c.pressed = true
		menu._unhandled_input(c)
		ok(not menu.visible and b.main.visible, "Esc closes %s" % which)
	# real numbers in a row and in the centre panel
	var k := b.roster.king
	b._select(k)
	var txt := _texts(b.card_buttons[0])
	ok(txt.contains(k.display_name) and txt.contains("LV %d" % k.level), "the King's row shows his name and level")
	var centre := _texts(b._detail)
	ok(centre.contains(k.display_name) and centre.contains("Level %d" % k.level) and centre.contains("%d / %d" % [k.stats.max_hp(k.loadout), k.stats.max_hp(k.loadout)]), "the centre shows his name, level and HP")
	for a in BarracksScreen.ATTRIBUTES:
		ok(centre.contains(a[0]) and centre.contains(str(k.stats.final_stat(a[1], k.loadout))), "the centre shows %s" % a[0])
	ok(b._detail.find_children("*", "TextureRect", true, false).any(func(t): return (t as TextureRect).texture is AtlasTexture and (t as TextureRect).custom_minimum_size.y > (t as TextureRect).custom_minimum_size.x * 2), "the portrait is a tall strip, not a full figure")
	var gear := _texts(b._equip_box)
	ok(gear.contains("Main weapon") and gear.contains("Weapon style") and gear.contains("Relic 1") and gear.contains("Relic 2"), "the equipment panel shows the four slots")
	ok(_texts(b._skills_box).contains("Abilities"), "the skills panel is there")
	b._select(b.roster.vessels()[0])
	ok(_texts(b._detail).contains(b.roster.vessels()[0].display_name), "choosing another member changes the centre")
	# the main menu does not pick the party
	var every := ""
	for c in b.find_children("*", "Button", true, false):
		every += (c as Button).text + "\n"
	ok(not every.contains("active party") and not every.contains("Stand down") and not every.contains("Join"), "no party controls in the main menu")
	b.save_button.pressed.emit()
	ok(b.status.text.begins_with("Saved"), "Save still saves: %s" % b.status.text)
	b.load_button.pressed.emit()
	ok(b.status.text.begins_with("Loaded"), "Load still loads")
	ok(b.card_buttons.size() == b._members().size(), "the rows are rebuilt after a load")
	print("hq checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func _texts(n: Node) -> String:
	var out := ""
	for c in n.find_children("*", "Label", true, false):
		out += (c as Label).text + "\n"
	return out
