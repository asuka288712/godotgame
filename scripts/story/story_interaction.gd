## Keep this root and its id when replacing Visual with final art.
extends Node3D

@export var interaction_id := ""
@export var display_name := "交互点"
@export_multiline var idle_text := ""
@export var target_location := ""
@export var target_spawn := "entry"
@export var minimum_stage := -1
@export var maximum_stage := 99
@export var radius := 2.6

func _ready() -> void:
	add_to_group("story_interactions")
	var label := get_node_or_null("NameLabel") as Label3D
	if label: label.text = display_name

func available() -> bool:
	return StoryManager.stage >= minimum_stage and StoryManager.stage <= maximum_stage

func distance_to(player: Node3D) -> float:
	var delta := global_position - player.global_position
	if absf(delta.y) > 3.0: return INF
	delta.y = 0
	return delta.length()

func interact() -> void:
	if not available():
		StoryManager.say(display_name, "现在还不能前往那里。先处理手头的事情吧。")
		return
	if not target_location.is_empty():
		StoryManager.travel(target_location, target_spawn)
	else:
		StoryManager.activate(interaction_id, display_name, idle_text)

func _process(_delta: float) -> void:
	# Stage-gated characters disappear along with their interaction prompts.
	if not target_location.is_empty(): return
	visible = available()
