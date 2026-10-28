extends Node
## Opens the grass test map (Data.MAPS.grasstest): raised plateau, shadows and standing tufts.
## Run tests/grass_test.tscn from the editor (F6) to look at it.

const Base = preload("res://scripts/base.gd")


func _ready() -> void:
	Base.map_key = "grasstest"
	add_child(load("res://scenes/base.tscn").instantiate())
