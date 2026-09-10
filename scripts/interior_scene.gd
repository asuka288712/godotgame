## Uses the same third-person/HD-2D follow camera as the village scene.
extends Node3D

@export var scene_title: String = "李 家 客 栈"
@onready var _player: CharacterBody3D = $Player
@onready var _camera: Camera3D = $Camera
@onready var _zhao_linger: Node3D = get_node_or_null("ZhaoLinger")

var cutscene_camera_active := false

func _ready() -> void:
	GameData.current_state = GameData.GameState.EXPLORE
	GameData.show_scene_title(scene_title)
	if _zhao_linger and _zhao_linger.has_method("begin_following") and GameData.party.any(func(member): return member.char_name == "赵灵儿"):
		_zhao_linger.call("begin_following", _player)

func _process(delta: float) -> void:
	if not _player or not _camera:
		return
	if cutscene_camera_active:
		return
	var target_position := _player.global_position + Vector3(0, 2, 8)
	_camera.global_position = _camera.global_position.lerp(target_position, 3.0 * delta)
	_camera.look_at(_player.global_position + Vector3(0, 1.5, 0), Vector3.UP)
