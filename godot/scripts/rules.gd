extends Node
## Rules engine: a port of js/engine.js plus the battle setup from js/game.js.
## Autoloaded as `Rules`. Units and battles are Dictionaries shaped like the JS objects
## (same keys, same order of random calls), so tests/run_tests.gd can replay battles
## recorded from the JS engine and expect identical results.
##
## Porting rules: divide with floats (GDScript int/int truncates), round with jround()
## (JS Math.round), compare units with is_same(), read optional keys with .get().

const DIRS := [[0, -1], [1, 0], [0, 1], [-1, 0]]  # 0 N, 1 E, 2 S, 3 W (grid space)
const SLOTS := ["w", "o", "h", "b", "a"]
const FIGHT := {"id": "fight", "name": "Fight", "fx": "atk", "pw": 1, "rng": "w", "cat": "phys", "tgt": "foe", "mp": 0, "aoe": 0, "desc": "Attack with the equipped weapon."}
const COMBO := {"id": "combo", "name": "Combo", "fx": "atk", "pw": 1, "rng": 1, "cat": "phys", "tgt": "foe", "mp": 0, "aoe": 0, "combo": 1, "jpCost": 3, "desc": "Spend 3 JP. +50% damage for every ally next to the target."}

# ---------- Random ----------
var _rng := RandomNumberGenerator.new()
var _lcg := -1


## Deterministic mode (tests): the same LCG as tools/js_trace.js.
func seed_lcg(n: int) -> void:
	_lcg = n & 0xFFFFFFFF


func unseed() -> void:
	_lcg = -1
	_rng.randomize()


func rnd() -> float:
	if _lcg >= 0:
		_lcg = (_lcg * 1103515245 + 12345) & 0xFFFFFFFF
		return _lcg / 4294967296.0
	return _rng.randf()


func ri(n: int) -> int:
	return int(floor(rnd() * n))


func pick(a: Array) -> Variant:
	return a[ri(a.size())]


static func jround(v: float) -> int:
	return int(floor(v + 0.5))


static func dist(a: Dictionary, b: Dictionary) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


static func _b36(n: int) -> String:
	const D := "0123456789abcdefghijklmnopqrstuvwxyz"
	if n == 0:
		return "0"
	var s := ""
	while n > 0:
		s = D[n % 36] + s
		n /= 36
	return s


static func st(u: Dictionary, k: String) -> Variant:
	return u.st.get(k, 0)


# ---------- Proficiencies (port of the block in engine.js) ----------
const PF_MAX := 99


static func pf_gain(lv: int) -> float:
	return 1 + lv * .02


## Uses needed to go from level lv to lv + 1.
static func pf_need(lv: int) -> int:
	return 2 + lv


static func new_profs() -> Dictionary:
	var o := {}
	for k in Data.PROFS:
		o[k] = {"lv": 1, "xp": 0}
	return o


static func ensure_profs(u: Dictionary) -> void:
	if not u.has("pf"):
		u["pf"] = new_profs()
	if not u.has("mpl"):
		u["mpl"] = new_profs()
	if not u.has("sk"):
		u["sk"] = {}


## Which proficiency an action trains and spends MP from. Items and passives have none.
static func pf_of(bu: Dictionary, ab: Dictionary) -> Variant:
	if ab.has("pf"):
		return ab.pf
	if ab.get("cat") == "item" or ab.get("type") == "R" or ab.get("type") == "S":
		return null
	match ab.fx:
		"atk":
			if typeof(ab.rng) == TYPE_STRING and ab.rng == "w":
				return "shot" if Data.WTYPES.get(bu.s.wt, Data.WTYPES.fist).r > 1 else "strike"
			return "shot" if ab.rng > 1 else "strike"
		"mag", "drain":
			return "arcane"
		"heal", "raise", "cure", "mp":
			return "mend"
		"buff":
			return "ward"
	return "trick"


static func pool_max(bu: Dictionary, pf: String) -> int:
	return jround(bu.s.mmp * pf_gain(bu.u.mpl[pf].lv))


static func mp_max_total(bu: Dictionary) -> int:
	var n := 0
	for k in bu.mps:
		n += pool_max(bu, k)
	return n


static func mp_total(bu: Dictionary) -> int:
	var n := 0
	for k in bu.mps:
		n += bu.mps[k]
	return n


## Takes up to n MP, from the fullest pools first. Returns how much was taken.
static func drain_mp(bu: Dictionary, n: int) -> int:
	var left := n
	var ks: Array = bu.mps.keys()
	for i in range(1, ks.size()):  # stable insertion sort, fullest first
		var k = ks[i]
		var j := i - 1
		while j >= 0 and bu.mps[ks[j]] < bu.mps[k]:
			ks[j + 1] = ks[j]
			j -= 1
		ks[j + 1] = k
	for k in ks:
		var m: int = min(left, bu.mps[k])
		bu.mps[k] -= m
		left -= m
	return n - left


static func fill_mp(bu: Dictionary, pf: String, n: int) -> int:
	var m: int = min(n, pool_max(bu, pf) - bu.mps[pf])
	bu.mps[pf] += m
	return m


static func pf_mult(a: Dictionary, ab: Dictionary) -> float:
	var pf = pf_of(a, ab) if a.u.has("pf") else null
	return pf_gain(a.u.pf[pf].lv) if pf != null else 1.0


## A use trains the skill's proficiency, and the MP level when it cost MP.
static func train_prof(a: Dictionary, ab: Dictionary, ev: Array) -> void:
	var pf = pf_of(a, ab)
	if pf == null or a.mon or a.team != 0:
		return
	var e: Dictionary = a.u.pf[pf]
	if e.lv < PF_MAX:
		e.xp += 1
		if e.xp >= pf_need(e.lv):
			e.xp = 0
			e.lv += 1
			ev.append({"type": "prof", "id": a.id, "pf": pf, "kind": "prof", "lv": e.lv})
	var m: Dictionary = a.u.mpl[pf]
	if ab.get("mp") and m.lv < PF_MAX:
		m.xp += 1
		if m.xp >= pf_need(m.lv):
			var before := pool_max(a, pf)
			m.xp = 0
			m.lv += 1
			a.mps[pf] += pool_max(a, pf) - before
			ev.append({"type": "prof", "id": a.id, "pf": pf, "kind": "mp", "lv": m.lv})


static func pools_full(u: Dictionary, s: Dictionary) -> Dictionary:
	ensure_profs(u)
	var o := {}
	for k in Data.PROFS:
		o[k] = jround(s.mmp * pf_gain(u.mpl[k].lv))
	return o


# ---------- Units ----------
func grow(u: Dictionary, g: Dictionary) -> void:
	for k in ["hp", "mp", "atk", "def", "mag", "res", "spd"]:
		var v = g.get(k, 0)
		u.b[k] += int(floor(v + rnd()))


