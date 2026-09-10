## Reusable collision wrapper for the Li Xiaoyao room GLB.
extends Node3D

@onready var _model: Node3D = $Model


func _ready() -> void:
	# Imported GLB files are read-only. Create their static mesh collisions after
	# the scene tree finishes initializing so every instance is immediately solid.
	_create_collisions.call_deferred()


func _create_collisions() -> void:
	for mesh_node: MeshInstance3D in _find_meshes(_model):
		if mesh_node.mesh != null:
			mesh_node.create_trimesh_collision()


func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for child in node.get_children():
		if child is MeshInstance3D:
			meshes.append(child)
		meshes.append_array(_find_meshes(child))
	return meshes
