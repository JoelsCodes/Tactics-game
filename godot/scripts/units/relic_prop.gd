class_name RelicProp
extends Node2D
## A relic lying on a grid tile. The King can summon its vessel from here (DeploymentManager.summon_vessel);
## no unit can pick it up. It does not block the tile. No drawing here; a visual scene can extend this
## class (DeploymentManager.prop_scene) and use `relic` and `cell`.

var relic: RelicItem
var cell := TacticalGrid.NO_CELL
