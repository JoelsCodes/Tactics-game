class_name Skirmish
extends RefCounted
## The Proving Grounds (Claude, Nov 2026, for the owner's "smaller map class"; the place, its name and its fights are drafts the owner can rename or
## remove): three compact FFT-scale maps (samples/skirmish_1..3.json, tools/make_skirmish_maps.py, about 150 tiles against our chapters' 384) and the owner's
## 11x11 Last Benediction cathedral (pg_4: samples/last_benediction.json, tools/make_last_benediction_map.py, drawn from a GLB by Board3D's scenery mode) to
## replay at any time once the base is open. No story: four of the Riverford Watch's kinds (Riverford.KINDS) at the level the player picks, every
## map at five levels. What they give (XP, relics) is kept, like any replay.

const MAPS := {"pg_1": "res://samples/skirmish_1.json", "pg_2": "res://samples/skirmish_2.json", "pg_3": "res://samples/skirmish_3.json", "pg_4": "res://samples/last_benediction.json"}
const NAMES := {"pg_1": "Thistle Rise", "pg_2": "The Sunken Span", "pg_3": "Cinder Shrine", "pg_4": "The Last Benediction"}
const LEVELS: Array[int] = [3, 10, 20, 35, 55]  ## the enemies' level for each of a map's levels (1-based)


static func is_skirmish(map_id: String) -> bool:
	return MAPS.has(map_id)


## The battle on `map_id` at level `level` (1-based, LEVELS).
static func setup(map_id: String, level: int) -> BattleSetup:
	var path: String = MAPS[map_id]
	var sp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))["spawns"]
	var lv: int = LEVELS[clampi(level, 1, LEVELS.size()) - 1]
	var s := BattleSetup.new()
	s.map_path = path
	s.king_cell = Riverford.cell(sp["king"])
	s.captain_cell = Riverford.cell(sp["captain"])
	for c in sp["stones"]:
		s.relics.append([FirstBattle._stone(), Riverford.cell(c)])
	var i := 0
	for e in sp["enemies"]:
		i += 1
		s.enemies.append([enemy(String(e["kind"]), map_id, i, lv), Riverford.cell(e["at"])])
	s.objective = "Defeat every enemy"
	s.max_summons = 6
	return s


## One of the Watch's kinds at `lv`.
static func enemy(kind: String, map_id: String, i: int, lv: int) -> EnemyData:
	var k: Dictionary = Riverford.KINDS[kind]
	var e := EnemyData.new()
	e.id = StringName("%s_%s_%d" % [map_id, kind, i])
	e.display_name = k.name
	e.stats = Riverford.stats(kind, lv)
	e.skills_only = true
	for sk in k.skills:
		var s := SkillLibrary.find(sk)
		if s != null:
			e.skills.append(s)
	e.exp_reward = int(k.exp)
	var style := WeaponStyle.new()
	style.geometry = TacticalMath.Geometry.ROOK
	e.loadout = EquipmentLoadout.make(WeaponItem.new(), style)
	return e
