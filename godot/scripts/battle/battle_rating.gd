class_name BattleRating
extends RefCounted
## The grade a won battle earns, the feats behind it and the bonus XP it pays. BattleStage feeds it every ActionResult (`on_action`)
## and closes it when the battle is won (`finish`); the results screen shows it and CampaignState keeps each map's best grade.
##
##   Victory      VICTORY_POINTS
##   Tempo        up to TEMPO_POINTS: all of it at or under par (PAR_BASE + one round per enemy), TEMPO_STEP less per round over
##   Survival     up to SURVIVAL_POINTS: SURVIVAL_STEP less for each ally that was down at the end; UNTOUCHED_POINTS more when
##                the whole party took no damage at all
##   Technique    up to TECHNIQUE_POINTS: critical hits, pincers, several knockouts in one action, Surges, the best Chain
##
##   S 90+   A 75+   B 60+   C 45+   D below; bonus XP = the enemy XP pool x BONUS[grade] percent.
##
## A lost battle is not rated. Nothing here changes the battle.

const VICTORY_POINTS := 40
const TEMPO_POINTS := 25
const TEMPO_STEP := 5
const PAR_BASE := 4
const SURVIVAL_POINTS := 20
const SURVIVAL_STEP := 10
const UNTOUCHED_POINTS := 5
const TECHNIQUE_POINTS := 15
const GRADES: Array = [["S", 90], ["A", 75], ["B", 60], ["C", 45], ["D", 0]]
const BONUS := {"S": 30, "A": 20, "B": 10, "C": 5, "D": 0}
const ORDER := "DCBAS"  ## worst to best

var crits := 0
var pincers := 0
var multi_kos := 0  ## actions that knocked out two or more enemies
var most_kos := 0  ## the most enemies one action knocked out
var surges := 0
var best_chain := 0
var biggest_hit := 0
var biggest_hitter := ""

var rounds := 0
var par := 0
var fallen := 0
var damage_taken := 0
var score := 0
var grade := ""
var bonus_percent := 0
var feats: Array[Dictionary] = []  ## {name, detail, points}: shown one by one on the results screen
var mvp: BattleUnit  ## the player unit that did the most (damage dealt + healing done + 10 per knockout)


static func par_for(enemy_count: int) -> int:
	return PAR_BASE + enemy_count


static func grade_for(points: int) -> String:
	for g in GRADES:
		if points >= int(g[1]):
			return g[0]
	return "D"


## True when grade `a` is better than `b` ("" is no grade at all).
static func better(a: String, b: String) -> bool:
	return ORDER.find(a) > ORDER.find(b)


## One performed action by a unit on the player's side.
func on_action(user: BattleUnit, r: ActionResult) -> void:
	if r == null or not r.ok or user == null or user.team != 0:
		return
	var kos := 0
	for h in r.hits:
		if h.heal or h.missed or h.target == null or h.target.team == user.team:
			continue
		if h.crit:
			crits += 1
		if h.knocked_out:
			kos += 1
		if h.amount > biggest_hit:
			biggest_hit = h.amount
			biggest_hitter = user.data.display_name
	for f in r.followups:
		if not f.hit.missed and f.hit.amount > 0:
			pincers += 1
			if f.hit.knocked_out:
				kos += 1
	if kos >= 2:
		multi_kos += 1
	most_kos = maxi(most_kos, kos)
	if r.surged:
		surges += 1


## Closes the rating of a won battle: `summary` as BattleController has it (before the XP is handed out), the round the battle ended in
## and the Momentum's best Chain.
func finish(summary: BattleSummary, enemy_count: int, last_round: int, chain: int) -> void:
	rounds = maxi(1, last_round)
	par = par_for(enemy_count)
	best_chain = chain
	fallen = 0
	damage_taken = 0
	var best := -1
	for bu in summary.lines:
		if bu.data.role() == UnitData.Role.ENEMY or bu.team != 0:
			continue
		var l: BattleSummary.UnitLine = summary.lines[bu]
		if bu.is_down() and not bu.fled:
			fallen += 1
		damage_taken += l.damage_taken
		var did := l.damage_dealt + l.healing_done + 10 * l.knockouts
		if l.turns > 0 and did > best:
			best = did
			mvp = bu
	feats.clear()
	score = VICTORY_POINTS
	feats.append({"name": "Victory", "detail": "The field is yours", "points": VICTORY_POINTS})
	var tempo := clampi(TEMPO_POINTS - TEMPO_STEP * maxi(0, rounds - par), 0, TEMPO_POINTS)
	score += tempo
	if tempo > 0:
		feats.append({"name": "Swift Victory" if rounds <= par else "Steady Pace", "detail": "Round %d (par %d)" % [rounds, par], "points": tempo})
	var survival := clampi(SURVIVAL_POINTS - SURVIVAL_STEP * fallen, 0, SURVIVAL_POINTS)
	score += survival
	if fallen == 0:
		feats.append({"name": "No One Fell", "detail": "Everyone left standing", "points": survival})
	elif survival > 0:
		feats.append({"name": "Hard Fought", "detail": "%d fell" % fallen, "points": survival})
	if damage_taken == 0:
		score += UNTOUCHED_POINTS
		feats.append({"name": "Untouched", "detail": "Not a scratch", "points": UNTOUCHED_POINTS})
	var tech := 0
	var parts: Array[String] = []
	if crits > 0:
		tech += 2 * crits
		parts.append("%d critical" % crits)
	if pincers > 0:
		tech += 3 * pincers
		parts.append("%d pincer" % pincers)
	if multi_kos > 0:
		tech += 4 * multi_kos
		parts.append("%d-in-one knockout" % most_kos)
	if surges > 0:
		tech += 3 * surges
		parts.append("%d Surge" % surges)
	if best_chain >= 3:
		tech += best_chain
		parts.append("Chain x%d" % best_chain)
	tech = mini(tech, TECHNIQUE_POINTS)
	score += tech
	if tech > 0:
		feats.append({"name": "Technique", "detail": ", ".join(parts), "points": tech})
	grade = grade_for(score)
	bonus_percent = int(BONUS[grade])


## The bonus XP the grade adds to a pool.
func bonus_for(pool: int) -> int:
	return pool * bonus_percent / 100
