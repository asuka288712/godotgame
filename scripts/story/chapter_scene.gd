## Common camera/UI for the editable chapter scenes. Geometry stays in .tscn.
extends Node3D
const ExplorationCamera := preload("res://scripts/exploration_camera.gd")

@export var location_id := "guestroom"
@onready var player: CharacterBody3D = $World/Player
@onready var camera: Camera3D = $Camera
var _companion: Node3D

func _ready() -> void:
	GameData.current_state = GameData.GameState.EXPLORE
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = ExplorationCamera.VIEW_SIZE
	GameData.show_scene_title(StoryManager.NAMES.get(location_id, location_id))
	if not get_node_or_null("UILayer/DialogueUI"):
		var layer := CanvasLayer.new()
		layer.name = "UILayer"
		add_child(layer)
		layer.add_child(preload("res://scenes/dialogue_ui.tscn").instantiate())
	GameData.play_persistent_music(GameData.OPENING_INN_MUSIC, -16)
	var spawn := get_node_or_null("Spawns/entry") as Node3D
	if spawn: player.position = spawn.position
	_follow_camera(1.0)

func _process(delta: float) -> void:
	if GameData.current_state != GameData.GameState.BATTLE:
		_follow_camera(minf(delta * 5, 1))
	if player.global_position.y < -6 and GameData.current_state == GameData.GameState.EXPLORE:
		player.velocity = Vector3.ZERO
		player.global_position = $Spawns/entry.global_position
		StoryManager.say("旁白", "水边湿滑，先退回岸边。")
	_sync_companion()

func _follow_camera(weight: float) -> void:
	ExplorationCamera.follow(camera, player, weight)

func _sync_companion() -> void:
	if StoryManager.stage < 12 or not GameData.party.any(func(member): return member.char_name == "赵灵儿"): return
	if is_instance_valid(_companion): return
	_companion = Node3D.new()
	_companion.name = "StoryCompanion"
	_companion.set_script(preload("res://scripts/story/story_companion.gd"))
	_companion.set("target", player)
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.set_script(preload("res://scripts/story/story_character.gd"))
	visual.set("character_scene", preload("res://scenes/zhao_linger.tscn"))
	visual.set("character_height", 1.85)
	_companion.add_child(visual)
	$World.add_child(_companion)
	_companion.global_position = player.global_position + Vector3(1.5, 0, 1.5)
