## Reuse the existing combat system without coupling chapter rooms to main.tscn.
extends Node

var _arena: Node3D
var _ui: Control
var _world: Node3D
var _camera: Camera3D
var _explore_environment: Environment
var _active := false

func start(enemies: Array) -> void:
	if _active: return
	var scene := get_parent()
	_world = scene.get_node("World")
	_camera = scene.get_node("Camera")
	if not is_instance_valid(_arena):
		_arena = preload("res://scenes/battle_arena.tscn").instantiate()
		scene.add_child(_arena)
		_ui = preload("res://scenes/battle_ui.tscn").instantiate()
		scene.get_node("UILayer").add_child(_ui)
		BattleSystem.battle_ended.connect(_on_ended)
	_explore_environment = scene.get_node("World/Environment").environment
	scene.get_node("World/Environment").environment = null
	_arena.show()
	_world.hide()
	_active = true
	GameData.stop_persistent_music()
	_camera.global_position = Vector3(0, 4, 14)
	_camera.look_at(Vector3(0, 1, 0))
	BattleSystem.start_battle(enemies)

func _on_ended(victory: bool) -> void:
	if not _active: return
	if victory: await _ui.victory_continue_requested
	else: await get_tree().create_timer(0.6, false).timeout
	BattleSystem.end_battle()
	_ui.hide()
	_arena.hide()
	_arena.get_node("Environment").environment = null
	_world.show()
	get_parent().get_node("World/Environment").environment = _explore_environment
	_active = false
	GameData.play_persistent_music(GameData.OPENING_INN_MUSIC, -16)
	# Free the combat nodes, so subsequent retries have a fresh environment.
	_arena.queue_free()
	_ui.queue_free()
	_arena = null
	_ui = null
	BattleSystem.battle_ended.disconnect(_on_ended)
	StoryManager.finish_battle(victory)
