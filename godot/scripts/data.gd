extends Node
## Game data, exported from js/data.js by tools/export_data.js into data/game_data.json.
## Autoloaded as `Data`. JSON numbers arrive as floats; whole numbers are turned back
## into ints so stats print as "80", not "80.0".

var RACES: Dictionary
var PROFS: Dictionary
var JOBS: Dictionary
var AB: Dictionary
var STATUS: Dictionary
var ELEMENTS: Dictionary
var WTYPES: Dictionary
var ITEMS: Dictionary
var CONS: Dictionary
var LOOT: Dictionary
var RECIPES: Array
var MONSTERS: Dictionary
var LAWS: Dictionary
var TERRAIN: Dictionary
var MAPS: Dictionary
var MISSIONS: Array
var LOCS: Dictionary
var ROUTES: Array
var ERRANDS: Array
var NAMES: Dictionary
var BASE_JOBS: Dictionary
var STARTER: Dictionary


func _init() -> void:
	var text := FileAccess.get_file_as_string("res://data/game_data.json")
	var d = JSON.parse_string(text)
	assert(d is Dictionary, "data/game_data.json is missing or invalid; run node godot/tools/export_data.js")
	d = _intify(d)
	for k in d:
		set(k, d[k])


static func _intify(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if v == floorf(v) and absf(v) < 1e15 else v
		TYPE_DICTIONARY:
			for k in v:
				v[k] = _intify(v[k])
		TYPE_ARRAY:
			for i in v.size():
				v[i] = _intify(v[i])
	return v


## Hex "#rrggbb" from the data to a Color.
static func col(hex: String) -> Color:
	return Color.html(hex)
