## 游戏开场：在逍遥房间内，由李大娘喊醒李逍遥。
## 这是独立节点；之后其他房间剧情也可以照这个结构新建自己的演出脚本。
extends Node

@export var enabled := true
# 横向摔倒画稿按站立角色的体量显示，不按画布高度放大。
@export_range(0.5, 1.0, 0.05) var wakeup_scale := 0.9
@export var get_out_of_bed_offset := Vector3(-0.95, 0.0, 0.0)

@onready var _player: CharacterBody3D = get_parent().get_node_or_null("Player")
@onready var _bed_marker: Marker3D = get_parent().get_node_or_null("BedPosition")
@onready var _aunt: Node3D = get_parent().get_node_or_null("LiDaniang")
@onready var _aunt_callout: Label3D = get_parent().get_node_or_null("LiDaniang/Callout")
@onready var _camera: Camera3D = get_parent().get_node_or_null("Camera")
@onready var _opening_music: AudioStreamPlayer = get_parent().get_node_or_null("OpeningMusic")
@onready var _cutscene_animation: AnimationPlayer = get_parent().get_node_or_null("CutsceneAnimationPlayer")
@onready var _blackout: CanvasLayer = get_parent().get_node_or_null("OpeningBlackout")
@onready var _wakeup_image: TextureRect = get_parent().get_node_or_null("OpeningBlackout/WakeupImage")

var _bed_position := Vector3.ZERO
var _standing_sprite_rotation := Vector3.ZERO
var _standing_pixel_size := 0.004
var _standing_sprite_offset := Vector2(0.0, 200.0)
var _opening_dialogue_active := false
var _opening_dialogue_line := 0
var _wakeup_in_progress := false
func _ready() -> void:
	DialogueSystem.dialogue_line.connect(_on_dialogue_line)
	DialogueSystem.advance_requested.connect(_on_dialogue_advance_requested)
	if GameData.opening_intro_finished:
		if _aunt:
			_aunt.visible = false
		if _blackout:
			_blackout.visible = false
		if _wakeup_image:
			_wakeup_image.visible = false
		return
	if _player:
		# Player 在 tscn 里保存的是起床后的常驻位置；床上起点可直接拖动 BedPosition 调整。
		_bed_position = _bed_marker.position if _bed_marker else _player.position
		_set_sleeping_pose()
	call_deferred("_play_opening")

func _play_opening() -> void:
	if not enabled or GameData.opening_intro_finished or not _player:
		return

	# 开场期间不能移动、跳跃或打开探索交互。
	GameData.current_state = GameData.GameState.PAUSED
	_player.cancel_auto_walk()
	# 第一条台词保持黑幕；玩家确认后才播放 wakeup 与掉床演出。
	_opening_dialogue_active = true
	_opening_dialogue_line = 0
	DialogueSystem.set_advance_locked(true)
	DialogueSystem.start_dialogue([
		{"speaker": "李大娘", "text": "李～逍～遥，李～逍～遥！"},
		{"speaker": "李逍遥", "text": "哇哇！作恶多端的罗煞鬼婆，既然落在你的手里， 要杀要剐不用多说！"},
		{"speaker": "李大娘", "text": "李逍遥！你皮痒啊？敢说老娘是什么鬼婆！"},
		{"speaker": "李逍遥", "text": "哎呦～疼啊！"},
		{"speaker": "李大娘", "text": "又在作白日梦了！你也老大不小了，整天疯疯癫癫地，也不学学做正经事！"},
		{"speaker": "李逍遥", "text": "婶婶～　你不要每次叫人起床都拿锅呀、铲呀，乱敲一通的，会吓死人哪！咱们这木床又不牢靠，万一我给摔死了，咱们李家就绝后啦。"},
		{"speaker": "李大娘", "text": "不这样叫得醒你吗？好歹你也跟林师傅学过几个月的木工，床不牢自己动手修一修不就好了？就只会削些木刀木剑的，成天学你爹舞刀弄剑，没个定性，有哪家姑娘愿意嫁给你喔．．"},
		{"speaker": "李逍遥", "text": "那我爹怎么会娶到我娘？"},
		{"speaker": "李大娘", "text": "啧！你娘也是跟你爹一个样儿嫁到咱们李家来，也不做针线女红，就只会跟着你爹疯．．"},
		{"speaker": "李逍遥", "text": "嘿．．大家都说～他们是江湖上人人羡慕的鸳鸯侠侣呢！"},
		{"speaker": "李大娘", "text": "是哦～侠侣？说要去行侠仗义丢下你这惹祸精，一去无回还不是我这老太婆省吃俭用的开了这么一家小小的客栈，才把你拉拔到这么大，结果养出这么一个懒鬼！"},
		{"speaker": "李逍遥", "text": "谁说我是懒鬼啦？"},
		{"speaker": "李逍遥", "text": "我将来要像我爹娘一样练成绝世武功，纵横四海、称霸江湖的一代大侠！"},
		{"speaker": "李大娘", "text": "少跟老娘鬼扯淡！你呀～游手好闲是出了名的。要不是这回我忙不过来，才不指望你这懒鬼来帮忙呢！"},
		{"speaker": "李逍遥", "text": "一大早就有客人上门啦？"},
		{"speaker": "李大娘", "text": "是啊．．还不快过来帮忙！"},
	])
	await DialogueSystem.dialogue_finished
	_opening_dialogue_active = false
	# 李大娘目前没有完整走路动作，直接退场，避免旧退场轨道从错误站位跳动。
	if _aunt:
		_aunt.visible = false
	GameData.opening_intro_finished = true

