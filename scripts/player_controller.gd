## 玩家控制器 — CharacterBody3D, 3D移动和交互输入
extends CharacterBody3D

signal interacted
signal auto_walk_finished

@export var move_speed: float = 5.0
@export var jump_velocity: float = 5.2
@export var gravity: float = 16.0
@export var coyote_time: float = 0.10

@onready var _sprite: AnimatedSprite3D = $AnimatedSprite3D

var _coyote_timer: float = 0.0
var _auto_walk_active := false
var _auto_walk_target := Vector3.ZERO
var _auto_walk_stop_distance := 1.0

func walk_to(target: Vector3, stop_distance := 1.0) -> void:
	_auto_walk_target = target
	_auto_walk_stop_distance = maxf(stop_distance, 0.35)
	_auto_walk_active = true

func cancel_auto_walk() -> void:
	_auto_walk_active = false
	# 对话开启或手动取消时立即刹车，避免沿用上一帧的自动行走速度。
	velocity.x = 0.0
	velocity.z = 0.0

func _ready() -> void:
	add_to_group("player")

func _physics_process(delta: float) -> void:
	if GameData.current_state != GameData.GameState.EXPLORE:
		velocity = Vector3.ZERO; return
	var was_on_floor := is_on_floor()
	if was_on_floor:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump") and _coyote_timer > 0.0:
		velocity.y = jump_velocity
		_coyote_timer = 0.0
	var dir := Vector2.ZERO
	var manual_move := Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down") or Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right")
	if manual_move:
		cancel_auto_walk()
		if Input.is_action_pressed("move_up"):    dir.y -= 1.0
		if Input.is_action_pressed("move_down"):  dir.y += 1.0
		if Input.is_action_pressed("move_left"):  dir.x -= 1.0
		if Input.is_action_pressed("move_right"): dir.x += 1.0
	elif _auto_walk_active:
		var flat_target := Vector3(_auto_walk_target.x, global_position.y, _auto_walk_target.z)
		var offset := flat_target - global_position
		if offset.length() <= _auto_walk_stop_distance:
			_auto_walk_active = false
			auto_walk_finished.emit()
		else:
			dir = Vector2(offset.x, offset.z).normalized()
	if dir != Vector2.ZERO:
		dir = dir.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.y * move_speed
		# 根据实际移动方向切换动画；自动靠近 NPC 时也会正确播放走路动作。
		if absf(dir.x) > absf(dir.y):
			if _sprite.animation != "walk":
				_sprite.play("walk")
		elif dir.y < 0:
			if _sprite.animation != "walku":
				_sprite.play("walku")
		else:
			if _sprite.animation != "walkd":
				_sprite.play("walkd")
		# 左右移动时翻转精灵
		if dir.x < 0:
			_sprite.flip_h = true
		elif dir.x > 0:
			_sprite.flip_h = false
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 0.4)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 0.4)
		# 静止时播放idle动画
		if _sprite.animation != "idle":
			_sprite.play("idle")
	if not was_on_floor:
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if GameData.current_state != GameData.GameState.EXPLORE: return
	# Switch on the input frame itself so horizontal movement never shows the
	# previous up/down animation for one rendered frame.
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		_sprite.play("walk")
	if event.is_action_pressed("interact"):
		if _auto_walk_active:
			cancel_auto_walk()
			return
		interacted.emit()
