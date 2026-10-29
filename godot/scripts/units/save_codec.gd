class_name SaveCodec
extends RefCounted
## SaveGame <-> plain data (a Dictionary of numbers, strings, arrays and dictionaries), ready for JSON.
##
## Why not save Godot resources directly: a `.tres` file can carry scripts, and nothing in it is
## checked. Here every field is written and read by name, enums are stored as names, numbers are clamped
## to their legal ranges on load, missing fields fall back to defaults, and the file has a version so
## old saves can be upgraded (see `migrate`).
##
## Skills and relics are shared (the same skill sits on a relic and in a human's skill tree; a relic is
## either spare or equipped), so each is written once in a table and referenced by key. Loading
## rebuilds the very same sharing.
##
## What is saved: unit stats, level, XP and lifetime XP, the proficiency ranks, all
## five loadout slots (Main Weapon, Weapon Style, Relic Slot 1, Relic Slot 2, Temp-Relic), skill levels
## and study progress, each vessel's tether_count and sever_count, the relic inventory, the
## chosen Co-Captain and the campaign counters. Battle-only state (HP, SP, positions, Fade Clocks) is not saved.

const VERSION := 2
const ROLE_TYPES: Array[String] = ["king", "co_captain", "vessel"]

## Attribute -> [min, max], the same ranges as CharacterStats.
const STAT_FIELDS := {
	"level": [1, 99], "base_max_hp": [25, 100], "attack": [0, 30], "defense": [0, 30], "magic": [0, 30],
	"resistance": [0, 30], "speed": [1, 30], "will": [0, 30], "move": [1, 8], "jump": [0, 6],
}


## SaveGame -> data.
static func encode(game: SaveGame) -> Dictionary:
	return Writer.new().write(game)


## data -> SaveGame (or the reason it cannot be loaded).
static func decode(data: Dictionary) -> SaveLoadResult:
	return Reader.new().read(data)


## Upgrades an older save's data to VERSION, one version at a time. When the format changes again,
## add the next `match` arm and a `_vN_to_vN+1` function.
static func migrate(data: Dictionary, from_version: int) -> Dictionary:
	var v := from_version
	while v < VERSION:
		match v:
			1:
				data = _v1_to_v2(data)
		v += 1
	return data


## Version 2 added character experience (exp, total_exp) and made level 1 the lowest character level
## (version 1 started at 0). Old characters get exp 0 and a level of at least 1.
static func _v1_to_v2(data: Dictionary) -> Dictionary:
	data = data.duplicate(true)
	var units: Array = []
	if data.get("king") is Dictionary:
		units.append(data.king)
		units.append_array(get_a(data.king, "vessels"))
	units.append_array(get_a(data, "co_captains"))
	for u in units:
		if u is Dictionary and u.get("stats") is Dictionary:
			u.stats["level"] = maxi(get_i(u.stats, "level", 1), 1)
			u.stats["exp"] = 0
			u.stats["total_exp"] = 0
	data["version"] = 2
	return data


# ---------- small helpers (type-safe reads from untrusted data) ----------

static func ename(e: Dictionary, value: int) -> String:
	var k = e.find_key(value)
	return String(k) if k != null else ""


static func eval(e: Dictionary, name: Variant, fallback: int) -> int:
	return int(e.get(name, fallback)) if name is String else fallback


static func get_i(d: Dictionary, key: String, fallback := 0, lo := -2147483648, hi := 2147483647) -> int:
	var v = d.get(key, fallback)
	return clampi(int(v), lo, hi) if v is int or v is float else fallback


static func get_f(d: Dictionary, key: String, fallback := 0.0, lo := -1e9, hi := 1e9) -> float:
	var v = d.get(key, fallback)
	return clampf(float(v), lo, hi) if v is int or v is float else fallback


static func get_s(d: Dictionary, key: String, fallback := "") -> String:
	var v = d.get(key, fallback)
	return v if v is String else fallback


static func get_d(d: Dictionary, key: String) -> Dictionary:
	var v = d.get(key, {})
	return v if v is Dictionary else {}


static func get_a(d: Dictionary, key: String) -> Array:
	var v = d.get(key, [])
	return v if v is Array else []


