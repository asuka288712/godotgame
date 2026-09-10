## NPC 行为脚本 — StaticBody3D, 对话交互
extends StaticBody3D

signal recruited(npc: StaticBody3D)

@export var npc_name: String = "村民"
@export var dialogue_texts: PackedStringArray = PackedStringArray(["你好，旅行者。"])
@export var character_texture: Texture2D
@export var interaction_radius: float = 2.5

@onready var _interact_area: Area3D = $InteractArea
@onready var _prompt_label: Label3D = $PromptLabel
@onready var _prompt_icon: Sprite3D = $PromptIcon
@onready var _sprite: AnimatedSprite3D = get_node_or_null("AnimatedSprite3D")

var _player_nearby: bool = false

func _ready() -> void:
	_apply_character_texture()
	_prompt_icon.top_level = true
	_update_prompt_icon_position()
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(&"idle"):
		_sprite.play(&"idle")
	var interaction_shape := _interact_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if interaction_shape and interaction_shape.shape is SphereShape3D:
		(interaction_shape.shape as SphereShape3D).radius = interaction_radius

func _apply_character_texture() -> void:
	if not character_texture or not _sprite or not _sprite.sprite_frames:
		return
	# Instances share the scene's SpriteFrames resource; duplicate it first so
	# assigning a texture to one NPC never changes every other NPC.
	var frames := _sprite.sprite_frames.duplicate(true) as SpriteFrames
	var animation_name: StringName = &"default" if frames.has_animation(&"default") else _sprite.animation
	if not frames.has_animation(animation_name) or frames.get_frame_count(animation_name) == 0:
		return
	frames.set_frame(animation_name, 0, character_texture)
	_sprite.sprite_frames = frames

func _on_player_near() -> void:
	_player_nearby = true; _prompt_label.visible = false; _prompt_icon.visible = true

func _on_player_far() -> void:
	_player_nearby = false; _prompt_label.visible = false; _prompt_icon.visible = false

func _process(_delta: float) -> void:
	_update_prompt_icon_position()
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return
	# 图标与自动靠近共用同一距离范围，避免 Area3D 进入信号遗漏时无法交互。
	var should_show := GameData.current_state == GameData.GameState.EXPLORE and is_interaction_prompt_visible(player.global_position)
	_prompt_label.visible = false
	_prompt_icon.visible = should_show

func _update_prompt_icon_position() -> void:
	if not _sprite or not _sprite.sprite_frames:
		return
	var texture := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	if not texture:
		return
	var sprite_scale_y := absf(_sprite.global_transform.basis.get_scale().y)
	var visual_height := float(texture.get_height()) * _sprite.pixel_size * sprite_scale_y
	_prompt_icon.global_position = global_position + Vector3.UP * (visual_height * 0.55 + 0.35)

func try_interact(player_position: Vector3 = Vector3.INF) -> Dictionary:
	var player_in_range := _player_nearby
	if player_position != Vector3.INF:
		var offset: Vector3 = global_position - player_position
		offset.y = 0.0
		player_in_range = offset.length() <= interaction_radius
	if not player_in_range: return {}
	var lines: Array = []
	for entry in dialogue_texts:
		var speaker := npc_name
		var text := entry
		# Optional "说话人|台词" format enables conversations with more than one
		# character while keeping existing single-speaker NPC data compatible.
		var separator := entry.find("|")
		if separator >= 0:
			speaker = entry.left(separator).strip_edges()
			text = entry.substr(separator + 1).strip_edges()
		lines.append({"speaker": speaker, "text": text})
	return {"lines": lines}

func is_interaction_prompt_visible(player_position: Vector3) -> bool:
	var offset := global_position - player_position
	offset.y = 0.0
	# 玩家交互区半径约 2.2 米：图标会比真正对话范围提前亮起。
	return offset.length() <= interaction_radius + 2.2

func get_interact_area() -> Area3D: return _interact_area