func new_unit(race: String, job: String, lv: int, name := "", id := "") -> Dictionary:
	var r: Dictionary = Data.RACES[race]
	var uid := id if id != "" else "u" + _b36(int(floor(rnd() * 1e9)))
	var u := {"id": uid, "name": name if name != "" else pick(Data.NAMES[race]), "race": race, "mon": null, "job": job, "sub": null, "lv": 1, "exp": 0,
		"b": {"hp": r.hp, "mp": r.mp, "atk": r.atk, "def": r.def, "mag": r.mag, "res": r.res, "spd": r.spd}, "eq": {"w": null, "o": null, "h": null, "b": null, "a": null},
		"ms": {}, "sk": {}, "pf": new_profs(), "mpl": new_profs(), "r": null, "s": null, "jail": 0, "errand": null}
	while u.lv < lv:
		u.lv += 1
		grow(u, Data.JOBS[job].g)
	return u


func new_monster(kind: String, lv: int, id := "") -> Dictionary:
	var m: Dictionary = Data.MONSTERS[kind]
	var uid := id if id != "" else "m" + _b36(int(floor(rnd() * 1e9)))
	var u := {"id": uid, "name": m.name, "race": "monster", "mon": kind, "job": null, "sub": null, "lv": 1, "exp": 0,
		"b": {"hp": m.hp, "mp": m.mp, "atk": m.atk, "def": m.def, "mag": m.mag, "res": m.res, "spd": m.spd}, "eq": {}, "ms": {}, "sk": {}, "pf": new_profs(), "mpl": new_profs(), "r": null, "s": null}
	while u.lv < lv:
		u.lv += 1
		grow(u, m.g)
	return u


static func items_of(u: Dictionary) -> Array:
	var out := []
	for s in SLOTS:
		var id = u.eq.get(s)
		if id:
			out.append(Data.ITEMS[id])
	return out


static func calc_stats(u: Dictionary) -> Dictionary:
	var s := {"mhp": u.b.hp, "mmp": u.b.mp, "atk": u.b.atk, "def": u.b.def, "mag": u.b.mag, "res": u.b.res, "spd": u.b.spd, "ev": 0, "mv": 0, "jp": 0, "wel": null}
	if u.mon:
		var m: Dictionary = Data.MONSTERS[u.mon]
		s.mv = m.mv; s.jp = m.jp; s.ev = m.ev; s.wt = m.w
		s.atk += m.watk
		return s
	var j: Dictionary = Data.JOBS[u.job]
	s.mv = j.mv; s.jp = j.jp; s.ev = j.ev; s.wt = "fist"
	for it in items_of(u):
		for k in it.stats:
			s["mhp" if k == "hp" else "mmp" if k == "mp" else k] += it.stats[k]
		if it.slot == "w":
			s.wt = it.t
			s.wel = it.get("el")
	if u.s == "fleet":
		s.mv += 1
	if u.r == "dodge":
		s.ev += 15
	return s


func gain_exp(u: Dictionary, n: float) -> Array:
	var out := []
	if u.mon or u.lv >= 50:
		return out
	u.exp += jround(n * (1.5 if u.s == "expup" else 1.0))
	while u.exp >= 100 and u.lv < 50:
		u.exp -= 100
		u.lv += 1
		grow(u, Data.JOBS[u.job].g)
		out.append(u.lv)
	return out


# ---------- Jobs and abilities ----------
static func can_equip(u: Dictionary, it: Dictionary, job = null) -> bool:
	if u.mon:
		return false
	var j: Dictionary = Data.JOBS[job if job else u.job]
	match it.slot:
		"w": return it.t in j.w
		"o": return j.sh or u.s == "shieldbearer"
		"h": return it.t in j.head
		"b": return it.t in j.body
	return true


static func taught(u: Dictionary) -> Dictionary:
	var s := {}
	for it in items_of(u):
		for id in it.teach:
			s[id] = it.id
	return s


static func job_abilities(job: String, type := "A") -> Array:
	var out := []
	for id in Data.AB:
		if Data.AB[id].job == job and Data.AB[id].type == type:
			out.append(id)
	return out


static func action_sets(u: Dictionary, bu = null) -> Array:
	if u.mon:
		var m: Dictionary = Data.MONSTERS[u.mon]
		return [{"name": m.name, "list": m.abil.duplicate()}]
	var list := known_skills(u).filter(func(id): return Data.AB.has(id) and Data.AB[id].type == "A")
	if bu != null and bu.vessel and not list.has(bu.vessel):
		list.append(bu.vessel)
	return [{"name": "Skills", "list": list}]


## Skills in use: whatever the equipped gear teaches, plus any kept for good (u.ms).
static func known_skills(u: Dictionary) -> Array:
	var ids: Array = taught(u).keys()
	for id in u.ms:
		if not ids.has(id):
			ids.append(id)
	return ids


## Adds a unit with its job's starter gear (game.js addUnit).
static func add_unit(units: Array, u: Dictionary, gear: bool) -> Dictionary:
	if gear:
		for id in Data.STARTER.get(u.job, []):
			var it: Dictionary = Data.ITEMS[id]
			if can_equip(u, it) and not u.eq[it.slot]:
				u.eq[it.slot] = id
	units.append(u)
	return u


## The starting clan from game.js newGame().
func new_party() -> Array:
	var units := []
	for p in [["human", "squire", "Rook"], ["saurian", "warrior", "Bram"], ["sylph", "archer", "Liss"], ["mossling", "animist", "Pip"], ["nuwa", "sage", "Oro"], ["human", "mender", "Tamsin"]]:
		add_unit(units, new_unit(p[0], p[1], 1, p[2]), true)
	units[0].leader = 1
	return units


func enemy_from_spec(spec: Array) -> Dictionary:
	var kind: String = spec[0]
	var lv: int = spec[1]
	var ex = spec[4] if spec.size() > 4 else null
	var u: Dictionary
	if Data.MONSTERS.has(kind):
		u = new_monster(kind, lv)
	else:
		var parts := kind.split(":")
		var job := parts[1]
		u = new_unit(parts[0], job, lv, ex.get("name", "") if ex else "")
		for id in (ex.eq if ex and ex.has("eq") else Data.STARTER.get(job, [])):
			var it: Dictionary = Data.ITEMS[id]
			if can_equip(u, it):
				u.eq[it.slot] = id
		# Enemies use what their gear teaches, plus one more of their class's skills.
		var tt := taught(u)
		var extra := job_abilities(job).filter(func(id): return not tt.has(id))
		if not extra.is_empty():
			u.ms[pick(extra)] = 1
		if job in ["warrior", "knight", "brawler"]:
			u.r = "counter"
		if ex and ex.get("leader"):
			u.leader = 1
	return {"u": u, "x": spec[2], "y": spec[3]}


