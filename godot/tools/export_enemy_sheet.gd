extends SceneTree
## Writes the universal enemy sheet (scripts/units/enemy_sheet.gd) out for reading: docs/enemy_sheet.csv (every archetype at every level 1-99, one
## row each) and docs/ENEMY_SHEET.md (how it works and each archetype at a few levels). Run after changing EnemySheet:
##   godot --headless --path godot --script res://tools/export_enemy_sheet.gd
const COLS := ["hp", "atk", "def", "mag", "res", "spd", "will", "sp", "move", "jump", "exp"]
const GLANCE := [1, 10, 20, 35, 55, 75, 99]


func _init() -> void:
	var csv := PackedStringArray(["archetype,name,family,role,level," + ",".join(COLS)])
	for arch in EnemySheet.names():
		var a: Dictionary = EnemySheet.ARCHETYPES[arch]
		for lv in range(1, 100):
			var r := EnemySheet.row(arch, lv)
			var cells := PackedStringArray([arch, a.name, a.family, a.role, str(lv)])
			for c in COLS:
				cells.append(str(r[c]))
			csv.append(",".join(cells))
	var f := FileAccess.open(ProjectSettings.globalize_path("res://docs/enemy_sheet.csv"), FileAccess.WRITE)
	f.store_string("\n".join(csv) + "\n")
	f.close()
	var md := PackedStringArray()
	md.append("# Universal enemy sheet (levels 1-99)")
	md.append("")
	md.append("Thirty enemy archetypes any map can pull from at any level: `EnemySheet.make(\"mage\", 40, &\"id\", \"Royal Mage\")` gives a Battle-Mage built for level 40. Source: `scripts/units/enemy_sheet.gd`; every level of every archetype is in `docs/enemy_sheet.csv` (written by `tools/export_enemy_sheet.gd`, which also writes this page). Checked by `tests/enemy_sheet_check.tscn`.")
	md.append("")
	md.append("## How it works (after Final Fantasy Tactics)")
	md.append("")
	md.append("- **Enemies are built like the party.** In FFT an enemy is a unit with a job and a level near the party's, made by the same rules as your own units. Here each archetype is a job: a multiplier per stat (FFT's job multipliers: a Knight's high PA, a Wizard's high MA) and a growth grade per stat.")
	md.append("- **Growth is FFT's law.** FFT adds raw / (C + level) to a hidden raw stat at each level-up (C is the job's growth constant: lower grows faster). From level 1 to L that multiplies the stat by (C + L) / (C + 1), a straight line in the level. Our party already grows exactly this way: +5% of the starting value a level is C = 19. Grades: **S** 13, **A** 16, **B** 19 (the party's rate), **C** 24, **D** 32; Speed: **f** 45, **n** 66 (the party's), **s** 95.")
	md.append("- **Stat at level L** = base x multiplier x (C + L) / (C + 1). Base at level 1 (multiplier 1.0): Attack 5, Defense 6, Magic 7.5, Resistance 5, Speed 6, Will 8 (the chapters' early enemies, after their tuning). Move and Jump are fixed per archetype, as per FFT job.")
	md.append("- **HP is fitted to this game's pace.** Damage here is scaled up and HP down, so two pure peers would down each other in about one blow. The aim is three to five good blows, so a soldier's HP at level L is four of the King's basic blows at level L (the King as he grows, weapon power 8); each archetype's HP is that times its HP multiplier, shaped by its HP grade. HP is the number shown in battle; sheet enemies skip the chapters' enemy HP cap and curve and their attack ramp (those are for hand-written enemies that do not grow).")
	md.append("- **SP** comes from Will and Magic as for everyone; **EXP** is the archetype's multiplier x (20 + 5 x level).")
	md.append("- **Pace it gives:** the King downs a soldier of his own level in about 4 blows at every level. A soldier downs the King in about 1.2 blows at level 1, 2 at 20, 3 at 55 and 4 at 99 (the early levels are deadly, as the chapters' first enemies are; a map can soften it with `tune`, e.g. `{\"atk\": -2}`).")
	md.append("")
	md.append("## The archetypes")
	md.append("")
	md.append("| key | name | family | role | HP | Atk | Def | Mag | Res | Spd | Will | growth (HP Atk Def Mag Res Spd Will) | Move | Jump | EXP x | skills |")
	md.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for arch in EnemySheet.names():
		var a: Dictionary = EnemySheet.ARCHETYPES[arch]
		var m: Array = a.mult
		md.append("| `%s` | %s | %s | %s | x%s | x%s | x%s | x%s | x%s | x%s | x%s | %s | %d | %d | %s | %s |" % [arch, a.name, a.family, a.role if a.role != "" else "-",
			m[0], m[1], m[2], m[3], m[4], m[5], m[6], " ".join(String(a.grow).split("")), a.move, a.jump, a.exp, ", ".join(a.skills)])
	md.append("")
	md.append("## At a glance (HP / Atk / Def / Mag / Res / Spd)")
	md.append("")
	var head := "| archetype |"
	var rule := "|---|"
	for lv in GLANCE:
		head += " Lv %d |" % lv
		rule += "---|"
	md.append(head)
	md.append(rule)
	for arch in EnemySheet.names():
		var line := "| %s |" % EnemySheet.ARCHETYPES[arch].name
		for lv in GLANCE:
			var r := EnemySheet.row(arch, lv)
			line += " %d / %d / %d / %d / %d / %d |" % [r.hp, r.atk, r.def, r.mag, r.res, r.spd]
		md.append(line)
	md.append("")
	md.append("## Using it")
	md.append("")
	md.append("```gdscript")
	md.append("# a level-40 mage under a map's own name, with the archetype's skills")
	md.append("var e := EnemySheet.make(\"mage\", 40, &\"crown_3_mage_1\", \"Royal Mage\")")
	md.append("# other skills, and a map's tuning (HP x0.8, Attack -2)")
	md.append("var k := EnemySheet.make(\"knight\", 40, &\"crown_3_knight_1\", \"Crown Knight\", [\"Shield Prod\", \"Pin Down\"], {\"hp\": 0.8, \"atk\": -2})")
	md.append("# just the numbers")
	md.append("var r := EnemySheet.row(\"thief\", 25)  # {hp, atk, def, mag, res, spd, will, sp, move, jump, exp}")
	md.append("```")
	md.append("")
	md.append("Nothing in the game uses the sheet yet: the chapters and the Proving Grounds still build their enemies from their own KINDS. Moving a map over is a one-line change per enemy.")
	f = FileAccess.open(ProjectSettings.globalize_path("res://docs/ENEMY_SHEET.md"), FileAccess.WRITE)
	f.store_string("\n".join(md) + "\n")
	f.close()
	print("wrote docs/enemy_sheet.csv (%d rows) and docs/ENEMY_SHEET.md" % (csv.size() - 1))
	quit(0)
