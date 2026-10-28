class_name FadeClock
extends RefCounted
## A vessel's turn countdown. Starts at the vessel's fade_turns when it is summoned and loses one at
## the start of each of the vessel's turns; when it reaches 0 the vessel fades (`faded`).

signal ticked(turns_left: int)
signal faded

var turns_left := 0
var total := 0


func _init(turns := 6) -> void:
	start(turns)


func start(turns: int) -> void:
	total = maxi(turns, 1)
	turns_left = total


func is_faded() -> bool:
	return turns_left <= 0


## Counts down one turn. Returns true when this tick makes the vessel fade.
func tick() -> bool:
	if is_faded():
		return false
	turns_left -= 1
	ticked.emit(turns_left)
	if turns_left == 0:
		faded.emit()
		return true
	return false


## Adds turns (a skill or relic that sustains a vessel). Does nothing once faded.
func extend(turns: int) -> void:
	if not is_faded():
		turns_left += maxi(turns, 0)
		ticked.emit(turns_left)
