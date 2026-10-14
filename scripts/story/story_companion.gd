extends Node3D
var target: Node3D
@onready var visual := $Visual
func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or GameData.current_state != GameData.GameState.EXPLORE:
		visual.face_motion(Vector3.ZERO)
		return
	var offset := target.global_position - global_position
	offset.y = 0
	var motion := Vector3.ZERO
	if offset.length() > 1.8:
		motion = offset.normalized() * minf(offset.length() - 1.8, 4.2 * delta)
		global_position += motion
		global_position.y = target.global_position.y
	if offset.length() > 12:
		global_position = target.global_position + Vector3(1.5, 0, 1.5)
	visual.face_motion(motion / maxf(delta, 0.001))
