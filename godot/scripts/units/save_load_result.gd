class_name SaveLoadResult
extends RefCounted
## The outcome of loading or decoding a save: the game, or why it failed, plus anything fishy.

var ok := false
var error := ""
var game: SaveGame
var warnings: Array[String] = []  ## fixed or suspicious things (clamped numbers, a relic in two places)
var from_backup := false  ## the main file was unreadable and the previous save was used


func fail(why: String) -> SaveLoadResult:
	ok = false
	error = why
	game = null
	return self
