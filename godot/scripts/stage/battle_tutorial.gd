class_name BattleTutorial
extends Node
## The summon tutorial of the story's chamber battle: a hint panel under the objectives (BattleHud.show_tip) that follows
## what the player is doing. It changes nothing in the rules and never blocks input; it only reads the stage's state:
##   Alaric's turn, nobody summoned    open SUMMON
##   the summon list is open           pick a vessel
##   choosing the crystal              click a glowing crystal
##   one summoned, one left            call the other one
##   a vessel's own turn               what a vessel does and how it fades
## The texts are a first draft by Claude (the owner can reword them).

const TIP_OPEN := "Alaric can call vessels. Open SUMMON in the command bar."
const TIP_PICK := "Pick a vessel to bring through. Bram holds the line; Lyra casts from behind him."
const TIP_CRYSTAL := "Click a glowing crystal near Alaric to place %s. Summoning is free: it does not use up Alaric's turn."
const TIP_SECOND := "One more spirit can be called this battle. Open SUMMON again."
const TIP_VESSEL := "Vessels take their own turns: move, then attack or use a skill. Each turn a vessel ends costs it one Fade Clock turn; at zero it fades and cannot return this battle."
const TIP_FADING := "Watch the Fade Clock on each vessel's card. Alaric can still fight on his own."

var stage: BattleStage
var _last := "<none>"


func _init(s: BattleStage) -> void:
	stage = s
	name = "BattleTutorial"


func _process(_delta: float) -> void:
	var tip := current_tip()
	if tip != _last:
		_last = tip
		stage.hud.show_tip(tip)


## The hint for the stage's state right now ("" for none).
func current_tip() -> String:
	if stage.battle == null or stage.hud == null or stage.mode == BattleStage.Mode.OVER:
		return ""
	var cur := stage.battle.current
	if cur == null or cur.team != 0:
		return ""
	var dm := stage.battle.deployment
	if stage.mode == BattleStage.Mode.SUMMON and stage.summoning != null:
		return TIP_CRYSTAL % stage.summoning.display_name
	if cur.is_vessel():
		return TIP_VESSEL if dm.summons_left() > 0 or not dm.vessels.is_empty() else ""
	if not cur.is_king():
		return ""
	var palette := stage.hud.palette
	if palette.menu.visible and palette.list_kind == "summon":
		return TIP_PICK
	if dm.summons_left() > 0:
		return TIP_OPEN if dm.summons_made == 0 else TIP_SECOND
	return TIP_FADING if not dm.vessels.is_empty() else ""
