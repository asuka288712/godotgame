## Controls the 3D battlefield sprites displayed behind the battle UI.
extends Node3D

signal attack_impact_reached(attacker_name: String, target_name: String)
signal attack_animation_finished(attacker_name: String)

const ATTACK_IMPACT_FRAMES := {
	"李逍遥": 30,
	"赵灵儿": 14,
}
const ENEMY_SCENES := {
	"蘑菇怪": preload("res://scenes/enemies/蘑菇怪.tscn"),
	"死士": preload("res://scenes/enemies/死士.tscn"),
	"蜜蜂精": preload("res://scenes/enemies/蜜蜂精.tscn"),
}
# 我方四个固定站位；当前李逍遥、赵灵儿使用前两个，后两个留给林月如等后续同伴。
const PARTY_HOME_SLOTS := [
	Vector3(-2.8, 0.10264492, 0.8), Vector3(-4.712226, 1.1435564, 0.41699386),
	Vector3(-1.55, 0.28, -0.62), Vector3(-3.45, 0.52, -1.28),
]
# These values preserve the transforms you tuned in battle_arena.tscn.
const ENEMY_LAYOUTS := [
	# 前排两只都上移 0.12，避免脚部与地面轻微穿模。
	{"position": Vector3(3.2, 1.22, -0.15), "scale": Vector3(10.0, 10.0, 10.0), "flip_h": false},
	{"position": Vector3(5.5, 0.84202265, -1.1), "scale": Vector3(5.184454, 5.184454, 10.0), "flip_h": true},
	# 第三、四只放在后排，避免遮住前排目标。
	{"position": Vector3(4.35, 0.92, -2.15), "scale": Vector3(4.6, 4.6, 4.6), "flip_h": false},
	{"position": Vector3(6.65, 1.02, -2.55), "scale": Vector3(4.6, 4.6, 4.6), "flip_h": true},
	# 第五个敌人预留最远后排位置。
	{"position": Vector3(5.55, 1.06, -3.65), "scale": Vector3(4.2, 4.2, 4.2), "flip_h": false},
]

@onready var _li_entity: Node3D = $LiXiaoyao
@onready var _zhao_entity: Node3D = $ZhaoLinger
@onready var _enemy_container: Node3D = $Enemies
@onready var _li_xiaoyao: AnimatedSprite3D = $LiXiaoyao/AnimatedSprite3D
@onready var _zhao_linger: AnimatedSprite3D = $ZhaoLinger/AnimatedSprite3D
var _li_home_position: Vector3
var _linger_idle_frames: SpriteFrames
var _enemy_battlers: Dictionary = {}
var _enemy_entities: Dictionary = {}
var _enemy_home_scales: Dictionary = {}
var _home_positions: Dictionary = {}
var _victory_tween: Tween
var _target_selection_active := false
var _targeting_enemies := true
var _hovered_target: SpriteBase3D
# 正在冲刺的对象。用于把两次相互普通攻击合并成一次“擦身而过”。
var _active_attack_tweens: Dictionary = {}
var _active_attack_targets: Dictionary = {}
var _active_attack_homes: Dictionary = {}

func _ready() -> void:
	add_to_group("battle_arena")
	_linger_idle_frames = _zhao_linger.sprite_frames
	_li_home_position = _li_entity.position
	_home_positions["李逍遥"] = _li_entity.global_position
	_home_positions["赵灵儿"] = _zhao_entity.global_position
	_li_entity.visible = false
	_zhao_entity.visible = false
	BattleSystem.battle_started.connect(_on_battle_started)
	BattleSystem.battle_ended.connect(_on_battle_ended)

