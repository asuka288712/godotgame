## 室内 HD-2D 前景遮挡：自动识别相机与玩家之间的网格，
## 只在角色屏幕位置附近挖出羽化透明区域，移开后平滑恢复原材质。
extends Node

const OCCLUSION_SHADER := preload("res://assets/shaders/character_occlusion.gdshader")

@export_range(0.02, 0.3, 0.005) var hole_radius := 0.10
@export_range(0.01, 0.2, 0.005) var feather_width := 0.075
@export_range(0.5, 2.5, 0.05) var ellipse_height := 1.45
@export_range(1.0, 12.0, 0.25) var fade_speed := 5.5
@export var excluded_node_name_fragments: PackedStringArray = ["fence", "栅栏"]

var _targets: Array[MeshInstance3D] = []
var _materials: Dictionary = {}

func _ready() -> void:
	var scene_root := get_parent()
	if scene_root:
		_collect_meshes(scene_root)

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if camera == null or player == null:
		return
	var subject_position := player.global_position + Vector3.UP
	var subject_uv := _world_to_screen_uv(camera, subject_position)
	for mesh in _targets:
		if not is_instance_valid(mesh) or not mesh.is_visible_in_tree():
			continue
		_update_occlusion(mesh, _blocks_camera(mesh, subject_position, camera.global_position), subject_uv, delta)

func _collect_meshes(node: Node) -> void:
	if _is_excluded(node):
		return
	for child in node.get_children():
		# 玩家、NPC、相机等动态节点不是室内前景物，不纳入遮挡检测。
		if child is CharacterBody3D or child is AnimatedSprite3D or child is Sprite3D:
			continue
		if child is MeshInstance3D:
			var mesh := child as MeshInstance3D
			if mesh.mesh and mesh.get_aabb().size.length() > 0.1:
				_targets.append(mesh)
		_collect_meshes(child)

func _is_excluded(node: Node) -> bool:
	var node_name := String(node.name).to_lower()
	for fragment in excluded_node_name_fragments:
		if node_name.contains(fragment.to_lower()):
			return true
	return false

func _world_to_screen_uv(camera: Camera3D, world_position: Vector3) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2(-2.0, -2.0)
	return camera.unproject_position(world_position) / viewport_size

func _blocks_camera(mesh: MeshInstance3D, subject_position: Vector3, camera_position: Vector3) -> bool:
	# 将相机连线转换到网格的本地坐标，再做真正的线段/AABB 相交。
	# 相比“网格中心到连线的距离”估算，它不会让旁边的大物体误触发。
	var inverse_transform := mesh.global_transform.affine_inverse()
	var local_subject := inverse_transform * subject_position
	var local_camera := inverse_transform * camera_position
	# 少量扩张确保单面墙、门板等极薄网格也能稳定命中。
	return mesh.get_aabb().grow(0.025).intersects_segment(local_subject, local_camera) != null

func _ensure_materials(mesh: MeshInstance3D) -> bool:
	if _materials.has(mesh):
		return true
	if mesh.mesh == null:
		return false
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
		material.set_shader_parameter("effect_enabled", 1.0)
		material.set_shader_parameter("effect_strength", 0.0)
		replacements.append({
			"surface": surface,
			"original": original,
			"shader": material,
			"active": false,
			"strength": 0.0,
		})
	if replacements.is_empty():
		return false
	_materials[mesh] = replacements
	return true

func _update_occlusion(mesh: MeshInstance3D, blocking: bool, subject_uv: Vector2, delta: float) -> void:
	if blocking and not _ensure_materials(mesh):
		return
	if not _materials.has(mesh):
		return
	for entry: Dictionary in _materials[mesh]:
		var target_strength := 1.0 if blocking else 0.0
		var strength := move_toward(float(entry["strength"]), target_strength, fade_speed * delta)
		var surface := int(entry["surface"])
		var material := entry["shader"] as ShaderMaterial
		if strength > 0.001 and not bool(entry["active"]):
			mesh.set_surface_override_material(surface, material)
			entry["active"] = true
		if bool(entry["active"]):
			material.set_shader_parameter("effect_strength", strength)
			material.set_shader_parameter("subject_uv_0", subject_uv)
			if strength <= 0.001:
				mesh.set_surface_override_material(surface, entry["original"] as Material)
				entry["active"] = false
		entry["strength"] = strength
