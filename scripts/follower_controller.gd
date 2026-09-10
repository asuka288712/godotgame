## Recruited companion movement — follows the player at a comfortable distance.
extends Node3D

@export var follow_distance: float = 1.5
@export var follow_speed: float = 4.2

var _target: Node3D
var _following: bool = false

func begin_following(target: Node3D, start_position: Vector3) -> void:
	_target = target
	global_position = start_position
	visible = true
	_following = true

func _physics_process(delta: float) -> void:
	if not _following or not _target or GameData.current_state != GameData.GameState.EXPLORE:
		return
	var offset := global_position - _target.global_position
	offset.y = 0.0
	if offset.length() < 0.01:
		offset = Vector3(1.0, 0.0, 1.0).normalized()
	var destination := _target.global_position + offset.normalized() * follow_distance
	destination.y = _target.global_position.y
	global_position = global_position.move_toward(destination, follow_speed * delta)