# ---------- Battle setup ----------
static func parse_map(k: String) -> Dictionary:
	var M: Dictionary = Data.MAPS[k]
	var tiles := []
	for r in M.rows:
		var row := []
		for tok in r.strip_edges().split(" ", false):
			row.append({"t": tok[0], "h": tok.substr(1).to_int()})
		tiles.append(row)
	return {"key": k, "name": M.name, "w": tiles[0].size(), "d": tiles.size(), "tiles": tiles, "deploy": M.deploy}


static func tile_at(B: Dictionary, x: int, y: int) -> Variant:
	if x >= 0 and y >= 0 and x < B.map.w and y < B.map.d:
		return B.map.tiles[y][x]
	return null


static func unit_at(B: Dictionary, x: int, y: int) -> Variant:
	for u in B.units:
		if not u.jailed and u.x == x and u.y == y:
			return u
	return null


static func alive(u: Dictionary) -> bool:
	return not u.ko and not u.jailed


static func make_bu(u: Dictionary, team: int, x: int, y: int, f: int) -> Dictionary:
	var s := calc_stats(u)
	return {"id": u.id, "u": u, "name": u.name, "team": team, "x": x, "y": y, "f": f, "lv": u.lv, "s": s, "hp": s.mhp, "mps": pools_full(u, s), "vessel": null, "learned": [], "st": {}, "ko": false, "jailed": false,
		"ct": 0, "jp": 0, "cards": 0, "brk": {}, "moved": false, "acted": false, "race": u.race, "job": u.job, "mon": u.mon, "ls": 0, "start": null,
		"vx": float(x), "vy": float(y), "vh": 0.0, "hop": 0.0, "walk": false, "flash": -1000.0}


static func face_toward(a: Dictionary, x: float, y: float) -> int:
	var dx: float = x - a.x
	var dy: float = y - a.y
	if not dx and not dy:
		return a.f
	if absf(dx) >= absf(dy):
		return 1 if dx > 0 else 3
	return 2 if dy > 0 else 0


## opts: { map, party: [unit], enemies: [{u, x, y}], law, inv, mission }
func make_battle(opts: Dictionary) -> Dictionary:
	var map := parse_map(opts.map)
	var B := {"map": map, "units": [], "law": opts.get("law"), "inv": opts.get("inv", {}), "mission": opts.get("mission"), "turnNo": 0, "over": 0,
		"stolenGil": 0, "gilLost": 0, "loot": {}, "kos": 0, "stolen": [], "lost": []}
	for i in opts.party.size():
		var d: Array = map.deploy[i]
		B.units.append(make_bu(opts.party[i], 0, d[0], d[1], 0))
	for e in opts.enemies:
		B.units.append(make_bu(e.u, 1, e.x, e.y, 2))
	var c0 := centroid(B, 0)
	var c1 := centroid(B, 1)
	for u in B.units:
		var c := c0 if u.team else c1
		u.f = face_toward(u, c.x, c.y)
		u.ct = ri(40) + u.s.spd
		u.vh = float(tile_at(B, u.x, u.y).h)
	spawn_objects(B)
	return B


# ---------- Vessel: field objects (port of engine.js) ----------
const SK_NEED := 3
const VESSEL_RADIUS := .3
const OBJ_MIN := 4
const OBJ_MAX := 8


static func vessel_pool() -> Array:
	return Data.AB.keys().filter(func(id): return Data.AB[id].type == "A" and Data.AB[id].job != null)


## 4-8 objects on free, passable tiles, each carrying a random skill.
func spawn_objects(B: Dictionary) -> void:
	var free := []
	for y in B.map.d:
		for x in B.map.w:
			if Data.TERRAIN[B.map.tiles[y][x].t].pass and unit_at(B, x, y) == null:
				free.append([x, y])
	var pool := vessel_pool()
	var n: int = min(free.size(), OBJ_MIN + ri(OBJ_MAX - OBJ_MIN + 1))
	B["objs"] = []
	for i in n:
		var c: Array = free.pop_at(ri(free.size()))
		B.objs.append({"id": "o%d" % i, "x": c[0], "y": c[1], "skill": pool[ri(pool.size())]})


static func vessel_radius(B: Dictionary) -> float:
	return VESSEL_RADIUS * max(B.map.w, B.map.d)


## Objects inside the dome around a unit (tile distance, plus the height difference).
static func objs_in_reach(B: Dictionary, bu: Dictionary) -> Array:
	var r := vessel_radius(B)
	var h0: float = tile_at(B, bu.x, bu.y).h
	return B.get("objs", []).filter(func(o): return sqrt(pow(o.x - bu.x, 2) + pow(o.y - bu.y, 2) + pow(tile_at(B, o.x, o.y).h - h0, 2)) <= r)


## Taking an object is free: it uses neither the move nor the action. Replaces the held skill.
static func pickup(B: Dictionary, bu: Dictionary, obj_id: String) -> Array:
	var o = null
	for c in objs_in_reach(B, bu):
		if c.id == obj_id:
			o = c
			break
	if o == null or not alive(bu) or bu.mon:
		return []
	B.objs.erase(o)
	bu.vessel = o.skill
	return [{"type": "pickup", "id": bu.id, "obj": o.id, "skill": o.skill}, {"type": "msg", "text": "%s takes %s into the vessel." % [bu.name, Data.AB[o.skill].name]}]


## Counts a use of a vessel skill. At SK_NEED uses a player unit keeps it for good.
static func train_vessel(a: Dictionary, ab_id: String, ev: Array) -> void:
	if a.vessel != ab_id or a.team != 0 or a.mon or taught(a.u).has(ab_id) or a.u.ms.has(ab_id):
		return
	var n: int = a.u.sk.get(ab_id, 0) + 1
	a.u.sk[ab_id] = n
	if n >= SK_NEED:
		a.u.sk.erase(ab_id)
		a.u.ms[ab_id] = 1
		a.learned.append(ab_id)
		ev.append({"type": "learn", "id": a.id, "skill": ab_id})
		ev.append({"type": "msg", "text": "%s learned %s!" % [a.name, Data.AB[ab_id].name]})


## A story mission battle (game.js buildBattle 'mission').
func mission_battle(stage: int, party: Array, inv: Dictionary) -> Dictionary:
	var m: Dictionary = Data.MISSIONS[stage]
	var enemies := []
	for spec in m.enemies:
		enemies.append(enemy_from_spec(spec))
	return make_battle({"map": m.map, "party": party.slice(0, m.deploy), "enemies": enemies, "law": m.law, "inv": inv, "mission": m})


static func centroid(B: Dictionary, team: int) -> Dictionary:
	var us: Array = B.units.filter(func(u): return u.team == team and alive(u))
	if us.is_empty():
		return {"x": 0.0, "y": 0.0}
	var sx := 0.0
	var sy := 0.0
	for u in us:
		sx += u.x
		sy += u.y
	return {"x": sx / us.size(), "y": sy / us.size()}


