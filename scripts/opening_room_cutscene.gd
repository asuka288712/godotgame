## 游戏开场：在逍遥房间内，由李大娘喊醒李逍遥。
## 这是独立节点；之后其他房间剧情也可以照这个结构新建自己的演出脚本。
extends Node

@export var enabled := true
@export var aunt_bedside_position := Vector3(1.72, 0.0, 3.35)
@export var get_out_of_bed_offset := Vector3(-0.95, 0.0, 0.0)

@onready var _player: CharacterBody3D = get_parent().get_node_or_null("Player")
@onready var _aunt: Node3D = get_parent().get_node_or_null("LiDaniang")
@onready var _aunt_callout: Label3D = get_parent().get_node_or_null("LiDaniang/Callout")
@onready var _camera: Camera3D = get_parent().get_node_or_null("Camera")
@onready var _opening_music: AudioStreamPlayer = get_parent().get_node_or_null("OpeningMusic")

var _bed_position := Vector3.ZERO
var _standing_sprite_rotation := Vector3.ZERO
var _aunt_entry_position := Vector3.ZERO

func _ready() -> void:
	if _player:
		_bed_position = _player.position
		_set_sleeping_pose()
	if _aunt:
		_aunt_entry_position = _aunt.position
	call_deferred("_play_opening")

func _play_opening() -> void:
	if not enabled or GameData.opening_intro_finished or not _player:
		return

	# 开场期间不能移动、跳跃或打开探索交互。
	GameData.current_state = GameData.GameState.PAUSED
	_player.cancel_auto_walk()
	# 先给睡姿两秒特写，结束后才进入李大娘走近和对话。
	_show_sleeping_close_up()
	await get_tree().create_timer(2.0).timeout
	_end_sleeping_close_up()

	# 李大娘从门口方向走到床边。素材只有站立图，因此用位置移动
	# 配合轻微上下起伏表现走近；之后替换走路序列也不需要动剧情流程。
	if _aunt:
		var approach := create_tween().set_parallel(true)
		approach.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		approach.tween_property(_aunt, "position", aunt_bedside_position, 1.15)
		approach.tween_property(_aunt, "rotation:y", 0.0, 0.2)
		await approach.finished

	if _aunt_callout:
		_aunt_callout.visible = true
	await get_tree().create_timer(0.95).timeout
	if _aunt_callout:
		_aunt_callout.visible = false
	# 听见喊声后，李逍遥从床的侧边落地，并恢复正常的 idle 动画。
	_get_out_of_bed()

	DialogueSystem.start_dialogue([
		{"speaker": "李大娘", "text": "逍遥！太阳都晒屁股了，还在床上赖着呢？快起来帮我招呼客人！"},
		{"speaker": "李逍遥", "text": "知道啦，婶婶……我这就起来。"},
		{"speaker": "李大娘", "text": "快些，楼下可忙着呢。洗把脸就下来！"},
	])
	await DialogueSystem.dialogue_finished
	# 台词结束即开始室内探索的背景音乐；李大娘同时自然退场。
	if _opening_music and not _opening_music.playing:
		_opening_music.play()
	# 对话完整结束后，李大娘才走回入口并退场。
	if _aunt:
		var leave_tween := create_tween()
		leave_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		leave_tween.tween_property(_aunt, "position", _aunt_entry_position, 0.9)
		await leave_tween.finished
		_aunt.visible = false
	GameData.opening_intro_finished = true

func _show_sleeping_close_up() -> void:
	if not _camera:
		return
	get_parent().set("cutscene_camera_active", true)
	_camera.global_position = _player.global_position + Vector3(0.0, 1.25, 4.2)
	_camera.look_at(_player.global_position + Vector3.UP * 0.75, Vector3.UP)

func _end_sleeping_close_up() -> void:
	get_parent().set("cutscene_camera_active", false)

func _set_sleeping_pose() -> void:
	var sprite := _player.get_node_or_null("AnimatedSprite3D") as AnimatedSprite3D
	if not sprite:
		return
	_standing_sprite_rotation = sprite.rotation
	# idle 的第四帧（索引 3）作为睡姿，精灵横转 90 度并稍微抬到床面上方。
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(&"idle"):
		sprite.play(&"idle")
		sprite.pause()
		sprite.frame = 3
	sprite.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	_player.position = _bed_position + Vector3.UP * 0.42

func _get_out_of_bed() -> void:
	var sprite := _player.get_node_or_null("AnimatedSprite3D") as AnimatedSprite3D
	if sprite:
		sprite.rotation = _standing_sprite_rotation
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(&"idle"):
			sprite.play(&"idle")
	var get_out := create_tween()
	get_out.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	get_out.tween_property(_player, "position", _bed_position + get_out_of_bed_offset, 0.42)
