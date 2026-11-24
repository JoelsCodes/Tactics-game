extends Node
## Headless: the universal enemy sheet (EnemySheet). Thirty archetypes, every one with stats for levels 1-99 that grow with the level (never shrink),
## stay inside the stat limits, and keep their character (a mage's Magic over its Attack, a knight's Defense over a thief's). A level-L soldier and a
## level-L party fighter (the party's own growth) trade blows evenly at every level, as in Final Fantasy Tactics, where enemies are built like the party.
## Every listed skill exists. make() builds an enemy whose HP is the sheet's, with no enemy HP cap, curve or attack ramp.
## godot --headless --path godot res://tests/enemy_sheet_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s (got %s, want %s)" % [what, a, b])


func _ready() -> void:
	DamageFormula.legacy_numbers(false)
	eq(EnemySheet.names().size(), 30, "thirty archetypes")
	for arch in EnemySheet.names():
		var a: Dictionary = EnemySheet.ARCHETYPES[arch]
		eq(a.mult.size(), 7, "%s: seven multipliers" % arch)
		eq(String(a.grow).length(), 7, "%s: seven growth grades" % arch)
		for sk in a.skills:
			ok(SkillLibrary.find(String(sk)) != null, "%s: skill %s exists" % [arch, sk])
		var prev := {}
		var grew := true
		var inside := true
		for lv in range(1, 100):
			var r := EnemySheet.row(arch, lv)
			for st in ["hp", "atk", "def", "mag", "res", "spd", "will", "exp"]:
				if not prev.is_empty() and int(r[st]) < int(prev[st]):
					grew = false
			for st in ["atk", "def", "mag", "res", "spd", "will"]:
				if int(r[st]) < 0 or int(r[st]) > 99:
					inside = false
			if int(r.hp) < 1 or int(r.hp) > 999 or int(r.sp) > 30:
				inside = false
			prev = r
		ok(grew, "%s: no stat goes down as the level goes up" % arch)
		ok(inside, "%s: every stat inside the game's limits, levels 1-99" % arch)
	# their character holds at every level
	for lv in [1, 20, 50, 99]:
		var m := EnemySheet.row("mage", lv)
		var k := EnemySheet.row("knight", lv)
		var t := EnemySheet.row("thief", lv)
		ok(int(m.mag) > int(m.atk) * 2, "level %d: the mage's Magic is far over its Attack" % lv)
		ok(int(k.def) > int(t.def), "level %d: the knight is better armoured than the thief" % lv)
		ok(int(t.spd) > int(k.spd), "level %d: the thief is faster than the knight" % lv)
		ok(int(EnemySheet.row("tyrant", lv).hp) >= 2 * int(EnemySheet.row("soldier", lv).hp), "level %d: the boss has at least twice a soldier's HP" % lv)
	# the pace at every level: the King (as he grows) needs about BLOWS basic blows to down a soldier of his level; the soldier's own blows on him
	# are printed (early levels are deadly by the owner's design, as the chapters' first enemies are)
	for lv in [1, 5, 10, 20, 35, 55, 75, 99]:
		var p := CharacterStats.new()
		p.level = lv
		var s := EnemySheet.row("soldier", lv)
		var weapon := 8
		var p_hit := DamageFormula.mitigate(weapon + p.final_stat(StatModifier.Stat.ATTACK), int(s.def)) * DamageFormula.DAMAGE_SCALE / 100.0
		var s_hit := DamageFormula.mitigate(weapon + int(s.atk), p.final_stat(StatModifier.Stat.DEFENSE)) * DamageFormula.DAMAGE_SCALE / 100.0
		var to_down_soldier := float(s.hp) / p_hit
		var to_down_party := float(p.max_hp()) / s_hit
		print("level %2d  soldier hp %3d atk %2d def %2d | party hp %3d atk %2d def %2d | blows: party downs soldier %.1f, soldier downs party %.1f"
			% [lv, s.hp, s.atk, s.def, p.max_hp(), p.final_stat(StatModifier.Stat.ATTACK), p.final_stat(StatModifier.Stat.DEFENSE), to_down_soldier, to_down_party])
		ok(to_down_soldier >= 3.5 and to_down_soldier <= 4.5, "level %d: the King downs a soldier of his level in about four blows (%.1f)" % [lv, to_down_soldier])
		ok(to_down_party >= 1.0 and to_down_party <= 6.0, "level %d: a soldier downs the King in 1-6 blows (%.1f)" % [lv, to_down_party])
	# make(): the enemy carries the sheet's numbers, keeps its HP past the old enemy cap, and gets no attack ramp
	var e := EnemySheet.make("mage", 60, &"sheet_mage_1", "Royal Mage")
	var r60 := EnemySheet.row("mage", 60)
	eq(e.display_name, "Royal Mage", "a name of the map's own")
	eq(e.stats.level, 60, "made at its level")
	eq(e.stats.max_hp(e.loadout), int(r60.hp), "its HP is the sheet's")
	eq(e.stats.final_stat(StatModifier.Stat.MAGIC, e.loadout), int(r60.mag), "its Magic is the sheet's")
	eq(e.ai_role, "caster", "a mage casts")
	ok(e.skills.size() > 0, "it has its skills")
	var boss := EnemySheet.make("tyrant", 99, &"sheet_boss")
	eq(boss.stats.max_hp(boss.loadout), int(EnemySheet.row("tyrant", 99).hp), "a level-99 boss keeps its full HP (no 300 cap)")
	var bu := BattleUnit.new(e, 1)
	eq(DamageFormula.ramp(bu), 1.0, "no attack ramp for a sheet enemy")
	var tuned := EnemySheet.make("soldier", 10, &"sheet_t", "", [], {"hp": 0.5, "atk": -2})
	eq(tuned.stats.max_hp(tuned.loadout), roundi(EnemySheet.row("soldier", 10).hp * 0.5), "a map's HP tuning applies")
	eq(tuned.stats.attack, int(EnemySheet.row("soldier", 10).atk) - 2, "a map's Attack tuning applies")
	print("enemy sheet checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)