## Rank letter ("S".."F") -> Rank, defaulting to C.
static func rank_of_letter(letter: Variant) -> TacticalMath.Rank:
	var i := TacticalMath.RANK_LETTERS.find(letter) if letter is String else -1
	return (i if i >= 0 else TacticalMath.Rank.C) as TacticalMath.Rank


# ---------- writing ----------

class Writer:
	var skill_keys := {}  ## SkillData -> key
	var skills := {}
	var relic_keys := {}  ## RelicItem -> key
	var relics := {}

	func write(game: SaveGame) -> Dictionary:
		var roster := game.roster
		var out := {"version": SaveCodec.VERSION, "saved_at": game.saved_at, "campaign": _campaign(game.campaign)}
		out["king"] = _unit(roster.king) if roster.king else null
		var caps := []
		for c in roster.co_captains:
			caps.append(_unit(c))
		out["co_captains"] = caps
		var inv := []
		for r in roster.relic_inventory:
			inv.append(_relic(r))
		out["relic_inventory"] = inv
		out["active_co_captain"] = roster.co_captains.find(roster.active_co_captain) if roster.active_co_captain else -1
		out["skills"] = skills
		out["relics"] = relics
		return out

	func _campaign(c: CampaignState) -> Dictionary:
		var d := {}
		for k in CampaignState.COUNTERS:
			d[k] = c.get(k)
		var m := []
		for id in c.missions_completed:
			m.append(String(id))
		d["missions_completed"] = m
		return d

	func _unit(u: UnitData) -> Dictionary:
		var d := {
			"type": SaveCodec.ROLE_TYPES[u.role()] if u.role() < SaveCodec.ROLE_TYPES.size() else "vessel",
			"id": String(u.id), "display_name": u.display_name,
			"stats": _stats(u.stats), "loadout": _loadout(u.loadout), "skill_tree": _tree(u.skill_tree),
			"palette": String(u.palette),
		}
		if u is KingData:
			var vs := []
			for v in (u as KingData).vessel_roster:
				vs.append(_unit(v))
			d["vessels"] = vs
		elif u is CoCaptainData:
			var ss := []
			for s in (u as CoCaptainData).signature_skills:
				ss.append(_skill(s))
			d["signature_skills"] = ss
		elif u is VesselData:
			var v := u as VesselData
			d["fade_turns"] = v.fade_turns
			d["sever_count"] = v.sever_count
			d["tether_count"] = v.tether_count
		return d

	func _stats(s: CharacterStats) -> Variant:
		if s == null:
			return null
		var d := {"display_name": s.display_name, "proficiency_efficiency": s.proficiency_efficiency,
			"exp": s.exp, "total_exp": s.total_exp}
		for k in SaveCodec.STAT_FIELDS:
			d[k] = s.get(k)
		var ranks := {}
		for c in Proficiency.all():
			ranks[String(Proficiency.id(c))] = TacticalMath.rank_letter(s.rank_of(c))
		d["ranks"] = ranks
		return d

	func _loadout(l: EquipmentLoadout) -> Variant:
		if l == null:
			return null
		var d := {}
		if l.main_weapon:
			var w := l.main_weapon
			d["main_weapon"] = _item(w, {"base_power": w.base_power, "smith_level": w.smith_level})
		if l.weapon_style:
			var st := l.weapon_style
			d["weapon_style"] = _item(st, {
				"geometry": SaveCodec.ename(TacticalMath.Geometry, st.geometry),
				"stance": SaveCodec.ename(WeaponStyle.Stance, st.stance), "reach": st.reach})
		d["relic_slot_1"] = _relic(l.relic_slot_1)
		d["relic_slot_2"] = _relic(l.relic_slot_2)
		d["temp_relic"] = _relic(l.temp_relic)
		return d

	## Common fields of items and skills (both have id, display_name, description and icon).
	func _item(item: Variant, extra: Dictionary) -> Dictionary:
		var d := {"id": String(item.id), "display_name": item.display_name, "description": item.description}
		if item.icon and item.icon.resource_path != "":
			d["icon"] = item.icon.resource_path
		d.merge(extra)
		return d

	## Key of a relic in the relics table ("" for none), adding it on first sight.
	func _relic(r: RelicItem) -> String:
		if r == null:
			return ""
		if relic_keys.has(r):
			return relic_keys[r]
		var key := "r%d" % relic_keys.size()
		relic_keys[r] = key
		var pas := []
		for m in r.passives:
			pas.append(_mod(m))
		var drw := []
		for m in r.drawbacks:
			drw.append(_mod(m))
		relics[key] = _item(r, {"skill": _skill(r.skill), "passives": pas, "drawbacks": drw,
			"sp_drain_per_turn": r.sp_drain_per_turn, "hp_drain_per_turn": r.hp_drain_per_turn})
		return key

	func _skill(s: SkillData) -> String:
		if s == null:
			return ""
		if skill_keys.has(s):
			return skill_keys[s]
		var key := "s%d" % skill_keys.size()
		skill_keys[s] = key
		skills[key] = _item(s, {"sp_cost": s.sp_cost, "base_power": s.base_power,
			"category": SaveCodec.ename(Proficiency.Category, s.category), "rank": SaveCodec.ename(SkillData.Rank, s.rank),
			"animation": s.animation, "effect": s.effect, "allows_move_after": s.allows_move_after, "push": s.push, "fixed_multiplier": s.fixed_multiplier, "slow": s.slow, "retreat": s.retreat, "status": s.status, "status_turns": s.status_turns, "spare": s.spare, "hop": s.hop})
		return key

	func _mod(m: StatModifier) -> Dictionary:
		return {"stat": SaveCodec.ename(StatModifier.Stat, m.stat), "flat": m.flat, "percent": m.percent}

	func _tree(t: SkillTree) -> Variant:
		if t == null:
			return null
		var ms := []
		for m in t.masteries:
			ms.append({"skill": _skill(m.skill), "mentor_name": m.mentor_name, "level": m.level, "progress": m.progress})
		return {"masteries": ms, "active_index": t.active_index}