# ---------- Stats in battle ----------
static func eff(bu: Dictionary, k: String) -> Variant:
	var v = bu.s[k] - bu.brk.get(k, 0)
	return max(1 if k == "spd" else 0, v)


static func speed(bu: Dictionary) -> float:
	var v: float = eff(bu, "spd")
	if st(bu, "haste"):
		v *= 1.5
	if st(bu, "slow"):
		v *= .5
	return v


# ---------- Turn order (CT) ----------
static func next_actor(B: Dictionary) -> Variant:
	for guard in 5000:
		var best = null
		for u in B.units:
			if alive(u) and u.ct >= 100 and (best == null or u.ct > best.ct):
				best = u
		if best != null:
			return best
		for u in B.units:
			if not alive(u):
				continue
			if st(u, "stop"):
				u.st.stop -= 1
				if u.st.stop <= 0:
					u.st.erase("stop")
				continue
			u.ct += speed(u)
	return null


static func turn_order(B: Dictionary, n: int) -> Array:
	var sim := []
	for u in B.units:
		if alive(u):
			sim.append({"u": u, "ct": u.ct, "sp": speed(u), "stop": st(u, "stop")})
	var out := []
	var guard := 0
	while out.size() < n and guard < 5000 and not sim.is_empty():
		guard += 1
		var best = null
		for s in sim:
			if s.ct >= 100 and (best == null or s.ct > best.ct):
				best = s
		if best != null:
			out.append(best.u)
			best.ct -= 100
			continue
		for s in sim:
			if s.stop > 0:
				s.stop -= 1
				continue
			s.ct += s.sp
	return out


func start_turn(B: Dictionary, bu: Dictionary) -> Dictionary:
	var ev := []
	B.turnNo += 1
	bu.moved = false
	bu.acted = false
	bu.start = {"x": bu.x, "y": bu.y, "f": bu.f}
	if bu.st.has("doom"):
		bu.st.doom -= 1
		ev.append({"type": "msg", "text": "%s: Doom %d" % [bu.name, bu.st.doom]})
		if bu.st.doom <= 0:
			ko_unit(B, bu, ev)
			return {"ev": ev, "skip": true}
	if st(bu, "poison"):
		hurt(B, bu, max(1, jround(bu.s.mhp / 8.0)), ev)
		if bu.ko:
			return {"ev": ev, "skip": true}
	if st(bu, "regen"):
		var h: int = max(1, jround(bu.s.mhp / 8.0))
		bu.hp = min(bu.s.mhp, bu.hp + h)
		ev.append({"type": "heal", "id": bu.id, "v": h})
	var skip := bool(st(bu, "sleep"))
	if skip:
		ev.append({"type": "msg", "text": bu.name + " is asleep."})
	return {"ev": ev, "skip": skip}


static func end_turn(_B: Dictionary, bu: Dictionary) -> void:
	bu.ct -= 100 if bu.moved and bu.acted else 80 if bu.moved or bu.acted else 60
	bu.ct = min(bu.ct, 60)
	for k in bu.st.keys():
		if k == "doom" or k == "stop":
			continue
		bu.st[k] -= 1
		if bu.st[k] <= 0:
			bu.st.erase(k)


# ---------- Movement ----------
static func can_move(bu: Dictionary) -> bool:
	return not bu.moved and not st(bu, "immobilize") and not st(bu, "sleep") and not st(bu, "stop")


## Reachable tiles: {"out": {key: {x, y, d, prev}}, "all": {...including occupied}}
static func reach(B: Dictionary, bu: Dictionary) -> Dictionary:
	var mv = 0 if st(bu, "immobilize") else eff(bu, "mv")
	var jp = eff(bu, "jp")
	var seen := {key(bu.x, bu.y): {"x": bu.x, "y": bu.y, "d": 0, "prev": null}}
	var q := [[bu.x, bu.y]]
	var qi := 0
	while qi < q.size():
		var x: int = q[qi][0]
		var y: int = q[qi][1]
		qi += 1
		var cur: Dictionary = seen[key(x, y)]
		var t0: Dictionary = tile_at(B, x, y)
		if cur.d >= mv:
			continue
		for d in DIRS:
			var nx: int = x + d[0]
			var ny: int = y + d[1]
			var t = tile_at(B, nx, ny)
			if t == null or not Data.TERRAIN[t.t].pass or seen.has(key(nx, ny)):
				continue
			var dh: int = t.h - t0.h
			if dh > jp or -dh > jp + 1:
				continue
			var o = unit_at(B, nx, ny)
			if o != null and not o.ko and o.team != bu.team:
				continue
			seen[key(nx, ny)] = {"x": nx, "y": ny, "d": cur.d + 1, "prev": key(x, y)}
			q.append([nx, ny])
	var out := {}
	for k in seen:
		var v: Dictionary = seen[k]
		var o = unit_at(B, v.x, v.y)
		if o == null or is_same(o, bu):
			out[k] = v
	return {"out": out, "all": seen}


static func path_to(R: Dictionary, x: int, y: int) -> Array:
	var p := []
	var k = key(x, y)
	while k:
		var n: Dictionary = R.all[k]
		p.push_front([n.x, n.y])
		k = n.prev
	return p


static func move_unit(_B: Dictionary, bu: Dictionary, x: int, y: int) -> void:
	var lx: int = bu.x
	var ly: int = bu.y
	bu.x = x
	bu.y = y
	bu.moved = true
	if lx != x or ly != y:
		bu.f = face_toward({"x": lx, "y": ly, "f": bu.f}, x, y)


# ---------- Abilities in battle ----------
static func ability_for(id: String) -> Variant:
	if id == "fight":
		return FIGHT
	if id == "combo":
		return COMBO
	if id.begins_with("item:"):
		var k := id.substr(5)
		var c: Dictionary = Data.CONS[k]
		return {"id": id, "name": c.name, "fx": c.fx, "pw": c.get("pw"), "cure": c.get("cure"), "rng": 1, "aoe": 0, "cat": "item", "mp": 0,
			"tgt": "ko" if c.fx == "raise" else "ally", "cons": k, "desc": c.desc}
	return Data.AB.get(id)


static func mp_cost(bu: Dictionary, ab: Dictionary) -> int:
	return int(ceil(ab.get("mp", 0) * (.5 if bu.u.s == "halfmp" else 1.0)))


## Why an ability can't be used right now, or "" if it can.
static func blocked(B: Dictionary, bu: Dictionary, ab: Dictionary) -> String:
	if st(bu, "disable") or st(bu, "sleep") or st(bu, "stop"):
		return "Cannot act"
	if ab.cat == "mag" and st(bu, "silence"):
		return "Silenced"
	if ab.get("mp") and mp_cost(bu, ab) > bu.mps[pf_of(bu, ab)]:
		return "Not enough MP"
	if ab.get("cons") and not (B.inv and B.inv.get(ab.cons, 0) > 0):
		return "None left"
	if ab.get("combo") and bu.jp < ab.jpCost:
		return "Needs %d JP" % ab.jpCost
	return ""


