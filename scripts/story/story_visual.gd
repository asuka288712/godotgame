## Non-destructive visual states: change placeholders without deleting event roots.
extends Node3D

@export var broken_after_stage := -1
@export var hidden_after_stage := -1
@export var statue_id := ""

func _process(_delta: float) -> void:
	if hidden_after_stage >= 0:
		visible = StoryManager.stage < hidden_after_stage
	if not statue_id.is_empty():
		scale.y = 0.22 if StoryManager.flags.has(statue_id) else 1.0
	if broken_after_stage >= 0 and StoryManager.stage >= broken_after_stage:
		rotation.z = -0.16
