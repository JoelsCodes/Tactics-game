class_name DamageForecast
extends RefCounted
## What an action would do to each unit it hits, worked out for the damage prediction view (ForecastPanel): the chance to hit, the
## damage or healing as a range (a physical skill rolls its rank band; Heal rolls 27 to 33), the target's HP before and after, whether
## it could be knocked out, and the extra effects (a status, poison, a push). Pure: it only reads the battle (BattleController.preview,
## miss_chance_for) and changes nothing.

class Line:
	var target: BattleUnit
	var heal := false
	var hit_percent := 100  ## chance the hit lands (heals never miss)
	var low := 0  ## the smallest HP change (damage or healing)
	var high := 0
	var hp_before := 0
	var hp_low := 0  ## target HP after the largest / smallest outcome (hp_low <= hp_high)
	var hp_high := 0
	var max_hp := 1
	var ko := false  ## even the smallest hit knocks it out
	var may_ko := false  ## the largest hit could
	var headline := ""  ## the big text: "59", "52-61", "+30", "50%"
	var caption := ""  ## under it: "Damage", "Heal", "Poison"
	var notes: Array[String] = []  ## other effects, e.g. "Marked", "Pushes 1 tile"

var action_name := ""
var sp_cost := 0
var lines: Array[Line] = []
var aimed: Line  ## the one on the aimed tile (the first when that tile holds nobody)


func is_empty() -> bool:
	return lines.is_empty()


## The forecast of `action` by `bu` aimed at `aim`.
static func make(battle: BattleController, bu: BattleUnit, action: BattleAction, aim: Vector2i) -> DamageForecast:
	var f := DamageForecast.new()
	f.action_name = action.display_name()
	f.sp_cost = battle._sp_spent(bu, action)
	var nominal := battle.preview(bu, action, aim)
	if nominal.hits.is_empty():
		return f
	var s := action.skill
	var rolls := s != null and s.is_physical() and s.fixed_multiplier <= 0.0
	var lo_r := battle.preview(bu, action, aim, s.band()[0]) if rolls else nominal
	var hi_r := battle.preview(bu, action, aim, s.band()[1]) if rolls else nominal
	for i in nominal.hits.size():
		var h: ActionResult.Hit = nominal.hits[i]
		var l := Line.new()
		l.target = h.target
		l.heal = h.heal
		l.low = lo_r.hits[i].amount
		l.high = hi_r.hits[i].amount
		if s != null and s.support == "heal":  # Heal rolls 30 plus or minus 10%
			l.low = roundi(SupportRules.HEAL_BASE * (1.0 - SupportRules.HEAL_SPREAD))
			l.high = roundi(SupportRules.HEAL_BASE * (1.0 + SupportRules.HEAL_SPREAD))
		l.low = mini(l.low, l.high)
		l.hit_percent = 100 if h.heal else roundi((1.0 - battle.miss_chance_for(bu, h.target, action)) * 100.0)
		l.hp_before = h.target.hp
		l.max_hp = maxi(1, h.target.max_hp())
		if h.heal:
			l.hp_low = mini(l.max_hp, h.target.hp + l.low)
			l.hp_high = mini(l.max_hp, h.target.hp + l.high)
		else:  # the largest hit leaves the least HP
			l.hp_low = maxi(0, h.target.hp - l.high)
			l.hp_high = maxi(0, h.target.hp - l.low)
			l.ko = l.hp_high <= 0
			l.may_ko = l.hp_low <= 0
		_text(l, s)
		_notes(l, s)
		f.lines.append(l)
		if f.aimed == null and (h.tile == aim):
			f.aimed = l
	if f.aimed == null:
		f.aimed = f.lines[0]
	return f


## The big text and its caption.
static func _text(l: Line, s: SkillData) -> void:
	var range_text := str(l.low) if l.low == l.high else "%d-%d" % [l.low, l.high]
	l.headline = ("+" + range_text) if l.heal else range_text
	l.caption = "Heal" if l.heal else "Damage"
	if s != null and s.support == "" and l.low == 0 and l.high == 0:  # an effect with no HP change
		l.headline = "Effect"
		l.caption = "Status" if not l.heal else "Support"
	if s == null or s.support == "":
		return
	match s.support:
		"pray":
			l.headline = "%d%%" % roundi(SupportRules.PRAY_CHANCE * 100.0)
			l.caption = "Cure ailments"
		"roulette":
			l.headline = "50 / 50"
			l.caption = "Full heal or half HP"
		"poison_spit":
			l.headline = "%d%%" % roundi(SupportRules.POISON_CHANCE * 100.0)
			l.caption = "Poison"
		"venom_removal":
			l.headline = "Cure"
			l.caption = "Poison"
		"chance":
			l.headline = "+%d%%" % SupportRules.CHANCE_PERCENT
			l.caption = "Random stat"


## Other effects of the skill (what it does besides the HP change).
static func _notes(l: Line, s: SkillData) -> void:
	if s == null:
		return
	if s.status != "":
		l.notes.append(s.status.replace("_", " ").capitalize())
	for n in SkillFx.notes(s):
		l.notes.append(n)
	if s.slow > 0:
		l.notes.append("-%d Move" % s.slow)
	if s.push > 0:
		l.notes.append("Pushes %d" % s.push)
	if s.spare:
		l.notes.append("Never KOs")
	if s.support == "roulette":
		l.notes.append("Never KOs")
	if s.support == "sp_finisher":
		l.notes.append("Uses all SP")
	if l.ko and l.hit_percent >= 100:
		l.notes.append("Knockout")