static func range_of(bu: Dictionary, ab: Dictionary) -> Dictionary:
	if typeof(ab.rng) == TYPE_STRING:
		var w: Dictionary = Data.WTYPES.get(bu.s.wt, Data.WTYPES.fist)
		return {"r": w.r, "v": w.v, "line": bool(w.get("line", false))}
	return {"r": ab.rng, "v": ab.v if ab.has("v") else (2 if ab.fx == "atk" else 5), "line": bool(ab.get("line", false))}


static func range_tiles(B: Dictionary, bu: Dictionary, ab: Dictionary, fx = null, fy = null) -> Array:
	if fx == null:
		fx = bu.x
		fy = bu.y
	var R := range_of(bu, ab)
	var r: int = R.r
	var h0: int = tile_at(B, fx, fy).h
	var out := []
	for y in range(fy - r, fy + r + 1):
		for x in range(fx - r, fx + r + 1):
			var t = tile_at(B, x, y)
			if t == null:
				continue
			var d: int = absi(x - fx) + absi(y - fy)
			if d > r or (R.line and x != fx and y != fy):
				continue
			if r > 0 and d == 0 and (ab.tgt == "foe" or ab.tgt == "ko"):
				continue
			if absi(t.h - h0) > R.v:
				continue
			out.append([x, y])
	return out


static func area_tiles(B: Dictionary, ab: Dictionary, cx: int, cy: int) -> Array:
	var aoe: int = ab.get("aoe", 0)
	if not aoe:
		return [[cx, cy]]
	var h0: int = tile_at(B, cx, cy).h
	var out := []
	for y in range(cy - aoe, cy + aoe + 1):
		for x in range(cx - aoe, cx + aoe + 1):
			var t = tile_at(B, x, y)
			if t != null and absi(x - cx) + absi(y - cy) <= aoe and absi(t.h - h0) <= 3:
				out.append([x, y])
	return out


static func targets_of(B: Dictionary, a: Dictionary, ab: Dictionary, cx: int, cy: int) -> Array:
	var out := []
	for p in area_tiles(B, ab, cx, cy):
		var t = unit_at(B, p[0], p[1])
		if t == null:
			continue
		if ab.tgt == "ko" or ab.fx == "raise":
			if t.ko and t.team == a.team:
				out.append(t)
			continue
		if t.ko:
			continue
		if ab.get("fo") and t.team == a.team:
			continue
		if ab.get("hits") == "allies" and t.team != a.team:
			continue
		out.append(t)
	return out


# ---------- Laws ----------
static func element_of(bu: Dictionary, ab: Dictionary) -> Variant:
	var el = ab.get("el")
	if el:
		return el
	if ab.fx == "atk" and bu.s.get("wel"):
		return bu.s.wel
	return null


static func law_match(law_id, bu: Dictionary, ab: Dictionary, cx: int, cy: int) -> bool:
	if not law_id:
		return false
	var L: Dictionary = Data.LAWS[law_id]
	match L.k:
		"cat": return ab.cat == L.v
		"fx": return ab.fx == L.v or (L.v == "heal" and ab.fx == "raise")
		"status":
			for s in ab.get("st", []):
				if Data.STATUS[s].get("bad"):
					return true
			return false
		"ranged": return ab.fx == "atk" and absi(cx - bu.x) + absi(cy - bu.y) > 1
		"el": return element_of(bu, ab) == L.v
		"w": return ab.fx == "atk" and bu.s.wt == L.v and not ab.get("cons")
		"fight": return ab.id == "fight"
	return false


static func breaks_law(B: Dictionary, bu: Dictionary, ab: Dictionary, cx: int, cy: int) -> bool:
	return B.law != null and law_match(B.law.ban, bu, ab, cx, cy)


# ---------- Hit, damage ----------
static func facing_rel(a: Dictionary, t: Dictionary) -> String:
	var dx: int = a.x - t.x
	var dy: int = a.y - t.y
	var f: Array = DIRS[t.f]
	var dot: int = dx * f[0] + dy * f[1]
	var cross: int = absi(dx * f[1] - dy * f[0])
	if dot > cross:
		return "front"
	if -dot > cross:
		return "back"
	return "side"


static func hit_chance(a: Dictionary, t: Dictionary, ab: Dictionary) -> Variant:
	if ab.fx != "atk" and ab.fx != "steal":
		return 100
	if a.team == t.team and ab.fx != "atk":
		return 100
	if st(t, "sleep") or st(t, "stop"):
		return 100
	var rel := facing_rel(a, t)
	if ab.fx == "steal":
		return clamp(50 + (speed(a) - speed(t)) * 4 + (20 if rel == "back" else 10 if rel == "side" else 0), 5, 95)
	var ev: float = eff(t, "ev") * (1.0 if rel == "front" else .5 if rel == "side" else .2)
	var h: float = 100 - ev
	if a.u.s == "concentrate":
		h += 25
	if st(a, "blind"):
		h *= .5
	return jround(clamp(h, 5, 100))


static func elem_mult(t: Dictionary, el) -> float:
	if not el:
		return 1.0
	if t.mon:
		var m: Dictionary = Data.MONSTERS[t.mon]
		if el in m.get("weak", []):
			return 1.5
		if el in m.get("resist", []):
			return .5
	return 1.0


static func combo_power(B: Dictionary, a: Dictionary, t: Dictionary) -> float:
	var n := 0
	for d in DIRS:
		var o = unit_at(B, t.x + d[0], t.y + d[1])
		if o != null and not is_same(o, a) and alive(o) and o.team == a.team:
			n += 1
	return 1 + n * .5


## Expected (un-randomized) amount. Positive = damage, negative = healing.
static func base_amount(B: Dictionary, a: Dictionary, t: Dictionary, ab: Dictionary) -> float:
	var el = element_of(a, ab)
	var fx: String = ab.fx
	if fx == "atk":
		var A: float = eff(a, "atk")
		var D: float = 0 if ab.get("pierce") else eff(t, "def")
		var d: float = (A - D / 2) * ab.pw * ab.get("hitsN", 1) * pf_mult(a, ab)
		if ab.get("combo"):
			d *= combo_power(B, a, t)
		if st(a, "boost"):
			d *= 1.5
		if a.u.s == "watkup":
			d *= 1.2
		if st(t, "protect") and not ab.get("pierce"):
			d *= .67
		if t.mon and Data.MONSTERS[t.mon].get("physHalf"):
			d *= .5
		return max(1.0, d * elem_mult(t, el))
	if fx == "mag" or fx == "drain":
		var d: float = float(ab.pw) * eff(a, "mag") / 20 * 40 / (40 + eff(t, "res")) * pf_mult(a, ab)
		if a.u.s == "magpowup":
			d *= 1.2
		if st(t, "shell"):
			d *= .67
		return max(1.0, d * elem_mult(t, el))
	if fx == "heal":
		if ab.cat == "item":
			return -ab.pw * (1.5 if a.u.s == "itemlore" else 1.0)
		var h: float = float(ab.pw) * eff(a, "mag") / 20 * pf_mult(a, ab) if ab.cat == "mag" else ab.pw * (1 + a.lv * .06) * pf_mult(a, ab)
		if a.u.s == "magpowup" and ab.cat == "mag":
			h *= 1.2
		return -h
	if fx == "mpdmg":
		return ab.pw * (1 + a.lv * .05)
	return 0.0


