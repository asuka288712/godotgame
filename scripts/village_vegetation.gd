## Foreground trees fade locally when their sprites cover the exploring hero.
extends Node3D

var _canopies: Array[Sprite3D] = []

func _ready() -> void:
	for canopy in $Forest/Trees.get_children():
		_canopies.append(canopy.get_node("Canopy") as Sprite3D)

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not camera or not player or not is_visible_in_tree():
		return
	var subject := player.global_position + Vector3.UP * 0.8
	var subject_screen := camera.unproject_position(subject)
	for canopy in _canopies:
		var center := canopy.global_position
		var world_size := Vector2(canopy.texture.get_size()) * canopy.pixel_size
		var screen_a := camera.unproject_position(center + Vector3(-world_size.x * 0.5, world_size.y * 0.5, 0))
		var screen_b := camera.unproject_position(center + Vector3(world_size.x * 0.5, -world_size.y * 0.5, 0))
		var bounds := Rect2(screen_a, screen_b - screen_a).abs().grow(8.0)
		var in_front := camera.global_position.distance_squared_to(center) < camera.global_position.distance_squared_to(subject)
		var obscures := in_front and not camera.is_position_behind(center) and bounds.has_point(subject_screen)
		canopy.modulate.a = lerpf(canopy.modulate.a, 0.3 if obscures else 1.0, minf(delta * 7.0, 1.0))
