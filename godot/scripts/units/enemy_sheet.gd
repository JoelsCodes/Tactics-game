class_name EnemySheet
extends RefCounted
## Universal enemy archetypes, levels 1-99 (owner, Nov 2026: "study Final Fantasy Tactics' enemy stat system and create a sheet we can pull from, level
## 1-99, e.g. a universal Mage enemy we can use for mage enemies"). Any map can ask for `EnemySheet.make("mage", 40, ...)` and get a Battle-Mage built
## for level 40, instead of writing a KINDS entry by hand for each chapter. The full table is docs/enemy_sheet.csv (written from this file by
## tools/export_enemy_sheet.gd); docs/ENEMY_SHEET.md explains it.
##
## How Final Fantasy Tactics does it, and how this follows it:
##   * In FFT an enemy is built exactly like a party unit: a job, a level near the party's, and stats from the same rules. There is no separate enemy table.
##   * Every unit has hidden "raw" stats. Each level-up adds raw / (C + level), where C is the job's growth constant for that stat (lower C = faster
##     growth). That product telescopes: after levelling from 1 to L, raw is raw_1 x (C + L) / (C + 1) - a straight line in the level.
##   * The job's multiplier then turns raw into the number shown (a Knight's PA multiplier is high, a Wizard's MA multiplier is high). Move and Jump are
##     fixed per job. Speed has a big C, so it barely grows; HP and MP have a small C, so they grow fastest.
##   * Our party already grows by FFT's law: +5% of the starting value a level (CharacterStats.GROWTH) is (C + L) / (C + 1) with C = 19, Speed's 1.5% is C ~ 66.
## So here: stat(L) = round(BASE[stat] x multiplier x (C + L) / (C + 1)), with each archetype's multiplier (its job multiplier) and growth grade (its C)
## per stat. Grades: S 13, A 16, B 19 (the party's own rate), C 24, D 32; Speed: f(ast) 45, n(ormal) 66 (the party's), s(low) 95. A level-L archetype is
## a peer of a level-L party member, as in FFT: the same yardstick at every level.
##
## HP is the one number fitted to this game rather than to FFT: our damage is scaled up (DamageFormula.DAMAGE_SCALE) and HP down (HP_SCALE) for a fast
## pace, so two pure peers would down each other in about one blow at level 1. The design aim is "three to five good blows" (DamageFormula), so a
## soldier's HP at level L is BLOWS of the King's basic blows at level L (the King as he grows: CharacterStats defaults, weapon 8), and each archetype's
## HP is that times its multiplier, shaped by its HP grade. It is the number shown in battle, kept as written (CharacterStats.sheet_hp): the chapters'
## enemy HP rules (the 300 cap, the level curve) and their attack ramp (DamageFormula.ramp) are for hand-written KINDS that do not grow, and would
## double-count here. Level-1 Attack and Magic are the level of the chapters' early enemies after their tuning (a soldier's 5, a mage's 11).

const BASE := {"atk": 5.0, "def": 6.0, "mag": 7.5, "res": 5.0, "spd": 6.0, "will": 8.0}
const BLOWS := 4.0  ## a soldier takes this many of the King's basic blows at its own level
const KING := {"hp": 60.0, "atk": 6.0, "def": 5.0, "weapon": 8}  ## the King at level 1 (CharacterStats defaults; the sample party's weapon power)
const GRADE := {"S": 13.0, "A": 16.0, "B": 19.0, "C": 24.0, "D": 32.0, "f": 45.0, "n": 66.0, "s": 95.0}
const STATS := ["hp", "atk", "def", "mag", "res", "spd", "will"]