static func status_chance(a: Dictionary, t: Dictionary, ab: Dictionary) -> int:
	var c: float = ab.get("ch", 100)
	if ab.cat == "mag":
		c += (eff(a, "mag") - eff(t, "res")) / 2.0
	if t.mon and Data.MONSTERS[t.mon].get("boss"):
		c *= .5
	return jround(clamp(c, 5, 95))


## Preview for the UI and the AI.
static func predict(B: Dictionary, a: Dictionary, ab: Dictionary, t: Dictionary) -> Dictionary:
	var p := {"hit": hit_chance(a, t, ab), "amt": jround(base_amount(B, a, t, ab))}
	if ab.get("st"):
		p.stCh = 100 if ab.fx == "buff" else status_chance(a, t, ab)
	return p


# ---------- Applying effects ----------
func ko_unit(B: Dictionary, bu: Dictionary, ev: Array) -> void:
	bu.hp = 0
	bu.ko = true
	bu.st = {}
	bu.ct = 0
	ev.append({"type": "ko", "id": bu.id})
	if bu.team == 1:
		B.kos += 1
		if bu.mon:
			var m: Dictionary = Data.MONSTERS[bu.mon]
			for l in m.loot:
				if rnd() < .6 or m.get("boss"):
					B.loot[l] = B.loot.get(l, 0) + 1


func hurt(B: Dictionary, t: Dictionary, d: float, ev: Array, src := "") -> void:
	var n: int = max(0, jround(d))
	if t.u.r == "manashield" and mp_total(t) > 0:
		var m := drain_mp(t, min(mp_total(t), n))
		n -= m
		if m:
			ev.append({"type": "mp", "id": t.id, "v": -m})
	t.hp -= n
	ev.append({"type": "dmg", "id": t.id, "v": n})
	if st(t, "sleep") and src == "phys":
		t.st.erase("sleep")
	if t.hp <= 0:
		ko_unit(B, t, ev)


static func add_status(t: Dictionary, s: String, ev: Array) -> void:
	if t.ko:
		return
	if s == "haste":
		t.st.erase("slow")
	if s == "slow":
		t.st.erase("haste")
	t.st[s] = 30 if s == "stop" else Data.STATUS[s].t
	ev.append({"type": "status", "id": t.id, "s": s})


func vary(v: float) -> float:
	return v * (.9 + rnd() * .2)


func apply_to(B: Dictionary, a: Dictionary, ab: Dictionary, t: Dictionary, ev: Array, react: Array) -> void:
	var hit = hit_chance(a, t, ab)
	if ab.fx == "atk" or ab.fx == "steal":
		if rnd() * 100 >= hit:
			ev.append({"type": "miss", "id": t.id})
			return
	var foe: bool = t.team != a.team
	match ab.fx:
		"atk", "mag":
			var d := vary(base_amount(B, a, t, ab))
			if ab.fx == "atk" and rnd() < .05:
				d *= 1.5
				ev.append({"type": "msg", "text": "Critical!"})
			hurt(B, t, d, ev, "phys" if ab.fx == "atk" else "mag")
			if foe:
				a.dealt = a.get("dealt", 0) + 1
			if not t.ko:
				for s in ab.get("st", []):
					if rnd() * 100 < status_chance(a, t, ab):
						add_status(t, s, ev)
				var brk = ab.get("brk")
				if brk:
					for k in brk:
						t.brk[k] = t.brk.get(k, 0) + brk[k]
						ev.append({"type": "msg", "text": "%s %s -%d" % [t.name, k.to_upper(), brk[k]]})
				react.append({"t": t, "ab": ab})
		"drain":
			var d: int = min(t.hp, jround(vary(base_amount(B, a, t, ab))))
			hurt(B, t, d, ev, "mag")
			a.hp = min(a.s.mhp, a.hp + d)
			ev.append({"type": "heal", "id": a.id, "v": d})
		"heal":
			var h := jround(vary(-base_amount(B, a, t, ab)))
			t.hp = min(t.s.mhp, t.hp + h)
			ev.append({"type": "heal", "id": t.id, "v": h})
			var cure = ab.get("cure")
			if cure:
				for s in cure:
					if st(t, s):
						t.st.erase(s)
						ev.append({"type": "msg", "text": "%s: %s cured" % [t.name, Data.STATUS[s].name]})
		"mp":
			var v := 0
			for k in Data.PROFS:
				v += fill_mp(t, k, ab.pw)
			ev.append({"type": "mp", "id": t.id, "v": v})
		"raise":
			if t.ko:
				t.ko = false
				t.hp = max(1, jround(t.s.mhp * ab.pw / 100.0))
				t.ct = 0
				ev.append({"type": "raise", "id": t.id})
				ev.append({"type": "heal", "id": t.id, "v": t.hp})
		"buff":
			for s in ab.st:
				add_status(t, s, ev)
		"debuff":
			var any := false
			for s in ab.st:
				if rnd() * 100 < status_chance(a, t, ab):
					add_status(t, s, ev)
					any = true
			if not any:
				ev.append({"type": "miss", "id": t.id})
		"cure":
			var any := false
			for s in ab.cure:
				if st(t, s):
					t.st.erase(s)
					any = true
			ev.append({"type": "msg", "text": (t.name + " is cured.") if any else ("No effect on " + t.name + ".")})
		"mpdmg":
			var v := drain_mp(t, min(mp_total(t), jround(vary(base_amount(B, a, t, ab)))))
			ev.append({"type": "mp", "id": t.id, "v": -v})
			if ab.get("drainmp"):
				fill_mp(a, pf_of(a, ab), v)
				ev.append({"type": "mp", "id": a.id, "v": v})
		"quick":
			t.ct = max(t.ct, 200)
			ev.append({"type": "msg", "text": t.name + " acts next!"})
		"steal":
			do_steal(B, a, t, ab, ev)


