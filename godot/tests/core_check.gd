extends Node
## Headless checks for the data layer (scripts/core): godot --headless --path godot res://tests/core_check.tscn

var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s: got %s, want %s" % [what, a, b])


func _ready() -> void:
	math()
	proficiency()
	stats_and_loadout()
	save_load()
	print("core checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func math() -> void:
	eq(TacticalMath.multiplier(0), 1.0, "mult 0")
	ok(is_equal_approx(TacticalMath.multiplier(50), 2.0), "mult 50")
	ok(is_equal_approx(TacticalMath.multiplier(99), 2.98), "mult 99")
	ok(is_equal_approx(TacticalMath.multiplier(150), 2.98), "mult clamps above 99")
	eq(TacticalMath.multiplier(-5), 1.0, "mult clamps below 0")
	eq(TacticalMath.scale(10, 25), 15, "scale")
	eq(TacticalMath.add_progress(3, 90, 25), Vector2i(4, 15), "bar carries")
	eq(TacticalMath.add_progress(0, 0, 250), Vector2i(2, 50), "two bars")
	eq(TacticalMath.add_progress(98, 50, 80), Vector2i(99, 0), "stops at 99")
	eq(TacticalMath.add_progress(99, 0, 50), Vector2i(99, 0), "no progress at 99")
	eq(TacticalMath.proficiency_gain(TacticalMath.Rank.S), 20, "S gain")
	eq(TacticalMath.proficiency_gain(TacticalMath.Rank.F), 4, "F gain")
	eq(TacticalMath.proficiency_gain(TacticalMath.Rank.D), 7, "D gain")
	eq(TacticalMath.proficiency_gain(TacticalMath.Rank.F, .1), 1, "gain at least 1")
	eq(TacticalMath.proficiency_gain(TacticalMath.Rank.C, 1.25), 13, "efficiency scales gain")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var seen := {}
	for i in 2000:
		seen[TacticalMath.roll_gain(TacticalMath.Rank.S, 1.0, rng)] = true
	eq(seen.keys().map(func(k): return k).reduce(func(a, b): return mini(a, b)), 17, "S rolls as low as 17")
	eq(seen.keys().reduce(func(a, b): return maxi(a, b)), 20, "S rolls up to 20")
	eq(seen.size(), 4, "S rolls 17, 18, 19 or 20")
	seen = {}
	for i in 2000:
		seen[TacticalMath.roll_gain(TacticalMath.Rank.F, 1.0, rng)] = true
	eq(seen.size(), 4, "F rolls 1-4")
	ok(not seen.has(0), "never 0")
	seen = {}
	for i in 500:
		seen[TacticalMath.roll_gain(TacticalMath.Rank.F, .1, rng)] = true
	eq(seen.keys(), [1], "at least 1 even when the gain is tiny")
	eq(TacticalMath.uses_per_level(TacticalMath.Rank.C), 10, "C uses per level")
	eq(TacticalMath.rank_from_letter("b"), TacticalMath.Rank.B, "rank letter")
	eq(TacticalMath.geometry_offsets(TacticalMath.Geometry.ROOK, 3).size(), 12, "rook 3")
	eq(TacticalMath.geometry_offsets(TacticalMath.Geometry.BISHOP, 2).size(), 8, "bishop 2")
	eq(TacticalMath.geometry_offsets(TacticalMath.Geometry.QUEEN, 2).size(), 16, "queen 2")
	eq(TacticalMath.geometry_offsets(TacticalMath.Geometry.KNIGHT, 5).size(), 8, "knight ignores reach")
	eq(TacticalMath.geometry_offsets(TacticalMath.Geometry.KING, 5).size(), 8, "king one step")
	eq(TacticalMath.geometry_rays(TacticalMath.Geometry.ROOK, 3)[0], [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)], "ray order")
	var mods: Array[StatModifier] = [StatModifier.make(StatModifier.Stat.ATTACK, 2), StatModifier.make(StatModifier.Stat.ATTACK, 0, 50), StatModifier.make(StatModifier.Stat.MOVE, -1)]
	eq(TacticalMath.apply_modifiers(6, StatModifier.Stat.ATTACK, mods), 12.0, "flat then percent")
	eq(StatModifier.make(StatModifier.Stat.MAX_SP, 0, -20).describe(), "Max Sp -20%", "describe")


