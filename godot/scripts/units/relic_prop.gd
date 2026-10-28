class_name RelicProp
extends Node2D
## A relic lying on a grid tile, dropped when a vessel was severed while holding it.
## A pickup, not an obstacle: units can stand on its tile. No drawing here; a visual scene can extend
## this class (DeploymentManager.prop_scene) and use `relic` and `cell`.

var relic: RelicItem
var cell := TacticalGrid.NO_CELL
