class_name RelicProp
extends Node2D
## A field relic lying on a grid tile. The King can summon a vessel onto it, which tethers the vessel
## to the relic and replaces this prop (DeploymentManager.summon_vessel). No unit can pick it up and it
## does not block the tile. No drawing here; a visual scene can extend this class
## (DeploymentManager.prop_scene) and use `relic` and `cell`.

var relic: RelicItem
var cell := TacticalGrid.NO_CELL
