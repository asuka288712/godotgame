## 赵灵儿专属行为：招募、跟随与专属行走动画。
extends StaticBody3D

const WALK_FRAME_COUNT := 54
const WALK_UP_FRAME_COUNT := 24
const WALK_DOWN_FRAME_COUNT := 12

signal recruited(npc: StaticBody3D)

@export var npc_name: String = "赵灵儿"
@export var dialogue_texts: PackedStringArray = PackedStringArray()
@export var character_texture: Texture2D
@export var interaction_radius: float = 4.0
@export var follow_distance: float = 1.5
@export var follow_speed: float = 4.2

@onready var _interact_area: Area3D = $InteractArea
@onready var _prompt_label: Label3D = $PromptLabel
@onready var _prompt_icon: Sprite3D = $PromptIcon
@onready var _sprite: AnimatedSprite3D = $AnimatedSprite3D

var _player_nearby := false
var _recruited := false
var _follow_target: Node3D

func _ready() -> void:
	_setup_walk_animation()
	_sprite.play(&"idle")
	_prompt_icon.top_level = true
	_update_prompt_icon_position()
	var interaction_shape := _interact_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if interaction_shape and interaction_shape.shape is SphereShape3D:
		(interaction_shape.shape as SphereShape3D).radius = interaction_radius

func _setup_walk_animation() -> void:
	var frames := _sprite.sprite_frames
	_add_walk_animation(frames, &"walk", "res://assets/sprite/anime/Lr/walk/%03d.png", WALK_FRAME_COUNT)
	_add_walk_animation(frames, &"walku", "res://assets/sprite/anime/Lr/walk/walku/%03d.png", WALK_UP_FRAME_COUNT)
	_add_walk_animation(frames, &"walkd", "res://assets/sprite/anime/Lr/walk/walkd/%03d.png", WALK_DOWN_FRAME_COUNT)

func _add_walk_animation(frames: SpriteFrames, animation_name: StringName, path_pattern: String, frame_count: int) -> void:
	if frames.has_animation(animation_name):
		frames.remove_animation(animation_name)
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, 24.0)
	frames.set_animation_loop(animation_name, true)
	for frame_number in range(1, frame_count + 1):
		var texture := load(path_pattern % frame_number) as Texture2D
		if texture:
			frames.add_frame(animation_name, texture)

func _on_player_near() -> void:
	_player_nearby = true
	_prompt_label.visible = false
	_prompt_icon.visible = true

func _on_player_far() -> void:
	_player_nearby = false
	_prompt_label.visible = false
	_prompt_icon.visible = false

func _process(_delta: float) -> void:
	_update_prompt_icon_position()
	if _follow_target:
		_prompt_icon.visible = false
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return
	var should_show := GameData.current_state == GameData.GameState.EXPLORE and is_interaction_prompt_visible(player.global_position)
	_prompt_label.visible = false
	_prompt_icon.visible = should_show

func _update_prompt_icon_position() -> void:
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
	if not player_in_range or _recruited:
		return {}
	_recruited = true
	GameData.recruit_zhao_linger()
	recruited.emit(self)
	var lines: Array = []
	for entry in dialogue_texts:
		var separator := entry.find("|")
		lines.append({
			"speaker": entry.left(separator).strip_edges() if separator >= 0 else npc_name,
			"text": entry.substr(separator + 1).strip_edges() if separator >= 0 else entry,
		})
	return {"lines": lines}

func begin_following(target: Node3D) -> void:
	_follow_target = target
	_prompt_label.visible = false
	_prompt_icon.visible = false
	_interact_area.monitoring = false

func _physics_process(delta: float) -> void:
	if not _follow_target or GameData.current_state != GameData.GameState.EXPLORE:
		return
	var leader_is_moving := Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down") or Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right")
	if not leader_is_moving:
		_sprite.play(&"idle")
		return
	var offset := global_position - _follow_target.global_position
	offset.y = 0.0
	if offset.length() < 0.01:
		offset = Vector3(-1.0, 0.0, -1.0).normalized()
	var destination := _follow_target.global_position + offset.normalized() * follow_distance
	destination.y = global_position.y
	var movement := destination - global_position
	if movement.length() > 0.03:
		if absf(movement.x) >= absf(movement.z):
			_sprite.play(&"walk")
			_sprite.flip_h = movement.x > 0.0
		elif movement.z < 0.0:
			_sprite.play(&"walku")
		else:
			_sprite.play(&"walkd")
		global_position = global_position.move_toward(destination, follow_speed * delta)
	else:
		_sprite.play(&"idle")

func is_interaction_prompt_visible(player_position: Vector3) -> bool:
	if _recruited:
		return false
	var offset := global_position - player_position
	offset.y = 0.0
	return offset.length() <= interaction_radius + 2.2

func get_interact_area() -> Area3D:
	return _interact_area