# ---------- reading ----------

class Reader:
	var skills := {}  ## key -> SkillData
	var relics := {}  ## key -> RelicItem
	var res := SaveLoadResult.new()

	func read(data: Dictionary) -> SaveLoadResult:
		var version := SaveCodec.get_i(data, "version", 0)
		if version < 1:
			return res.fail("not a save file (no version)")
		if version > SaveCodec.VERSION:
			return res.fail("saved by a newer version of the game (save v%d, this game v%d)" % [version, SaveCodec.VERSION])
		data = SaveCodec.migrate(data, version)
		for key in SaveCodec.get_d(data, "skills"):
			var sd = data.skills[key]
			if sd is Dictionary:
				skills[key] = _skill(sd)
		for key in SaveCodec.get_d(data, "relics"):
			var rd = data.relics[key]
			if rd is Dictionary:
				relics[key] = _relic(rd)
		var game := SaveGame.new()
		game.saved_at = SaveCodec.get_i(data, "saved_at", 0, 0)
		game.campaign = _campaign(SaveCodec.get_d(data, "campaign"))
		var roster := PartyRoster.new()
		var kd = data.get("king")
		if not kd is Dictionary or kd.get("type") != "king":
			return res.fail("the save has no King")
		var king := _unit(kd) as KingData
		if king == null:
			return res.fail("the King could not be read")
		roster.king = king
		for cd in SaveCodec.get_a(data, "co_captains"):
			var c = _unit(cd) if cd is Dictionary and cd.get("type") == "co_captain" else null
			if c is CoCaptainData:
				roster.co_captains.append(c)
			else:
				res.warnings.append("a Co-Captain entry could not be read and was skipped")
		for key in SaveCodec.get_a(data, "relic_inventory"):
			var r := _relic_ref(key)
			if r != null:
				roster.relic_inventory.append(r)
		var chosen := SaveCodec.get_i(data, "active_co_captain", -1)
		if chosen >= 0 and chosen < roster.co_captains.size():
			roster.active_co_captain = roster.co_captains[chosen]
		elif chosen >= roster.co_captains.size():
			res.warnings.append("the active Co-Captain entry pointed at no Co-Captain and was ignored")
		res.warnings.append_array(roster.audit())
		game.roster = roster
		res.game = game
		res.ok = true
		return res

	func _campaign(d: Dictionary) -> CampaignState:
		var c := CampaignState.new()
		for k in CampaignState.COUNTERS:
			c.set(k, SaveCodec.get_i(d, k, 0, 0))
		for id in SaveCodec.get_a(d, "missions_completed"):
			if id is String and id != "" and not c.missions_completed.has(StringName(id)):
				c.missions_completed.append(StringName(id))
		return c

	func _unit(d: Dictionary) -> UnitData:
		var u: UnitData
		match SaveCodec.get_s(d, "type"):
			"king":
				var k := KingData.new()
				for vd in SaveCodec.get_a(d, "vessels"):
					if vd is Dictionary and vd.get("type") == "vessel":
						k.vessel_roster.append(_unit(vd) as VesselData)
					else:
						res.warnings.append("a vessel entry could not be read and was skipped")
				u = k
			"co_captain":
				var c := CoCaptainData.new()
				for key in SaveCodec.get_a(d, "signature_skills"):
					var s := _skill_ref(key)
					if s != null:
						c.signature_skills.append(s)
				u = c
			"vessel":
				var v := VesselData.new()
				v.fade_turns = SaveCodec.get_i(d, "fade_turns", 5, 1, 20)
				v.sever_count = SaveCodec.get_i(d, "sever_count", 0, 0)
				v.tether_count = SaveCodec.get_i(d, "tether_count", 0, 0)
				u = v
			_:
				return null
		u.id = StringName(SaveCodec.get_s(d, "id"))
		u.display_name = SaveCodec.get_s(d, "display_name")
		u.stats = _stats(SaveCodec.get_d(d, "stats")) if d.get("stats") is Dictionary else null
		u.loadout = _loadout(SaveCodec.get_d(d, "loadout")) if d.get("loadout") is Dictionary else null
		u.skill_tree = _tree(SaveCodec.get_d(d, "skill_tree")) if d.get("skill_tree") is Dictionary else null
		var pal := SaveCodec.get_s(d, "palette", "original")
		u.palette = StringName(pal) if CharacterLook.looks(CharacterLook.base_of(u)).has(pal) else &"original"  # an unknown look is the original
		return u

	func _stats(d: Dictionary) -> CharacterStats:
		var s := CharacterStats.new()
		s.display_name = SaveCodec.get_s(d, "display_name")
		s.proficiency_efficiency = SaveCodec.get_f(d, "proficiency_efficiency", 1.0, 0.5, 1.5)
		for k in SaveCodec.STAT_FIELDS:
			var lim: Array = SaveCodec.STAT_FIELDS[k]
			s.set(k, SaveCodec.get_i(d, k, s.get(k), lim[0], lim[1]))
		var to_next := ExperienceCurve.to_next(s.level)
		s.exp = SaveCodec.get_i(d, "exp", 0, 0, maxi(to_next - 1, 0))  # always below the next level's cost
		s.total_exp = SaveCodec.get_i(d, "total_exp", 0, 0)
		var ranks := SaveCodec.get_d(d, "ranks")
		for c in Proficiency.all():
			s.set_rank(c, SaveCodec.rank_of_letter(ranks.get(String(Proficiency.id(c)))))
		return s

	func _loadout(d: Dictionary) -> EquipmentLoadout:
		var l := EquipmentLoadout.new()
		if d.get("main_weapon") is Dictionary:
			var wd: Dictionary = d.main_weapon
			var w := WeaponItem.new()
			_item(w, wd)
			w.base_power = SaveCodec.get_i(wd, "base_power", 8, 1, 30)
			w.smith_level = SaveCodec.get_i(wd, "smith_level", 0, 0, 99)
			l.main_weapon = w
		if d.get("weapon_style") is Dictionary:
			var sd: Dictionary = d.weapon_style
			var st := WeaponStyle.new()
			_item(st, sd)
			st.geometry = SaveCodec.eval(TacticalMath.Geometry, sd.get("geometry"), TacticalMath.Geometry.ROOK) as TacticalMath.Geometry
			st.stance = SaveCodec.eval(WeaponStyle.Stance, sd.get("stance"), WeaponStyle.Stance.IMPACT) as WeaponStyle.Stance
			st.reach = SaveCodec.get_i(sd, "reach", 2, 1, 8)
			l.weapon_style = st
		l.relic_slot_1 = _relic_ref(d.get("relic_slot_1"))
		l.relic_slot_2 = _relic_ref(d.get("relic_slot_2"))
		l.temp_relic = _relic_ref(d.get("temp_relic"))
		return l

	func _item(item: Variant, d: Dictionary) -> void:
		item.id = StringName(SaveCodec.get_s(d, "id"))
		item.display_name = SaveCodec.get_s(d, "display_name")
		item.description = SaveCodec.get_s(d, "description")
		var icon := SaveCodec.get_s(d, "icon")
		if icon != "" and icon.begins_with("res://") and ResourceLoader.exists(icon):
			item.icon = load(icon) as Texture2D

	func _relic(d: Dictionary) -> RelicItem:
		var r := RelicItem.new()
		_item(r, d)
		r.skill = _skill_ref(d.get("skill"))
		for md in SaveCodec.get_a(d, "passives"):
			if md is Dictionary:
				r.passives.append(_mod(md))
		for md in SaveCodec.get_a(d, "drawbacks"):
			if md is Dictionary:
				r.drawbacks.append(_mod(md))
		r.sp_drain_per_turn = SaveCodec.get_i(d, "sp_drain_per_turn", 0, 0, 10)
		r.hp_drain_per_turn = SaveCodec.get_i(d, "hp_drain_per_turn", 0, 0, 30)
		return r

	func _skill(d: Dictionary) -> SkillData:
		var s := SkillData.new()
		_item(s, d)
		s.sp_cost = SaveCodec.get_i(d, "sp_cost", 3, 0, 30)
		s.base_power = SaveCodec.get_i(d, "base_power", 6, 0, 50)
		s.category = SaveCodec.eval(Proficiency.Category, d.get("category"), Proficiency.Category.PHYSICAL) as Proficiency.Category
		s.rank = SaveCodec.eval(SkillData.Rank, d.get("rank"), SkillData.Rank.D) as SkillData.Rank
		s.animation = SaveCodec.get_s(d, "animation")
		s.effect = SaveCodec.get_s(d, "effect")
		s.allows_move_after = bool(d.get("allows_move_after", false))
		s.push = SaveCodec.get_i(d, "push", 0, 0, 3)
		s.fixed_multiplier = float(d.get("fixed_multiplier", 0.0))
		s.slow = SaveCodec.get_i(d, "slow", 0, 0, 3)
		s.retreat = bool(d.get("retreat", false))
		s.status = SaveCodec.get_s(d, "status")
		s.status_turns = SaveCodec.get_i(d, "status_turns", 0, 0, 3)
		s.spare = bool(d.get("spare", false))
		s.hop = bool(d.get("hop", false))
		return s

	func _mod(d: Dictionary) -> StatModifier:
		var m := StatModifier.new()
		m.stat = SaveCodec.eval(StatModifier.Stat, d.get("stat"), StatModifier.Stat.ATTACK) as StatModifier.Stat
		m.flat = SaveCodec.get_i(d, "flat", 0, -99, 99)
		m.percent = SaveCodec.get_i(d, "percent", 0, -90, 200)
		return m

	func _tree(d: Dictionary) -> SkillTree:
		var t := SkillTree.new()
		var remap := {}  ## index in the file -> index in the tree (entries with no skill are skipped)
		var i := -1
		for md in SaveCodec.get_a(d, "masteries"):
			i += 1
			if not md is Dictionary:
				continue
			var s := _skill_ref(md.get("skill"))
			if s == null:
				res.warnings.append("a skill entry pointed at no skill and was skipped")
				continue
			var m := SkillMastery.make(s, SaveCodec.get_s(md, "mentor_name"))
			m.level = SaveCodec.get_i(md, "level", 0, 0, 99)
			m.progress = SaveCodec.get_i(md, "progress", 0, 0, 99)
			remap[i] = t.masteries.size()
			t.masteries.append(m)
		t.active_index = remap.get(SaveCodec.get_i(d, "active_index", -1), -1)
		if t.active_study() != null and t.active_study().is_mastered():
			t.active_index = -1  # a learned skill is not a study
		return t

	func _relic_ref(key: Variant) -> RelicItem:
		if not key is String or key == "":
			return null
		if not relics.has(key):
			res.warnings.append("a relic reference pointed at nothing and was skipped")
			return null
		return relics[key]

	func _skill_ref(key: Variant) -> SkillData:
		if not key is String or key == "":
			return null
		return skills.get(key)