func proficiency() -> void:
	eq(TacticalMath.RANK_LETTERS, ["S", "A", "B", "C", "D", "F"], "ranks S A B C D F")
	var c := CharacterStats.new()
	for cat in Proficiency.all():
		eq(c.rank_of(cat), TacticalMath.Rank.C, "default rank C")
	c.set_rank(Proficiency.Category.VOID, TacticalMath.Rank.S)
	eq(c.rank_of(Proficiency.Category.VOID), TacticalMath.Rank.S, "set rank")
	eq(c.skill_gain(Proficiency.Category.VOID), 20, "S gain")
	eq(c.skill_gain(Proficiency.Category.HEALING), 10, "C gain")
	c.proficiency_efficiency = 1.5
	eq(c.skill_gain(Proficiency.Category.HEALING), 15, "efficiency scales the gain")
	var m := SkillMastery.make(SkillData.new())
	m.level = 1
	eq(m.add_progress(112), 1, "112 points: one level")
	eq(m.progress, 12, "leftover progress")
	ok(is_equal_approx(m.fill(), .12), "fill")
	m.level = 98
	m.add_progress(200)
	ok(m.is_maxed() and m.level == 99 and m.progress == 0, "skills max at 99")
	var s := SkillData.new()
	s.base_power = 10
	eq(s.power_at(0), 10, "skill power 0")
	eq(s.power_at(99), 30, "skill power 99")


func make_char(lv: int) -> CharacterStats:
	var c := CharacterStats.new()
	c.level = lv
	return c


