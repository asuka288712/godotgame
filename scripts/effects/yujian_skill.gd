## 御剑术演出模板：由 AnimationPlayer 驱动飞剑阶段，代码负责动态目标位置与剑雨生成。
extends Control

signal playback_finished

const SWORD_TEXTURE := preload("res://assets/sprite/sword.png")
const SWORD_SFX := preload("res://assets/music/sound/sw.mp3")

@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _flying_sword: TextureRect = $FlyingSword

var _caster_screen_position := Vector2.ZERO
var _target_screen_position := Vector2.ZERO
var _flight_progress := 0.0

# 这个属性由 AnimationPlayer 的 value track 在 0.0 → 1.0 之间驱动。
var flight_progress: float:
	set(value):
		_flight_progress = value
		_update_flying_sword()
	get:
		return _flight_progress

func play_skill(caster_screen_position: Vector2, target_screen_position: Vector2) -> void:
	_caster_screen_position = caster_screen_position
	_target_screen_position = target_screen_position
	_flying_sword.visible = true
	flight_progress = 0.0
	_animation_player.play(&"yujian")

func _update_flying_sword() -> void:
	# 飞剑从施法者手边飞至敌人上方。路径可通过时间轴的 flight_progress 调速。
	var start := _caster_screen_position + Vector2(18, -82) - _flying_sword.size * 0.5
	var end := _target_screen_position + Vector2(-21, -285) - _flying_sword.size * 0.5
	_flying_sword.position = start.lerp(end, _flight_progress)
	var direction := (end - start).normalized()
	_flying_sword.rotation = direction.angle() - PI * 0.5 + _flight_progress * (PI * 0.5)

# AnimationPlayer 在飞剑到达敌人上方的这一帧调用。
func start_sword_rain() -> void:
	_flying_sword.visible = false
	_spawn_sword_rain()

func _spawn_sword_rain() -> void:
	for sword_index in range(10):
		_spawn_falling_sword(sword_index)
		await get_tree().create_timer(0.045).timeout

func _spawn_falling_sword(_index: int) -> void:
	var sword := TextureRect.new()
	sword.texture = SWORD_TEXTURE
	sword.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sword.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sword.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sword.size = Vector2(44, 122)
	sword.pivot_offset = sword.size * 0.5
	sword.rotation = deg_to_rad(randf_range(-18.0, 18.0))
	var landing := _target_screen_position + Vector2(randf_range(-88.0, 88.0), randf_range(-10.0, 115.0))
	sword.position = Vector2(landing.x + randf_range(-75.0, 75.0), -150.0 - randf_range(0.0, 260.0))
	sword.z_index = 8
	add_child(sword)
	var tween := create_tween()
	tween.tween_property(sword, "position", landing, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_play_sword_sound)
	tween.tween_property(sword, "modulate:a", 0.0, 0.15)
	tween.tween_callback(sword.queue_free)

func _play_sword_sound() -> void:
	var player := AudioStreamPlayer.new()
	player.stream = SWORD_SFX
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

# AnimationPlayer 在演出末尾调用。战斗 UI 之后可以 await 这个信号再结算下一步。
func finish_playback() -> void:
	playback_finished.emit()
