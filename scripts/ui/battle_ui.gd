## 战斗 UI — 指令菜单、技能选择、目标选择、战斗日志、队伍状态
extends Control

signal victory_continue_requested

const LI_SHOUT_SFX := preload("res://assets/music/sound/ha.mp3")
const LI_SWORD_SFX := preload("res://assets/music/sound/sw.mp3")
const LIGHTNING_SFX := preload("res://assets/music/sound/ld.mp3")
const EARTH_SPELL_SFX := preload("res://assets/music/sound/tz.mp3")
const FIRE_SPELL_SFX := preload("res://assets/music/sound/yz.mp3")
const BATTLE_MUSIC := preload("res://assets/music/林坤信 - 势如破竹.mp3")
const VICTORY_MUSIC := preload("res://assets/music/林坤信 - 得胜令.mp3")
const BATTLE_FONT := preload("res://assets/fonts/font.ttf")
const DAMAGE_FONT_PATH := "res://assets/ui/other/01_UI_Resources/B1FONT/font_%s_%s.png"
const FU_TALISMAN_TEXTURE := preload("res://assets/uis/fu.png")
const HEAL_EFFECT_ATLAS := preload("res://assets/effects/heal/Heal_Effect.png")
const BATTLE_STATUS_CARD := preload("res://scripts/ui/battle_status_card.gd")
# 状态卡头像。没有配置的角色或敌人会退回使用战斗 idle 第一帧。
const PORTRAIT_TEXTURE_PATHS: Dictionary = {
	"李逍遥": "res://assets/sprite/poratait/head/lxy.png",
	"赵灵儿": "res://assets/sprite/poratait/head/zlr.png",
}
const COMMAND_ART: Dictionary = {
	"default": preload("res://assets/ui/buttle/buttle.png"),
	"attack": preload("res://assets/ui/buttle/buttle_a.png"),
	"skill": preload("res://assets/ui/buttle/buttle_m.png"),
	"item": preload("res://assets/ui/buttle/buttle_i.png"),
	"defend": preload("res://assets/ui/buttle/buttle_d.png"),
	"escape": preload("res://assets/ui/buttle/buttle_e.png"),
}
const FALLING_SWORD_TEXTURE := preload("res://assets/sprite/sword.png")
const LIGHTNING_FRAME_COUNT := 12
const LIGHTNING_IMPACT_FRAME_COUNT := 6
const FIRE_FRAME_COUNT := 12
const MUD_FRAME_COUNT := 5
const METEOR_FRAME_COUNT := 33
const SWORD_SLASH_FRAME_COUNT := 6
const LINGER_SLASH_FRAME_COUNT := 5
const WIND_FRAME_COUNT := 8
const FU_FRAME_COUNT := 6
const HEAL_FRAME_COUNT := 11
const HEAL_FRAME_SIZE := Vector2(192, 192)

@onready var _party_panel: VBoxContainer = $PartyScroll/PartyPanel
@onready var _enemy_panel: VBoxContainer = $EnemyScroll/EnemyPanel
@onready var _status_card_template: Panel = $StatusCardTemplate
@onready var _enemy_status_card_template: Panel = $EnemyStatusCardTemplate
@onready var _turn_label: Label = $TurnLabel
@onready var _action_gauge: ProgressBar = $ActionGauge
@onready var _action_gauge_label: Label = $ActionGauge/Label
@onready var _action_timeline: Control = $ActionTimeline
@onready var _action_timeline_title: Label = $ActionTimeline/Title
@onready var _action_timeline_track: ColorRect = $ActionTimeline/Track
@onready var _action_timeline_runners: Control = $ActionTimeline/Runners
@onready var _cmd_panel: Control = $CmdPanel
@onready var _sub_menu: Control = $SubMenu
@onready var _sub_menu_scroll: ScrollContainer = $SubMenu/ScrollContainer
@onready var _sub_menu_list: VBoxContainer = $SubMenu/ScrollContainer/List
@onready var _sub_menu_back: Button = $SubMenu/BackButton
@onready var _target_panel: VBoxContainer = $TargetPanel
@onready var _battle_stage: Control = $BattleStage
@onready var _scene_background: TextureRect = $BattleSceneBackground
@onready var _command_artwork: TextureRect = $CommandArtwork
@onready var _victory_panel: Control = $VictoryPanel
@onready var _command_buttons: Array[Button] = [
	$CmdPanel/AttackButton as Button,
	$CmdPanel/SkillButton as Button,
	$CmdPanel/ItemButton as Button,
	$CmdPanel/DefendButton as Button,
	$CmdPanel/EscapeButton as Button,
]

var _font: Font
var _current_char = null
var _battle_music_player: AudioStreamPlayer
var _music_fade_tween: Tween
var _action_gauge_tween: Tween
var _action_runner_icons: Dictionary = {}
var _awaiting_victory_click := false
var _targeting_enemies := true

var CMD_KEYS   = ["attack", "skill", "item", "defend", "escape"]

