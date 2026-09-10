## A reusable E-key doorway that changes to another scene.
extends Area3D

@export_file("*.tscn") var target_scene: String
@export var prompt_text: String = "[E] 进入"

@onready var _prompt: Label3D = $PromptLabel

var _player_nearby := false

func _ready() -> void:
	_prompt.text = prompt_text
	_prompt.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_player_nearby = true
		_prompt.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		_player_nearby = false
		_prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby or not event.is_action_pressed("interact"):
		return
	if target_scene.is_empty():
		push_warning("Scene portal has no target scene assigned.")
		return
	get_viewport().set_input_as_handled()
	# Scene changes keep autoload state. Explicitly restore exploration so a
	# previously opened menu/dialogue cannot leave the new player frozen.
	GameData.current_state = GameData.GameState.EXPLORE
	get_tree().change_scene_to_file(target_scene)
