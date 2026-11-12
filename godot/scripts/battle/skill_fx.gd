class_name SkillFx
extends RefCounted
## The extra rules a skill carries in its "fx" object (SkillData.fx, data/skills/*.json), used by every proficiency from rank E to S.
## BattleController calls it from `preview` (the nominal numbers and the area), `perform` (rolls, then the effects) and `end_turn`
## (burn and regen). Every key is optional.
##
## Damage (per unit hit, after the proficiency's own formula):
##   scale       x the damage (a float)
##   hits        n strikes at 60% each (so 2 hits = 120%)
##   execute     +percent damage on a target at 30% HP or less
##   vs_status   {"status": name, "bonus": percent}: more damage on a target that has it
##   desperate   up to +percent damage as the user's HP runs out
##   pct_hp      damage is this percent of the target's max HP instead (ignores Defense and Resistance)
##   chaos       [low, high]: the damage is rolled between those percents of itself on every use
## Area and aiming:
##   blast       radius: every tile within this many steps of the aimed tile is hit too
##   self_only   no aiming: it lands on the user alone
## On each unit hit that is not missed:
##   drain       the user regains this percent of the damage dealt
##   status      {name: turns}, with status_chance (percent, default 100)
##   mods        [{stat, pct, turns}]: a stat raised or lowered for some of the target's turns
##   sp_drain    the target loses this much SP (sp_steal: the user gains it)
##   sp_give     the target gains this much SP
##   soul        a soul-binding effect: it does nothing to Lyra once she is a living Co-Captain ("Unbound")
##   vessels_only  it works on vessels only (anyone else is "Unmoved")
##   telegraph   the aim is marked and the blow lands when the caster's next turn comes (BattleController.land_telegraphs)
##   fade_drain  a vessel target's Fade Clock loses this many ticks (never below 1; nothing happens to anyone else)
##   heal_pct    restores this percent of the target's max HP
##   cleanse     removes every harmful status and lowered stat
##   guard       the target guards (half damage) until its next turn
##   pull        the target is dragged this many tiles toward the user
##   swap        the user and the target change places
##   delay       the target's next turn comes later (CT lost)
##   rush        the target's next turn comes sooner (CT gained)
## On the user once the action lands (`self`): heal_pct, recoil_pct (of max HP, never the last point), sp_gain, mods, guard, status.
## Targeting is set by the skill's allies_only / enemies_only.

const LOW_HP_PERCENT := 30
const BLAST_REACH := 3  ## height levels a blast reaches up or down from the aimed tile
const BURN_PERCENT := 6
const REGEN_PERCENT := 8
const HIT_PERCENT := 60  ## each strike of a multi-hit skill


static func has(s: SkillData) -> bool:
	return s != null and not s.fx.is_empty()


## Lyra, once she is a living Co-Captain, is out of reach of soul-binding skills (her bond to Alaric is her own).
static func soul_immune(t: BattleUnit) -> bool:
	return t.data != null and t.data.display_name == "Lyra" and not t.is_vessel()


static func flag(s: SkillData, key: String) -> bool:
	return s != null and bool(s.fx.get(key, false))


static func num(s: SkillData, key: String, fallback := 0) -> int:
	return int(s.fx.get(key, fallback)) if s != null else fallback


## Tactical skills always land (the status proficiency's can be resisted: they miss like an attack).
static func never_misses(s: SkillData) -> bool:
	return s != null and s.category == Proficiency.Category.TACTICAL


## Whether the skill needs somebody on the other end (an ally or an enemy skill with nobody there is refused).
static func needs_target(s: SkillData) -> bool:
	return s != null and (s.allies_only or s.enemies_only)


static func stat_of(name: String) -> StatModifier.Stat:
	var i := StatModifier.Stat.keys().find(name.to_upper())
	return (i if i >= 0 else StatModifier.Stat.ATTACK) as StatModifier.Stat