func _ready() -> void:
	visible = false
	add_to_group("battle_ui")
	_setup_font()
	_setup_command_buttons()
	_sub_menu_back.pressed.connect(_cancel_sub_menu)
	_battle_stage.gui_input.connect(_on_battle_stage_gui_input)
	BattleSystem.battle_started.connect(_on_battle_started)
	BattleSystem.battle_ended.connect(_on_battle_ended)
	BattleSystem.turn_changed.connect(_on_turn_changed)
	BattleSystem.action_gauges_updated.connect(_on_action_gauges_updated)
	BattleSystem.request_player_action.connect(_on_request_action)
	BattleSystem.action_executed.connect(_on_action_executed)
	BattleSystem.damage_dealt.connect(_on_damage_dealt)
	BattleSystem.attack_missed.connect(_on_attack_missed)
	BattleSystem.cast_interrupted.connect(_on_cast_interrupted)
	BattleSystem.attack_animation_requested.connect(_on_attack_animation_requested)
	BattleSystem.lightning_strike_requested.connect(_on_lightning_strike_requested)
	BattleSystem.elemental_spell_requested.connect(_on_elemental_spell_requested)
	BattleSystem.zhao_magic_cast_requested.connect(_on_zhao_magic_cast_requested)
	BattleSystem.zhao_magic_cast_finished.connect(_on_zhao_magic_cast_finished)
	BattleSystem.sword_slash_requested.connect(_on_sword_slash_requested)
	BattleSystem.attack_sfx_requested.connect(_on_attack_sfx_requested)
	BattleSystem.yujian_magic_cast_requested.connect(_on_yujian_magic_cast_requested)
	BattleSystem.yujian_sword_rain_requested.connect(_on_yujian_sword_rain_requested)
	BattleSystem.yujian_magic_cast_finished.connect(_on_yujian_magic_cast_finished)
	BattleSystem.tianshi_fufa_requested.connect(_on_tianshi_fufa_requested)
	BattleSystem.healing_effect_requested.connect(_on_healing_effect_requested)
	BattleSystem.li_skill_shout_requested.connect(_on_li_skill_shout_requested)
	BattleSystem.wind_skill_requested.connect(_on_wind_skill_requested)

func capture_exploration_background() -> void:
	# Wait for the world to finish drawing, while the battle interface is hidden.
	await RenderingServer.frame_post_draw
	var screenshot := get_viewport().get_texture().get_image()
	_scene_background.texture = ImageTexture.create_from_image(screenshot)

func _setup_font() -> void:
	_font = BATTLE_FONT
	_turn_label.add_theme_font_override("font", _font)
	_turn_label.add_theme_font_size_override("font_size", 20)
	_turn_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	_action_gauge_label.add_theme_font_override("font", _font)
	_action_gauge_label.add_theme_font_size_override("font_size", 16)
	_action_gauge_label.add_theme_color_override("font_color", Color(0.20, 0.10, 0.04))
	_action_timeline_title.add_theme_font_override("font", _font)
	_action_timeline_title.add_theme_font_size_override("font_size", 16)
	_action_timeline_title.add_theme_color_override("font_color", Color(1.0, 0.87, 0.55))
	for marker in [$ActionTimeline/Start as Label, $ActionTimeline/Finish as Label]:
		marker.add_theme_font_override("font", _font)
		marker.add_theme_font_size_override("font_size", 14)
		marker.add_theme_color_override("font_color", Color(0.92, 0.69, 0.32))
	var action_point := ColorRect.new()
	action_point.color = Color(1.0, 0.78, 0.25, 0.95)
	const ACTION_POINT_RATIO := 0.60
	action_point.position = Vector2(_action_timeline_track.position.x + _action_timeline_track.size.x * ACTION_POINT_RATIO - 1.5, 23.0)
	action_point.size = Vector2(3.0, 18.0)
	action_point.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_timeline.add_child(action_point)
	var action_point_label := Label.new()
	action_point_label.text = "行动"
	action_point_label.position = Vector2(_action_timeline_track.position.x + _action_timeline_track.size.x * ACTION_POINT_RATIO - 20.0, 38.0)
	action_point_label.size = Vector2(40.0, 16.0)
	action_point_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_point_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_point_label.add_theme_font_override("font", _font)
	action_point_label.add_theme_font_size_override("font_size", 11)
	action_point_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.25))
	_action_timeline.add_child(action_point_label)
	$VictoryPanel/VictoryLabel.add_theme_font_override("font", _font)
	$VictoryPanel/ContinueHint.add_theme_font_override("font", _font)

# ============================================================
#  事件回调
# ============================================================
func _on_battle_started(enemies: Array) -> void:
	visible = true
	_awaiting_victory_click = false
	_victory_panel.visible = false
	_set_battle_hud_visible(true)
	_hide_all_panels()
	if is_instance_valid(GameData._scene_title_layer):
		GameData._scene_title_layer.hide()
	_play_battle_music()
	_build_battle_stage(enemies)
	_update_party_panel()
	_update_enemy_panel(enemies)

func _on_battle_ended(victory: bool) -> void:
	_stop_battle_music()
	if BattleSystem.did_escape:
		_turn_label.text = "成功逃跑！"
	elif victory:
		_play_victory_music()
		_set_battle_hud_visible(false)
		_show_experience_rewards()
		_victory_panel.visible = true
		# Do not accept the mouse-up from the action that delivered the final hit.
		await get_tree().create_timer(0.35, false).timeout
		_awaiting_victory_click = true
	else:
		_turn_label.text = "战斗失败……"
	_hide_all_panels()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _go_back_one_battle_menu():
			get_viewport().set_input_as_handled()
			return
	_handle_target_input(event)


func _on_battle_stage_gui_input(event: InputEvent) -> void:
	_handle_target_input(event)


func _handle_target_input(event: InputEvent) -> void:
	if _awaiting_victory_click and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_awaiting_victory_click = false
		victory_continue_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if BattleSystem.state != BattleSystem.BState.SELECT_TARGET:
		return
	var arena := _get_battle_arena()
	if not arena:
		return
	# 避免战斗系统在选目标、但战场拾取已被旧事件关闭时卡住技能释放。
	if arena.has_method("ensure_target_selection"):
		arena.ensure_target_selection(_targeting_enemies)
	if event is InputEventMouseMotion:
		arena.update_target_hover(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target_name: String = arena.confirm_target_at(event.position)
		if not target_name.is_empty():
			_confirm_battler_target(target_name)
			get_viewport().set_input_as_handled()

func _build_battle_stage(_enemies: Array) -> void:
	var title: Label = $BattleStage/BattleTitle
	title.add_theme_font_override("font", _font)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.54))