func do_steal(B: Dictionary, a: Dictionary, t: Dictionary, ab: Dictionary, ev: Array) -> void:
	if ab.what == "gil":
		if t.mon and a.team == 0:
			ev.append({"type": "msg", "text": "Nothing to steal."})
			return
		var g: int = 20 * t.lv + ri(40)
		if a.team == 0:
			B.stolenGil += g
		else:
			B.gilLost += g
		ev.append({"type": "msg", "text": "%s stole %d gil!" % [a.name, g]})
		return
	var id = t.u.eq.get(ab.what)
	if not id:
		ev.append({"type": "msg", "text": "Nothing to steal."})
		return
	t.u.eq[ab.what] = null
	var hp_pct: float = float(t.hp) / t.s.mhp
	t.s = calc_stats(t.u)
	t.hp = max(1, min(t.s.mhp, jround(t.s.mhp * hp_pct)))
	for k in t.mps:
		t.mps[k] = min(t.mps[k], pool_max(t, k))
	if a.team == 0:
		B.stolen.append(id)
	else:
		B.lost.append({"unit": t.u.id, "item": id})
	ev.append({"type": "msg", "text": "%s stole %s!" % [a.name, Data.ITEMS[id].name]})


## Runs the reactions of damaged targets.
func reactions(B: Dictionary, a: Dictionary, ab: Dictionary, list: Array, ev: Array) -> void:
	for item in list:
		var t: Dictionary = item.t
		if not alive(t) or not alive(a) or st(t, "sleep") or st(t, "stop") or st(t, "disable"):
			continue
		var r = t.u.r
		var d := dist(a, t)
		if r == "laststand" and not t.ls and t.hp < t.s.mhp / 4.0:
			t.ls = 1
			ev.append({"type": "msg", "text": t.name + ": Last Stand!"})
			add_status(t, "boost", ev)
			add_status(t, "protect", ev)
			continue
		if r == "autopotion":
			var ok: bool = t.team == 1 or (B.inv and B.inv.get("potion", 0) > 0)
			if ok and t.hp < t.s.mhp:
				if t.team == 0:
					B.inv.potion -= 1
				var h: int = min(50, t.s.mhp - t.hp)
				t.hp += h
				ev.append({"type": "msg", "text": t.name + ": Auto-Potion"})
				ev.append({"type": "heal", "id": t.id, "v": h})
			continue
		if ab.fx != "atk":
			continue
		var wr := range_of(t, FIGHT)
		var pw := 0.0
		if (r == "counter" or r == "bonecrusher") and d == 1:
			pw = 1.5 if r == "bonecrusher" else 1.0
		if r == "returnfire" and d > 1 and wr.r >= d:
			pw = 1.0
		if not pw:
			continue
		ev.append({"type": "msg", "text": "%s: %s!" % [t.name, Data.AB[r].name]})
		ev.append({"type": "act", "id": t.id, "tx": a.x, "ty": a.y, "ab": "fight"})
		t.f = face_toward(t, a.x, a.y)
		var f2 := FIGHT.duplicate()
		f2.pw = pw
		apply_to(B, t, f2, a, ev, [])


static func exp_for(a: Dictionary, t: Dictionary, _ab: Dictionary) -> int:
	if t.team == a.team:
		return 8
	return 10 + max(0, (t.lv - a.lv) * 4)


## Performs an ability at a center tile. Returns events for the UI.
func perform(B: Dictionary, a: Dictionary, ab_id: String, cx: int, cy: int) -> Array:
	var ab: Dictionary = ability_for(ab_id)
	var ev := []
	var targets := targets_of(B, a, ab, cx, cy)
	a.f = face_toward(a, cx, cy)
	ev.append({"type": "act", "id": a.id, "tx": cx, "ty": cy, "ab": ab_id, "el": element_of(a, ab)})
	ev.append({"type": "msg", "text": a.name + ": " + ab.name})
	if ab.get("mp"):
		a.mps[pf_of(a, ab)] -= mp_cost(a, ab)
	if ab.get("cons"):
		B.inv[ab.cons] -= 1
	if ab.get("combo"):
		a.jp -= ab.jpCost
	var used_boost: bool = st(a, "boost") and ab.fx == "atk"
	var react := []
	var ko_before := {}
	for u in B.units:
		if u.ko:
			ko_before[u.id] = 1
	var exp_gain := 0
	for t in targets:
		if ab.cat == "mag" and t.u.r == "absorbmp" and ab.get("mp") and t.team != a.team:
			var v := fill_mp(t, pf_of(a, ab), mp_cost(a, ab))
			if v:
				ev.append({"type": "mp", "id": t.id, "v": v})
		apply_to(B, a, ab, t, ev, react)
		exp_gain += exp_for(a, t, ab)
	if targets.is_empty():
		exp_gain = 4
	if used_boost:
		a.st.erase("boost")
	# Judge: law and JP
	if B.law:
		if law_match(B.law.ban, a, ab, cx, cy):
			penalize(B, a, ev)
		elif law_match(B.law.fav, a, ab, cx, cy):
			a.jp += 1
			ev.append({"type": "jp", "id": a.id, "v": 1})
	for u in B.units:
		if u.ko and not ko_before.has(u.id) and u.team != a.team and alive(a):
			a.jp += 1
			ev.append({"type": "jp", "id": a.id, "v": 1})
			exp_gain += 10
	if not a.jailed:
		reactions(B, a, ab, react, ev)
	train_prof(a, ab, ev)
	train_vessel(a, ab_id, ev)
	if a.team == 0 and not a.mon:
		var lv := gain_exp(a.u, min(60, exp_gain))
		if not lv.is_empty():
			level_up(a, lv, ev)
	a.acted = true
	check_end(B)
	return ev


static func level_up(a: Dictionary, _lvls: Array, ev: Array) -> void:
	var old: Dictionary = a.s
	var old_max := {}
	for k in Data.PROFS:
		old_max[k] = pool_max(a, k)
	a.s = calc_stats(a.u)
	a.lv = a.u.lv
	a.hp += a.s.mhp - old.mhp
	for k in Data.PROFS:
		a.mps[k] += pool_max(a, k) - old_max[k]
	ev.append({"type": "lvup", "id": a.id, "lv": a.lv})


static func penalize(_B: Dictionary, a: Dictionary, ev: Array) -> void:
	a.cards += 1
	if a.cards == 1:
		ev.append({"type": "card", "id": a.id, "red": false})
		ev.append({"type": "msg", "text": "Yellow card for %s! Next offense means jail." % a.name})
		return
	a.jailed = true
	ev.append({"type": "card", "id": a.id, "red": true})
	ev.append({"type": "msg", "text": "Red card! %s is sent to jail." % a.name})


static func check_end(B: Dictionary) -> int:
	if B.over:
		return B.over
	var p := false
	var e := false
	for u in B.units:
		if alive(u):
			if u.team == 0:
				p = true
			else:
				e = true
	if not e:
		B.over = 1
	elif not p:
		B.over = -1
	return B.over


