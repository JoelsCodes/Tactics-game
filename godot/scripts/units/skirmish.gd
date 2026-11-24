class_name Skirmish
extends RefCounted
## The Proving Grounds (Claude, Nov 2026, for the owner's "smaller map class"; the place, its name and its fights are drafts the owner can rename or
## remove): three compact FFT-scale maps (samples/skirmish_1..3.json, tools/make_skirmish_maps.py, about 150 tiles against our chapters' 384) and the owner's
## 10x24 Sacred Canal Bridge (pg_6: samples/sacred_canal.json, SacredCanalScenery) and the owner's
## Claude's Hollowmark maps pg_7..pg_29 (HollowmarkScenery: the Drowned Reliquary, the Last Terrace Garden, three train maps, the Colosseum, the Orrery and
## four thug hideouts: the Rat's Wharf, the Crooked Cellar, Blackrock Quarry and the Crow's Roost; four foggy swamps: the Drowned Chapel, Hangman's Fen, the Stilt Hollows and the Sunken Causeway; the Bog Sanctum, the owner's swamp boss arena; four sky islands: the Broken Stair, the Windward Colonnade, the Sky Harbor and the Crystal Spire; the Ashen Throne and the Sundered Ward, two final boss arenas), and the owner's
## 11x11 Last Benediction cathedral (pg_4: samples/last_benediction.json, tools/make_last_benediction_map.py, drawn from a GLB by Board3D's scenery mode) to
## replay at any time once the base is open. No story: four of the Riverford Watch's kinds (Riverford.KINDS) at the level the player picks, every
## map at five levels. What they give (XP, relics) is kept, like any replay.

const MAPS := {"pg_1": "res://samples/skirmish_1.json", "pg_2": "res://samples/skirmish_2.json", "pg_3": "res://samples/skirmish_3.json", "pg_4": "res://samples/last_benediction.json", "pg_6": "res://samples/sacred_canal.json", "pg_7": "res://samples/sluice_vault.json", "pg_8": "res://samples/last_terrace_garden.json", "pg_9": "res://samples/passenger_car.json", "pg_10": "res://samples/dining_car.json", "pg_11": "res://samples/train_station.json", "pg_12": "res://samples/colosseum.json", "pg_13": "res://samples/star_gazer.json", "pg_14": "res://samples/rats_wharf.json", "pg_15": "res://samples/crooked_cellar.json", "pg_16": "res://samples/blackrock_quarry.json", "pg_17": "res://samples/crows_roost.json", "pg_18": "res://samples/drowned_chapel.json", "pg_19": "res://samples/hangmans_fen.json", "pg_20": "res://samples/stilt_hollows.json", "pg_21": "res://samples/sunken_causeway.json", "pg_22": "res://samples/bog_sanctum.json", "pg_23": "res://samples/broken_stair.json", "pg_24": "res://samples/windward_colonnade.json", "pg_25": "res://samples/sky_harbor.json", "pg_26": "res://samples/crystal_spire.json", "pg_27": "res://samples/ashen_throne.json", "pg_28": "res://samples/sundered_ward.json", "pg_29": "res://samples/unmade_reach.json"}
const NAMES := {"pg_1": "Thistle Rise", "pg_2": "The Sunken Span", "pg_3": "Cinder Shrine", "pg_4": "The Last Benediction", "pg_6": "Sacred Canal Bridge", "pg_7": "The Drowned Reliquary", "pg_8": "The Last Terrace Garden", "pg_9": "The Night Express", "pg_10": "The Dining Car", "pg_11": "Hollowmark Station", "pg_12": "The Colosseum", "pg_13": "The Star-Watcher's Orrery", "pg_14": "The Rat's Wharf", "pg_15": "The Crooked Cellar", "pg_16": "Blackrock Quarry", "pg_17": "The Crow's Roost", "pg_18": "The Drowned Chapel", "pg_19": "Hangman's Fen", "pg_20": "The Stilt Hollows", "pg_21": "The Sunken Causeway", "pg_22": "The Bog Sanctum", "pg_23": "The Broken Stair", "pg_24": "The Windward Colonnade", "pg_25": "The Sky Harbor", "pg_26": "The Crystal Spire", "pg_27": "The Ashen Throne", "pg_28": "The Sundered Ward", "pg_29": "The Unmade Reach"}
## Shelved maps (not on the world map, not in MAPS): built and tested but put aside until their art is fixed. Emberwell Village (pg_5, the owner's burning village)
## waits for the owner to fix its white materials in Blender (Nov 2026). `setup` still builds them (tests, screenshots); `is_skirmish` and the world map do not list them.
## To bring one back: move its line into MAPS and NAMES and its place entry back into WorldData (see git history, "Emberwell Village").
const SHELVED := {"pg_5": "res://samples/emberwell_village.json"}
const LEVELS: Array[int] = [3, 10, 20, 35, 55]  ## the enemies' level for each of a map's levels (1-based)


static func is_skirmish(map_id: String) -> bool:
	return MAPS.has(map_id)


## The battle on `map_id` at level `level` (1-based, LEVELS).
static func setup(map_id: String, level: int) -> BattleSetup:
	var path: String = MAPS[map_id] if MAPS.has(map_id) else SHELVED[map_id]
	var sp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))["spawns"]
	var lv: int = LEVELS[clampi(level, 1, LEVELS.size()) - 1]
	var s := BattleSetup.new()
	s.map_path = path
	s.king_cell = Riverford.cell(sp["king"])
	s.captain_cell = Riverford.cell(sp["captain"])
	var i := 0
	for e in sp["enemies"]:
		i += 1
		s.enemies.append([enemy(String(e["kind"]), map_id, i, lv), Riverford.cell(e["at"])])
	s.objective = "Defeat every enemy"
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