func _on_turn_changed(character, is_party: bool) -> void:
	_current_char = character
	_turn_label.text = "—— %s 的回合 ——" % character.char_name
	_start_action_gauge(character, is_party)
	_update_party_panel()
	_update_enemy_panel(BattleSystem.battle_enemies)

func _start_action_gauge(character, is_party: bool) -> void:
	if _action_gauge_tween:
		_action_gauge_tween.kill()
	_action_gauge.value = 0.0
	var side := "我方" if is_party else "敌方"
	_action_gauge_label.text = "%s · %s 蓄力中" % [side, character.char_name]
	# 目前仅作行动条视觉展示；速度越高，蓄力动画越短。
	var charge_duration := clampf(0.92 - GameData.get_stat(character, "speed") * 0.012, 0.28, 0.78)
	_action_gauge_tween = create_tween()
	_action_gauge_tween.tween_property(_action_gauge, "value", 100.0, charge_duration)
	_action_gauge_tween.tween_callback(func():
		_action_gauge_label.text = "%s · %s 可以行动" % [side, character.char_name]
	)
	_action_timeline_title.text = "%s · %s 到行动点，可选择指令" % [side, character.char_name]

func _on_action_gauges_updated(entries: Array) -> void:
	var active_ids: Dictionary = {}
	for entry in entries:
		var identifier := str(entry.get("id", 0))
		active_ids[identifier] = true
		var runner := _action_runner_icons.get(identifier) as TextureRect
		if runner == null:
			runner = _make_action_runner(entry.character, bool(entry.is_party))
			_action_runner_icons[identifier] = runner
			_action_timeline_runners.add_child(runner)
		var progress := float(entry.progress) / 100.0
		var travel_width := _action_timeline_track.size.x - runner.size.x
		runner.position = Vector2(_action_timeline_track.position.x + travel_width * progress, 20.0 if bool(entry.is_party) else 30.0)
		var actor_state: int = int(entry.get("actor_state", 0))
		runner.modulate = (Color(1.0, 0.95, 0.55) if bool(entry.is_party) else Color(1.0, 0.72, 0.55)) if actor_state == BattleSystem.ActorState.CASTING else (Color.WHITE if bool(entry.is_party) else Color(1.0, 0.82, 0.72))
	for identifier in _action_runner_icons.keys().duplicate():
		if not active_ids.has(identifier):
			var old_runner := _action_runner_icons[identifier] as TextureRect
			if old_runner:
				old_runner.queue_free()
			_action_runner_icons.erase(identifier)

func _make_action_runner(character, is_party: bool) -> TextureRect:
	var runner := TextureRect.new()
	runner.custom_minimum_size = Vector2(26, 26)
	runner.size = Vector2(26, 26)
	runner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	runner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	runner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	runner.tooltip_text = character.char_name
	var portrait_path: String = PORTRAIT_TEXTURE_PATHS.get(character.char_name, "")
	if not portrait_path.is_empty():
		runner.texture = load(portrait_path) as Texture2D
	else:
		var arena := _get_battle_arena()
		if arena and arena.has_method("get_idle_portrait"):
			runner.texture = arena.get_idle_portrait(character.char_name) as Texture2D
	runner.modulate = Color(1.0, 1.0, 1.0) if is_party else Color(1.0, 0.82, 0.72)
	return runner

func _on_request_action() -> void:
	_show_command_menu()

func _on_action_executed(desc: String) -> void:
	_update_party_panel()
	_update_enemy_panel(BattleSystem.battle_enemies)

func _on_damage_dealt(target_name: String, amount: int, is_heal: bool) -> void:
	if is_heal:
		_show_damage_number(target_name, amount, "green")
		return
	_show_damage_number(target_name, amount, "yellow" if _is_enemy_battler(target_name) else "red")
	var arena := _get_battle_arena()
	if _is_defeated_battler(target_name):
		if arena:
			arena.defeat_battler(target_name)
	elif arena:
		arena.flash_battler(target_name)

func _on_attack_missed(target_name: String) -> void:
	var miss := Label.new()
	miss.text = "MISS"
	miss.position = _effect_center_for(target_name) + Vector2(-42, -120)
	miss.size = Vector2(84, 38)
	miss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	miss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	miss.z_index = 20
	miss.add_theme_font_override("font", _font)
	miss.add_theme_font_size_override("font_size", 28)
	miss.add_theme_color_override("font_color", Color(0.96, 0.92, 0.65))
	miss.add_theme_color_override("font_outline_color", Color(0.18, 0.08, 0.03))
	miss.add_theme_constant_override("outline_size", 5)
	_battle_stage.add_child(miss)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(miss, "position:y", miss.position.y - 50.0, 0.65)
	tween.tween_property(miss, "modulate:a", 0.0, 0.50).set_delay(0.18)
	tween.chain().tween_callback(miss.queue_free)

func _on_cast_interrupted(target_name: String) -> void:
	# 除了战场飘字，也在行动条给出明确反馈，避免被特效或状态面板遮住。
	_turn_label.text = "—— %s 的读条被打断！——" % target_name
	_action_timeline_title.text = "%s 被打断，行动条回到起点" % target_name
	var interrupt := Label.new()
	interrupt.text = "打断！"
	interrupt.position = _effect_center_for(target_name) + Vector2(-66, -108)
	interrupt.size = Vector2(132, 54)
	interrupt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interrupt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interrupt.z_index = 100
	interrupt.add_theme_font_override("font", _font)
	interrupt.add_theme_font_size_override("font_size", 34)
	interrupt.add_theme_color_override("font_color", Color(1.0, 0.48, 0.25))
	interrupt.add_theme_color_override("font_outline_color", Color(0.20, 0.04, 0.02))
	interrupt.add_theme_constant_override("outline_size", 5)
	_battle_stage.add_child(interrupt)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(interrupt, "position:y", interrupt.position.y - 46.0, 0.64)
	tween.tween_property(interrupt, "modulate:a", 0.0, 0.48).set_delay(0.18)
	tween.chain().tween_callback(interrupt.queue_free)

