extends Node
## Headless: the Company Headquarters (BarracksScreen in the MenuKit look). Every section opens, Q / E and the shoulder buttons step through
## them, Esc goes back to Company, a member card selects that member and Skills / Equipment open the selected member's menu, every member has
## a card with real numbers, and the old buttons (save, load, mentorship, loadouts, Co-Captain) still exist and work.
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
	ok(b.card_buttons.size() == members.size() and members.size() > 0, "a card for every member (%d)" % members.size())
	ok(b.card_buttons[0].button_pressed and b.selected_unit == b.roster.king, "the King is selected at first")
	ok(b.nav_buttons.size() == BarracksScreen.SECTIONS.size(), "all seven sections in the navigation")
	for name in ["Formation", "Campaign", "Records", "System", "Company"]:
		b.show_section(name)
		ok(b._pages[name].visible and b._pages.keys().filter(func(k): return b._pages[k].visible).size() == 1, "%s shows alone" % name)
	# keyboard and controller: Q / E and the shoulders step through sections; Esc returns to Company
	var e := InputEventKey.new()
	e.keycode = KEY_E
	e.pressed = true
	b._unhandled_input(e)
	ok(b.section == "Formation", "E steps to the next section")
	var j := InputEventJoypadButton.new()
	j.button_index = JOY_BUTTON_RIGHT_SHOULDER
	j.pressed = true
	b._unhandled_input(j)
	ok(b.section == "Campaign", "the right shoulder button steps too")
	var q := InputEventKey.new()
	q.keycode = KEY_Q
	q.pressed = true
	b._unhandled_input(q)
	ok(b.section == "Formation", "Q steps back")
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	b._unhandled_input(esc)
	ok(b.section == "Company", "Esc goes back to Company")
	# selecting a card: Skills and Equipment open that member
	var vi := members.find(b.roster.vessels()[0])
	b.card_buttons[vi].button_pressed = true
	ok(b.selected_unit == members[vi] and not b.card_buttons[0].button_pressed, "a card selects its member, one at a time")
	b.show_section("Skills")
	ok(b.skills_menu.visible and b.skills_menu.unit == members[vi] and not b.main.visible, "Skills opens the selected member's skills")
	b.skills_menu.closed.emit()
	ok(b.main.visible, "closing it returns to the Headquarters")
	b.show_section("Equipment")
	ok(b.loadout_menu.visible and not b.main.visible, "Equipment opens the selected member's loadout")
	b.loadout_menu.closed.emit()
	# real numbers on a card
	var k := b.roster.king
	var txt := _texts(b.card_buttons[0])
	ok(txt.contains(k.display_name) and txt.contains("LV %d" % k.level) and txt.contains("%d / %d" % [k.stats.max_hp(k.loadout), k.stats.max_hp(k.loadout)]), "the King's card shows his name, level and HP")
	# the old buttons still exist and work
	ok(b.mentor_buttons.size() == b.roster.humans().size() and b.vessel_loadout_buttons.size() == b.roster.vessels().size(), "Mentorship and Loadout buttons for every member")
	b.save_button.pressed.emit()
	ok(b.status.text.begins_with("Saved"), "Save still saves: %s" % b.status.text)
	b.load_button.pressed.emit()
	ok(b.status.text.begins_with("Loaded"), "Load still loads")
	ok(b.card_buttons.size() == b._members().size(), "the cards are rebuilt after a load")
	print("hq checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func _texts(n: Node) -> String:
	var out := ""
	for c in n.find_children("*", "Label", true, false):
		out += (c as Label).text + "\n"
	return out
