class_name BaseCutscene
extends Cutscene3D
## After the first full battle, in the chamber: Alaric, Bram and Lyra talk about making this room their base. Then it
## the story opens the next place (the riverbank) and it fades out into the world map. Not a battle: no input, no rules.
## The dialogue is a first draft by Claude, in the characters' voices (the owner writes the story: reword freely).
## Cells are (column, row): the column is the depth (0 is the front wall), the row runs left to right.

const MAP := FirstBattle.CHAMBER
const ALARIC_AT := Vector2i(8, 4)
const BRAM_AT := Vector2i(8, 6)
const LYRA_AT := Vector2i(8, 2)
const NEXT_SCENE := "res://scenes/world_map.tscn"
## [speaker, portrait, text, face]
const LINES: Array = [
	["LYRA", "mira", "Two down. They'll send more when these don't come back."],
	["BRAM", "warden", "Then we hold here. One way in, a wall at our backs. I've held worse."],
	["ALARIC", "king", "This room answered me when nothing else did.", "eyes_closed"],
	["LYRA", "mira", "The altar is why. Every spirit you call is anchored to it. Walk away from it, and you start from nothing."],
	["ALARIC", "king", "Then we don't walk away. This is where we stand.", "calm"],
	["BRAM", "warden", "Home, then. Of a kind."],
	["LYRA", "mira", "A base. A table for the maps, a ledger for every relic, a place to plan. I can build on that."],
	["ALARIC", "king", "Then it begins here.", "looking_up"],
]

@export var go_on := true  ## false in the checks: stop at the end instead of changing to the barracks

var king: UnitView3D
var bram: UnitView3D
var lyra: UnitView3D


func _ready() -> void:
	setup_scene(MAP)
	king = make_unit("king", ALARIC_AT)
	bram = make_unit("warden", BRAM_AT, UnitLook.VESSEL_TINT)
	lyra = make_unit("mira", LYRA_AT, UnitLook.VESSEL_TINT)
	look(king, Vector2i(1, 0), ALARIC_AT)
	look(bram, ALARIC_AT - BRAM_AT, BRAM_AT)
	look(lyra, ALARIC_AT - LYRA_AT, LYRA_AT)
	_run()


func _run() -> void:
	await fade_to(0.0, 1.4)
	beat.emit("start")
	for l in LINES:
		beat.emit(String(l[0]).to_lower())
		await say(l[2], l[1], l[0], String(l[3]) if l.size() > 3 else "")
	beat.emit("end")
	var game := carried_game if carried_game != null else GameSession.current()
	GameSession.game = game
	game.campaign.unlock_area(&"riverbank")  # the story's next place
	GameSession.autosave()
	await fade_to(1.0, 1.6)
	finished.emit()
	if go_on:
		get_tree().change_scene_to_file(NEXT_SCENE)