## One entry per archetype: "name", "family", "role" (EnemyData.ai_role), "mult" (hp atk def mag res spd will, like FFT's job multipliers),
## "grow" (the growth grade of each, in the same order), "move", "jump", "exp" (a multiplier on the XP yardstick), "skills" (rank E/D skills from
## SkillLibrary; a map may give its own). "boss" marks the one archetype written as a boss.
const ARCHETYPES := {
	# ---- people (FFT's generic jobs)
	"soldier": {"name": "Soldier", "family": "people", "role": "", "mult": [1.0, 1.0, 1.0, 0.4, 0.8, 1.0, 0.9], "grow": "BBBDCnC", "move": 4, "jump": 2, "exp": 1.0,
		"skills": ["Quick Jab", "Crescent Strike", "Shield Prod"]},  # FFT Squire: even, no magic
	"knight": {"name": "Knight", "family": "people", "role": "guardian", "mult": [1.3, 1.15, 1.6, 0.3, 0.9, 0.6, 0.9], "grow": "ABADCsC", "move": 3, "jump": 1, "exp": 1.25,
		"skills": ["Shield Prod", "Shoulder Barge", "Grip Loosen"]},  # Knight: HP and PA high, slow, heavy armour
	"archer": {"name": "Archer", "family": "people", "role": "skirmisher", "mult": [0.85, 1.05, 0.7, 0.4, 0.8, 1.15, 1.0], "grow": "BACDCfB", "move": 4, "jump": 3, "exp": 1.0,
		"skills": ["Pin Down", "Hamstring Cut", "Dirty Sand Kick"]},
	"brawler": {"name": "Brawler", "family": "people", "role": "brute", "mult": [1.25, 1.2, 0.9, 0.3, 0.8, 1.05, 1.0], "grow": "SABDCnB", "move": 4, "jump": 3, "exp": 1.1,
		"skills": ["Quick Jab", "Twin Strike", "Stunning Blow"]},  # Monk: the best HP growth among people
	"thief": {"name": "Thief", "family": "people", "role": "skirmisher", "mult": [0.8, 0.95, 0.7, 0.4, 0.8, 1.35, 1.0], "grow": "CBCDCfB", "move": 5, "jump": 4, "exp": 1.0,
		"skills": ["Feinting Lunge", "Step-Aside Strike", "Dirty Sand Kick"]},  # Thief: Speed's growth is the job's point
	"mage": {"name": "Battle-Mage", "family": "people", "role": "caster", "mult": [0.7, 0.4, 0.6, 1.5, 1.15, 1.0, 1.6], "grow": "CDCSAnA", "move": 4, "jump": 2, "exp": 1.1,
		"skills": ["Ember Flick", "Frost Prick", "Static Snap", "Fireball"]},  # Wizard: MA x1.5, fragile
	"healer": {"name": "Healer", "family": "people", "role": "support", "mult": [0.8, 0.45, 0.75, 1.25, 1.3, 0.95, 1.8], "grow": "BDCASnS", "move": 4, "jump": 2, "exp": 1.1,
		"skills": ["Bandage Hat", "Hum a Tune", "Soak"]},  # Priest: resists magic, deep SP
	"hexer": {"name": "Hexer", "family": "people", "role": "support", "mult": [0.75, 0.4, 0.65, 1.3, 1.25, 1.05, 1.7], "grow": "CDCAAnA", "move": 4, "jump": 2, "exp": 1.1,
		"skills": ["Hush", "Lullaby", "Slow Spell", "Itch Powder"]},  # Time Mage / Oracle: status
	"summoner": {"name": "Summoner", "family": "people", "role": "caster", "mult": [0.7, 0.35, 0.6, 1.6, 1.2, 0.8, 1.8], "grow": "CDCAAsA", "move": 3, "jump": 2, "exp": 1.3,
		"skills": ["Fireball", "Chain Spark", "Frost Lance"]},  # Summoner: the biggest MA, the slowest
	"lancer": {"name": "Lancer", "family": "people", "role": "", "mult": [1.1, 1.15, 1.15, 0.3, 0.8, 0.95, 0.9], "grow": "BABDCnC", "move": 4, "jump": 4, "exp": 1.15,
		"skills": ["Hamstring Cut", "Rending Cut", "Pin Down"]},  # Lancer / Dragoon: armour and the high jump
	"duelist": {"name": "Duelist", "family": "people", "role": "skirmisher", "mult": [1.0, 1.2, 0.9, 0.7, 1.0, 1.05, 1.1], "grow": "BABCBnB", "move": 4, "jump": 3, "exp": 1.2,
		"skills": ["Feinting Lunge", "Twin Strike", "Rending Cut"]},  # Samurai: strong blade, some magic
	"assassin": {"name": "Assassin", "family": "people", "role": "skirmisher", "mult": [0.8, 1.15, 0.65, 0.4, 0.75, 1.45, 1.0], "grow": "CADDCfB", "move": 5, "jump": 4, "exp": 1.2,
		"skills": ["Twin Strike", "Hamstring Cut", "Step-Aside Strike"]},  # Ninja: the fastest, glass
	"spellblade": {"name": "Spellblade", "family": "people", "role": "", "mult": [1.0, 1.0, 0.95, 1.0, 1.0, 1.0, 1.1], "grow": "BBBBBnB", "move": 4, "jump": 3, "exp": 1.15,
		"skills": ["Crescent Strike", "Static Snap", "Frost Lance"]},  # Geomancer: even blade and spell
	"commander": {"name": "Commander", "family": "people", "role": "support", "mult": [1.0, 0.9, 0.9, 0.8, 1.0, 0.95, 1.5], "grow": "BBBCBnA", "move": 4, "jump": 2, "exp": 1.3,
		"skills": ["Feinting Lunge", "Shield Prod", "Bonk"]},  # Orator: leads, talks, holds
	"chanter": {"name": "Chanter", "family": "people", "role": "support", "mult": [0.75, 0.5, 0.6, 1.1, 1.1, 1.0, 1.7], "grow": "CDCBAnS", "move": 4, "jump": 2, "exp": 1.1,
		"skills": ["Hum a Tune", "Lullaby", "Hush"]},  # Bard / Dancer: songs, poor body
	"berserker": {"name": "Berserker", "family": "people", "role": "brute", "mult": [1.4, 1.4, 0.7, 0.2, 0.6, 0.95, 0.7], "grow": "SSCDDnD", "move": 4, "jump": 2, "exp": 1.2,
		"skills": ["Wild Swing", "Rending Cut", "Shoulder Barge"]},  # all PA and HP
	"crossbow": {"name": "Crossbowman", "family": "people", "role": "skirmisher", "mult": [0.85, 1.2, 0.75, 0.3, 0.8, 0.9, 0.9], "grow": "BACDCnC", "move": 3, "jump": 2, "exp": 1.05,
		"skills": ["Pin Down", "Cripple", "Hamstring Cut"]},  # Gunner: hits hard from range, slow to move
	"alchemist": {"name": "Alchemist", "family": "people", "role": "support", "mult": [0.85, 0.7, 0.75, 0.9, 1.0, 1.05, 1.3], "grow": "BCCBBnB", "move": 4, "jump": 2, "exp": 1.0,
		"skills": ["Bandage Hat", "Poison Spit", "Itch Powder"]},  # Chemist: items and poisons
	"darkknight": {"name": "Dark Knight", "family": "people", "role": "brute", "mult": [1.2, 1.2, 1.2, 1.1, 0.9, 0.9, 1.2], "grow": "AABBCnB", "move": 4, "jump": 2, "exp": 1.4,
		"skills": ["Hollow Touch", "Rending Cut", "Null Pulse"]},  # a late elite: blade and void
	# ---- monsters (FFT's monster families: fixed jobs of their own)
	"beast": {"name": "Beast", "family": "monster", "role": "skirmisher", "mult": [0.95, 1.1, 0.6, 0.2, 0.6, 1.3, 0.8], "grow": "BACDDfC", "move": 5, "jump": 3, "exp": 0.9,
		"skills": ["Hamstring Cut", "Crescent Strike"]},  # wolves, hounds, panthers
	"flyer": {"name": "Flyer", "family": "monster", "role": "skirmisher", "mult": [0.75, 0.95, 0.55, 0.5, 0.8, 1.4, 0.9], "grow": "CBDCCfC", "move": 6, "jump": 5, "exp": 0.95,
		"skills": ["Step-Aside Strike", "Hamstring Cut", "Dirty Sand Kick"]},  # birds, bats, moths
	"drake": {"name": "Drake", "family": "monster", "role": "brute", "mult": [1.5, 1.3, 1.2, 1.0, 1.0, 0.95, 1.0], "grow": "SAABBnB", "move": 4, "jump": 3, "exp": 1.6,
		"skills": ["Wild Swing", "Fireball", "Rending Cut"]},  # dragons and wyverns: big on everything
	"construct": {"name": "Construct", "family": "monster", "role": "guardian", "mult": [1.6, 1.2, 1.7, 0.2, 0.6, 0.5, 0.6], "grow": "ABSDDsD", "move": 3, "jump": 1, "exp": 1.3,
		"skills": ["Shoulder Barge", "Stunning Blow", "Grip Loosen"]},  # golems, statues, machines: a wall
	"ooze": {"name": "Ooze", "family": "monster", "role": "", "mult": [1.3, 0.7, 1.2, 0.6, 0.5, 0.5, 0.8], "grow": "ACACDsC", "move": 3, "jump": 1, "exp": 0.8,
		"skills": ["Grip Loosen", "Poison Spit"]},  # slimes: soaks blows, weak to magic
	"undead": {"name": "Undead", "family": "monster", "role": "brute", "mult": [1.15, 1.05, 0.9, 0.4, 0.6, 0.7, 0.6], "grow": "ABBDDsD", "move": 3, "jump": 2, "exp": 0.9,
		"skills": ["Rending Cut", "Cripple", "Grip Loosen"]},  # skeletons, ghouls
	"wraith": {"name": "Wraith", "family": "monster", "role": "caster", "mult": [0.7, 0.4, 0.5, 1.35, 1.4, 1.1, 1.4], "grow": "CDDASnA", "move": 5, "jump": 4, "exp": 1.15,
		"skills": ["Hollow Touch", "Dim Light", "Null Pulse"]},  # ghosts: magic in and out, no body
	"fungus": {"name": "Fungus", "family": "monster", "role": "caster", "mult": [1.0, 0.6, 0.9, 0.9, 0.9, 0.5, 1.0], "grow": "BCBBBsB", "move": 3, "jump": 1, "exp": 0.85,
		"skills": ["Spark Sneeze", "Itch Powder", "Poison Spit"]},  # spore caps, plants: status from where they stand
	"shellback": {"name": "Shellback", "family": "monster", "role": "guardian", "mult": [1.0, 1.0, 1.4, 0.2, 0.7, 0.75, 0.7], "grow": "BBADCsC", "move": 3, "jump": 2, "exp": 0.9,
		"skills": ["Shield Prod", "Cripple", "Grip Loosen"]},  # crabs, beetles, tortoises
	"fiend": {"name": "Fiend", "family": "monster", "role": "caster", "mult": [1.2, 1.0, 0.9, 1.45, 1.2, 1.1, 1.4], "grow": "ABBSAnA", "move": 4, "jump": 3, "exp": 1.6,
		"skills": ["Fireball", "Chain Spark", "Hollow Touch"]},  # demons: a monster that casts like a mage
	# ---- the boss (FFT's Lucavi: a job of its own, everything high and three times the HP)
	"tyrant": {"name": "Tyrant", "family": "boss", "role": "", "boss": true, "mult": [3.0, 1.3, 1.25, 1.3, 1.25, 1.05, 1.5], "grow": "AAAAAnA", "move": 4, "jump": 3, "exp": 4.0,
		"skills": ["Feinting Lunge", "Twin Strike", "Rending Cut", "Fireball", "Pin Down"]},
}


