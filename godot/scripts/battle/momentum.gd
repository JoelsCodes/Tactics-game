class_name Momentum
extends RefCounted
## Momentum: the party's shared gauge (0 to MAX) that fighting well fills, and the Chain that makes it fill faster.
##
##   A player unit's action        + DAMAGE_GAIN x (damage / the target's max HP) per target hit (capped per target)
##                                 + CRIT_GAIN per critical hit, + KO_GAIN per knockout, + PINCER_GAIN per pincer follow-up that lands,
##                                 + HEAL_GAIN per ally healed; the whole sum x (1 + CHAIN_STEP per link of the Chain, up to CHAIN_CAP links)
##   The Chain                     +1 for every player action in a row that lands damage; an attack that hits nothing, or an ally
##                                 knocked out, breaks it (back to 0). Support actions neither add to it nor break it.
##   An enemy's action             + GRIT_GAIN per player unit it hurts, + AVENGE_GAIN when it knocks one out (the tide turns)
##   A full gauge                  the acting player unit may spend all of it on a Surge (BattleController.surge_unit): its next
##                                 damaging action cannot miss and is critical on every target. A surged action fills nothing.
##
## Only the player's side has it. It lives for one battle and is never saved. BattleStage feeds it every ActionResult (`on_action`)
## and shows it (MomentumGauge); nothing here touches the battle itself.

signal changed  ## the gauge or the Chain moved
signal filled  ## the gauge just reached MAX

const MAX := 100.0
const DAMAGE_GAIN := 30.0
const CRIT_GAIN := 8.0
const KO_GAIN := 15.0
const PINCER_GAIN := 10.0
const HEAL_GAIN := 4.0
const GRIT_GAIN := 5.0
const AVENGE_GAIN := 10.0
const CHAIN_STEP := 0.1
const CHAIN_CAP := 5

var value := 0.0
var chain := 0  ## player actions in a row that landed damage
var best_chain := 0
var surges := 0  ## Surges spent this battle


func is_full() -> bool:
	return value >= MAX


func ratio() -> float:
	return clampf(value / MAX, 0.0, 1.0)


## The Chain's multiplier on the next gain.
func chain_mult() -> float:
	return 1.0 + CHAIN_STEP * mini(maxi(chain - 1, 0), CHAIN_CAP)


## Takes one performed action into account. `player_side` is true when the user fights for the player and is under the
## player's control. Returns what was gained (0 for a surged action).
func on_action(user: BattleUnit, r: ActionResult, player_side: bool) -> float:
	if r == null or not r.ok:
		return 0.0
	var gain := 0.0
	if player_side:
		var aimed := false  # the action tried to hurt someone
		var landed := false
		var base := 0.0
		for h in r.hits:
			if h.heal:
				if h.amount > 0:
					base += HEAL_GAIN
				continue
			if h.target != null and h.target.team == user.team:
				continue  # hurting an ally earns nothing
			aimed = true
			if h.missed or h.amount <= 0:
				continue
			landed = true
			base += minf(DAMAGE_GAIN, DAMAGE_GAIN * float(h.amount) / maxf(1.0, float(h.target.max_hp())))
			if h.crit:
				base += CRIT_GAIN
			if h.knocked_out:
				base += KO_GAIN
		for f in r.followups:
			if f.hit.missed or f.hit.amount <= 0:
				continue
			landed = true
			base += PINCER_GAIN
			if f.hit.knocked_out:
				base += KO_GAIN
		if landed:
			chain += 1
			best_chain = maxi(best_chain, chain)
		elif aimed:
			chain = 0
		if not r.surged:
			gain = base * chain_mult()
	else:
		for h in r.hits:
			if h.heal or h.missed or h.amount <= 0 or h.target == null or h.target.team != 0:
				continue
			gain += GRIT_GAIN
			if h.knocked_out:
				gain += AVENGE_GAIN
				chain = 0
		for f in r.followups:
			if not f.hit.missed and f.hit.amount > 0 and f.hit.target.team == 0:
				gain += GRIT_GAIN
				if f.hit.knocked_out:
					gain += AVENGE_GAIN
					chain = 0
	add(gain)
	return gain


func add(amount: float) -> void:
	var was_full := is_full()
	value = clampf(value + amount, 0.0, MAX)
	changed.emit()
	if not was_full and is_full():
		filled.emit()


## Spends the whole gauge on a Surge. False when it is not full.
func spend() -> bool:
	if not is_full():
		return false
	value = 0.0
	surges += 1
	changed.emit()
	return true


## Gives a Surge that was armed but never used back.
func refund() -> void:
	surges = maxi(0, surges - 1)
	value = MAX
	changed.emit()