func _on_attack_animation_requested(attacker_name: String, target_name: String) -> void:
	var arena := _get_battle_arena()
	if arena:
		arena.play_attack_animation(attacker_name, target_name)

func _on_attack_sfx_requested(attacker_name: String) -> void:
	if attacker_name == "李逍遥":
		_play_one_shot_sound(LI_SHOUT_SFX)
		_play_one_shot_sound(LI_SWORD_SFX)
	elif attacker_name == "赵灵儿":
		_play_one_shot_sound(LI_SWORD_SFX)

func _on_yujian_magic_cast_requested() -> void:
	var arena := _get_battle_arena()
	if arena:
		arena.play_li_magic_cast()

func _on_yujian_sword_rain_requested(target_name: String) -> void:
	_play_one_shot_sound(LI_SHOUT_SFX)
	_play_yujian_flying_sword(target_name)

func _on_yujian_magic_cast_finished() -> void:
	var arena := _get_battle_arena()
	if arena:
		arena.finish_li_magic_cast()

func _on_tianshi_fufa_requested(target_name: String) -> void:
	_play_tianshi_fufa(target_name)

func _on_li_skill_shout_requested() -> void:
	_play_one_shot_sound(LI_SHOUT_SFX)

func _on_healing_effect_requested(target_name: String) -> void:
	_play_healing_effect(target_name)

func _on_wind_skill_requested(caster_name: String, target_name: String) -> void:
	_play_wind_projectile(caster_name, target_name)