static func has(arch: String) -> bool:
	return ARCHETYPES.has(arch)


static func names() -> Array:
	return ARCHETYPES.keys()


## (C + level) / (C + 1): FFT's raw growth from level 1 to `level` for growth constant C.
static func growth(c: float, level: int) -> float:
	return (c + float(level)) / (c + 1.0)


## The King's basic blow at `level` on a soldier of that level, as the battle works it out (DamageFormula.mitigate x DAMAGE_SCALE): his Attack grows
## by the party's law (C 19), the soldier's Defense by FFT's (BASE x (C + L) / (C + 1), grade B).
static func king_blow(level: int) -> float:  # unrounded, so the yardstick rises smoothly with the level
	var atk := float(KING.atk) * growth(19.0, level)
	var def := float(BASE.def) * growth(19.0, level)
	return (float(KING.weapon) + atk) * 100.0 / (100.0 + DamageFormula.DEFENSE_K * def) * DamageFormula.DAMAGE_SCALE / 100.0


## A soldier's HP at `level`: BLOWS of the King's blows.
static func hp_yardstick(level: int) -> float:
	return BLOWS * king_blow(level)


## One row of the sheet: every number of `arch` at `level` (1-99), as shown in battle. Keys: hp atk def mag res spd will sp move jump exp.
static func row(arch: String, level: int) -> Dictionary:
	var a: Dictionary = ARCHETYPES[arch]
	var lv := clampi(level, 1, 99)
	var g: String = a.grow
	var r := {}
	for i in STATS.size():
		var st: String = STATS[i]
		var c := float(GRADE[g[i]])
		if st == "hp":  # the yardstick at this level, times the multiplier, shaped by the grade against the party's own rate (B); the shape at half
			# strength, since the yardstick itself rises slowly (mitigation grows with Defense) and a slow grade must not make HP fall
			var v := hp_yardstick(lv) * float(a.mult[i]) * sqrt(growth(c, lv) / growth(19.0, lv))
			r[st] = clampi(roundi(v), 1, 999)
		else:
			r[st] = clampi(roundi(float(BASE[st]) * float(a.mult[i]) * growth(c, lv)), 1 if st == "spd" else 0, 99)
	r["sp"] = mini(30, roundi((CharacterStats.SP_BASE + float(r.will) * 0.5 + float(r.mag) * 0.25)))
	r["move"] = int(a.move)
	r["jump"] = int(a.jump)
	r["exp"] = mini(999, roundi(float(a.exp) * (20.0 + 5.0 * lv)))  # the XP yardstick: about a fifth of a level's XP for a peer (ExperienceCurve)
	return r