func stats_and_loadout() -> void:
	# scale: default character (base HP 60, will 6, magic 5)
	eq(make_char(0).level, 1, "characters start at level 1 (0 is clamped up)")
	eq(make_char(1).max_hp(), 61, "hp lv1: 60 x 1.02")
	eq(make_char(50).max_hp(), 120, "hp lv50")
	eq(make_char(1).max_sp(), 9, "sp lv1")  # (5 + 3 + 1.25) x 1.02 = 9.4
	eq(make_char(50).max_sp(), 19, "sp lv50")
	var big := make_char(99)
	big.base_max_hp = 100
	big.will = 30
	big.magic = 30
	eq(big.max_hp(), 298, "hp at most ~300")
	eq(big.max_sp(), 30, "sp capped at 30")

	var w := WeaponItem.new()
	w.base_power = 8
	var style := WeaponStyle.new()
	style.geometry = TacticalMath.Geometry.BISHOP
	style.stance = WeaponStyle.Stance.PIERCE
	var l := EquipmentLoadout.make(w, style)
	eq(l.weapon_power(), 8, "weapon power")
	eq(w.tier_name(), "Raw", "tier 0")
	eq(w.smith_upgrade(30), 30, "smith")
	eq(l.weapon_power(), 13, "smithed power")
	eq(w.tier_name(), "Tempered", "tier 1")
	w.smith_upgrade(200)
	eq(w.smith_level, 99, "smith caps")
	eq(w.tier_name(), "Masterwork", "masterwork")

	var other := WeaponItem.new()
	l.main_weapon = other  # refused (prints an error)
	ok(l.main_weapon == w, "main weapon cannot be swapped")
	ok(not l.can_equip(EquipmentLoadout.Slot.MAIN_WEAPON, other), "main weapon slot not player-changeable")
	ok(not l.can_equip(EquipmentLoadout.Slot.RELIC_SLOT_1, style), "relic slot takes only relics")

	var r1 := RelicItem.new()
	r1.display_name = "Shattered Banner"
	var sk := SkillData.new()
	sk.id = &"rally"
	r1.skill = sk
	r1.passives = [StatModifier.make(StatModifier.Stat.ATTACK, 2), StatModifier.make(StatModifier.Stat.WILL, 4)]
	r1.drawbacks = [StatModifier.make(StatModifier.Stat.MOVE, -1)]
	r1.sp_drain_per_turn = 1
	var r2 := RelicItem.new()
	r2.drawbacks = [StatModifier.make(StatModifier.Stat.MAX_SP, 0, -20)]
	r2.hp_drain_per_turn = 5
	eq(l.equip(EquipmentLoadout.Slot.RELIC_SLOT_1, r1), null, "equip relic 1")
	ok(not l.can_equip(EquipmentLoadout.Slot.RELIC_SLOT_2, r1), "same relic not in both slots")
	l.equip(EquipmentLoadout.Slot.RELIC_SLOT_2, r2)
	ok(r1.has_drawback(), "has drawback")
	eq(l.skills().size(), 1, "relic skills")
	eq(l.sp_drain_per_turn(), 1, "sp drain")
	eq(l.hp_drain_per_turn(), 5, "hp drain")

	var c := make_char(50)
	eq(c.final_stat(StatModifier.Stat.ATTACK, l), 8, "attack +2")
	eq(c.final_stat(StatModifier.Stat.MOVE, l), 3, "move -1")
	eq(c.final_stat(StatModifier.Stat.SPEED, l), 6, "a style changes no stats")
	eq(c.max_sp(l), 18, "will +4 then -20% sp")  # (5 + 10 / 2 + 5 / 4) x 2.0 = 22.5, x .8 = 18
	# Temp-Relic: never player-equipped; tethering fills it and its relic counts like the others
	var r3 := RelicItem.new()
	r3.passives = [StatModifier.make(StatModifier.Stat.DEFENSE, 3)]
	ok(not l.can_equip(EquipmentLoadout.Slot.TEMP_RELIC, r3), "Temp-Relic not player-equipped")
	l.tether_relic(r3)
	eq(c.final_stat(StatModifier.Stat.DEFENSE, l), 8, "temp relic passive applies")
	ok(not l.can_equip(EquipmentLoadout.Slot.RELIC_SLOT_1, r3), "tethered relic not also in a relic slot")
	eq(l.release_temp_relic(), r3, "release")
	ok(l.temp_relic == null and l.relic_slot_2 == r2, "release leaves the other slots")

	eq(EquipmentLoadout.SLOT_NAMES, ["Main Weapon", "Weapon Style", "Relic Slot 1", "Relic Slot 2", "Temp-Relic"], "slot names")
	eq(EquipmentLoadout.slot_type(EquipmentLoadout.Slot.TEMP_RELIC), ItemResource.ItemType.RELIC, "temp relic slot type")
	eq(EquipmentLoadout.slot_type(EquipmentLoadout.Slot.WEAPON_STYLE), ItemResource.ItemType.WEAPON_STYLE, "style slot type")
	ok(is_equal_approx(c.efficiency(), 1.0), "base efficiency")


func save_load() -> void:
	var c := make_char(12)
	c.display_name = "Ada"
	c.set_rank(Proficiency.Category.VOID, TacticalMath.Rank.S)
	var err := ResourceSaver.save(c, "user://core_check_char.tres")
	eq(err, OK, "save")
	var back: CharacterStats = ResourceLoader.load("user://core_check_char.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	ok(back != null and back.display_name == "Ada" and back.level == 12, "load stats")
	ok(back != null and back.rank_of(Proficiency.Category.VOID) == TacticalMath.Rank.S and back.rank_of(Proficiency.Category.PHYSICAL) == TacticalMath.Rank.C, "load ranks")
	var l := EquipmentLoadout.make(WeaponItem.new(), WeaponStyle.new())
	eq(ResourceSaver.save(l, "user://core_check_loadout.tres"), OK, "save loadout")
	var lb: EquipmentLoadout = ResourceLoader.load("user://core_check_loadout.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	ok(lb != null and lb.main_weapon != null and lb.weapon_style != null, "load loadout")