func _play_wind_projectile(caster_name: String, target_name: String) -> void:
	if target_name.is_empty():
		return
	var wind := TextureRect.new()
	wind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wind.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wind.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wind.size = Vector2(88, 100)
	wind.pivot_offset = wind.size * 0.5
	wind.position = _effect_center_for(caster_name) - wind.size * 0.5
	wind.z_index = 7
	_battle_stage.add_child(wind)
	var target_size := Vector2(270, 300)
	var target_position := _effect_position_for(target_name, target_size, Vector2(0, -0.08))
	var flight := create_tween()
	flight.tween_property(wind, "position", target_position, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flight.parallel().tween_property(wind, "size", target_size, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flight.tween_interval(0.30)
	flight.tween_property(wind, "modulate:a", 0.0, 0.12)
	flight.tween_callback(wind.queue_free)
	for frame_number in range(WIND_FRAME_COUNT):
		wind.texture = load("res://assets/effects/wind/skill002_hit_%04d.png" % frame_number) as Texture2D
		await get_tree().create_timer(0.075, false).timeout

func _on_lightning_strike_requested(target_name: String) -> void:
	_play_one_shot_sound(LIGHTNING_SFX)
	_play_lightning_strike(target_name)

func _on_elemental_spell_requested(spell_name: String, target_name: String) -> void:
	if spell_name == "炎咒":
		_play_one_shot_sound(FIRE_SPELL_SFX)
		_play_elemental_effect(target_name, "res://assets/effects/fire/%02d.png", FIRE_FRAME_COUNT, Vector2(280, 280), 0.06)
	elif spell_name == "土咒":
		_play_one_shot_sound(EARTH_SPELL_SFX)
		_play_elemental_effect(target_name, "res://assets/effects/mud/effect_d05_%02d.png", MUD_FRAME_COUNT, Vector2(270, 180), 0.10)
	elif spell_name == "流星火雨":
		_play_elemental_effect(target_name, "res://assets/effects/meteor/%02d.png", METEOR_FRAME_COUNT, Vector2(260, 260), 0.05)

func _on_zhao_magic_cast_requested(_target_name: String) -> void:
	var arena := _get_battle_arena()
	if arena:
		arena.play_linger_magic_cast()

func _on_zhao_magic_cast_finished() -> void:
	var arena := _get_battle_arena()
	if arena:
		arena.finish_linger_magic_cast()

func _get_battle_arena() -> Node:
	return get_tree().get_first_node_in_group("battle_arena")

func _on_sword_slash_requested(attacker_name: String, target_name: String) -> void:
	if attacker_name == "赵灵儿":
		_play_linger_normal_attack_effect(attacker_name)
	else:
		_play_sword_slash(attacker_name, target_name)

func _play_one_shot_sound(sound: AudioStream) -> void:
	var player := AudioStreamPlayer.new()
	player.bus = &"SFX"
	player.stream = sound
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _play_battle_music() -> void:
	if not _battle_music_player:
		_battle_music_player = AudioStreamPlayer.new()
		_battle_music_player.stream = BATTLE_MUSIC
		_battle_music_player.bus = &"Music"
		add_child(_battle_music_player)
		_battle_music_player.finished.connect(func():
			if GameData.current_state == GameData.GameState.BATTLE:
				_battle_music_player.play())
	if _music_fade_tween:
		_music_fade_tween.kill()
	if not _battle_music_player.playing:
		_battle_music_player.volume_db = -40.0
		_battle_music_player.play()
	_music_fade_tween = create_tween()
	_music_fade_tween.tween_property(_battle_music_player, "volume_db", -4.0, 0.75)

func _stop_battle_music() -> void:
	if not _battle_music_player or not _battle_music_player.playing:
		return
	if _music_fade_tween:
		_music_fade_tween.kill()
	_music_fade_tween = create_tween()
	_music_fade_tween.tween_property(_battle_music_player, "volume_db", -40.0, 0.55)
	_music_fade_tween.tween_callback(_battle_music_player.stop)

func _play_victory_music() -> void:
	var player := AudioStreamPlayer.new()
	player.stream = VICTORY_MUSIC
	player.bus = &"Music"
	player.volume_db = -40.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	var fade := create_tween()
	fade.tween_property(player, "volume_db", -3.0, 0.45)
	var remaining_time := maxf(player.stream.get_length() - 1.15, 0.0)
	fade.tween_interval(remaining_time)
	fade.tween_property(player, "volume_db", -40.0, 0.70)

func _play_sword_slash(attacker_name: String, target_name: String) -> void:
	var slash := TextureRect.new()
	slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slash.size = Vector2(230, 250)
	slash.position = _effect_position_for(target_name, slash.size, Vector2(0, -0.05))
	slash.flip_h = false
	slash.z_index = 7
	_battle_stage.add_child(slash)
	for frame_number in range(1, SWORD_SLASH_FRAME_COUNT + 1):
		slash.texture = load("res://assets/effects/sword/attack1_fire%04d.png" % frame_number) as Texture2D
		await get_tree().create_timer(0.07, false).timeout
	slash.queue_free()

func _play_linger_normal_attack_effect(caster_name: String) -> void:
	var slash := TextureRect.new()
	slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slash.size = Vector2(300, 150)
	var arena := _get_battle_arena()
	var caster_center: Vector2 = _effect_center_for(caster_name)
	if arena and arena.has_method("get_battler_current_screen_position"):
		caster_center = arena.get_battler_current_screen_position(caster_name)
	# 普攻剑光跟着赵灵儿的冲刺位置走；法术和伤害显示仍固定在站位点。
	slash.position = caster_center - slash.size * 0.5 + Vector2(0, slash.size.y * 0.08)
	slash.z_index = 7
	_battle_stage.add_child(slash)
	for frame_number in range(1, LINGER_SLASH_FRAME_COUNT + 1):
		slash.texture = load("res://assets/effects/dsw/battleAttackSkill_21000%d.png" % frame_number) as Texture2D
		await get_tree().create_timer(0.075, false).timeout
	slash.queue_free()

func _play_falling_swords(target_name: String) -> void:
	var target_center := _effect_center_for(target_name)
	for sword_index in range(10):
		var sword := TextureRect.new()
		sword.texture = FALLING_SWORD_TEXTURE
		sword.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sword.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sword.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sword.size = Vector2(44, 122)
		sword.pivot_offset = sword.size * 0.5
		sword.rotation = deg_to_rad(randf_range(-18.0, 18.0))
		var landing_x := target_center.x + randf_range(-88.0, 88.0)
		var landing_y := target_center.y + randf_range(-10.0, 115.0)
		sword.position = Vector2(landing_x + randf_range(-75.0, 75.0), -150.0 - randf_range(0.0, 260.0))
		sword.z_index = 8
		_battle_stage.add_child(sword)
		var tween := create_tween()
		tween.tween_interval(sword_index * 0.045)
		tween.tween_property(sword, "position", Vector2(landing_x, landing_y), 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# 每一把剑落下时各播放一次剑鸣/破空声，形成连续剑雨的节奏。
		tween.tween_callback(_play_one_shot_sound.bind(LI_SWORD_SFX))
		tween.tween_property(sword, "modulate:a", 0.0, 0.15)
		tween.tween_callback(sword.queue_free)

func _play_yujian_flying_sword(target_name: String) -> void:
	var caster_center := _effect_center_for("李逍遥")
	var target_center := _effect_center_for(target_name)
	var sword := TextureRect.new()
	sword.texture = FALLING_SWORD_TEXTURE
	sword.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sword.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sword.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sword.size = Vector2(42, 118)
	sword.pivot_offset = sword.size * 0.5
	# Start near Li Xiaoyao's raised hand, rather than at his feet.
	sword.position = caster_center + Vector2(18, -82) - sword.pivot_offset
	var direction := (target_center - sword.position - sword.pivot_offset).normalized()
	# sword.png's blade points downward at rotation 0, so offset from its down-axis.
	sword.rotation = direction.angle() - PI * 0.5
	sword.z_index = 18
	_battle_stage.add_child(sword)
	# The sword first rises above the target, then turns its tip down before
	# transforming into the existing falling-sword effect.
	var sky_position := target_center + Vector2(-21, -285)
	var flight := create_tween()
	flight.tween_property(sword, "position", sky_position, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flight.parallel().tween_property(sword, "scale", Vector2(1.22, 1.22), 0.75)
	# At rotation 0 this sword's blade points down towards the enemies.
	flight.tween_property(sword, "rotation", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flight.tween_callback(_play_falling_swords.bind(target_name))
	flight.tween_property(sword, "modulate:a", 0.0, 0.12)
	flight.tween_callback(sword.queue_free)

func _play_tianshi_fufa(target_name: String) -> void:
	var target_center := _effect_center_for(target_name)
	var talisman := TextureRect.new()
	talisman.texture = FU_TALISMAN_TEXTURE
	talisman.mouse_filter = Control.MOUSE_FILTER_IGNORE
	talisman.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	talisman.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	talisman.size = Vector2(82, 160)
	talisman.pivot_offset = talisman.size * 0.5
	talisman.position = target_center - talisman.pivot_offset + Vector2(0, -36)
	talisman.modulate.a = 0.0
	talisman.z_index = 12
	_battle_stage.add_child(talisman)
	var appear := create_tween()
	appear.tween_property(talisman, "modulate:a", 0.5, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var effect := TextureRect.new()
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	effect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	effect.size = Vector2(180, 180)
	effect.position = target_center - effect.size * 0.5 + Vector2(0, -22)
	effect.z_index = 13
	_battle_stage.add_child(effect)
	for frame_number in range(1, FU_FRAME_COUNT + 1):
		effect.texture = load("res://assets/effects/fu/%02d.png" % frame_number) as Texture2D
		await get_tree().create_timer(0.09, false).timeout
	effect.queue_free()

	var caster_center := _effect_center_for("李逍遥")
	var sword := TextureRect.new()
	sword.texture = FALLING_SWORD_TEXTURE
	sword.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sword.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sword.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sword.size = Vector2(34, 96)
	sword.pivot_offset = sword.size * 0.5
	sword.position = caster_center + Vector2(18, -74) - sword.pivot_offset
	var direction := (target_center - sword.position - sword.pivot_offset).normalized()
	sword.rotation = direction.angle() - PI * 0.5
	sword.z_index = 15
	_battle_stage.add_child(sword)
	var impact_position := target_center - sword.pivot_offset + Vector2(0, -28)
	var flight := create_tween()
	flight.set_parallel(true)
	flight.tween_property(sword, "position", impact_position, 0.52).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flight.tween_property(talisman, "modulate:a", 0.0, 0.18).set_delay(0.48)
	flight.tween_property(sword, "modulate:a", 0.0, 0.18).set_delay(0.48)
	flight.chain().tween_callback(talisman.queue_free)
	flight.tween_callback(sword.queue_free)

func _play_healing_effect(target_name: String) -> void:
	var effect := TextureRect.new()
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	effect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	effect.size = Vector2(230, 230)
	effect.position = _effect_center_for(target_name) - effect.size * 0.5 + Vector2(0, 52)
	effect.z_index = 16
	_battle_stage.add_child(effect)
	for frame_number in range(HEAL_FRAME_COUNT):
		var frame := AtlasTexture.new()
		frame.atlas = HEAL_EFFECT_ATLAS
		frame.region = Rect2(float(frame_number) * HEAL_FRAME_SIZE.x, 0.0, HEAL_FRAME_SIZE.x, HEAL_FRAME_SIZE.y)
		effect.texture = frame
		await get_tree().create_timer(0.085, false).timeout
	effect.queue_free()

func _play_lightning_strike(target_name: String) -> void:
	_play_lightning_impact(target_name)
	var lightning := TextureRect.new()
	lightning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lightning.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lightning.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lightning.size = Vector2(250, 330)
	lightning.position = _effect_position_for(target_name, lightning.size, Vector2(0, -0.12))
	lightning.z_index = 6
	_battle_stage.add_child(lightning)
	for frame_number in range(1, LIGHTNING_FRAME_COUNT + 1):
		lightning.texture = load("res://assets/effects/flash/%02d.png" % frame_number) as Texture2D
		await get_tree().create_timer(0.05, false).timeout
	lightning.queue_free()

func _play_elemental_effect(target_name: String, path_pattern: String, frame_count: int, effect_size: Vector2, frame_time: float) -> void:
	var effect := TextureRect.new()
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	effect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	effect.size = effect_size
	effect.position = _effect_position_for(target_name, effect_size, Vector2(0, 0.06))
	effect.z_index = 6
	_battle_stage.add_child(effect)
	for frame_number in range(1, frame_count + 1):
		effect.texture = load(path_pattern % frame_number) as Texture2D
		await get_tree().create_timer(frame_time, false).timeout
	effect.queue_free()

func _play_lightning_impact(target_name: String) -> void:
	var impact := TextureRect.new()
	impact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	impact.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	impact.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	impact.size = Vector2(230, 110)
	impact.position = _effect_position_for(target_name, impact.size, Vector2(0, 0.22))
	impact.z_index = 5 # Render below the lightning itself.
	_battle_stage.add_child(impact)
	for frame_number in range(1, LIGHTNING_IMPACT_FRAME_COUNT + 1):
		impact.texture = load("res://assets/effects/ak/battleAttackSkill_20_2000%d.png" % frame_number) as Texture2D
		await get_tree().create_timer(0.08, false).timeout
	impact.queue_free()

func _effect_center_for(target_name: String) -> Vector2:
	var arena := _get_battle_arena()
	if arena:
		return arena.get_battler_screen_position(target_name)
	return Vector2(640, 360)

func _effect_position_for(target_name: String, effect_size: Vector2, offset_ratio: Vector2) -> Vector2:
	var center := _effect_center_for(target_name)
	return center - effect_size * 0.5 + Vector2(offset_ratio.x * effect_size.x, offset_ratio.y * effect_size.y)

func _show_damage_number(target_name: String, amount: int, color_name: String) -> void:
	var damage_text := str(maxi(amount, 0))
	var digit_size := Vector2(36, 61)
	var number := HBoxContainer.new()
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.add_theme_constant_override("separation", -5)
	number.position = _effect_center_for(target_name) + Vector2(-damage_text.length() * 16.0, -128.0)
	number.z_index = 20
	_battle_stage.add_child(number)
	for character in damage_text:
		var digit := TextureRect.new()
		digit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		digit.custom_minimum_size = digit_size
		digit.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		digit.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		digit.texture = load(DAMAGE_FONT_PATH % [color_name, character]) as Texture2D
		number.add_child(digit)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(number, "position:y", number.position.y - 72.0, 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(number, "modulate:a", 0.0, 0.72).set_delay(0.18)
	tween.chain().tween_callback(number.queue_free)

func _is_enemy_battler(character_name: String) -> bool:
	return BattleSystem.battle_enemies.any(func(enemy): return enemy.char_name == character_name)

func _is_defeated_enemy(character_name: String) -> bool:
	return BattleSystem.battle_enemies.any(func(enemy): return enemy.char_name == character_name and enemy.hp <= 0)

func _is_defeated_battler(character_name: String) -> bool:
	return _is_defeated_enemy(character_name) or BattleSystem.combat_party.any(func(member): return member.char_name == character_name and member.hp <= 0)

# ============================================================
#  指令菜单
# ============================================================
func _cancel_sub_menu() -> void:
	# 返回主菜单时同步重置战斗状态，否则攻击按钮会被旧的“选技能/物品”状态忽略。
	if BattleSystem.state in [BattleSystem.BState.SELECT_SKILL, BattleSystem.BState.SELECT_ITEM]:
		BattleSystem.state = BattleSystem.BState.SELECT_COMMAND
		BattleSystem.selected_action = ""
		BattleSystem.selected_skill = null
		BattleSystem.selected_item = null
	_show_command_menu()

func _go_back_one_battle_menu() -> bool:
	match BattleSystem.state:
		BattleSystem.BState.SELECT_TARGET:
			var arena := _get_battle_arena()
			if arena and arena.has_method("cancel_target_selection"):
				arena.cancel_target_selection()
			match BattleSystem.selected_action:
				"skill":
					BattleSystem.state = BattleSystem.BState.SELECT_SKILL
					_show_skill_menu()
				"item":
					BattleSystem.state = BattleSystem.BState.SELECT_ITEM
					_show_item_menu()
				_:
					BattleSystem.state = BattleSystem.BState.SELECT_COMMAND
					BattleSystem.selected_action = ""
					_show_command_menu()
			return true
		BattleSystem.BState.SELECT_SKILL, BattleSystem.BState.SELECT_ITEM:
			_cancel_sub_menu()
			return true
	return false

func _show_command_menu() -> void:
	_hide_all_panels()
	preload("res://scripts/ui/ui_motion.gd").reveal(_cmd_panel, 0.16)
	_cmd_panel.visible = true
	_command_artwork.visible = true
	_command_artwork.texture = COMMAND_ART["default"]
func _setup_command_buttons() -> void:
	for index in range(_command_buttons.size()):
		var button := _command_buttons[index]
		button.add_theme_font_override("font", _font)
		button.pressed.connect(_on_command_pressed.bind(CMD_KEYS[index]))
		button.mouse_entered.connect(_set_command_art_highlight.bind(CMD_KEYS[index]))
		button.mouse_exited.connect(_clear_command_art_highlight)

func _set_command_art_highlight(command: String) -> void:
	_command_artwork.texture = COMMAND_ART.get(command, COMMAND_ART["default"])

func _clear_command_art_highlight() -> void:
	_command_artwork.texture = COMMAND_ART["default"]

func _on_command_pressed(cmd: String) -> void:
	BattleSystem.select_command(cmd)
	if cmd == "skill": _show_skill_menu()
	elif cmd == "item": _show_item_menu()
	elif cmd == "attack": _show_target_menu(true)

func _show_skill_menu() -> void:
	_hide_all_panels()
	_sub_menu.visible = true
	_clear_children(_sub_menu_list)

	for skill in _current_char.skills:
		var btn := Button.new()
		# 技能列表有滚动条时可用宽度更窄；读条说明放进提示，避免长文字把 VBox 撑出面板。
		btn.text = "%s  %d气" % [skill.skill_name, skill.mp_cost]
		btn.tooltip_text = "%s\n消耗 %d 真气%s\n%s" % [skill.skill_name, skill.mp_cost, " · 读条 %.1f 秒" % skill.cast_time if skill.cast_time > 0.0 else " · 即时", skill.description]
		btn.custom_minimum_size = Vector2(0, 28)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.flat = true
		btn.add_theme_font_override("font", _font)
		btn.add_theme_font_size_override("font_size", 11)
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.add_theme_color_override("font_color", Color(0.34, 0.16, 0.05))
		btn.add_theme_color_override("font_hover_color", Color(0.52, 0.28, 0.09))
		btn.add_theme_color_override("font_pressed_color", Color(0.46, 0.23, 0.07))
		btn.add_theme_color_override("font_focus_color", Color(0.52, 0.28, 0.09))
		# 法力不足时仍显示技能，改为灰色且不可点击，方便玩家知道该技能存在及所需 MP。
		btn.add_theme_color_override("font_disabled_color", Color(0.42, 0.42, 0.42))
		btn.disabled = skill.mp_cost > _current_char.mp
		btn.pressed.connect(_on_skill_pressed.bind(skill))
		_sub_menu_list.add_child(btn)
	_reset_sub_menu_scroll()

func _on_skill_pressed(skill) -> void:
	BattleSystem.select_skill(skill)
	if BattleSystem.state == BattleSystem.BState.SELECT_TARGET:
		_show_target_menu(skill.target_type == "single_enemy")
	else:
		# All-target skills begin immediately; remove the old skill buttons so a
		# second click cannot overwrite the skill while its animation is running.
		_hide_all_panels()

func _show_item_menu() -> void:
	_hide_all_panels()
	_sub_menu.visible = true
	_clear_children(_sub_menu_list)

	for item in GameData.inventory:
		var btn := Button.new()
		btn.text = "　%s x%d" % [item.item_name, item.count]
		btn.custom_minimum_size = Vector2(0, 28)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.flat = true
		btn.add_theme_font_override("font", _font)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", Color(0.34, 0.16, 0.05))
		btn.add_theme_color_override("font_hover_color", Color(0.52, 0.28, 0.09))
		btn.add_theme_color_override("font_pressed_color", Color(0.46, 0.23, 0.07))
		btn.add_theme_color_override("font_focus_color", Color(0.52, 0.28, 0.09))
		btn.pressed.connect(_on_item_pressed.bind(item))
		_sub_menu_list.add_child(btn)
	_reset_sub_menu_scroll()

func _reset_sub_menu_scroll() -> void:
	_sub_menu_scroll.scroll_horizontal = 0
	_sub_menu_scroll.scroll_vertical = 0
	# 容器在本帧末才会根据新增按钮重新计算高度，因此再重置一次，
	# 防止从物品栏切回技能时保留旧的滚动位置。
	_sub_menu_scroll.call_deferred("set_scroll_vertical", 0)

func _on_item_pressed(item) -> void:
	BattleSystem.select_item(item)
	_show_target_menu(false)

func _show_target_menu(is_enemy_target: bool) -> void:
	# 只剩一个存活敌人时直接锁定，省去一次没有意义的点选。
	if is_enemy_target:
		var alive_enemies: Array = BattleSystem.battle_enemies.filter(func(enemy): return enemy.hp > 0)
		if alive_enemies.size() == 1:
			_on_target_pressed(BattleSystem.battle_enemies.find(alive_enemies[0]), true)
			return
	_hide_all_panels()
	_targeting_enemies = is_enemy_target
	_turn_label.text = "请选择%s（移到角色上高亮，左键确认）" % ("敌人" if is_enemy_target else "队友")
	_action_gauge_label.text = "请选择%s" % ("敌人" if is_enemy_target else "队友")
	_action_timeline_title.text = "请选择%s（其他人的跑条仍在继续）" % ("敌人" if is_enemy_target else "队友")
	var arena := _get_battle_arena()
	if arena:
		arena.begin_target_selection(is_enemy_target)

func _confirm_battler_target(target_name: String) -> void:
	var targets: Array = BattleSystem.battle_enemies if _targeting_enemies else BattleSystem.combat_party
	for index in range(targets.size()):
		if targets[index].char_name == target_name:
			_on_target_pressed(index, _targeting_enemies)
			return

func _on_target_pressed(idx: int, is_enemy: bool) -> void:
	_hide_all_panels()
	BattleSystem.confirm_target(idx, is_enemy)

# ============================================================
#  队伍 / 敌人状态
# ============================================================
func _update_party_panel() -> void:
	_clear_children(_party_panel)
	for p in BattleSystem.combat_party:
		_party_panel.add_child(_make_status_card(p, false))

func _update_enemy_panel(enemies: Array) -> void:
	_clear_children(_enemy_panel)
	for e in enemies:
		var statuses: Array = []
		if BattleSystem.is_vulnerable(e.char_name):
			statuses.append({
				"icon_path": "res://assets/ui/other/01_UI_Resources/A1ICON/MaxSP.png",
				"description": "易伤：受到的伤害提高。",
				"color": Color(1.0, 0.67, 0.22),
			})
		if BattleSystem.is_sleeping(e.char_name):
			statuses.append({"symbol": "睡", "description": "昏睡：还会跳过 %d 次行动。" % BattleSystem.sleeping_turns_remaining(e.char_name), "color": Color(0.55, 0.72, 1.0)})
		if e.hp <= 0:
			statuses.append({"symbol": "败", "description": "已被击败，无法继续行动。", "color": Color(0.55, 0.55, 0.55)})
		_enemy_panel.add_child(_make_status_card(e, true, statuses))

func _make_status_card(battler, is_enemy: bool, statuses: Array = []) -> Panel:
	var template := _enemy_status_card_template if is_enemy else _status_card_template
	var card := template.duplicate() as Panel
	card.visible = true
	card.set_script(BATTLE_STATUS_CARD)
	var portrait_sources: Dictionary = PORTRAIT_TEXTURE_PATHS.duplicate()
	var arena := _get_battle_arena()
	if not portrait_sources.has(battler.char_name) and arena and arena.has_method("get_idle_portrait"):
		var idle_portrait := arena.get_idle_portrait(battler.char_name) as Texture2D
		if idle_portrait:
			portrait_sources[battler.char_name] = idle_portrait
	card.setup(battler, is_enemy, _font, portrait_sources, statuses)
	return card

# ============================================================
#  辅助
# ============================================================
func _hide_all_panels() -> void:
	_cmd_panel.visible = false
	_command_artwork.visible = false
	_sub_menu.visible = false
	_target_panel.visible = false

func _set_battle_hud_visible(should_show: bool) -> void:
	_party_panel.visible = should_show
	_enemy_panel.visible = should_show
	_turn_label.visible = false
	_action_gauge.visible = false
	_action_timeline.visible = should_show
	$BattleStage/BattleTitle.visible = should_show

func _clear_children(node: Node) -> void:
	for c in node.get_children(): c.free()

func _show_experience_rewards() -> void:
	var reward_label := _victory_panel.get_node_or_null("ExperienceRewards") as Label
	if not reward_label:
		reward_label = Label.new()
		reward_label.name = "ExperienceRewards"
		reward_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		reward_label.position = Vector2(-370, 240)
		reward_label.size = Vector2(740, 200)
		reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reward_label.add_theme_font_override("font", _font)
		reward_label.add_theme_font_size_override("font_size", 20)
		reward_label.add_theme_color_override("font_color", Color("ffe4a3"))
		reward_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		reward_label.add_theme_constant_override("shadow_offset_x", 2)
		reward_label.add_theme_constant_override("shadow_offset_y", 2)
		_victory_panel.add_child(reward_label)
	var lines: PackedStringArray = []
	for reward in BattleSystem.victory_rewards:
		lines.append("%s  ·  经验 +%d" % [reward.name, reward.experience])
		if reward.after > reward.before:
			lines.append("升级！Lv.%d → Lv.%d  体力 +%d  真气 +%d" % [reward.before, reward.after, reward.gains.max_hp, reward.gains.max_mp])
			lines.append("攻击 +%d  防御 +%d  身法 +%d" % [reward.gains.attack, reward.gains.defense, reward.gains.speed])
		reward_label.text = "\n".join(lines)
	preload("res://scripts/ui/ui_motion.gd").reveal(reward_label, 0.35)