static func usable_ids(B: Dictionary, bu: Dictionary) -> Array:
	var ids := ["fight"]
	for s in action_sets(bu.u, bu):
		ids.append_array(s.list)
	if bu.team == 0 and B.inv:
		for k in Data.CONS:
			if B.inv.get(k, 0) > 0:
				ids.append("item:" + k)
	if bu.jp >= COMBO.jpCost:
		ids.append("combo")
	return ids


# ---------- AI ----------
static func score_action(B: Dictionary, a: Dictionary, ab: Dictionary, cx: int, cy: int) -> float:
	if breaks_law(B, a, ab, cx, cy):
		return -999
	var ts := targets_of(B, a, ab, cx, cy)
	if ts.is_empty():
		return -1
	var s := 0.0
	for t in ts:
		var ally: bool = t.team == a.team
		var sign := -1.5 if ally else 1.0
		match ab.fx:
			"atk", "mag", "drain":
				var h: float = hit_chance(a, t, ab) / 100.0
				var d := base_amount(B, a, t, ab)
				var v: float = float(min(d, t.hp)) / t.s.mhp * 100 * h
				if d >= t.hp:
					v += 50 * h
				for x in ab.get("st", []):
					if not st(t, x):
						v += 15 * status_chance(a, t, ab) / 100.0 * h
				if ab.get("brk"):
					v += 6
				s += sign * v
			"heal":
				var miss: int = t.s.mhp - t.hp
				var v: float = (float(min(-base_amount(B, a, t, ab), miss)) / t.s.mhp * 100 if t.hp < t.s.mhp * .7 else 0.0)
				if ab.get("cure"):
					v += ab.cure.filter(func(x): return bool(st(t, x))).size() * 10
				s += v if ally else -v
			"raise":
				s += 90
			"buff":
				for x in ab.st:
					if not st(t, x):
						s += (1 if ally else -1) * (28 if x == "haste" else 16)
			"debuff":
				for x in ab.st:
					if not st(t, x):
						s += (-1 if ally else 1) * status_chance(a, t, ab) * (.5 if x == "stop" or x == "doom" else .32)
			"cure":
				if ally:
					s += ab.cure.filter(func(x): return bool(st(t, x))).size() * 22
			"steal":
				if not ally:
					if ab.what == "gil":
						s += 0 if t.mon else 12
					else:
						s += 22 if t.u.eq.get(ab.what) else 0
			"mpdmg":
				if not ally and mp_total(t) > 0:
					s += 10
			"quick":
				if ally and not is_same(t, a):
					s += 30
			"mp":
				if ally:
					s += 20 if (t.s.mmp * 6 - mp_total(t)) > 20 else 0
	if B.law and law_match(B.law.fav, a, ab, cx, cy):
		s += 4
	s -= mp_cost(a, ab) * .2
	return s


## BFS distance (ignoring the move limit) from units of `team` across passable tiles.
static func dist_field(B: Dictionary, team: int, bu: Dictionary) -> Dictionary:
	var D := {}
	var q := []
	var jp = eff(bu, "jp")
	for u in B.units:
		if alive(u) and u.team == team:
			for d in DIRS:
				var x: int = u.x + d[0]
				var y: int = u.y + d[1]
				var t = tile_at(B, x, y)
				if t != null and Data.TERRAIN[t.t].pass and not D.has(key(x, y)):
					D[key(x, y)] = 1
					q.append([x, y])
	var qi := 0
	while qi < q.size():
		var x: int = q[qi][0]
		var y: int = q[qi][1]
		qi += 1
		var dd: int = D[key(x, y)]
		var t0: Dictionary = tile_at(B, x, y)
		for d in DIRS:
			var nx: int = x + d[0]
			var ny: int = y + d[1]
			var t = tile_at(B, nx, ny)
			if t == null or not Data.TERRAIN[t.t].pass or D.has(key(nx, ny)) or absi(t.h - t0.h) > jp + 1:
				continue
			D[key(nx, ny)] = dd + 1
			q.append([nx, ny])
	return D


static func ai_plan(B: Dictionary, a: Dictionary) -> Dictionary:
	# A free pickup first: an empty vessel takes the nearest object in reach.
	var pick = null
	if not a.vessel and not a.mon:
		var o = null
		for c in objs_in_reach(B, a):
			if o == null or dist(a, c) < dist(a, o):
				o = c
		if o != null:
			pickup(B, a, o.id)
			pick = o.skill
	var ox: int = a.x
	var oy: int = a.y
	var tiles: Array = reach(B, a).out.values() if can_move(a) else [{"x": a.x, "y": a.y}]
	var can_act: bool = not a.acted and not st(a, "disable")
	var ids := []
	if can_act:
		ids = usable_ids(B, a).filter(func(id): return blocked(B, a, ability_for(id)) == "")
	var best = null
	var fd := dist_field(B, 1 - a.team, a)
	for T in tiles:
		a.x = T.x
		a.y = T.y
		var near: int = fd.get(key(T.x, T.y), 99)
		for id in ids:
			var ab: Dictionary = ability_for(id)
			if ab.cat == "item" and a.team == 1:
				continue
			for c in range_tiles(B, a, ab):
				var s := score_action(B, a, ab, c[0], c[1])
				if s <= 0:
					continue
				s -= T.get("d", 0) * .3
				if ab.fx == "heal" or ab.cat == "mag":
					s += min(near, 4) * .5  # casters prefer some distance
				if best == null or s > best.s:
					best = {"s": s, "x": T.x, "y": T.y, "id": id, "cx": c[0], "cy": c[1]}
	a.x = ox
	a.y = oy
	if best != null and best.s > 2:
		best["pick"] = pick
		return best
	# Nothing worth doing: advance toward the nearest foe.
	var mv = null
	for T in tiles:
		var d = fd.get(key(T.x, T.y))
		if d == null:
			continue
		if mv == null or d < mv.d:
			mv = {"d": d, "x": T.x, "y": T.y}
	return {"s": 0, "x": mv.x if mv else a.x, "y": mv.y if mv else a.y, "id": null, "cx": null, "cy": null, "pick": pick}


static func nearest_foe(B: Dictionary, a: Dictionary) -> Variant:
	var best = null
	for u in B.units:
		if alive(u) and u.team != a.team and (best == null or dist(a, u) < dist(a, best)):
			best = u
	return best


## Today's banned and favored law (engine.js dailyLaw).
static func daily_law(day: int) -> Dictionary:
	var keys := Data.LAWS.keys()
	var s := (day * 2654435761) & 0xFFFFFFFF
	s = (s * 1103515245 + 12345) & 0xFFFFFFFF
	var ban: String = keys[int(floor(s / 4294967296.0 * keys.size()))]
	s = (s * 1103515245 + 12345) & 0xFFFFFFFF
	var fav: String = keys[int(floor(s / 4294967296.0 * keys.size()))]
	if fav == ban:
		fav = keys[(keys.find(ban) + 1) % keys.size()]
	return {"ban": ban, "fav": fav}
