## 主场景控制器 — 游戏状态管理、信号连接、相机跟随
extends Node3D

@onready var _player: CharacterBody3D = $World/Player
@onready var _camera: Camera3D = $Camera
@onready var _world_node: Node3D = $World
@onready var _battle_arena: Node3D = $BattleArena
@onready var _world_environment: WorldEnvironment = $World/Environment
@onready var _arena_environment: WorldEnvironment = $BattleArena/Environment
@onready var _village_music: AudioStreamPlayer = $VillageMusic
var _npcs: Array = []
var _pending_interact_npc: Node3D
var _arena_environment_resource: Environment
var _world_environment_resource: Environment

func _ready() -> void:
	_arena_environment_resource = _arena_environment.environment
	_world_environment_resource = _world_environment.environment
	_arena_environment.environment = null
	_battle_arena.visible = false
	GameData.current_state = GameData.GameState.EXPLORE
	GameData.show_scene_title("余 杭 镇")
	_village_music.finished.connect(_on_village_music_finished)
	_play_village_music()
	if not _player:
		push_error("Player not found at $World/Player")
		return
	if not _camera:
		push_error("Camera not found at $Camera")
		return
	var npcs_node = $World/NPCs
	if npcs_node:
		_npcs = npcs_node.get_children()
	_connect_signals()
	_restore_recruited_companions()

func _restore_recruited_companions() -> void:
	if not GameData.party.any(func(member): return member.char_name == "赵灵儿"):
		return
	for npc in _npcs:
		if npc.get("npc_name") == "赵灵儿" and npc.has_method("begin_following"):
			npc.call("begin_following", _player)
			return

func _connect_signals() -> void:
	_player.interacted.connect(_on_player_interact)
	_player.auto_walk_finished.connect(_on_auto_walk_finished)
	BattleSystem.battle_ended.connect(_on_battle_ended)
	BattleSystem.battle_started.connect(_on_battle_started)

	var player_area: Area3D = _player.get_node("InteractionArea")
	for npc in _npcs:
		var npc_area: Area3D = npc.get_interact_area()
		player_area.area_entered.connect(_on_npc_area_entered.bind(npc, npc_area))
		player_area.area_exited.connect(_on_npc_area_exited.bind(npc, npc_area))
		npc.recruited.connect(_on_npc_recruited)

func _on_npc_area_entered(area: Area3D, npc, npc_area: Area3D) -> void:
	if area == npc_area:
		npc._on_player_near()

func _on_npc_area_exited(area: Area3D, npc, npc_area: Area3D) -> void:
	if area == npc_area:
		npc._on_player_far()

func _on_player_interact() -> void:
	if GameData.current_state != GameData.GameState.EXPLORE:
		return
	for npc in _npcs:
		var result: Dictionary = npc.try_interact(_player.global_position)
		if not result.is_empty():
			DialogueSystem.start_dialogue(result["lines"])
			return
	var nearby_npc: Node3D = _find_nearest_auto_interact_npc()
	if nearby_npc:
		_pending_interact_npc = nearby_npc
		# 再靠近一些再停下，给对话留出更自然的贴近感。
		var stop_distance := maxf(float(nearby_npc.get("interaction_radius")) - 1.0, 0.8)
		_player.walk_to(nearby_npc.global_position, stop_distance)
		return
	$UILayer/InventoryUI.toggle()

func _find_nearest_auto_interact_npc() -> Node3D:
	# 只有已亮出交互提示图标的 NPC 才能触发自动靠近。
	var closest_npc: Node3D
	var closest_distance: float = INF
	for npc in _npcs:
		var npc_3d: Node3D = npc as Node3D
		if not is_instance_valid(npc_3d) or not bool(npc_3d.call("is_interaction_prompt_visible", _player.global_position)):
			continue
		var offset: Vector3 = npc_3d.global_position - _player.global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance <= closest_distance:
			closest_npc = npc_3d
			closest_distance = distance
	return closest_npc

func _on_auto_walk_finished() -> void:
	var npc: Node3D = _pending_interact_npc
	_pending_interact_npc = null
	if GameData.current_state != GameData.GameState.EXPLORE or not is_instance_valid(npc):
		return
	var result: Dictionary = npc.call("try_interact", _player.global_position)
	if not result.is_empty():
		DialogueSystem.start_dialogue(result["lines"])

func _on_npc_recruited(npc: Node) -> void:
	if npc.get("npc_name") != "赵灵儿":
		return
	var npc_3d := npc as Node3D
	if not npc_3d:
		return
	if npc.has_method("begin_following"):
		npc.call("begin_following", _player)

func _try_complete_pending_interaction() -> void:
	if GameData.current_state != GameData.GameState.EXPLORE or not is_instance_valid(_pending_interact_npc):
		return
	var offset: Vector3 = _pending_interact_npc.global_position - _player.global_position
	offset.y = 0.0
	if offset.length() > float(_pending_interact_npc.get("interaction_radius")):
		return
	# NPC 的实体碰撞可能阻止角色走到预设终点；进入可对话范围便立刻结束自动行走。
	_player.cancel_auto_walk()
	_on_auto_walk_finished()

func _on_battle_ended(victory: bool) -> void:
	if victory:
		await $UILayer/BattleUI.victory_continue_requested
	else:
		await get_tree().create_timer(0.35 if BattleSystem.did_escape else 1.5).timeout
	BattleSystem.end_battle()
	$UILayer/BattleUI.visible = false
	_world_node.visible = true
	_battle_arena.visible = false
	_world_environment.environment = _world_environment_resource
	_arena_environment.environment = null
	_play_village_music()

func _on_battle_started(_enemies) -> void:
	# 战斗音乐由 BattleUI 接管，避免与村庄 BGM 叠加。
	if _village_music.playing:
		_village_music.stop()

func _play_village_music() -> void:
	if not _village_music.playing:
		_village_music.play()

func _on_village_music_finished() -> void:
	if GameData.current_state != GameData.GameState.BATTLE:
		_play_village_music()

func _process(delta: float) -> void:
	_try_complete_pending_interaction()
	if GameData.current_state == GameData.GameState.BATTLE:
		_world_node.visible = false
		_battle_arena.visible = true
		_world_environment.environment = null
		_arena_environment.environment = _arena_environment_resource
		var camera_target := Vector3(0, 1.4, 0)
		var camera_position := Vector3(0, 3, 12)
		if BattleSystem.state == BattleSystem.BState.VICTORY:
			camera_target = _battle_arena.get_victory_focus_position() + Vector3(0, 0.9, 0)
			camera_position = camera_target + Vector3(0, 3.8, 7.0)
		var camera_follow_speed := 1.7 if BattleSystem.state == BattleSystem.BState.VICTORY else 4.0
		_camera.global_position = _camera.global_position.lerp(camera_position, camera_follow_speed * delta)
		_camera.look_at(camera_target, Vector3.UP)
	elif _player and _camera:
		_battle_arena.visible = false
		_world_environment.environment = _world_environment_resource
		_arena_environment.environment = null
		var target_pos: Vector3 = _player.global_position + Vector3(0, 3, 14)
		_camera.global_position = _camera.global_position.lerp(target_pos, 3.0 * delta)
		_camera.look_at(_player.global_position + Vector3(0, 1.5, 0), Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_F1:
			if GameData.current_state == GameData.GameState.EXPLORE:
				# F1 用于当前 ATB 测试：李逍遥对两只蜜蜂精。
				BattleSystem.start_battle(["蜜蜂精", "蜜蜂精"], [GameData.party[0]])
				get_viewport().set_input_as_handled()