## A ready enemy of `arch` at `level`. `name` overrides the archetype's name ("Royal Mage" for a mage); `skills` overrides its skills;
## `tune` takes a map's tuning like the chapters' TUNE: "hp" multiplies HP, "atk" and "mag" are added.
static func make(arch: String, level: int, id: StringName, name := "", skills: Array = [], tune := {}) -> EnemyData:
	var a: Dictionary = ARCHETYPES[arch]
	var r := row(arch, level)
	var e := EnemyData.new()
	e.id = id
	e.display_name = name if name != "" else String(a.name)
	var c := CharacterStats.new()
	c.display_name = e.display_name
	c.level = clampi(level, 1, 99)
	c.sheet_hp = maxi(1, roundi(float(r.hp) * float(tune.get("hp", 1.0))))
	c.base_max_hp = clampi(int(r.hp), 25, 100)  # unused while sheet_hp is set; kept in its range
	c.attack = maxi(0, int(r.atk) + int(tune.get("atk", 0)))
	c.defense = int(r.def)
	c.magic = maxi(0, int(r.mag) + int(tune.get("mag", 0)))
	c.resistance = int(r.res)
	c.speed = int(r.spd)
	c.will = int(r.will)
	c.move = int(r.move)
	c.jump = int(r.jump)
	c.grows = false
	e.stats = c
	e.skills_only = true
	for sk in (skills if not skills.is_empty() else a.skills):
		var s := SkillLibrary.find(String(sk))
		if s != null:
			e.skills.append(s)
	e.exp_reward = int(r.exp)
	e.ai_role = String(a.role)
	var style := WeaponStyle.new()
	style.geometry = TacticalMath.Geometry.ROOK
	e.loadout = EquipmentLoadout.make(WeaponItem.new(), style)
	return e
