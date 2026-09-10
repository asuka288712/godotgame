## HD-2D 前景遮挡：为挡住角色的家具局部挖出渐变透明孔。
extends Node3D

const OCCLUSION_SHADER := preload("res://assets/shaders/character_occlusion.gdshader")

@export var obstructing_meshes: PackedStringArray = ["立方体_004", "立方体_005"]
@export_range(0.02, 0.3, 0.005) var hole_radius := 0.095
@export_range(0.01, 0.2, 0.005) var feather_width := 0.07
@export_range(0.5, 2.5, 0.05) var ellipse_height := 1.45

var _targets: Array[MeshInstance3D] = []
var _materials: Dictionary = {}

func _ready() -> void:
	for mesh_name in obstructing_meshes:
		var mesh := get_node_or_null(NodePath(mesh_name)) as MeshInstance3D
		if mesh == null:
			push_warning("Camera fade mesh not found: %s" % mesh_name)
			continue
		_targets.append(mesh)
		_prepare_occlusion_materials(mesh)

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if camera == null or player == null:
		return

	var subjects: Array[Vector3] = [player.global_position + Vector3.UP]
	var aunt := get_parent().get_node_or_null("LiDaniang/Sprite3D") as Sprite3D
	if aunt and aunt.is_visible_in_tree():
		subjects.append(aunt.global_position)

	var screen_subjects: Array[Vector2] = []
	for world_position in subjects:
		screen_subjects.append(_world_to_screen_uv(camera, world_position))
	while screen_subjects.size() < 2:
		screen_subjects.append(Vector2(-2.0, -2.0))

	for mesh in _targets:
		var is_blocking := false
		for subject_position in subjects:
			if _blocks_camera(mesh, subject_position, camera.global_position):
				is_blocking = true
				break
		_update_occlusion(mesh, is_blocking, screen_subjects[0], screen_subjects[1])

func _world_to_screen_uv(camera: Camera3D, world_position: Vector3) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2(-2.0, -2.0)
	return camera.unproject_position(world_position) / viewport_size

func _blocks_camera(mesh: MeshInstance3D, subject_position: Vector3, camera_position: Vector3) -> bool:
	var camera_line := camera_position - subject_position
	var line_length_squared := camera_line.length_squared()
	if is_zero_approx(line_length_squared):
		return false
	var along_line := clampf(
		(mesh.global_position - subject_position).dot(camera_line) / line_length_squared,
		0.0,
		1.0
	)
	if along_line <= 0.0 or along_line >= 1.0:
		return false
	var nearest_point := subject_position + camera_line * along_line
	var size := mesh.get_aabb().size
	var mesh_scale := mesh.global_transform.basis.get_scale()
	var maximum_scale := maxf(mesh_scale.x, maxf(mesh_scale.y, mesh_scale.z))
	var radius := size.length() * maximum_scale * 0.55
	return mesh.global_position.distance_to(nearest_point) <= radius

func _prepare_occlusion_materials(mesh: MeshInstance3D) -> void:
	var replacements: Array[Dictionary] = []
	for surface in mesh.mesh.get_surface_count():
		var original := mesh.get_active_material(surface) as BaseMaterial3D
		if original == null:
			continue
		var material := ShaderMaterial.new()
		material.shader = OCCLUSION_SHADER
		material.set_shader_parameter("albedo_tint", original.albedo_color)
		if original.albedo_texture:
			material.set_shader_parameter("albedo_texture", original.albedo_texture)
		material.set_shader_parameter("hole_radius", hole_radius)
		material.set_shader_parameter("feather_width", feather_width)
		material.set_shader_parameter("ellipse_height", ellipse_height)
		# 平时不替换材质。只有真的遮挡角色时才临时启用 Shader，
		# 这样柜子/立方体在其他时刻完整保留原本的光照与贴图。
		replacements.append({
			"surface": surface,
			"original": original,
			"shader": material,
			"active": false,
		})
	_materials[mesh] = replacements

func _update_occlusion(mesh: MeshInstance3D, enabled: bool, first_subject: Vector2, second_subject: Vector2) -> void:
	for entry: Dictionary in _materials.get(mesh, []):
		var active := bool(entry["active"])
		var surface := int(entry["surface"])
		var material := entry["shader"] as ShaderMaterial
		if enabled:
			if not active:
				mesh.set_surface_override_material(surface, material)
				entry["active"] = true
			material.set_shader_parameter("effect_enabled", 1.0)
			material.set_shader_parameter("subject_uv_0", first_subject)
			material.set_shader_parameter("subject_uv_1", second_subject)
		elif active:
			mesh.set_surface_override_material(surface, entry["original"] as Material)
			entry["active"] = false