func _on_dialogue_line(_speaker: String, _text: String) -> void:
	if not _opening_dialogue_active:
		return
	# 到“婶婶～”这句前，wakeup 动作结束并切回普通 idle。
	if _opening_dialogue_line == 5:
		_play_idle()
	_opening_dialogue_line += 1

func _on_dialogue_advance_requested(line_index: int) -> void:
	_try_start_wakeup(line_index)

func _try_start_wakeup(line_index: int) -> void:
	if not _opening_dialogue_active or line_index != 0 or _wakeup_in_progress:
		return
	_play_wakeup_cutscene()

func _play_wakeup_cutscene() -> void:
	_wakeup_in_progress = true
	if _cutscene_animation:
		_cutscene_animation.play(&"opening_intro")
		# 不依赖动画完成信号收黑幕，避免轨道中断时场景一直被遮住。
		await get_tree().create_timer(1.25, false).timeout
	else:
		_play_wakeup()
	# 动画轨道淡出黑幕，结束时再强制关闭遮罩，保证不会残留黑屏。
	if _blackout:
		_blackout.visible = false
	if _wakeup_image:
		_wakeup_image.visible = false
	# 起身演出结束后解除锁定；由玩家下一次点击进入第二句。
	DialogueSystem.unlock_advance()

func _play_wakeup() -> void:
	# wakeup 与黑幕淡出同一关键帧开始：画面出现时才起音乐，随后可无缝带到客栈。
	GameData.play_persistent_music(GameData.OPENING_INN_MUSIC)
	var sprite := _player.get_node_or_null("AnimatedSprite3D") as AnimatedSprite3D
	if sprite:
		sprite.rotation = _standing_sprite_rotation
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(&"wakeup"):
			sprite.pixel_size = _standing_pixel_size * wakeup_scale
			var texture := sprite.sprite_frames.get_frame_texture(&"wakeup", 0)
			# 原图下沿即接地点，抵消精灵节点的抬高，缩放后仍贴地。
			sprite.offset = Vector2(_standing_sprite_offset.x, texture.get_height() * 0.5 - sprite.position.y / sprite.pixel_size)
			sprite.play(&"wakeup")
	var fall_tween := create_tween()
	fall_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fall_tween.tween_property(_player, "position", _bed_position + get_out_of_bed_offset, 0.42)

func _play_idle() -> void:
	var sprite := _player.get_node_or_null("AnimatedSprite3D") as AnimatedSprite3D
	if sprite:
		sprite.rotation = _standing_sprite_rotation
		sprite.pixel_size = _standing_pixel_size
		sprite.offset = _standing_sprite_offset
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(&"idle"):
			sprite.play(&"idle")

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
	_standing_pixel_size = sprite.pixel_size
	_standing_sprite_offset = sprite.offset
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
