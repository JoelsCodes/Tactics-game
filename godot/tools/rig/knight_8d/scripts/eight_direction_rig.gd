@tool
extends Node2D
class_name EightWayKnightRig
## Editable 8-direction rigid cutout rig, using native Skeleton2D and Bone2D nodes.
## Source contains 5 illustrated viewpoints; SW/W/NW mirror SE/E/NE respectively.

enum Facing {S, SW, W, NW, N, NE, E, SE}
enum Motion {IDLE, WALK}

@export var facing: Facing = Facing.S:
    set(value):
        facing = value
        if is_node_ready():
            _show_facing()

@export var motion: Motion = Motion.IDLE
@export_range(0.0, 3.0, 0.05) var animation_speed: float = 1.0
@export var preview_animation_in_editor: bool = false

const NAMES = ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]
var elapsed: float = 0.0

func _ready() -> void:
    _show_facing()
    set_process(true)

func _show_facing() -> void:
    for i in range(NAMES.size()):
        var v: Node2D = get_node("Directions/" + NAMES[i])
        v.visible = (i == facing)

func set_facing_vector(move_vector: Vector2) -> void:
    if move_vector.length_squared() < 0.001:
        return
    # Godot's 2D Y axis points down; atan2 maps E=0, SE=45, S=90 etc.
    var step: int = posmod(roundi(rad_to_deg(atan2(move_vector.y, move_vector.x)) / 45.0), 8)
    var lookup: Array[int] = [Facing.E, Facing.SE, Facing.S, Facing.SW,
        Facing.W, Facing.NW, Facing.N, Facing.NE]
    facing = lookup[step]

func set_walking(is_walking: bool) -> void:
    motion = Motion.WALK if is_walking else Motion.IDLE

func _process(delta: float) -> void:
    if Engine.is_editor_hint() and not preview_animation_in_editor:
        return
    elapsed += delta * animation_speed
    _apply_pose()

func _bone(view: String, path: String) -> Bone2D:
    return get_node("Directions/" + view + "/Skeleton2D/Hips/" + path) as Bone2D

func _apply_pose() -> void:
    var name: String = NAMES[facing]
    var t: float = elapsed
    var walking: bool = motion == Motion.WALK
    var swing: float = sin(t * 8.0) if walking else 0.0
    var subtle: float = sin(t * 2.4)

    var chest := _bone(name, "Chest")
    chest.rotation = (swing * 0.028) if walking else (subtle * 0.006)
    var head := _bone(name, "Chest/Neck/Head")
    head.rotation = -chest.rotation * 0.65
    var left_arm := _bone(name, "Chest/LeftUpperArm")
    var right_arm := _bone(name, "Chest/RightUpperArm")
    left_arm.rotation = (swing * 0.17) if walking else (subtle * 0.008)
    right_arm.rotation = (-swing * 0.17) if walking else (-subtle * 0.008)
    _bone(name, "Chest/LeftUpperArm/LeftForearm").rotation = -left_arm.rotation * 0.28
    _bone(name, "Chest/RightUpperArm/RightForearm").rotation = -right_arm.rotation * 0.28
    _bone(name, "LeftThigh").rotation = (-swing * 0.13) if walking else 0.0
    _bone(name, "RightThigh").rotation = (swing * 0.13) if walking else 0.0
    _bone(name, "LeftThigh/LeftShin").rotation = maxf(0.0, swing) * 0.10 if walking else 0.0
    _bone(name, "RightThigh/RightShin").rotation = maxf(0.0, -swing) * 0.10 if walking else 0.0
    _bone(name, "Weapon").rotation = swing * 0.018 if walking else 0.0
