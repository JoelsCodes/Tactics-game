extends Node
## The battle's steel command menu (SteelMenu, SteelButton, CommandPalette): only the selected bar is lit, the lit bar glides to the next in 120 ms, a disabled
## command is muted and cannot be lit, a confirm flashes for 80 ms, the menu ticks and clicks with its own quiet sounds, the list that Abilities and Summon open takes
## the bars' place instead of stacking over them, and the whole menu fits the HUD's reserved bottom band.
## godot --headless --path godot res://tests/command_menu_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s (got %s, want %s)" % [what, str(a), str(b)])


func _ready() -> void:
	SaveSystem.dir = "user://test_saves_command_menu"
	await menu_alone()
	steel_helpers()
	await in_battle()
	print("command menu checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func menu_alone() -> void:
	var host := Control.new()
	host.size = Vector2(900, 600)
	add_child(host)
	var m := SteelMenu.new()
	host.add_child(m)
	var names := ["Attack", "Abilities", "Items", "Wait"]
	var bs: Array[SteelButton] = []
	for n in names:
		bs.append(m.add_command(SteelButton.new(n, "", n == "Abilities" or n == "Items")))
	bs[0].disabled = true   # the first is unusable: the lit bar must start on the first that can be used
	bs[2].disabled = true
	m.refresh(true)
	for i in 3:
		await get_tree().process_frame
	ok(m.selected == bs[1], "the lit bar starts on the first command that can be used (not the muted one)")
	ok(bs[1].lit and not bs[0].lit and not bs[2].lit and not bs[3].lit, "only the selected command is lit")
	ok(m.selector.visible and m.selector.size.x > 400, "the selector is shown and as wide as the bar plus its glow (%s)" % str(m.selector.size))
	# a muted command cannot be lit, however the mouse or focus reaches it
	bs[2].mouse_entered.emit()
	ok(m.selected == bs[1], "hovering a muted command does not light it")
	# hovering another command moves the selection and ticks
	CombatAudio.played.clear()
	bs[3].mouse_entered.emit()
	ok(m.selected == bs[3] and bs[3].lit and not bs[1].lit, "hovering a usable command lights it and puts the old one out")
	ok("menu_tick" in CombatAudio.played, "a change of selection ticks (played: %s)" % str(CombatAudio.played))
	var target := Rect2(m._list.position + bs[3].position, bs[3].size)
	eq(m.selector_target, target, "the selector's target is the new bar's rectangle")
	# the glide: not there yet halfway, there after the glide time
	await get_tree().create_timer(SteelMenu.GLIDE * 0.35).timeout
	var mid_y := m.selector.position.y
	var goal_y := target.position.y - SteelMenu.PAD
	ok(mid_y < goal_y - 1.0, "the selector is still gliding a third of the way through (y %.1f, goal %.1f)" % [mid_y, goal_y])
	await get_tree().create_timer(SteelMenu.GLIDE + 0.08).timeout
	ok(absf(m.selector.position.y - goal_y) < 0.6 and absf(m.selector.size.y - (target.size.y + SteelMenu.PAD * 2.0)) < 0.6, "the selector has arrived after the glide (y %.1f, goal %.1f)" % [m.selector.position.y, goal_y])
	eq(SteelMenu.GLIDE, 0.12, "the glide is 120 ms")
	# confirm: a bright flash that is gone after 80 ms, and the menu's own click
	CombatAudio.played.clear()
	var mat := m.selector.material as ShaderMaterial
	bs[3].pressed.emit()
	ok(float(mat.get_shader_parameter("flash")) > 0.5, "a confirm flashes the lit bar")
	ok("menu_confirm" in CombatAudio.played, "a confirm clicks softly (played: %s)" % str(CombatAudio.played))
	await get_tree().create_timer(SteelMenu.FLASH + 0.08).timeout
	ok(float(mat.get_shader_parameter("flash")) < 0.05, "the flash is gone after %d ms" % int(SteelMenu.FLASH * 1000.0))
	# the buttons keep the generic HUD hover tick and click away (the menu plays its own)
	ok(bs[0].has_meta("ui_sound"), "the steel buttons opt out of the HUD's generic sounds")
	# chevrons only where a list opens; the words are Inter at 16 px or more
	ok(bs[1].submenu and not bs[3].submenu, "a chevron only on the commands that open a list")
	ok(bs[1].get_theme_font_size("font_size") >= 16, "the words are at least 16 px")
	host.queue_free()


## The HUD's central style helpers give every panel the steel look (docs/mockups/steel_hud): one set of textures, no old gold frames.
func steel_helpers() -> void:
	for f in ["steel_panel", "steel_lit", "steel_card", "steel_card_lit", "steel_tab", "steel_tab_lit", "steel_tab_off", "steel_portrait", "steel_divider", "steel_banner", "steel_arrow_l", "steel_arrow_r"]:
		ok(ResourceLoader.exists("res://assets/ui/%s.png" % f), "the texture %s exists" % f)
	ok((HudStyle.slim_panel().texture as Texture2D).resource_path.ends_with("steel_panel.png"), "panels are steel")
	ok((HudStyle.lit_panel().texture as Texture2D).resource_path.ends_with("steel_lit.png"), "the lit panel is the lit steel")
	ok((HudStyle.queue_box(true).texture as Texture2D).resource_path.ends_with("steel_card_lit.png") and (HudStyle.queue_box(false).texture as Texture2D).resource_path.ends_with("steel_card.png"), "the turn cards are steel, the acting one lit")
	ok((HudStyle.portrait_box(Color.RED).texture as Texture2D).resource_path.ends_with("steel_portrait.png"), "the portrait ring is steel")
	var tab := HudStyle.plaque("ACTING")
	ok((tab.get_theme_stylebox("panel") as StyleBoxTexture).texture.resource_path.ends_with("steel_tab.png"), "the caption tab is a steel hexagon")
	eq((tab.get_node("Text") as Label).get_theme_color("font_color"), HudStyle.CAPTION, "the caption is the cool steel blue, not cream")
	ok((HudStyle.steel_button_box("hover").texture as Texture2D).resource_path.ends_with("steel_tab_lit.png") and (HudStyle.steel_button_box("disabled").texture as Texture2D).resource_path.ends_with("steel_tab_off.png"), "small buttons light on hover and mute when disabled")
	tab.free()


func in_battle() -> void:
	BattleStage.pending_game = FirstBattle.chamber_game(FirstBattle.game())
	BattleStage.pending_setup = WorldData.setup_for("pg_1", 1, true)
	var b: BattleStage = load("res://scenes/battle.tscn").instantiate()
	b.enemy_delay = 0.05
	add_child(b)
	var waited := 0.0
	while waited < 30.0 and (b.battle.current == null or b.battle.current.team != 0):
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	for i in 4:
		await get_tree().process_frame
	var pal := b.hud.palette
	var cmds := pal._commands.commands()
	var shown := cmds.filter(func(c): return c.visible)
	eq(shown.size(), 6, "six commands show: Attack, Abilities, Items, Defend or Summon, Wait, Move")
	ok(pal._commands.selected == pal.attack_button and pal.attack_button.lit, "the lit bar is Attack at the start of a turn")
	ok(pal.items_button.disabled and not pal.items_button.lit, "Items is muted steel and not lit")
	var lit := cmds.filter(func(c): return c.lit)
	eq(lit.size(), 1, "exactly one command is lit")
	# the geometry the menu is built to (the headless test's font metrics are not the real Inter's, so a measured height would test the test): six bars, five gaps
	# and the ornaments fit the band the HUD reserves for the palette, so the camera's framing of every battle is unchanged
	var built := 6 * SteelButton.HEIGHT + 5 * SteelMenu.GAP + 2.0 * SteelMenu.ORNAMENT
	ok(built <= BattleHud.BOTTOM_BAND, "the menu is built to fit the HUD's bottom band (%.0f of %d px)" % [built, BattleHud.BOTTOM_BAND])
	ok(not pal._plaque.visible, "the plaque is gone while commands show: the unit is on the Acting card")
	# the list takes the bars' place: bars out, list in; Back brings the bars back
	pal.open_list("abilities")
	ok(pal.menu.visible and not pal._commands.visible, "Abilities opens in the bars' place, not stacked over them")
	for i in 3:
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	ok(pal.menu.modulate.a > 0.99, "the list has faded fully in after the slide")
	pal.back_button.pressed.emit()
	ok(pal._commands.visible and not pal.menu.visible, "Back brings the command bars back")
	await get_tree().create_timer(0.3).timeout
	ok(pal._commands.modulate.a > 0.99, "the bars have faded fully back in")
	b.queue_free()