func play_attack_animation(attacker_name: String, target_name: String) -> void:
	var attacker: SpriteBase3D = _get_battler(attacker_name)
	var target: SpriteBase3D = _get_battler(target_name)
	if not attacker or not target:
		return
	var attacker_entity := _entity_for_battler(attacker)
	var target_entity := _entity_for_battler(target)
	if not attacker_entity or not target_entity:
		return
	var home: Vector3 = _home_positions.get(attacker_name, attacker_entity.global_position)
	var target_home: Vector3 = _home_positions.get(target_name, target_entity.global_position)
	_active_attack_targets[attacker_name] = target_name
	_active_attack_homes[attacker_name] = home
	# 普攻永远冲向目标的初始站位；若目标已离开那里，攻击会扑空。
	var approach_direction := home - target_home
	approach_direction.y = 0.0
	if approach_direction.length_squared() < 0.001:
		approach_direction = Vector3.LEFT
	var stop_distance := _combat_stop_distance(attacker, target)
	var approach_position := target_home + approach_direction.normalized() * stop_distance
	approach_position.y = home.y
	var animated_attacker := attacker as AnimatedSprite3D
	var attack_duration := 0.60
	var attack_frame_time := 0.05
	var impact_time := attack_duration - attack_frame_time
	if animated_attacker and animated_attacker.sprite_frames and animated_attacker.sprite_frames.has_animation(&"attack"):
		var frames := animated_attacker.sprite_frames
		var attack_speed := maxf(frames.get_animation_speed(&"attack"), 1.0)
		var frame_count := frames.get_frame_count(&"attack")
		attack_duration = float(frame_count) / attack_speed
		attack_frame_time = 1.0 / attack_speed
		# Frame numbers are one-based for the editor: frame 30 means the start
		# of the 30th frame. Clamp it so shorter animations still work safely.
		var impact_frame: int = clampi(ATTACK_IMPACT_FRAMES.get(attacker_name, frame_count), 1, frame_count)
		impact_time = float(impact_frame - 1) * attack_frame_time
	var tween := create_tween()
	_active_attack_tweens[attacker_name] = tween
	tween.tween_property(attacker_entity, "global_position", approach_position, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if animated_attacker and animated_attacker.sprite_frames.has_animation(&"attack"):
		tween.tween_callback(func(): animated_attacker.play(&"attack"))
	# Effects and damage are synced to the character's configured attack frame.
	tween.tween_interval(impact_time)
	tween.tween_callback(func(): attack_impact_reached.emit(attacker_name, target_name))
	tween.tween_interval(maxf(attack_duration - impact_time, 0.0))
	tween.tween_property(attacker_entity, "global_position", home, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if animated_attacker:
		tween.tween_callback(func(): animated_attacker.play(&"battle_idle") if attacker_name == "赵灵儿" else animated_attacker.play(&"idle"))
	tween.tween_callback(func():
		_active_attack_tweens.erase(attacker_name)
		_active_attack_targets.erase(attacker_name)
		_active_attack_homes.erase(attacker_name)
		attack_animation_finished.emit(attacker_name)
	)

func _play_mutual_miss_animation(attacker_name: String, target_name: String, attacker_entity: Node3D, target_entity: Node3D, attacker_home: Vector3, target_home: Vector3) -> void:
	_active_attack_tweens.erase(attacker_name)
	_active_attack_tweens.erase(target_name)
	_active_attack_targets.erase(attacker_name)
	_active_attack_targets.erase(target_name)
	_active_attack_homes.erase(attacker_name)
	_active_attack_homes.erase(target_name)
	var attacker_sprite := _get_battler(attacker_name) as AnimatedSprite3D
	var target_sprite := _get_battler(target_name) as AnimatedSprite3D
	if attacker_sprite and attacker_sprite.sprite_frames.has_animation(&"attack"):
		attacker_sprite.play(&"attack")
	if target_sprite and target_sprite.sprite_frames.has_animation(&"attack"):
		target_sprite.play(&"attack")
	# 两人穿到对方原本站位（而非停在攻击距离），所以视觉上会真正错身而过。
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(attacker_entity, "position", target_home, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(target_entity, "position", attacker_home, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_callback(func():
		attack_impact_reached.emit(attacker_name, target_name)
		attack_impact_reached.emit(target_name, attacker_name)
	)
	tween.set_parallel(true)
	tween.tween_property(attacker_entity, "position", attacker_home, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(target_entity, "position", target_home, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func():
		if attacker_sprite: attacker_sprite.play(&"battle_idle") if attacker_name == "赵灵儿" else attacker_sprite.play(&"idle")
		if target_sprite: target_sprite.play(&"battle_idle") if target_name == "赵灵儿" else target_sprite.play(&"idle")
		attack_animation_finished.emit(attacker_name)
		attack_animation_finished.emit(target_name)
	)

func play_li_magic_cast() -> void:
	if _li_xiaoyao.sprite_frames.has_animation(&"magic"):
		_li_xiaoyao.play(&"magic")

func finish_li_magic_cast() -> void:
	_li_xiaoyao.play(&"idle")

func play_linger_magic_cast() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation(&"magic")
	frames.set_animation_speed(&"magic", 24.0)
	frames.set_animation_loop(&"magic", false)
	for frame_number in range(1, 47):
		var texture := load("res://assets/sprite/anime/Lr/attack/magic/%03d.png" % frame_number) as Texture2D
		if texture:
			frames.add_frame(&"magic", texture)
	_zhao_linger.sprite_frames = frames
	_zhao_linger.play(&"magic")

func finish_linger_magic_cast() -> void:
	_zhao_linger.sprite_frames = _linger_idle_frames
	_zhao_linger.play(&"battle_idle")

func flash_battler(target_name: String) -> void:
	var battler: SpriteBase3D = _get_battler(target_name)
	if not battler:
		return
	var animated := battler as AnimatedSprite3D
	if animated and animated.sprite_frames and animated.sprite_frames.has_animation(&"hit"):
		animated.play(&"hit")
		await get_tree().create_timer(_animation_duration(animated, &"hit")).timeout
		if animated.sprite_frames.has_animation(&"idle"):
			animated.play(&"idle")
	var tween := create_tween()
	tween.tween_property(battler, "modulate", Color(1.0, 0.22, 0.22, 1.0), 0.06)
	tween.tween_property(battler, "modulate", Color.WHITE, 0.18)

func defeat_battler(target_name: String) -> void:
	if target_name == "李逍遥" or target_name == "赵灵儿":
		return
	var enemy: SpriteBase3D = _get_battler(target_name)
	if not enemy or not enemy.visible:
		return
	var animated_enemy := enemy as AnimatedSprite3D
	if animated_enemy and animated_enemy.sprite_frames and animated_enemy.sprite_frames.has_animation(&"die"):
		animated_enemy.play(&"die")
		await get_tree().create_timer(_animation_duration(animated_enemy, &"die")).timeout
	var tween := create_tween()
	tween.tween_property(enemy, "modulate", Color(0.35, 0.33, 0.30, 1.0), 0.10)
	var enemy_entity := _entity_for_battler(enemy)
	if not enemy_entity:
		return
	var home_scale: Vector3 = _enemy_home_scales.get(target_name, enemy_entity.scale)
	tween.parallel().tween_property(enemy_entity, "scale", home_scale * 0.48, 0.36)
	tween.parallel().tween_property(enemy_entity, "position:y", enemy_entity.position.y - 0.35, 0.36)
	tween.tween_property(enemy, "modulate:a", 0.0, 0.16)
	tween.tween_callback(func(): enemy_entity.visible = false)

func _animation_duration(sprite: AnimatedSprite3D, animation_name: StringName) -> float:
	var frames := sprite.sprite_frames
	return float(frames.get_frame_count(animation_name)) / maxf(frames.get_animation_speed(animation_name), 1.0)

func get_idle_portrait(character_name: String) -> Texture2D:
	var sprite := _get_battler(character_name) as AnimatedSprite3D
	if not sprite or not sprite.sprite_frames:
		return null
	var frames := sprite.sprite_frames
	var idle_name: StringName = &"idle" if frames.has_animation(&"idle") else &"battle_idle"
	if not frames.has_animation(idle_name) or frames.get_frame_count(idle_name) == 0:
		return null
	return frames.get_frame_texture(idle_name, 0)

func get_battler_screen_position(character_name: String) -> Vector2:
	var battler: SpriteBase3D = _get_battler(character_name)
	var camera := get_viewport().get_camera_3d()
	if not battler or not camera:
		return Vector2.ZERO
	# 法术、伤害数字、MISS 与目标拾取都锁在站位点，不会跟着冲刺中的模型跑。
	return camera.unproject_position(_home_positions.get(character_name, battler.global_position))

func get_battler_current_screen_position(character_name: String) -> Vector2:
	var battler: SpriteBase3D = _get_battler(character_name)
	var camera := get_viewport().get_camera_3d()
	if not battler or not camera:
		return Vector2.ZERO
	return camera.unproject_position(battler.global_position)

func is_battler_at_home(character_name: String) -> bool:
	var battler: SpriteBase3D = _get_battler(character_name)
	var home: Vector3 = _home_positions.get(character_name, Vector3.INF)
	var entity: Node3D = _entity_for_battler(battler) if battler else null
	if not entity or home == Vector3.INF:
		return false
	return entity.global_position.distance_to(home) <= 0.18

func begin_target_selection(target_enemies: bool) -> void:
	_target_selection_active = true
	_targeting_enemies = target_enemies
	clear_target_hover()

func ensure_target_selection(target_enemies: bool) -> void:
	# UI 仍处于选目标状态时，确保战场拾取不会因前一次点击被意外关闭。
	if not _target_selection_active or _targeting_enemies != target_enemies:
		begin_target_selection(target_enemies)

func update_target_hover(screen_position: Vector2) -> String:
	if not _target_selection_active:
		return ""
	var target: SpriteBase3D = _target_at_screen_position(screen_position)
	if target != _hovered_target:
		clear_target_hover()
		_hovered_target = target
		if _hovered_target:
			_hovered_target.modulate = Color(1.0, 0.84, 0.30, 1.0)
	return _target_name_for_battler(target)

func confirm_target_at(screen_position: Vector2) -> String:
	var target_name := update_target_hover(screen_position)
	if target_name.is_empty():
		return ""
	_target_selection_active = false
	clear_target_hover()
	return target_name

func cancel_target_selection() -> void:
	_target_selection_active = false
	clear_target_hover()

func clear_target_hover() -> void:
	if _hovered_target and is_instance_valid(_hovered_target):
		_hovered_target.modulate = Color.WHITE
	_hovered_target = null

func _target_at_screen_position(screen_position: Vector2) -> SpriteBase3D:
	var candidates: Array[SpriteBase3D] = []
	if _targeting_enemies:
		for enemy in BattleSystem.battle_enemies:
			if enemy.hp > 0:
				var enemy_battler: SpriteBase3D = _get_battler(enemy.char_name) as SpriteBase3D
				if enemy_battler and enemy_battler.visible:
					candidates.append(enemy_battler)
	else:
		for member in BattleSystem.combat_party:
			if member.hp > 0:
				var party_battler: SpriteBase3D = _get_battler(member.char_name) as SpriteBase3D
				if party_battler and party_battler.visible:
					candidates.append(party_battler)
	var closest: SpriteBase3D
	# Enemies can be much larger than their root point (for example the 10×
	# mushroom), so a wider screen-space pick radius keeps skill targeting
	# reliable when clicking their visible body rather than its exact center.
	var closest_distance := 210.0
	for battler in candidates:
		var distance := get_battler_screen_position(_target_name_for_battler(battler)).distance_to(screen_position)
		if distance < closest_distance:
			closest = battler
			closest_distance = distance
	return closest

func _target_name_for_battler(battler: SpriteBase3D) -> String:
	if battler == _li_xiaoyao:
		return "李逍遥"
	if battler == _zhao_linger:
		return "赵灵儿"
	for enemy_name in _enemy_battlers:
		if _enemy_battlers[enemy_name] == battler:
			return enemy_name
	return ""

func play_victory_presentation() -> void:
	for battler in [_li_xiaoyao, _zhao_linger]:
		if not battler.visible:
			continue
		if battler.sprite_frames and battler.sprite_frames.has_animation(&"win"):
			battler.play(&"win")
	if _victory_tween:
		_victory_tween.kill()
	_victory_tween = create_tween().set_loops()
	for battler in [_li_xiaoyao, _zhao_linger]:
		if battler.visible:
			_victory_tween.parallel().tween_property(battler, "rotation:z", 0.10, 0.28).from(-0.10).set_trans(Tween.TRANS_SINE)
	_victory_tween.tween_property(_li_xiaoyao, "rotation:z", -0.10, 0.28).set_trans(Tween.TRANS_SINE)
	if _zhao_linger.visible:
		_victory_tween.parallel().tween_property(_zhao_linger, "rotation:z", -0.10, 0.28).set_trans(Tween.TRANS_SINE)

func get_victory_focus_position() -> Vector3:
	var party_members: Array[Vector3] = []
	if _li_xiaoyao.visible:
		party_members.append(_li_xiaoyao.global_position)
	if _zhao_linger.visible:
		party_members.append(_zhao_linger.global_position)
	if party_members.is_empty():
		return Vector3.ZERO
	var total := Vector3.ZERO
	for position in party_members:
		total += position
	return total / float(party_members.size())

func _get_battler(character_name: String):
	match character_name:
		"李逍遥": return _li_xiaoyao
		"赵灵儿": return _zhao_linger
		_:
			return _enemy_battlers.get(character_name) as SpriteBase3D

func _entity_for_battler(battler: SpriteBase3D) -> Node3D:
	if battler == _li_xiaoyao:
		return _li_entity
	if battler == _zhao_linger:
		return _zhao_entity
	for enemy_name in _enemy_battlers:
		if _enemy_battlers[enemy_name] == battler:
			return _enemy_entities.get(enemy_name) as Node3D
	return null

func _combat_stop_distance(attacker: SpriteBase3D, target: SpriteBase3D) -> float:
	return _sprite_world_radius(attacker) + _sprite_world_radius(target) + 0.25

func _sprite_world_radius(battler: SpriteBase3D) -> float:
	var texture: Texture2D
	if battler is AnimatedSprite3D:
		var animated := battler as AnimatedSprite3D
		if animated.sprite_frames:
			texture = animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
	elif battler is Sprite3D:
		texture = (battler as Sprite3D).texture
	if not texture:
		return 0.75
	var world_scale := battler.global_transform.basis.get_scale()
	var width := float(texture.get_width()) * battler.pixel_size * absf(world_scale.x)
	return maxf(width * 0.42, 0.35)

func _on_battle_started(enemies: Array) -> void:
	cancel_target_selection()
	if _victory_tween:
		_victory_tween.kill()
	_li_xiaoyao.rotation = Vector3.ZERO
	_zhao_linger.rotation = Vector3.ZERO
	_li_entity.visible = BattleSystem.combat_party.any(func(member): return member.char_name == "李逍遥")
	_zhao_entity.visible = BattleSystem.combat_party.any(func(member): return member.char_name == "赵灵儿")
	_li_xiaoyao.play(&"idle")
	_zhao_linger.play(&"battle_idle")
	# 战斗开始时把已登场同伴对齐到各自固定站位。
	for party_index in range(mini(BattleSystem.combat_party.size(), PARTY_HOME_SLOTS.size())):
		var party_name: String = BattleSystem.combat_party[party_index].char_name
		var party_entity: Node3D = _li_entity if party_name == "李逍遥" else (_zhao_entity if party_name == "赵灵儿" else null)
		if party_entity:
			party_entity.global_position = PARTY_HOME_SLOTS[party_index]
			_home_positions[party_name] = PARTY_HOME_SLOTS[party_index]
	_clear_generated_enemies()
	for index in range(enemies.size()):
		_spawn_enemy(enemies[index], index)

func _spawn_enemy(enemy_data, index: int) -> void:
	# 同类怪物会以 #2、#3 编号，显示和命中各自独立，但仍使用同一份怪物场景。
	var base_name: String = enemy_data.char_name.split("#")[0]
	var scene: PackedScene = ENEMY_SCENES.get(base_name, ENEMY_SCENES["死士"])
	var entity := scene.instantiate() as Node3D
	var layout: Dictionary = ENEMY_LAYOUTS[min(index, ENEMY_LAYOUTS.size() - 1)]
	entity.name = "Enemy_%d_%s" % [index + 1, enemy_data.char_name]
	entity.position = layout["position"]
	var visual_scale: Vector3 = layout["scale"]
	# 蘑菇怪和蜜蜂精的画面尺寸独立于队列站位，避免换了测试顺序就缩小。
	if base_name in ["蘑菇怪", "蜜蜂精"]:
		visual_scale = Vector3(10.0, 10.0, 10.0)
	entity.scale = visual_scale
	# 蘑菇维持原本的落地高度；蜜蜂作为飞行单位悬在地面上方。
	if base_name == "蘑菇怪":
		entity.position.y = maxf(entity.position.y, 1.22)
	elif base_name == "蜜蜂精":
		entity.position.y += 1.15
	_enemy_container.add_child(entity)
	var sprite := entity.get_node_or_null("AnimatedSprite3D") as AnimatedSprite3D
	if not sprite:
		entity.queue_free()
		return
	# 只有死士（以及暂时复用死士精灵的怪物）需要镜像；蘑菇和蜜蜂维持素材原始朝向。
	sprite.flip_h = scene == ENEMY_SCENES["死士"]
	sprite.cast_shadow = 1
	sprite.modulate = Color.WHITE
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(&"idle"):
		sprite.play(&"idle")
	_enemy_battlers[enemy_data.char_name] = sprite
	_enemy_entities[enemy_data.char_name] = entity
	_enemy_home_scales[enemy_data.char_name] = entity.scale
	_home_positions[enemy_data.char_name] = entity.global_position

func _clear_generated_enemies() -> void:
	for entity in _enemy_entities.values():
		if is_instance_valid(entity):
			entity.queue_free()
	_enemy_battlers.clear()
	_enemy_entities.clear()
	_enemy_home_scales.clear()
	for enemy_name in _home_positions.keys().duplicate():
		if enemy_name not in ["李逍遥", "赵灵儿"]:
			_home_positions.erase(enemy_name)

func _on_battle_ended(victory: bool) -> void:
	cancel_target_selection()
	if victory:
		play_victory_presentation()
		return
	if _victory_tween:
		_victory_tween.kill()
	_li_entity.visible = false
	_zhao_entity.visible = false
	for entity in _enemy_entities.values():
		if is_instance_valid(entity):
			entity.visible = false