## Tiles around `aim` that a blast of `radius` also reaches (not the aimed tile itself).
static func blast_tiles(grid: TacticalGrid, aim: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if absi(dx) + absi(dy) > radius or (dx == 0 and dy == 0):
				continue
			var c := aim + Vector2i(dx, dy)
			if grid.in_bounds(c) and not grid.is_void(c) and not grid.is_obstacle(c) and absf(grid.height(c) - grid.height(aim)) <= BLAST_REACH:
				out.append(c)
	return out


## The damage or healing of one hit after the skill's own modifiers (the nominal number; `chaos` is rolled in `roll`).
static func adjust(user: BattleUnit, target: BattleUnit, s: SkillData, amount: int, heal: bool) -> int:
	var fx := s.fx
	if heal:
		if fx.has("heal_pct"):
			amount += maxi(1, target.max_hp() * int(fx.heal_pct) / 100)
		return amount
	if fx.has("pct_hp"):
		amount = maxi(1, target.max_hp() * int(fx.pct_hp) / 100)
	if fx.has("hits"):
		amount = maxi(1, roundi(amount * HIT_PERCENT / 100.0 * int(fx.hits)))
	if fx.has("scale"):
		amount = maxi(1, roundi(amount * float(fx.scale)))
	var bonus := 0
	if fx.has("execute") and target.hp * 100 <= target.max_hp() * LOW_HP_PERCENT:
		bonus += int(fx.execute)
	if fx.has("vs_status") and target.has_status(String(fx.vs_status.status)):
		bonus += int(fx.vs_status.bonus)
	if fx.has("desperate"):
		var lost := 1.0 - float(user.hp) / maxi(1, user.max_hp())
		bonus += roundi(lost * int(fx.desperate))
	if bonus != 0:
		amount = maxi(1, amount * (100 + bonus) / 100)
	return amount


## Rolls what is random in a performed action (before the HP changes are applied): `chaos`.
static func roll(r: ActionResult, s: SkillData, rng: RandomNumberGenerator) -> void:
	if not s.fx.has("chaos"):
		return
	var c: Array = s.fx.chaos
	for h in r.hits:
		if h.missed or h.amount <= 0:
			continue
		h.amount = maxi(1, h.amount * rng.randi_range(int(c[0]), int(c[1])) / 100)
		h.knocked_out = not h.heal and h.amount >= h.target.hp
		h.notes.append("Chaos")


## The effects that land once the HP changes are applied: on every hit that was not missed, then on the user.
static func apply(ctrl: BattleController, user: BattleUnit, s: SkillData, r: ActionResult, rng: RandomNumberGenerator) -> void:
	var fx := s.fx
	var landed := false
	for h in r.hits:
		if h.missed:
			continue
		landed = true
		var t := h.target
		if fx.get("soul", false) and soul_immune(t):
			h.notes.append("Unbound")
			continue
		if fx.get("vessels_only", false) and not t.is_vessel():
			h.notes.append("Unmoved")
			continue
		if fx.has("drain") and not h.heal and h.amount > 0:
			var back := mini(maxi(1, h.amount * int(fx.drain) / 100), user.max_hp() - user.hp)
			user.hp += maxi(0, back)
			h.notes.append("Drained %d" % maxi(0, back))
		if t.is_down():
			continue
		if fx.has("status"):
			var chance := int(fx.get("status_chance", 100))
			for name in fx.status:
				if chance >= 100 or rng.randi_range(1, 100) <= chance:
					t.add_status(String(name), int(fx.status[name]))
					h.notes.append(status_label(String(name)))
				else:
					h.notes.append("Resisted")
		for m in fx.get("mods", []):
			_mod(t, m, h)
		if fx.has("sp_drain"):
			var n := mini(int(fx.sp_drain), t.sp)
			t.sp -= n
			if fx.get("sp_steal", false):
				user.sp = mini(user.max_sp(), user.sp + n)
			h.notes.append("-%d SP" % n)
		if fx.has("fade_drain") and t.fade_clock != null:
			var f := t.fade_clock.shorten(int(fx.fade_drain))
			h.notes.append("Fade -%d" % f if f > 0 else "Fade Clock at its last tick")
		if fx.has("sp_give"):
			var g := mini(int(fx.sp_give), t.max_sp() - t.sp)
			t.sp += g
			h.notes.append("+%d SP" % g)
		if fx.get("cleanse", false):
			h.notes.append("Cleansed" if cleanse(t) else "Nothing to cleanse")
		for st in fx.get("cure", []):
			if t.has_status(String(st)):
				t.statuses.erase(String(st))
				h.notes.append("%s cured" % status_label(String(st)))
		if fx.get("guard", false):
			t.guarding = true
			h.notes.append("Guarding")
		if fx.has("pull") and t != user:
			_pull(ctrl, user, t, int(fx.pull), r)
		if fx.get("swap", false) and t != user:
			_swap(ctrl, user, t, r)
		if fx.has("delay"):
			t.ct = maxi(0, t.ct - int(fx.delay))
			h.notes.append("Delayed")
		if fx.has("rush"):
			t.ct += int(fx.rush)
			h.notes.append("Hastened")
	if landed and fx.has("self"):
		_self(user, fx.self, r)


## What a status is called on screen.
static func status_label(name: String) -> String:
	return {"mild_blind": "Blinded", "atk_down": "Attack down", "poison": "Poisoned", "burn": "Burning", "regen": "Regen", "ward": "Warded",
		"exposed": "Exposed", "silence": "Silenced", "root": "Rooted", "marked": "Marked", "sleep": "Asleep", "stun": "Stunned", "confuse": "Confused",
		"berserk": "Berserk", "doom": "Doomed", "curse": "Cursed", "blind": "Blind", "slowed": "Slowed", "haste": "Hasted"}.get(name, name.capitalize())


## Removes every harmful status and lowered stat. Returns whether anything went.
static func cleanse(t: BattleUnit) -> bool:
	var had := false
	for st in BattleUnit.NEGATIVE:
		if t.has_status(st):
			t.statuses.erase(st)
			had = true
	for k in t.buffs.keys():
		if int(t.buffs[k][0]) < 0:
			t.buffs.erase(k)
			had = true
	return had


static func _mod(t: BattleUnit, m: Dictionary, h: ActionResult.Hit) -> void:
	var st := stat_of(String(m.stat))
	t.add_buff(st, int(m.pct), int(m.turns))
	h.notes.append("%s %s%d%%" % [StatModifier.stat_name(st), "+" if int(m.pct) >= 0 else "", int(m.pct)])


static func _self(user: BattleUnit, d: Dictionary, r: ActionResult) -> void:
	var note := ""
	if d.has("heal_pct"):
		var n := mini(user.max_hp() * int(d.heal_pct) / 100, user.max_hp() - user.hp)
		user.hp += maxi(0, n)
		note = "Healed %d" % maxi(0, n)
	if d.has("recoil_pct"):
		user.hp = maxi(1, user.hp - maxi(1, user.max_hp() * int(d.recoil_pct) / 100))
		note = "Recoil"
	if d.has("sp_gain"):
		user.sp = mini(user.max_sp(), user.sp + int(d.sp_gain))
	for m in d.get("mods", []):
		var st := stat_of(String(m.stat))
		user.add_buff(st, int(m.pct), int(m.turns))
	if d.get("guard", false):
		user.guarding = true
	for name in d.get("status", {}):
		user.add_status(String(name), int(d.status[name]))
	if note != "" and not r.hits.is_empty():
		r.hits[0].notes.append("User: " + note)


## Drags `t` up to `n` tiles toward `user` along the straight line between them (never onto the user's tile, nor a tile that cannot be stood on).
static func _pull(ctrl: BattleController, user: BattleUnit, t: BattleUnit, n: int, r: ActionResult) -> void:
	var off := user.cell - t.cell
	if off.x != 0 and off.y != 0:
		return
	var dir := Vector2i(signi(off.x), signi(off.y))
	var dest := t.cell
	for i in n:
		var next := dest + dir
		if next == user.cell or not ctrl.grid.can_stand(next):
			break
		dest = next
	if dest != t.cell:
		var from := t.cell
		ctrl.grid.move_occupant(t, dest)
		t.cell = dest
		r.pushed.append({"unit": t, "from": from, "to": dest})


static func _swap(ctrl: BattleController, user: BattleUnit, t: BattleUnit, r: ActionResult) -> void:
	var a := user.cell
	var b := t.cell
	ctrl.grid.remove(user)
	ctrl.grid.remove(t)
	ctrl.grid.place(user, b, user.team)
	ctrl.grid.place(t, a, t.team)
	user.cell = b
	t.cell = a
	r.pushed.append({"unit": user, "from": a, "to": b})
	r.pushed.append({"unit": t, "from": b, "to": a})


## Burn and regen at the end of the unit's own turn. Burn never takes the last point (like poison). Fills `bu.tick_notes`.
static func tick(bu: BattleUnit) -> void:
	bu.tick_notes.clear()
	if bu.is_down():
		return
	if bu.has_status(BattleUnit.BURN):
		var d := mini(maxi(1, bu.max_hp() * BURN_PERCENT / 100), maxi(0, bu.hp - 1))
		bu.hp -= d
		bu.tick_notes.append("Burn -%d" % d)
	if bu.has_status(BattleUnit.REGEN):
		var g := mini(maxi(1, bu.max_hp() * REGEN_PERCENT / 100), bu.max_hp() - bu.hp)
		bu.hp += g
		bu.tick_notes.append("Regen +%d" % g)


## How much the AI values what a previewed hit does besides HP: harmful statuses and lowered stats on a foe, boosts and cures on an
## ally. Nothing for an effect the target already has.
static func ai_value(user: BattleUnit, h: ActionResult.Hit, s: SkillData) -> float:
	if not has(s):
		return 0.0
	var t := h.target
	var ally := t.team == user.team
	var v := 0.0
	var fx := s.fx
	if not ally and ((fx.get("soul", false) and soul_immune(t)) or (fx.get("vessels_only", false) and not t.is_vessel())):
		return 0.0
	for name in fx.get("status", {}):
		var bad: bool = name in BattleUnit.NEGATIVE
		if t.has_status(String(name)):
			continue
		v += (6.0 if bad and not ally else (-6.0 if bad and ally else (5.0 if ally else -5.0)))
	for m in fx.get("mods", []):
		var good := int(m.pct) > 0
		v += 5.0 if good == ally else -5.0
	if fx.get("cleanse", false):
		var count := 0
		for st in BattleUnit.NEGATIVE:
			if t.has_status(st):
				count += 1
		v += (4.0 * count) if ally else 0.0
	if fx.get("guard", false) and ally and not t.guarding:
		v += 3.0
	if fx.has("sp_drain") and not ally:
		v += 0.6 * mini(int(fx.sp_drain), t.sp)
	if fx.has("fade_drain") and not ally and t.fade_clock != null:
		v += 6.0 * mini(int(fx.fade_drain), t.fade_clock.turns_left - 1)
	if fx.has("sp_give") and ally:
		v += 0.5 * mini(int(fx.sp_give), t.max_sp() - t.sp)
	if fx.has("delay") and not ally:
		v += 0.15 * int(fx.delay)
	if fx.has("rush") and ally:
		v += 0.1 * int(fx.rush)
	if fx.has("pull") and not ally:
		v += 1.0
	return v


## Short lines for the forecast: what the skill does besides its HP change.
static func notes(s: SkillData) -> Array[String]:
	var out: Array[String] = []
	if not has(s):
		return out
	var fx := s.fx
	for name in fx.get("status", {}):
		out.append(status_label(String(name)) + (" %d%%" % int(fx.status_chance) if fx.has("status_chance") else ""))
	for m in fx.get("mods", []):
		out.append("%s %s%d%%" % [StatModifier.stat_name(stat_of(String(m.stat))), "+" if int(m.pct) >= 0 else "", int(m.pct)])
	if fx.has("blast"):
		out.append("Blast %d" % int(fx.blast))
	if fx.has("hits"):
		out.append("%d hits" % int(fx.hits))
	if fx.has("drain"):
		out.append("Drains %d%%" % int(fx.drain))
	if fx.has("execute"):
		out.append("Execute +%d%%" % int(fx.execute))
	if fx.has("chaos"):
		out.append("Random damage")
	if fx.has("pull"):
		out.append("Pulls %d" % int(fx.pull))
	if fx.get("swap", false):
		out.append("Swaps places")
	if fx.get("cleanse", false):
		out.append("Cleanses")
	if fx.get("guard", false):
		out.append("Guards")
	if fx.has("sp_drain"):
		out.append("-%d SP" % int(fx.sp_drain))
	if fx.has("fade_drain"):
		out.append("Fade -%d" % int(fx.fade_drain))
	if fx.has("sp_give"):
		out.append("+%d SP" % int(fx.sp_give))
	if fx.has("delay"):
		out.append("Delays")
	if fx.has("rush"):
		out.append("Hastens")
	return out
